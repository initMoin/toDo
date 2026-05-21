import Foundation

struct WatchDirectSyncClient {
   private let supabaseURL: URL
   private let publishableKey: String

   init?() {
      guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty else {
         return nil
      }

      self.supabaseURL = url
      self.publishableKey = publishableKey
   }

   func fetchToDos(session: WatchAuthSession, limit: Int = 30) async throws -> [WatchToDoItem] {
      let select = "id,user_id,task,is_done,created_at,updated_at,lifecycle_state,trashed_at,reminder_intent,due_at"
      let endpoint = restURL(path: "todos", queryItems: [
         URLQueryItem(name: "select", value: select),
         URLQueryItem(name: "user_id", value: "eq.\(session.userID.uuidString.lowercased())"),
         URLQueryItem(name: "lifecycle_state", value: "in.(active,done)"),
         URLQueryItem(name: "order", value: "updated_at.desc"),
         URLQueryItem(name: "limit", value: "\(limit)")
      ])
      let data = try await data(for: authorizedRequest(url: endpoint, session: session))
      return try JSONDecoder.watchBridge.decode([RemoteToDoRecord].self, from: data).map(WatchToDoItem.init(record:))
   }

   func apply(_ action: WatchToDoAction, session: WatchAuthSession) async throws {
      switch action.type {
      case .requestRefresh, .openOnPhone:
         return
      case .create:
         try await create(action, session: session)
      case .complete, .reopen, .setDueDate, .snooze:
         try await update(action, session: session)
      }
   }

   private func create(_ action: WatchToDoAction, session: WatchAuthSession) async throws {
      let task = action.task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !task.isEmpty else { throw DirectSyncError.invalidAction("Add a task before saving.") }

      let now = Date()
      let dueDate = action.dueDate
      let payload = ToDoCreatePayload(
         id: action.cloudID ?? UUID(),
         userID: session.userID,
         task: task,
         notes: "",
         isDone: false,
         createdAt: action.occurredAt,
         updatedAt: now,
         lifecycleState: "active",
         reminderIntent: dueDate == nil ? "soft" : (action.isTimeSensitive == true ? "timeSensitive" : "due"),
         dueAt: dueDate,
         dueTimeZone: dueDate == nil ? nil : TimeZone.current.identifier,
         isRecurring: false,
         recurrenceUnit: nil,
         recurrenceInterval: nil,
         recurrenceMode: nil,
         recurrenceCount: nil,
         recurrenceAnchorAt: dueDate,
         recurrenceEndAt: nil,
         sortPosition: nil
      )
      var request = authorizedRequest(url: restURL(path: "todos"), session: session)
      request.httpMethod = "POST"
      request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
      request.httpBody = try JSONEncoder.watchBridge.encode(payload)
      _ = try await data(for: request, acceptedStatusCodes: 200..<300)
   }

   private func update(_ action: WatchToDoAction, session: WatchAuthSession) async throws {
      guard let id = action.cloudID else {
         throw DirectSyncError.invalidAction("This ToDo needs to sync through iPhone before Watch can update it directly.")
      }

      let dueAt: Date?
      let reminderIntent: String?
      switch action.type {
      case .complete:
         dueAt = nil
         reminderIntent = nil
         try await patch(id: id, session: session, payload: ToDoUpdatePayload(isDone: true, lifecycleState: "done"))
      case .reopen:
         dueAt = nil
         reminderIntent = nil
         try await patch(id: id, session: session, payload: ToDoUpdatePayload(isDone: false, lifecycleState: "active"))
      case .setDueDate:
         dueAt = action.dueDate
         reminderIntent = action.dueDate == nil ? "soft" : (action.isTimeSensitive == true ? "timeSensitive" : "due")
         try await patch(id: id, session: session, payload: ToDoUpdatePayload(dueAt: dueAt, shouldEncodeDueAt: true, reminderIntent: reminderIntent))
      case .snooze:
         guard let seconds = action.snoozeSeconds, seconds > 0 else {
            throw DirectSyncError.invalidAction("Choose a snooze duration.")
         }
         dueAt = Date(timeIntervalSinceNow: seconds)
         reminderIntent = action.isTimeSensitive == true ? "timeSensitive" : "due"
         try await patch(id: id, session: session, payload: ToDoUpdatePayload(dueAt: dueAt, shouldEncodeDueAt: true, reminderIntent: reminderIntent))
      case .create, .requestRefresh, .openOnPhone:
         return
      }
   }

