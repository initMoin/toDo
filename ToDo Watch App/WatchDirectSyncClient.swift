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
         URLQueryItem(name: "select", value: "id,task,is_done,lifecycle_state,trashed_at,due_at,reminder_intent,created_at,updated_at"),
         URLQueryItem(name: "user_id", value: "eq.\(authSession.userID.uuidString.lowercased())"),
         URLQueryItem(name: "order", value: "updated_at.desc")
      ]

      let records: [WatchRemoteToDoRecord] = try await send(
         method: "GET",
         components: components,
         authSession: authSession
      )

      let activeRecords = records.filter { $0.trashedAt == nil }
      let todoIDs = activeRecords.map(\.id)
      let nanoDos = try await fetchNanoDos(todoIDs: todoIDs, authSession: authSession)
      let nanoDosByToDoID = Dictionary(grouping: nanoDos, by: \.todoID)

      return activeRecords.map { record in
         WatchToDoItem(
            id: record.id.uuidString,
            cloudID: record.id,
            task: record.task,
            isDone: record.isDone,
            lifecycleState: WatchToDoState(rawValue: record.lifecycleState) ?? .active,
            trashedAt: record.trashedAt,
            dueDate: record.dueAt,
            isTimeSensitive: record.reminderIntent == "timeSensitive",
            createdAt: record.createdAt ?? .now,
            updatedAt: record.updatedAt ?? .now,
            nanoDos: (nanoDosByToDoID[record.id] ?? []).map(\.watchItem)
         )
      }
   }

   func apply(_ action: WatchToDoAction, authSession: WatchAuthSession) async throws {
      switch action.type {
      case .create:
         let id = action.cloudID ?? UUID()
         let now = Date()
         let payload = WatchToDoUpsertPayload(
            id: id,
            userID: authSession.userID,
            task: action.task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? String(localized: "New toDō"),
            notes: "",
            isDone: false,
            createdAt: now,
            updatedAt: now,
            lifecycleState: WatchToDoState.active.rawValue,
            reminderIntent: action.isTimeSensitive == true ? "timeSensitive" : "quiet",
            dueAt: action.dueDate,
            dueTimeZone: action.dueDate == nil ? nil : TimeZone.current.identifier,
            isRecurring: false,
            completeWhenAllNanoDosDone: false
         )
         try await upsert([payload], table: "todos", authSession: authSession)
      case .updateTask:
         guard let id = action.cloudID,
               let task = action.task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "task": task,
            "updated_at": Self.dateString(.now)
         ])
      case .setDueDate, .snooze:
         guard let id = action.cloudID else { return }
         let dueDate = action.type == .snooze
            ? Date().addingTimeInterval(action.snoozeSeconds ?? 900)
            : action.dueDate
         var body: [String: Any] = [
            "due_at": dueDate.map(Self.dateString) ?? NSNull(),
            "updated_at": Self.dateString(.now)
         ]
         if let isTimeSensitive = action.isTimeSensitive {
            body["reminder_intent"] = isTimeSensitive ? "timeSensitive" : "quiet"
         }
         try await patchToDo(id: id, authSession: authSession, body: body)
      case .complete:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "is_done": true,
            "lifecycle_state": WatchToDoState.done.rawValue,
            "updated_at": Self.dateString(.now)
         ])
      case .reopen:
         guard let id = action.cloudID else { return }
         try await patchToDo(id: id, authSession: authSession, body: [
            "is_done": false,
            "lifecycle_state": WatchToDoState.active.rawValue,
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
            "trashed_at": Self.dateString(.now),
            "updated_at": Self.dateString(.now)
         ])
      case .completeNanoDo, .reopenNanoDo:
         guard let nanoDoID = action.nanoDoCloudID else { return }
         try await patchNanoDo(id: nanoDoID, authSession: authSession, body: [
            "is_done": action.type == .completeNanoDo,
            "updated_at": Self.dateString(.now)
         ])
      case .deleteNanoDo:
         guard let nanoDoID = action.nanoDoCloudID else { return }
         try await deleteNanoDo(id: nanoDoID, authSession: authSession)
      case .requestRefresh, .openOnPhone:
         break
      }
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

   private func upsert<T: Encodable>(_ payloads: [T], table: String, authSession: WatchAuthSession) async throws {
      var components = restComponents(path: table)
      components.queryItems = [URLQueryItem(name: "on_conflict", value: "id")]
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

   private func send<T: Decodable>(
      method: String,
      components: URLComponents,
      authSession: WatchAuthSession,
      body: Data? = nil,
      prefer: String? = nil
   ) async throws -> T {
      let data = try await sendData(method: method, components: components, authSession: authSession, body: body, prefer: prefer)
      return try Self.decoder.decode(T.self, from: data)
   }

   private func sendEmpty(
      method: String,
      components: URLComponents,
      authSession: WatchAuthSession,
      body: Data? = nil,
      prefer: String? = nil
   ) async throws {
      _ = try await sendData(method: method, components: components, authSession: authSession, body: body, prefer: prefer)
   }

   private func sendData(
      method: String,
      components: URLComponents,
      authSession: WatchAuthSession,
      body: Data? = nil,
      prefer: String? = nil
   ) async throws -> Data {
      guard let url = components.url else {
         throw WatchDirectSyncError.invalidConfiguration
      }
      var request = URLRequest(url: url)
      request.httpMethod = method
      request.httpBody = body
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      if let prefer {
         request.setValue(prefer, forHTTPHeaderField: "Prefer")
      }

      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw WatchDirectSyncError.invalidResponse
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
         throw WatchDirectSyncError.server(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
      }
      return data
   }

   private func restComponents(path: String) -> URLComponents {
      URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/\(path)"), resolvingAgainstBaseURL: false)!
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
         if let date = parseDate(value) {
            return date
         }
         throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
      }
      return decoder
   }()

   nonisolated private static func dateString(_ date: Date) -> String {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return formatter.string(from: date)
   }

   nonisolated private static func parseDate(_ value: String) -> Date? {
      let fractionalFormatter = ISO8601DateFormatter()
      fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = fractionalFormatter.date(from: value) {
         return date
      }

      let wholeSecondFormatter = ISO8601DateFormatter()
      wholeSecondFormatter.formatOptions = [.withInternetDateTime]
      return wholeSecondFormatter.date(from: value)
   }
}

private struct WatchRemoteToDoRecord: Decodable {
   let id: UUID
   let task: String
   let isDone: Bool
   let lifecycleState: String
   let trashedAt: Date?
   let dueAt: Date?
   let reminderIntent: String
   let createdAt: Date?
   let updatedAt: Date?
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
      WatchNanoDoItem(
         id: id.uuidString,
         cloudID: id,
         task: task,
         isDone: isDone,
         dueDate: dueAt,
         updatedAt: updatedAt ?? .now
      )
   }
}

private struct WatchToDoUpsertPayload: Encodable {
   let id: UUID
   let userID: UUID
   let task: String
   let notes: String
   let isDone: Bool
   let createdAt: Date
   let updatedAt: Date
   let lifecycleState: String
   let reminderIntent: String
   let dueAt: Date?
   let dueTimeZone: String?
   let isRecurring: Bool
   let completeWhenAllNanoDosDone: Bool
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
   var nilIfEmpty: String? {
      isEmpty ? nil : self
   }
}
