import Foundation

enum AppPreferences {
    enum Keys {
        static let syncMode = "syncMode"
        static let tagSortOption = "tagSortOption"
        static let tagSortAscending = "tagSortAscending"
        static let tagManagementDefaultTagsExpanded = "tagManagementDefaultTagsExpanded"

        static let toDoListSortOption = "toDoListSortOption"
        static let toDoListSortReversed = "toDoListSortReversed"
        static let createToDoTagsEnabledByDefault = "createToDoTagsEnabledByDefault"
        static let deleteCompletedToDosImmediately = "deleteCompletedToDosImmediately"
        static let doneSwipePrimaryAction = "doneSwipePrimaryAction"
        static let snoozeOptions = SnoozePreferences.storageKey
        static let appTimeSource = "appTimeSource"
        static let locationTimeZoneIdentifier = "locationTimeZoneIdentifier"
        static let remotePushDeviceToken = "remotePushDeviceToken"
        static let lastSignInProvider = "lastSignInProvider"
        static let lastSignInProviderUserID = "lastSignInProviderUserID"
        static let mirrorSyncDeletesToDeviceOnly = "mirrorSyncDeletesToDeviceOnly"
        static let lastSuccessfulSyncAt = "lastSuccessfulSyncAt"
        static let pendingStoreMigration = "pendingStoreMigration"
        static let storedTagNormalizationVersion = "storedTagNormalizationVersion"
        static let toDoLifecycleNormalizationVersion = "toDoLifecycleNormalizationVersion"
        static let toDoReminderIntentNormalizationVersion = "toDoReminderIntentNormalizationVersion"
    }

    enum ToDoListSortOption: String, CaseIterable, Identifiable {
        case dueDate
        case creationDate
        case tag
        case dueMonthSections
        case tagSections
        case nanoDoSections

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dueDate:
                return "Due Date"
            case .creationDate:
                return "Created"
            case .tag:
                return "By Tag"
            case .dueMonthSections:
                return "Due by Month"
            case .tagSections:
                return "Tag Sections"
            case .nanoDoSections:
                return "Most NanoDos"
            }
        }

        var compactTitle: String {
            switch self {
            case .dueDate:
                return "Due"
            case .creationDate:
                return "Created"
            case .tag:
                return "By Tag"
            case .dueMonthSections:
                return "Month"
            case .tagSections:
                return "Tag Groups"
            case .nanoDoSections:
                return "NanoDos"
            }
        }

        var usesSections: Bool {
            switch self {
            case .dueDate, .creationDate, .tag:
                return false
            case .dueMonthSections, .tagSections, .nanoDoSections:
                return true
            }
        }

        static var orderingOptions: [Self] {
            allCases.filter { !$0.usesSections }
        }

        static var groupingOptions: [Self] {
            allCases.filter(\.usesSections)
        }
    }

    enum DoneSwipePrimaryAction: String, CaseIterable, Identifiable {
        case archive
        case delete

        var id: String { rawValue }

        var title: String {
            switch self {
            case .archive:
                return "Move to Archives"
            case .delete:
                return "Delete Permanently"
            }
        }
    }

    static var defaults: [String: Any] {
        [
            Keys.syncMode: SyncMode.syncEverywhere.rawValue,
            Keys.tagSortOption: TagSortOption.name.rawValue,
            Keys.tagSortAscending: TagSortOption.name.defaultAscending,
            Keys.tagManagementDefaultTagsExpanded: true,
            Keys.toDoListSortOption: ToDoListSortOption.dueDate.rawValue,
            Keys.toDoListSortReversed: false,
            Keys.createToDoTagsEnabledByDefault: false,
            Keys.deleteCompletedToDosImmediately: false,
            Keys.doneSwipePrimaryAction: DoneSwipePrimaryAction.archive.rawValue,
            Keys.snoozeOptions: SnoozePreferences.defaultEncodedString,
            Keys.appTimeSource: AppTimeSource.location.rawValue,
            Keys.locationTimeZoneIdentifier: AppTimePreferences.appleParkTimeZoneIdentifier,
            Keys.mirrorSyncDeletesToDeviceOnly: true,
        ]
    }

    static let storedTagNormalizationVersion = 1
    static let toDoLifecycleNormalizationVersion = 1
    static let toDoReminderIntentNormalizationVersion = 1

    static func registerDefaults(userDefaults: UserDefaults = .standard) {
        userDefaults.register(defaults: defaults)
    }

    static func resetToDefaults(userDefaults: UserDefaults = .standard) {
        for (key, value) in defaults {
            userDefaults.set(value, forKey: key)
        }
    }

    static func preferredSyncMode(userDefaults: UserDefaults = .standard) -> SyncMode {
        guard let rawValue = userDefaults.string(forKey: Keys.syncMode),
              let mode = SyncMode(rawValue: rawValue)
        else {
            return .syncEverywhere
        }

        return sanitizedSyncMode(mode)
    }

    static func sanitizedSyncMode(_ mode: SyncMode) -> SyncMode {
        guard mode == .iCloud, !CloudKitConfig.isAvailable else {
            return mode
        }

        return .deviceOnly
    }
}