   private func patch(id: UUID, session: WatchAuthSession, payload: ToDoUpdatePayload) async throws {
      let endpoint = restURL(path: "todos", queryItems: [
         URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
         URLQueryItem(name: "user_id", value: "eq.\(session.userID.uuidString.lowercased())")
      ])
      var request = authorizedRequest(url: endpoint, session: session)
      request.httpMethod = "PATCH"
      request.httpBody = try JSONEncoder.watchBridge.encode(payload)
      _ = try await data(for: request, acceptedStatusCodes: 200..<300)
   }

   private func restURL(path: String, queryItems: [URLQueryItem] = []) -> URL {
      supabaseURL
         .appending(path: "rest/v1/\(path)")
         .appending(queryItems: queryItems)
   }

   private func authorizedRequest(url: URL, session: WatchAuthSession) -> URLRequest {
      var request = URLRequest(url: url)
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      return request
   }

   private func data(for request: URLRequest, acceptedStatusCodes: Range<Int> = 200..<300) async throws -> Data {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw DirectSyncError.invalidResponse
      }
      guard acceptedStatusCodes.contains(httpResponse.statusCode) else {
         throw DirectSyncError.rejected(errorMessage(from: data) ?? "ToDo Sync rejected the Watch request.")
      }
      return data
   }

   private func errorMessage(from data: Data) -> String? {
      if let response = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
         return response.message ?? response.errorDescription ?? response.error
      }
      return String(data: data, encoding: .utf8)
   }
}

private struct RemoteToDoRecord: Decodable {
   let id: UUID
   let task: String
   let isDone: Bool
   let createdAt: Date?
   let updatedAt: Date?
   let lifecycleState: String?
   let trashedAt: Date?
   let reminderIntent: String
   let dueAt: Date?

   enum CodingKeys: String, CodingKey {
      case id
      case task
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
      case lifecycleState = "lifecycle_state"
      case trashedAt = "trashed_at"
      case reminderIntent = "reminder_intent"
      case dueAt = "due_at"
   }
}

private extension WatchToDoItem {
   init(record: RemoteToDoRecord) {
      self.init(
         id: record.id.uuidString,
         cloudID: record.id,
         task: record.task,
         isDone: record.isDone,
         lifecycleState: WatchToDoState(rawValue: record.lifecycleState ?? "active") ?? .active,
         trashedAt: record.trashedAt,
         dueDate: record.dueAt,
         isTimeSensitive: record.reminderIntent == "timeSensitive",
         createdAt: record.createdAt ?? record.updatedAt ?? .now,
         updatedAt: record.updatedAt ?? record.createdAt ?? .now
      )
   }
}

private struct ToDoCreatePayload: Encodable {
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
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Date?
   let recurrenceEndAt: Date?
   let sortPosition: Double?

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case task
      case notes
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
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
      case sortPosition = "sort_position"
   }
}

private struct ToDoUpdatePayload: Encodable {
   let isDone: Bool?
   let lifecycleState: String?
   let dueAt: Date?
   let shouldEncodeDueAt: Bool
   let reminderIntent: String?
   let updatedAt: Date

   init(
      isDone: Bool? = nil,
      lifecycleState: String? = nil,
      dueAt: Date? = nil,
      shouldEncodeDueAt: Bool = false,
      reminderIntent: String? = nil,
      updatedAt: Date = .now
   ) {
      self.isDone = isDone
      self.lifecycleState = lifecycleState
      self.dueAt = dueAt
      self.shouldEncodeDueAt = shouldEncodeDueAt
      self.reminderIntent = reminderIntent
      self.updatedAt = updatedAt
   }

   enum CodingKeys: String, CodingKey {
      case isDone = "is_done"
      case lifecycleState = "lifecycle_state"
      case dueAt = "due_at"
      case reminderIntent = "reminder_intent"
      case updatedAt = "updated_at"
   }

   func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(isDone, forKey: .isDone)
      try container.encodeIfPresent(lifecycleState, forKey: .lifecycleState)
      if shouldEncodeDueAt {
         if let dueAt {
            try container.encode(dueAt, forKey: .dueAt)
         } else {
            try container.encodeNil(forKey: .dueAt)
         }
      }
      try container.encodeIfPresent(reminderIntent, forKey: .reminderIntent)
      try container.encode(updatedAt, forKey: .updatedAt)
   }
}

private struct ErrorResponse: Decodable {
   let error: String?
   let message: String?
   let errorDescription: String?
}

enum DirectSyncError: LocalizedError {
   case invalidResponse
   case rejected(String)
   case invalidAction(String)

   var errorDescription: String? {
      switch self {
      case .invalidResponse:
         return "ToDo Sync returned an invalid response."
      case .rejected(let message), .invalidAction(let message):
         return message
      }
   }
}

private extension URL {
   func appending(queryItems: [URLQueryItem]) -> URL {
      guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
      components.queryItems = (components.queryItems ?? []) + queryItems
      return components.url ?? self
   }
}
