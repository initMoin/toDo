import Foundation

struct WatchActionQueueStore {
   private let storageKey = "watch.pending.todo.actions"
   private let userDefaults: UserDefaults

   init(userDefaults: UserDefaults = .standard) {
      self.userDefaults = userDefaults
   }

   func load() -> [WatchToDoAction] {
      guard let data = userDefaults.data(forKey: storageKey) else { return [] }
      return (try? JSONDecoder.watchBridge.decode([WatchToDoAction].self, from: data)) ?? []
   }

   func enqueue(_ action: WatchToDoAction) {
      var actions = load()
      guard !actions.contains(where: { $0.id == action.id }) else { return }
      actions.append(action)
      save(actions)
   }

   func remove(_ actionIDs: Set<UUID>) {
      guard !actionIDs.isEmpty else { return }
      save(load().filter { !actionIDs.contains($0.id) })
   }

   func clear() {
      userDefaults.removeObject(forKey: storageKey)
   }

   private func save(_ actions: [WatchToDoAction]) {
      guard let data = try? JSONEncoder.watchBridge.encode(actions) else { return }
      userDefaults.set(data, forKey: storageKey)
   }
}

extension JSONEncoder {
   static var watchBridge: JSONEncoder {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return encoder
   }
}

extension JSONDecoder {
   static var watchBridge: JSONDecoder {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
   }
}
