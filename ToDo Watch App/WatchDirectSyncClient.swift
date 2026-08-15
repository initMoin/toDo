import Foundation

struct WatchDirectSyncClient {
   private let supabaseURL: URL
   private let publishableKey: String
   private let session: URLSession

   init?(
      bundle: Bundle = .main,
      session: URLSession = .shared
   ) {
      guard let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseURL = URL(string: urlString),
            let publishableKey = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty
      else {
         return nil
      }

      self.supabaseURL = supabaseURL
      self.publishableKey = publishableKey
      self.session = session
   }

   func fetchToDos(authSession: WatchAuthSession) async throws -> [WatchToDoItem] {
      var components = restComponents(path: "todos")
      components.queryItems = [
         URLQueryItem(name: "select", value: "id,task,notes,is_done,lifecycle_state,due_at,reminder_intent,created_at,updated_at,completed_at,is_recurring,recurrence_unit,recurrence_interval,recurrence_mode,recurrence_count,complete_when_all_nanodos_done"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())"),
         URLQueryItem(name: "order", value: "updated_at.desc")
      ]

      let records: [WatchRemoteToDoRecord] = try await send(method: "GET", components: components, authSession: authSession)
      let activeRecords = records.filter { $0.lifecycleState != WatchToDoState.trashed.rawValue }
      let todoIDs = activeRecords.map(\.id)
      let nanoDos = try await fetchNanoDos(todoIDs: todoIDs, authSession: authSession)
      let nanoDosByToDoID = Dictionary(grouping: nanoDos, by: \.todoID)
      let tagsByToDoID = (try? await fetchTags(todoIDs: todoIDs, authSession: authSession)) ?? [:]

      return activeRecords.map { record in
         WatchToDoItem(
            id: record.id.uuidString,
            cloudID: record.id,
            task: record.task,
            isDone: record.isDone,
            lifecycleState: WatchToDoState(rawValue: record.lifecycleState) ?? .active,
            trashedAt: nil,
            dueDate: record.dueAt,
            isTimeSensitive: record.reminderIntent == "timeSensitive",
            createdAt: record.createdAt ?? .now,
            updatedAt: record.updatedAt ?? .now,
            completedAt: record.completedAt,
            notes: record.notes ?? "",
            tags: tagsByToDoID[record.id] ?? [],
            recurrenceSummary: recurrenceSummary(for: record),
            recurrenceUnitRaw: record.recurrenceUnit,
            recurrenceInterval: record.recurrenceInterval,
            recurrenceModeRaw: record.recurrenceMode,
            recurrenceCount: record.recurrenceCount,
            completeWhenAllNanoDosDone: record.completeWhenAllNanoDosDone ?? false,
            nanoDos: (nanoDosByToDoID[record.id] ?? []).map(\.watchItem)
         )
      }
   }

