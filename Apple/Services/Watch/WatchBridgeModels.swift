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
   /// Provider authentication alone is not enough to authorize Watch sync.
   /// This remains optional on the wire so older companion payloads decode.
   let isAccountResolved: Bool
   let userID: UUID?
   let provider: String?
   let email: String?
   let username: String?
   let accountSetupVersion: Int?
   let source: WatchAuthSource
   let displayName: String?
   let avatarURL: String?
   let issuedAt: Date

   private enum CodingKeys: String, CodingKey {
      case isAuthenticated
      case isAccountResolved
      case userID
      case provider
      case email
      case username
      case accountSetupVersion
      case source
      case displayName
      case avatarURL
      case issuedAt
   }

   init(
      isAuthenticated: Bool,
      isAccountResolved: Bool = false,
      userID: UUID?,
      provider: String?,
      email: String?,
      username: String? = nil,
      accountSetupVersion: Int? = nil,
      source: WatchAuthSource,
      displayName: String? = nil,
      avatarURL: String? = nil,
      issuedAt: Date = .now
   ) {
      self.isAuthenticated = isAuthenticated
      self.isAccountResolved = isAccountResolved
      self.userID = userID
      self.provider = provider
      self.email = email
      self.username = username
      self.accountSetupVersion = accountSetupVersion
      self.source = source
      self.displayName = displayName
      self.avatarURL = avatarURL
      self.issuedAt = issuedAt
   }

   init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      isAuthenticated = try container.decode(Bool.self, forKey: .isAuthenticated)
      isAccountResolved = try container.decodeIfPresent(Bool.self, forKey: .isAccountResolved) ?? false
      userID = try container.decodeIfPresent(UUID.self, forKey: .userID)
      provider = try container.decodeIfPresent(String.self, forKey: .provider)
      email = try container.decodeIfPresent(String.self, forKey: .email)
      username = try container.decodeIfPresent(String.self, forKey: .username)
      accountSetupVersion = try container.decodeIfPresent(Int.self, forKey: .accountSetupVersion)
      source = try container.decode(WatchAuthSource.self, forKey: .source)
      displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
      avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
      issuedAt = try container.decode(Date.self, forKey: .issuedAt)
   }

   static let offline = WatchAuthState(
      isAuthenticated: false,
      isAccountResolved: false,
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
   case updateNotes
   case setDueDate
   case setRecurrence
   case setLocationReminder
   case updateTags
   case snooze
   case archive
   case trash
   case complete
   case reopen
   case createNanoDo
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

struct WatchTagItem: Codable, Equatable, Hashable, Identifiable, Sendable {
   let id: String
   let cloudID: UUID?
   let name: String

   init(
      id: String,
      cloudID: UUID? = nil,
      name: String
   ) {
      self.id = id
      self.cloudID = cloudID
      self.name = name
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
   let completedAt: Date?
   let notes: String
   let tags: [WatchTagItem]
   let recurrenceSummary: String?
   let recurrenceUnitRaw: String?
   let recurrenceInterval: Int?
   let recurrenceModeRaw: String?
   let recurrenceCount: Int?
   let hasLocationReminder: Bool
   let locationReminderLabel: String?
   let locationReminderTriggerTitle: String?
   let locationReminderLatitude: Double?
   let locationReminderLongitude: Double?
   let locationReminderRadius: Double?
   let locationReminderTriggerRaw: String?
   let completeWhenAllNanoDosDone: Bool
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
      case completedAt
      case notes
      case tags
      case recurrenceSummary
      case recurrenceUnitRaw
      case recurrenceInterval
      case recurrenceModeRaw
      case recurrenceCount
      case hasLocationReminder
      case locationReminderLabel
      case locationReminderTriggerTitle
      case locationReminderLatitude
      case locationReminderLongitude
      case locationReminderRadius
      case locationReminderTriggerRaw
      case completeWhenAllNanoDosDone
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
      completedAt: Date? = nil,
      notes: String = "",
      tags: [WatchTagItem] = [],
      recurrenceSummary: String? = nil,
      recurrenceUnitRaw: String? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceModeRaw: String? = nil,
      recurrenceCount: Int? = nil,
      hasLocationReminder: Bool = false,
      locationReminderLabel: String? = nil,
      locationReminderTriggerTitle: String? = nil,
      locationReminderLatitude: Double? = nil,
      locationReminderLongitude: Double? = nil,
      locationReminderRadius: Double? = nil,
      locationReminderTriggerRaw: String? = nil,
      completeWhenAllNanoDosDone: Bool = false,
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
      self.completedAt = completedAt
      self.notes = notes
      self.tags = tags
      self.recurrenceSummary = recurrenceSummary
      self.recurrenceUnitRaw = recurrenceUnitRaw
      self.recurrenceInterval = recurrenceInterval
      self.recurrenceModeRaw = recurrenceModeRaw
      self.recurrenceCount = recurrenceCount
      self.hasLocationReminder = hasLocationReminder
      self.locationReminderLabel = locationReminderLabel
      self.locationReminderTriggerTitle = locationReminderTriggerTitle
      self.locationReminderLatitude = locationReminderLatitude
      self.locationReminderLongitude = locationReminderLongitude
      self.locationReminderRadius = locationReminderRadius
      self.locationReminderTriggerRaw = locationReminderTriggerRaw
      self.completeWhenAllNanoDosDone = completeWhenAllNanoDosDone
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
      self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
      self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
      self.tags = try container.decodeIfPresent([WatchTagItem].self, forKey: .tags) ?? []
      self.recurrenceSummary = try container.decodeIfPresent(String.self, forKey: .recurrenceSummary)
      self.recurrenceUnitRaw = try container.decodeIfPresent(String.self, forKey: .recurrenceUnitRaw)
      self.recurrenceInterval = try container.decodeIfPresent(Int.self, forKey: .recurrenceInterval)
      self.recurrenceModeRaw = try container.decodeIfPresent(String.self, forKey: .recurrenceModeRaw)
      self.recurrenceCount = try container.decodeIfPresent(Int.self, forKey: .recurrenceCount)
      self.hasLocationReminder = try container.decodeIfPresent(Bool.self, forKey: .hasLocationReminder) ?? false
      self.locationReminderLabel = try container.decodeIfPresent(String.self, forKey: .locationReminderLabel)
      self.locationReminderTriggerTitle = try container.decodeIfPresent(String.self, forKey: .locationReminderTriggerTitle)
      self.locationReminderLatitude = try container.decodeIfPresent(Double.self, forKey: .locationReminderLatitude)
      self.locationReminderLongitude = try container.decodeIfPresent(Double.self, forKey: .locationReminderLongitude)
      self.locationReminderRadius = try container.decodeIfPresent(Double.self, forKey: .locationReminderRadius)
      self.locationReminderTriggerRaw = try container.decodeIfPresent(String.self, forKey: .locationReminderTriggerRaw)
      self.completeWhenAllNanoDosDone = try container.decodeIfPresent(Bool.self, forKey: .completeWhenAllNanoDosDone) ?? false
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
   let notes: String?
   let dueDate: Date?
   let isTimeSensitive: Bool?
   let tagNames: [String]?
   let recurrenceUnitRaw: String?
   let recurrenceInterval: Int?
   let recurrenceModeRaw: String?
   let recurrenceCount: Int?
   let locationReminderLatitude: Double?
   let locationReminderLongitude: Double?
   let locationReminderRadius: Double?
   let locationReminderTriggerRaw: String?
   let locationReminderLabel: String?
   let nanoDoTask: String?
   let nanoDoTasks: [String]?
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
      notes: String? = nil,
      dueDate: Date? = nil,
      isTimeSensitive: Bool? = nil,
      tagNames: [String] = [],
      recurrenceUnitRaw: String? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceModeRaw: String? = nil,
      recurrenceCount: Int? = nil,
      locationReminderLatitude: Double? = nil,
      locationReminderLongitude: Double? = nil,
      locationReminderRadius: Double? = nil,
      locationReminderTriggerRaw: String? = nil,
      locationReminderLabel: String? = nil,
      nanoDoTask: String? = nil,
      nanoDoTasks: [String] = [],
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
      self.notes = notes
      self.dueDate = dueDate
      self.isTimeSensitive = isTimeSensitive
      self.tagNames = tagNames
      self.recurrenceUnitRaw = recurrenceUnitRaw
      self.recurrenceInterval = recurrenceInterval
      self.recurrenceModeRaw = recurrenceModeRaw
      self.recurrenceCount = recurrenceCount
      self.locationReminderLatitude = locationReminderLatitude
      self.locationReminderLongitude = locationReminderLongitude
      self.locationReminderRadius = locationReminderRadius
      self.locationReminderTriggerRaw = locationReminderTriggerRaw
      self.locationReminderLabel = locationReminderLabel
      self.nanoDoTask = nanoDoTask
      self.nanoDoTasks = nanoDoTasks
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
      notes: String? = nil,
      dueDate: Date? = nil,
      isTimeSensitive: Bool? = nil,
      tagNames: [String] = [],
      recurrenceUnitRaw: String? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceModeRaw: String? = nil,
      recurrenceCount: Int? = nil,
      locationReminderLatitude: Double? = nil,
      locationReminderLongitude: Double? = nil,
      locationReminderRadius: Double? = nil,
      locationReminderTriggerRaw: String? = nil,
      locationReminderLabel: String? = nil,
      nanoDoTask: String? = nil,
      nanoDoTasks: [String] = [],
      snoozeSeconds: TimeInterval? = nil,
      nanoDo: WatchNanoDoItem? = nil
   ) {
      self.init(
         type: type,
         localIdentifier: item?.id,
         cloudID: cloudID ?? item?.cloudID,
         task: task,
         notes: notes,
         dueDate: dueDate,
         isTimeSensitive: isTimeSensitive,
         tagNames: tagNames,
         recurrenceUnitRaw: recurrenceUnitRaw,
         recurrenceInterval: recurrenceInterval,
         recurrenceModeRaw: recurrenceModeRaw,
         recurrenceCount: recurrenceCount,
         locationReminderLatitude: locationReminderLatitude,
         locationReminderLongitude: locationReminderLongitude,
         locationReminderRadius: locationReminderRadius,
         locationReminderTriggerRaw: locationReminderTriggerRaw,
         locationReminderLabel: locationReminderLabel,
         nanoDoTask: nanoDoTask,
         nanoDoTasks: nanoDoTasks,
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
