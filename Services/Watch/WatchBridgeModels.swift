import Foundation

// MARK: - Bridge Identifiers
enum WatchBridgeMessageKind: String, Codable, Sendable {
   case snapshot
   case action
   case actionReceipt
   case authState
}

// MARK: - Auth Models
enum WatchAuthSource: String, Codable, Sendable {
   case iPhone
   case apple
   case offline
}

struct WatchAuthState: Codable, Equatable, Sendable {
   let isAuthenticated: Bool
   let userID: UUID?
   let provider: String?
   let email: String?
   let source: WatchAuthSource
   let issuedAt: Date

   init(
      isAuthenticated: Bool,
      userID: UUID?,
      provider: String?,
      email: String?,
      source: WatchAuthSource,
      issuedAt: Date = .now
   ) {
      self.isAuthenticated = isAuthenticated
      self.userID = userID
      self.provider = provider
      self.email = email
      self.source = source
      self.issuedAt = issuedAt
   }

   static let offline = WatchAuthState(
      isAuthenticated: false,
      userID: nil,
      provider: nil,
      email: nil,
      source: .offline
   )
}

// MARK: - ToDo Models
enum WatchSyncMode: String, Codable, Sendable {
   case deviceOnly = "device_only"
   case iCloud = "icloud"
   case syncEverywhere = "sync_everywhere"
}

enum WatchToDoState: String, Codable, Sendable {
   case active
   case done
   case archived
   case trashed
}

enum WatchToDoActionType: String, Codable, Sendable {
   case create
   case updateTask
   case setDueDate
   case snooze
   case archive
   case trash
   case complete
   case reopen
   case completeNanoDo
   case reopenNanoDo
   case deleteNanoDo
   case requestRefresh
   case openOnPhone
}

struct WatchNanoDoItem: Codable, Equatable, Hashable, Identifiable, Sendable {
   let id: String
   let cloudID: UUID?
   let task: String
   let isDone: Bool
   let dueDate: Date?
   let updatedAt: Date

   init(
      id: String,
      cloudID: UUID? = nil,
      task: String,
      isDone: Bool,
      dueDate: Date? = nil,
      updatedAt: Date = .now
   ) {
      self.id = id
      self.cloudID = cloudID
      self.task = task
      self.isDone = isDone
      self.dueDate = dueDate
      self.updatedAt = updatedAt
   }
}

struct WatchToDoItem: Codable, Equatable, Hashable, Identifiable, Sendable {
   let id: String
   let cloudID: UUID?
   let task: String
   let isDone: Bool
   var lifecycleState: WatchToDoState
   var trashedAt: Date?
   var dueDate: Date?
   var isTimeSensitive: Bool
   let createdAt: Date
   let updatedAt: Date
   let nanoDos: [WatchNanoDoItem]

   enum CodingKeys: String, CodingKey {
      case id
      case cloudID
      case task
      case isDone
      case lifecycleState
      case trashedAt
      case dueDate
      case isTimeSensitive
      case createdAt
      case updatedAt
      case nanoDos
   }

   // Explicit init to ensure consistency across targets
   init(
      id: String,
      cloudID: UUID? = nil,
      task: String,
      isDone: Bool,
      lifecycleState: WatchToDoState = .active,
      trashedAt: Date? = nil,
      dueDate: Date? = nil,
      isTimeSensitive: Bool = false,
      createdAt: Date = .now,
      updatedAt: Date = .now,
      nanoDos: [WatchNanoDoItem] = []
   ) {
      self.id = id
      self.cloudID = cloudID
      self.task = task
      self.isDone = isDone
      self.lifecycleState = lifecycleState
      self.trashedAt = trashedAt
      self.dueDate = dueDate
      self.isTimeSensitive = isTimeSensitive
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.nanoDos = nanoDos
   }

   init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.id = try container.decode(String.self, forKey: .id)
      self.cloudID = try container.decodeIfPresent(UUID.self, forKey: .cloudID)
      self.task = try container.decode(String.self, forKey: .task)
      self.isDone = try container.decode(Bool.self, forKey: .isDone)
      self.lifecycleState = try container.decodeIfPresent(WatchToDoState.self, forKey: .lifecycleState) ?? .active
      self.trashedAt = try container.decodeIfPresent(Date.self, forKey: .trashedAt)
      self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
      self.isTimeSensitive = try container.decodeIfPresent(Bool.self, forKey: .isTimeSensitive) ?? false
      self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
      self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? self.createdAt
      self.nanoDos = try container.decodeIfPresent([WatchNanoDoItem].self, forKey: .nanoDos) ?? []
   }
}

// MARK: - Payloads
struct WatchToDoSnapshot: Codable, Equatable, Sendable {
   let generatedAt: Date
   let syncMode: WatchSyncMode?
   let authState: WatchAuthState?
   let items: [WatchToDoItem]