   func apply(_ action: WatchToDoAction, authSession: WatchAuthSession) async throws {
      switch action.type {
      case .create:
         try await create(action, authSession: authSession)
      case .updateTask:
         guard let id = action.cloudID,
               let task = action.task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "task": task,
            "updated_at": Self.dateString(.now)
         ])
      case .updateNotes:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "notes": action.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "updated_at": Self.dateString(.now)
         ])
      case .setDueDate, .snooze:
         try await setDueDate(action, authSession: authSession)
      case .setRecurrence:
         try await setRecurrence(action, authSession: authSession)
      case .setLocationReminder:
         // Supabase todos do not currently expose location-reminder columns. Paired-phone
         // sync persists these through SwiftData and schedules monitoring on iPhone.
         return
      case .updateTags:
         guard let id = action.cloudID,
               let tagNames = action.tagNames else { return }
         try await replaceTags(tagNames: tagNames, todoID: id, authSession: authSession)
      case .complete:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "is_done": true,
            "lifecycle_state": WatchToDoState.done.rawValue,
            "completed_at": Self.dateString(.now),
            "updated_at": Self.dateString(.now)
         ])
      case .reopen:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "is_done": false,
            "lifecycle_state": WatchToDoState.active.rawValue,
            "completed_at": NSNull(),
            "updated_at": Self.dateString(.now)
         ])
      case .archive:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "lifecycle_state": WatchToDoState.archived.rawValue,
            "updated_at": Self.dateString(.now)
         ])
      case .trash:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "lifecycle_state": WatchToDoState.trashed.rawValue,
            "updated_at": Self.dateString(.now)
         ])
      case .completeNanoDo, .reopenNanoDo:
         guard let nanoDoID = action.nanoDoCloudID else { return }
         try await patchNanoDo(id: nanoDoID, authSession: authSession, body: [
            "is_done": action.type == .completeNanoDo,
            "updated_at": Self.dateString(.now)
         ])
      case .createNanoDo:
         guard let todoID = action.cloudID,
               let task = action.nanoDoTask?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else { return }
         let now = Date()
         try await upsert([
            WatchNanoDoUpsertPayload(
               id: UUID(),
               todoID: todoID,
               userID: authSession.userID,
               task: task,
               isDone: false,
               dueAt: nil,
               createdAt: now,
               updatedAt: now
            )
         ], table: "nanodos", authSession: authSession)
      case .deleteNanoDo:
         guard let nanoDoID = action.nanoDoCloudID else { return }
         try await deleteNanoDo(id: nanoDoID, authSession: authSession)
      case .requestRefresh, .openOnPhone:
         break
      }
   }

   private func create(_ action: WatchToDoAction, authSession: WatchAuthSession) async throws {
      let id = action.cloudID ?? UUID()
      let now = Date()
      let hasRecurrence = action.dueDate != nil && action.recurrenceUnitRaw != nil && action.recurrenceInterval != nil && action.recurrenceModeRaw != nil
      let payload = WatchToDoUpsertPayload(
         id: id,
         userID: authSession.userID,
         task: action.task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? String(localized: "New toDō"),
         notes: action.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
         isDone: false,
         createdAt: now,
         updatedAt: now,
         completedAt: nil,
         lifecycleState: WatchToDoState.active.rawValue,
         reminderIntent: Self.reminderIntentValue(
            isTimeSensitive: action.isTimeSensitive,
            dueDate: action.dueDate
         ),
         dueAt: action.dueDate,
         dueTimeZone: action.dueDate == nil ? nil : TimeZone.current.identifier,
         isRecurring: hasRecurrence,
         recurrenceUnit: hasRecurrence ? action.recurrenceUnitRaw : nil,
         recurrenceInterval: hasRecurrence ? action.recurrenceInterval : nil,
         recurrenceMode: hasRecurrence ? action.recurrenceModeRaw : nil,
         recurrenceCount: action.recurrenceModeRaw == "finite" ? action.recurrenceCount : nil,
         recurrenceAnchorAt: hasRecurrence ? action.dueDate : nil,
         recurrenceEndAt: nil,
         completeWhenAllNanoDosDone: false
      )
      try await upsert([payload], table: "todos", authSession: authSession)

      if let tagNames = action.tagNames {
         try await replaceTags(tagNames: tagNames, todoID: id, authSession: authSession)
      }

      let nanoDoPayloads = (action.nanoDoTasks ?? [])
         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
         .filter { !$0.isEmpty }
         .map {
            WatchNanoDoUpsertPayload(
               id: UUID(),
               todoID: id,
               userID: authSession.userID,
               task: $0,
               isDone: false,
               dueAt: nil,
               createdAt: now,
               updatedAt: now
            )
         }
      if !nanoDoPayloads.isEmpty {
         try await upsert(nanoDoPayloads, table: "nanodos", authSession: authSession)
      }
   }

   private func setDueDate(_ action: WatchToDoAction, authSession: WatchAuthSession) async throws {
      guard let id = action.cloudID else { return }
      let dueDate = action.type == .snooze ? Date().addingTimeInterval(action.snoozeSeconds ?? 900) : action.dueDate
      var body: [String: Any] = [
         "due_at": dueDate.map(Self.dateString) ?? NSNull(),
         "updated_at": Self.dateString(.now)
      ]
      if action.isTimeSensitive != nil || action.dueDate != nil || action.type == .snooze {
         body["reminder_intent"] = Self.reminderIntentValue(
            isTimeSensitive: action.isTimeSensitive,
            dueDate: dueDate
         )
      }
      if dueDate == nil {
         body["is_recurring"] = false
         body["recurrence_unit"] = NSNull()
         body["recurrence_interval"] = NSNull()
         body["recurrence_mode"] = NSNull()
         body["recurrence_count"] = NSNull()
         body["recurrence_anchor_at"] = NSNull()
         body["recurrence_end_at"] = NSNull()
      }
      try await patchToDo(id: id, authSession: authSession, body: body)
   }

   private func setRecurrence(_ action: WatchToDoAction, authSession: WatchAuthSession) async throws {
      guard let id = action.cloudID else { return }
      guard let unit = action.recurrenceUnitRaw,
            let interval = action.recurrenceInterval,
            interval > 0,
            let mode = action.recurrenceModeRaw else {
         try await patchToDo(id: id, authSession: authSession, body: clearedRecurrenceBody())
         return
      }

      try await patchToDo(id: id, authSession: authSession, body: [
         "is_recurring": true,
         "recurrence_unit": unit,
         "recurrence_interval": interval,
         "recurrence_mode": mode,
         "recurrence_count": mode == "finite" ? (action.recurrenceCount ?? 1) : NSNull(),
         "recurrence_anchor_at": action.dueDate.map(Self.dateString) ?? NSNull(),
         "recurrence_end_at": NSNull(),
         "updated_at": Self.dateString(.now)
      ])
   }

   private func clearedRecurrenceBody() -> [String: Any] {
      [
         "is_recurring": false,
         "recurrence_unit": NSNull(),
         "recurrence_interval": NSNull(),
         "recurrence_mode": NSNull(),
         "recurrence_count": NSNull(),
         "recurrence_anchor_at": NSNull(),
         "recurrence_end_at": NSNull(),
         "updated_at": Self.dateString(.now)
      ]
   }

   private func fetchNanoDos(todoIDs: [UUID], authSession: WatchAuthSession) async throws -> [WatchRemoteNanoDoRecord] {
      guard !todoIDs.isEmpty else { return [] }
      var components = restComponents(path: "nanodos")
      components.queryItems = [
         URLQueryItem(name: "select", value: "id,todo_id,task,is_done,due_at,created_at,updated_at"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())"),
         URLQueryItem(name: "todo_id", value: "in.(\(todoIDs.map { $0.uuidString.lowercased() }.joined(separator: ",")))")
      ]
      return try await send(method: "GET", components: components, authSession: authSession)
   }

   private func fetchTags(todoIDs: [UUID], authSession: WatchAuthSession) async throws -> [UUID: [WatchTagItem]] {
      guard !todoIDs.isEmpty else { return [:] }
      var todoTagComponents = restComponents(path: "todo_tags")
      todoTagComponents.queryItems = [
         URLQueryItem(name: "select", value: "todo_id,tag_id"),
         URLQueryItem(name: "todo_id", value: "in.(\(todoIDs.map { $0.uuidString.lowercased() }.joined(separator: ",")))")
      ]
      let links: [WatchRemoteToDoTagRecord] = try await send(method: "GET", components: todoTagComponents, authSession: authSession)
      let tagIDs = Array(Set(links.map(\.tagID)))
      guard !tagIDs.isEmpty else { return [:] }

      var tagComponents = restComponents(path: "tags")
      tagComponents.queryItems = [
         URLQueryItem(name: "select", value: "id,name"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())"),
         URLQueryItem(name: "id", value: "in.(\(tagIDs.map { $0.uuidString.lowercased() }.joined(separator: ",")))")
      ]
      let tags: [WatchRemoteTagRecord] = try await send(method: "GET", components: tagComponents, authSession: authSession)
      let tagByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })

      return Dictionary(grouping: links, by: \.todoID).mapValues { links in
         links.compactMap { link in
            guard let tag = tagByID[link.tagID] else { return nil }
            return WatchTagItem(id: tag.id.uuidString, cloudID: tag.id, name: tag.name)
         }
      }
   }

   private func replaceTags(tagNames: [String], todoID: UUID, authSession: WatchAuthSession) async throws {
      let names = sanitizedTagNames(tagNames)
      try await deleteToDoTagLinks(todoID: todoID, authSession: authSession)
      guard !names.isEmpty else { return }

      let now = Date()
      let existingTags = try await fetchTags(names: names, authSession: authSession)
      let existingByName = Dictionary(uniqueKeysWithValues: existingTags.map { ($0.name.lowercased(), $0) })
      var resolvedTags: [WatchRemoteTagRecord] = []
      var newPayloads: [WatchTagUpsertPayload] = []

      for name in names {
         if let existing = existingByName[name] {
            resolvedTags.append(existing)
         } else {
            let id = UUID()
            newPayloads.append(WatchTagUpsertPayload(id: id, userID: authSession.userID, name: name, isDefault: false, createdAt: now, updatedAt: now))
            resolvedTags.append(WatchRemoteTagRecord(id: id, name: name))
         }
      }

      if !newPayloads.isEmpty {
         try await upsert(newPayloads, table: "tags", authSession: authSession)
      }
      try await upsert(
         resolvedTags.map { WatchToDoTagUpsertPayload(todoID: todoID, tagID: $0.id) },
         table: "todo_tags",
         authSession: authSession,
         onConflict: "todo_id,tag_id"
      )
   }

   private func fetchTags(names: [String], authSession: WatchAuthSession) async throws -> [WatchRemoteTagRecord] {
      guard !names.isEmpty else { return [] }
      var components = restComponents(path: "tags")
      components.queryItems = [
         URLQueryItem(name: "select", value: "id,name"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())"),
         URLQueryItem(name: "name", value: "in.(\(names.joined(separator: ",")))")
      ]
      return try await send(method: "GET", components: components, authSession: authSession)
   }

   private func deleteToDoTagLinks(todoID: UUID, authSession: WatchAuthSession) async throws {
      var components = restComponents(path: "todo_tags")
      components.queryItems = [URLQueryItem(name: "todo_id", value: "eq.\(todoID.uuidString.lowercased())")]
      try await sendEmpty(method: "DELETE", components: components, authSession: authSession)
   }

   private func sanitizedTagNames(_ names: [String]) -> [String] {
      var seen = Set<String>()
      return names
         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
         .filter { !$0.isEmpty }
         .filter { seen.insert($0).inserted }
         .prefix(5)
         .map(\.self)
   }

   private func upsert<T: Encodable>(
      _ payloads: [T],
      table: String,
      authSession: WatchAuthSession,
      onConflict: String = "id"
   ) async throws {
      var components = restComponents(path: table)
      components.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]
      try await sendEmpty(
         method: "POST",
         components: components,
         authSession: authSession,
         body: Self.encoder.encode(payloads),
         prefer: "resolution=merge-duplicates,return=minimal"
      )
   }

   private func patchToDo(id: UUID, authSession: WatchAuthSession, body: [String: Any]) async throws {
      try await patch(table: "todos", id: id, authSession: authSession, body: body)
   }

   private func patchNanoDo(id: UUID, authSession: WatchAuthSession, body: [String: Any]) async throws {
      try await patch(table: "nanodos", id: id, authSession: authSession, body: body)
   }

   private func deleteNanoDo(id: UUID, authSession: WatchAuthSession) async throws {
      var components = restComponents(path: "nanodos")
      components.queryItems = [
         URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())")
      ]
      try await sendEmpty(method: "DELETE", components: components, authSession: authSession)
   }

   private func patch(table: String, id: UUID, authSession: WatchAuthSession, body: [String: Any]) async throws {
      var components = restComponents(path: table)
      components.queryItems = [
         URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())")
      ]
      let data = try JSONSerialization.data(withJSONObject: body)
      try await sendEmpty(method: "PATCH", components: components, authSession: authSession, body: data)
   }

   private func send<T: Decodable>(method: String, components: URLComponents, authSession: WatchAuthSession, body: Data? = nil, prefer: String? = nil) async throws -> T {
      let data = try await sendData(method: method, components: components, authSession: authSession, body: body, prefer: prefer)
      return try Self.decoder.decode(T.self, from: data)
   }

   private func sendEmpty(method: String, components: URLComponents, authSession: WatchAuthSession, body: Data? = nil, prefer: String? = nil) async throws {
      _ = try await sendData(method: method, components: components, authSession: authSession, body: body, prefer: prefer)
   }

   private func sendData(method: String, components: URLComponents, authSession: WatchAuthSession, body: Data? = nil, prefer: String? = nil) async throws -> Data {
      guard let url = components.url else { throw WatchDirectSyncError.invalidConfiguration }
      var request = URLRequest(url: url)
      request.httpMethod = method
      request.httpBody = body
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }

      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else { throw WatchDirectSyncError.invalidResponse }
      guard (200..<300).contains(httpResponse.statusCode) else {
         let responseBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
         let message = responseBody?.nilIfEmpty ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
         AppLog.error("Watch direct sync HTTP \(httpResponse.statusCode): \(message)", logger: AppLog.sync)
         throw WatchDirectSyncError.server(message)
      }
      return data
   }

   private func restComponents(path: String) -> URLComponents {
      URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/\(path)"), resolvingAgainstBaseURL: false)!
   }

   private func recurrenceSummary(for record: WatchRemoteToDoRecord) -> String? {
      guard record.isRecurring == true,
            let unit = record.recurrenceUnit,
            let interval = record.recurrenceInterval,
            let mode = record.recurrenceMode else { return nil }
      let cadence = interval == 1 ? unit : "\(interval) \(unit)"
      if mode == "continuous" {
         return String(format: String(localized: "Every %@"), cadence)
      }
      return String(format: String(localized: "Every %@, %@ times"), cadence, "\(record.recurrenceCount ?? 1)")
   }

   private static let encoder: JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      encoder.dateEncodingStrategy = .custom { date, encoder in
         var container = encoder.singleValueContainer()
         try container.encode(dateString(date))
      }
      return encoder
   }()

   private static let decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .custom { decoder in
         let container = try decoder.singleValueContainer()
         let value = try container.decode(String.self)
         if let date = parseDate(value) { return date }
         throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
      }
      return decoder
   }()

   nonisolated private static func dateString(_ date: Date) -> String {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return formatter.string(from: date)
   }

   nonisolated private static func reminderIntentValue(isTimeSensitive: Bool?, dueDate: Date?) -> String {
      if isTimeSensitive == true {
         return "timeSensitive"
      }

      return dueDate == nil ? "soft" : "due"
   }

   nonisolated private static func parseDate(_ value: String) -> Date? {
      let fractionalFormatter = ISO8601DateFormatter()
      fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = fractionalFormatter.date(from: value) { return date }
      let wholeSecondFormatter = ISO8601DateFormatter()
      wholeSecondFormatter.formatOptions = [.withInternetDateTime]
      return wholeSecondFormatter.date(from: value)
   }
}

