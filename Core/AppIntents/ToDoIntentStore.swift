import Foundation
import SwiftData

@MainActor
enum ToDoIntentStore {
   private static var cachedContainer: ModelContainer?

   static func modelContainer() throws -> ModelContainer {
      if let cachedContainer {
         return cachedContainer
      }

      let syncMode = AppPreferences.preferredSyncMode()
      SharedStoreLocation.migrateLegacyStoresIfNeeded()
      let storeURL = defaultStoreURL(for: syncMode)
      SharedStoreLocation.ensureStoreDirectoryExists(for: storeURL)

      let configuration = ModelConfiguration(
         "ToDo",
         url: storeURL,
         cloudKitDatabase: CloudKitConfig.database(for: syncMode)
      )
      let container = try ModelContainer(
         for: ToDo.self,
         Tag.self,
         NanoDo.self,
         SyncConflict.self,
         configurations: configuration
      )
      cachedContainer = container
      return container
   }

   static func modelContext() throws -> ModelContext {
      ModelContext(try modelContainer())
   }

   static func persistentIdentifierString(for toDo: ToDo) -> String {
      String(describing: toDo.id)
   }

   private static func defaultStoreURL(for syncMode: SyncMode) -> URL {
      SharedStoreLocation.storeURL(for: syncMode)
   }
}
