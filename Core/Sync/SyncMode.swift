import Foundation

enum SyncMode: String, CaseIterable, Codable, Identifiable {
    case deviceOnly = "device_only"
    case iCloud = "icloud"
    case syncEverywhere = "sync_everywhere"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deviceOnly:
            return String(localized: "This Device Only")
        case .iCloud:
            return String(localized: "Sync with iCloud")
        case .syncEverywhere:
            return String(localized: "toDō Sync")
        }
    }

    var subtitle: String {
        switch self {
        case .deviceOnly:
            return String(localized: "Keep your toDōs only on this device.")
        case .iCloud:
            return String(localized: "Keep your Apple devices in step with iCloud.")
        case .syncEverywhere:
            return String(localized: "Use your toDō account for iPhone, Android, and web.")
        }
    }

    var requiresAuthenticatedAccount: Bool {
        self == .syncEverywhere
    }

    var usesCloudKit: Bool {
        self == .iCloud
    }

    var usesSupabase: Bool {
        self == .syncEverywhere
    }
}

struct SyncModeOption: Identifiable, Equatable {
    let mode: SyncMode
    let isAvailable: Bool
    let detailText: String
    let requiresRelaunchToApply: Bool

    var id: String { mode.id }
}

enum SyncMigrationDirection: String, CaseIterable, Identifiable {
    case deviceOnlyToICloud = "device_only_to_icloud"
    case deviceOnlyToSyncEverywhere = "device_only_to_sync_everywhere"
    case iCloudToSyncEverywhere = "icloud_to_sync_everywhere"
    case iCloudToDeviceOnly = "icloud_to_device_only"
    case syncEverywhereToDeviceOnly = "sync_everywhere_to_device_only"
    case syncEverywhereToICloud = "sync_everywhere_to_icloud"

    var id: String { rawValue }

    var sourceMode: SyncMode {
        switch self {
        case .deviceOnlyToICloud, .deviceOnlyToSyncEverywhere:
            return .deviceOnly
        case .iCloudToSyncEverywhere, .iCloudToDeviceOnly:
            return .iCloud
        case .syncEverywhereToDeviceOnly, .syncEverywhereToICloud:
            return .syncEverywhere
        }
    }

    var destinationMode: SyncMode {
        switch self {
        case .deviceOnlyToICloud, .syncEverywhereToICloud:
            return .iCloud
        case .deviceOnlyToSyncEverywhere, .iCloudToSyncEverywhere:
            return .syncEverywhere
        case .iCloudToDeviceOnly, .syncEverywhereToDeviceOnly:
            return .deviceOnly
        }
    }
}
