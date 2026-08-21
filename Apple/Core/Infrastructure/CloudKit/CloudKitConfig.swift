import Foundation
import SwiftData

enum CloudKitConfig {
    static let containerIdentifier = "iCloud.dev.iamshift.toDo"
    static let isAvailable = true

    static func database(for syncMode: SyncMode) -> ModelConfiguration.CloudKitDatabase {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return .none
        }

        return syncMode.usesCloudKit && isAvailable ? .private(containerIdentifier) : .none
    }
}