private struct WatchRemoteToDoRecord: Decodable {
   let id: UUID
   let task: String
   let notes: String?
   let isDone: Bool
   let lifecycleState: String
   let dueAt: Date?
   let reminderIntent: String
   let createdAt: Date?
   let updatedAt: Date?
   let completedAt: Date?
   let isRecurring: Bool?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let completeWhenAllNanoDosDone: Bool?
}

private struct WatchRemoteNanoDoRecord: Decodable {
   let id: UUID
   let todoID: UUID
   let task: String
   let isDone: Bool
   let dueAt: Date?
   let createdAt: Date?
   let updatedAt: Date?

   var watchItem: WatchNanoDoItem {
      WatchNanoDoItem(id: id.uuidString, cloudID: id, task: task, isDone: isDone, dueDate: dueAt, updatedAt: updatedAt ?? .now)
   }
}

private struct WatchRemoteToDoTagRecord: Decodable {
   let todoID: UUID
   let tagID: UUID
}

private struct WatchRemoteTagRecord: Codable {
   let id: UUID
   let name: String
}

private struct WatchToDoUpsertPayload: Encodable {
   let id: UUID
   let userID: UUID
   let task: String
   let notes: String
   let isDone: Bool
   let createdAt: Date
   let updatedAt: Date
   let completedAt: Date?
   let lifecycleState: String
   let reminderIntent: String
   let dueAt: Date?
   let dueTimeZone: String?
   let isRecurring: Bool
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Date?
   let recurrenceEndAt: Date?
   let completeWhenAllNanoDosDone: Bool

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case task
      case notes
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
      case completedAt = "completed_at"
      case lifecycleState = "lifecycle_state"
      case reminderIntent = "reminder_intent"
      case dueAt = "due_at"
      case dueTimeZone = "due_time_zone"
      case isRecurring = "is_recurring"
      case recurrenceUnit = "recurrence_unit"
      case recurrenceInterval = "recurrence_interval"
      case recurrenceMode = "recurrence_mode"
      case recurrenceCount = "recurrence_count"
      case recurrenceAnchorAt = "recurrence_anchor_at"
      case recurrenceEndAt = "recurrence_end_at"
      case completeWhenAllNanoDosDone = "complete_when_all_nanodos_done"
   }
}