   init(
      generatedAt: Date = .now,
      syncMode: WatchSyncMode? = nil,
      authState: WatchAuthState? = nil,
      items: [WatchToDoItem]
   ) {
      self.generatedAt = generatedAt
      self.syncMode = syncMode
      self.authState = authState
      self.items = items
   }
}

struct WatchToDoAction: Codable, Equatable, Identifiable, Sendable {
   let id: UUID
   let type: WatchToDoActionType
   let localIdentifier: String?
   let cloudID: UUID?
   let task: String?
   let dueDate: Date?
   let isTimeSensitive: Bool?
   let snoozeSeconds: TimeInterval?
   let nanoDoLocalIdentifier: String?
   let nanoDoCloudID: UUID?
   let occurredAt: Date

   init(
      id: UUID = UUID(),
      type: WatchToDoActionType,
      localIdentifier: String? = nil,
      cloudID: UUID? = nil,
      task: String? = nil,
      dueDate: Date? = nil,
      isTimeSensitive: Bool? = nil,
      snoozeSeconds: TimeInterval? = nil,
      nanoDoLocalIdentifier: String? = nil,
      nanoDoCloudID: UUID? = nil,
      occurredAt: Date = .now
   ) {
      self.id = id
      self.type = type
      self.localIdentifier = localIdentifier
      self.cloudID = cloudID
      self.task = task
      self.dueDate = dueDate
      self.isTimeSensitive = isTimeSensitive
      self.snoozeSeconds = snoozeSeconds
      self.nanoDoLocalIdentifier = nanoDoLocalIdentifier
      self.nanoDoCloudID = nanoDoCloudID
      self.occurredAt = occurredAt
   }

   init(
      type: WatchToDoActionType,
      item: WatchToDoItem? = nil,
      cloudID: UUID? = nil,
      task: String? = nil,
      dueDate: Date? = nil,
      isTimeSensitive: Bool? = nil,
      snoozeSeconds: TimeInterval? = nil,
      nanoDo: WatchNanoDoItem? = nil
   ) {
      self.init(
         type: type,
         localIdentifier: item?.id,
         cloudID: cloudID ?? item?.cloudID,
         task: task,
         dueDate: dueDate,
         isTimeSensitive: isTimeSensitive,
         snoozeSeconds: snoozeSeconds,
         nanoDoLocalIdentifier: nanoDo?.id,
         nanoDoCloudID: nanoDo?.cloudID
      )
   }
}

struct WatchToDoActionReceipt: Codable, Equatable, Sendable {
   let actionID: UUID
   let accepted: Bool
   let message: String?
   let handledAt: Date

   init(actionID: UUID, accepted: Bool, message: String? = nil, handledAt: Date = .now) {
      self.actionID = actionID
      self.accepted = accepted
      self.message = message
      self.handledAt = handledAt
   }
}

enum WatchBridgeCodec {
   static let schemaVersion = 1

   private static let encoder: JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return encoder
   }()

   private static let decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
   }()

   static func envelope<T: Encodable>(
      kind: WatchBridgeMessageKind,
      payload: T,
      sentAt: Date = .now
   ) throws -> [String: Any] {
      [
         "schemaVersion": schemaVersion,
         "kind": kind.rawValue,
         "sentAt": sentAt,
         "payload": try encoder.encode(payload)
      ]
   }

   static func decodeKind(from envelope: [String: Any]) -> WatchBridgeMessageKind? {
      decodeKind(
         schemaVersion: envelope["schemaVersion"] as? Int,
         rawKind: envelope["kind"] as? String
      )
   }

   static func decodeKind(schemaVersion incomingSchemaVersion: Int?, rawKind: String?) -> WatchBridgeMessageKind? {
      guard incomingSchemaVersion == schemaVersion,
            let rawKind else { return nil }
      return WatchBridgeMessageKind(rawValue: rawKind)
   }

   static func decodePayload<T: Decodable>(_ type: T.Type, from envelope: [String: Any]) throws -> T? {
      guard envelope["schemaVersion"] as? Int == schemaVersion,
            let payload = envelope["payload"] as? Data else {
         return nil
      }
      return try decodePayload(type, from: payload)
   }

   static func decodePayload<T: Decodable>(_ type: T.Type, from payload: Data?) throws -> T? {
      guard let payload else { return nil }
      return try decoder.decode(type, from: payload)
   }
}

struct WatchEnvelopeParts: Sendable {
   let schemaVersion: Int?
   let rawKind: String?
   let payload: Data?

   nonisolated init(_ envelope: [String: Any]) {
      self.schemaVersion = envelope["schemaVersion"] as? Int
      self.rawKind = envelope["kind"] as? String
      self.payload = envelope["payload"] as? Data
   }
}
