import SwiftData

enum PreviewSupport {
    static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
        } catch {
            fatalError("Failed to initialize preview model container: \(error)")
        }
    }
}