private struct WatchNanoDoUpsertPayload: Encodable {
   let id: UUID
   let todoID: UUID
   let userID: UUID
   let task: String
   let isDone: Bool
   let dueAt: Date?
   let createdAt: Date
   let updatedAt: Date

   enum CodingKeys: String, CodingKey {
      case id
      case todoID = "todo_id"
      case userID = "user_id"
      case task
      case isDone = "is_done"
      case dueAt = "due_at"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
   }
}

private struct WatchTagUpsertPayload: Encodable {
   let id: UUID
   let userID: UUID
   let name: String
   let isDefault: Bool
   let createdAt: Date
   let updatedAt: Date

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case name
      case isDefault = "is_default"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
   }
}

private struct WatchToDoTagUpsertPayload: Encodable {
   let todoID: UUID
   let tagID: UUID

   enum CodingKeys: String, CodingKey {
      case todoID = "todo_id"
      case tagID = "tag_id"
   }
}

enum WatchDirectSyncError: LocalizedError {
   case invalidConfiguration
   case invalidResponse
   case server(String)

   var errorDescription: String? {
      switch self {
      case .invalidConfiguration:
         return String(localized: "Direct Watch sync is not configured.")
      case .invalidResponse:
         return String(localized: "Direct Watch sync returned an invalid response.")
      case .server(let message):
         return message
      }
   }
}

private extension String {
   var nilIfEmpty: String? { isEmpty ? nil : self }
}
