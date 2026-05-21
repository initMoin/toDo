import Combine
import Foundation
import SwiftData

struct SyncFeedback: Identifiable, Equatable {
   enum Style {
      case success
      case warning
      case failure
   }

   let id = UUID()
   let title: String
   let message: String
   let style: Style
}

enum SyncActivityState: Equatable {
   case idle
   case activating
   case syncing
   case synced
   case failed
}

enum SyncOperationPhase: String, Equatable {
   case activating
   case queuedLocalChanges
   case preparingLocalData
   case uploadingPendingDeletes
   case loadingRemoteChanges
   case cleaningRemoteDuplicates
   case applyingRemoteChanges
   case sendingLocalChanges
   case reconcilingRelationships
   case listeningForUpdates

   var title: String {
      switch self {
      case .activating:
         return String(localized: "Activating")
      case .queuedLocalChanges:
         return String(localized: "Waiting to Sync")
      case .preparingLocalData:
         return String(localized: "Preparing Local Data")
      case .uploadingPendingDeletes:
         return String(localized: "Syncing Deletes")
      case .loadingRemoteChanges:
         return String(localized: "Checking Account")
      case .cleaningRemoteDuplicates:
         return String(localized: "Cleaning Duplicates")
      case .applyingRemoteChanges:
         return String(localized: "Applying Updates")
      case .sendingLocalChanges:
         return String(localized: "Sending Changes")
      case .reconcilingRelationships:
         return String(localized: "Linking Tags")
      case .listeningForUpdates:
         return String(localized: "Listening for Updates")
      }
   }

   var detail: String {
      switch self {
      case .activating:
         return String(localized: "Connecting this device to ToDo Sync.")
      case .queuedLocalChanges:
         return String(localized: "ToDo is batching recent changes before sending them.")
      case .preparingLocalData:
         return String(localized: "Checking local ToDos before syncing.")
      case .uploadingPendingDeletes:
         return String(localized: "Sending delete markers so other devices stay consistent.")
      case .loadingRemoteChanges:
         return String(localized: "Checking your account for newer ToDos.")
      case .cleaningRemoteDuplicates:
         return String(localized: "Removing duplicated synced ToDos safely.")
      case .applyingRemoteChanges:
         return String(localized: "Updating this device with synced ToDos.")
      case .sendingLocalChanges:
         return String(localized: "Sending this device's latest changes.")
      case .reconcilingRelationships:
         return String(localized: "Making sure tags and ToDos stay linked correctly.")
      case .listeningForUpdates:
         return String(localized: "Waiting for changes from your other devices.")
      }
   }
}

@MainActor
final class SyncCoordinator: ObservableObject {
   static let shared = SyncCoordinator()

   @Published private(set) var preferredSyncMode: SyncMode
   @Published private(set) var effectiveSyncMode: SyncMode
   @Published private(set) var syncFeedback: SyncFeedback?
   @Published private(set) var syncActivityState: SyncActivityState = .idle
   @Published private(set) var currentSyncPhase: SyncOperationPhase?
   @Published private(set) var lastFailedSyncPhase: SyncOperationPhase?
   @Published private(set) var lastSuccessfulSyncAt: Date?
   @Published private(set) var lastSyncErrorMessage: String?

   private let migrationService: MigrationService
   private let userDefaults: UserDefaults
   private let localBackend = LocalDeviceSyncBackend()
   private let cloudKitBackend = CloudKitSyncBackend()
   private let supabaseBackend = SupabaseSyncBackend()
   private var activeBackend: (any ToDoSyncBackend)?
   private var configuredStoreSyncMode: SyncMode
   private var clearFeedbackTask: Task<Void, Never>?

   private init(
      migrationService: MigrationService = .shared,
      userDefaults: UserDefaults = .standard
   ) {
      self.migrationService = migrationService
      self.userDefaults = userDefaults
      let initialPreference = AppPreferences.preferredSyncMode(userDefaults: userDefaults)
      if initialPreference.rawValue != userDefaults.string(forKey: AppPreferences.Keys.syncMode) {
         userDefaults.set(initialPreference.rawValue, forKey: AppPreferences.Keys.syncMode)
      }
      configuredStoreSyncMode = initialPreference
      preferredSyncMode = initialPreference
      effectiveSyncMode = initialPreference
      let lastSyncTimestamp = userDefaults.double(forKey: AppPreferences.Keys.lastSuccessfulSyncAt)
      if lastSyncTimestamp > 0 {
         lastSuccessfulSyncAt = Date(timeIntervalSince1970: lastSyncTimestamp)
         syncActivityState = .synced
      }
   }

   func configure(modelContainer: ModelContainer, configuredSyncMode: SyncMode? = nil) {
      if let configuredSyncMode {
         self.configuredStoreSyncMode = configuredSyncMode
      }
      migrationService.configure(modelContainer: modelContainer)
      localBackend.configure(modelContainer: modelContainer)
      cloudKitBackend.configure(modelContainer: modelContainer)
      supabaseBackend.configure(modelContainer: modelContainer)
   }

   func start(userID: UUID?) async {
      await applyPreferredSyncMode(userID: userID)
   }

   func applyPreferredSyncMode(userID: UUID?) async {
      let resolvedMode = resolvedMode(for: preferredSyncMode, userID: userID)
      guard canApplyWithoutRelaunch(resolvedMode) else { return }
      _ = await transition(to: resolvedMode, userID: userID)
   }

   func setPreferredSyncMode(_ mode: SyncMode, userID: UUID?, shouldTransferData: Bool = true) async {
      let sanitizedMode = AppPreferences.sanitizedSyncMode(mode)
      guard sanitizedMode == mode else {
         showFeedback(
            title: "Sync Unavailable",
            message: "\(mode.title) is not available on this build of ToDo.",
            style: .failure
         )
         return
      }

      guard preferredSyncMode != sanitizedMode else {
         await applyPreferredSyncMode(userID: userID)
         return
      }

      let previousPreference = preferredSyncMode
      preferredSyncMode = sanitizedMode
      userDefaults.set(sanitizedMode.rawValue, forKey: AppPreferences.Keys.syncMode)

      let resolvedMode = resolvedMode(for: sanitizedMode, userID: userID)
      migrationService.stagePendingStoreMigrationIfNeeded(
         from: effectiveSyncMode,
         to: resolvedMode,
         userID: userID,
         shouldTransferData: shouldTransferData
      )
      if !canApplyWithoutRelaunch(resolvedMode) {
         showFeedback(
            title: "\(sanitizedMode.title) Saved",
            message: "Relaunch ToDo to finish moving into \(sanitizedMode.title).",
            style: .warning
         )
         return
      }

      do {
         try migrationService.executeIfNeeded(
            from: effectiveSyncMode,
            to: resolvedMode,
            userID: userID,
            shouldTransferData: shouldTransferData
         )
      } catch {
         preferredSyncMode = previousPreference
         userDefaults.set(previousPreference.rawValue, forKey: AppPreferences.Keys.syncMode)
         showFeedback(
            title: "Sync Change Failed",
            message: error.localizedDescription,
            style: .failure
         )
         return
      }

      if previousPreference != sanitizedMode || effectiveSyncMode != resolvedMode {
         if await transition(to: resolvedMode, userID: userID) {
            showFeedback(
               title: "Sync Updated",
               message: successMessage(for: sanitizedMode, userID: userID, didTransferData: shouldTransferData),
               style: .success
            )
         }
      }
   }

   func prepareDeviceOnlySnapshot(from userID: UUID) async {
      do {
         try migrationService.executeIfNeeded(from: .syncEverywhere, to: .deviceOnly, userID: userID)
      } catch {
         showFeedback(
            title: "Sync Change Failed",
            message: error.localizedDescription,
            style: .failure
         )
      }
   }

   func scheduleLocalSync() {
      activeBackend?.scheduleLocalSync()
   }

   func flushLocalSync(userID: UUID?) async {
      await activeBackend?.flushLocalSync(userID: userID)
   }

   func refreshFromRemote(userID: UUID?) async {
      await activeBackend?.refreshFromRemote(userID: userID)
   }

   func availableOptions(isAuthenticated: Bool) -> [SyncModeOption] {
      SyncMode.allCases.map { mode in
         let isAvailable = mode != .iCloud || CloudKitConfig.isAvailable
         return SyncModeOption(
            mode: mode,
            isAvailable: isAvailable,
            detailText: !isAvailable
            ? "Unavailable right now while ToDo's CloudKit data model is being hardened."
            : mode == .syncEverywhere && !isAuthenticated
            ? "Best for iPhone, Android, and web. Sign in to activate it."
            : mode.subtitle,
            requiresRelaunchToApply: mode == .iCloud || preferredSyncMode == .iCloud
         )
      }
   }

   func migrationPlan(for mode: SyncMode) -> SyncMigrationPlan? {
      migrationService.plan(from: effectiveSyncMode, to: mode)
   }

   var pendingRestartSyncMode: SyncMode? {
      guard preferredSyncMode != effectiveSyncMode else { return nil }
      guard preferredSyncMode.usesCloudKit != configuredStoreSyncMode.usesCloudKit else { return nil }
      return preferredSyncMode
   }

   func clearFeedback() {
      clearFeedbackTask?.cancel()
      syncFeedback = nil
   }

   func showTransientFeedback(title: String, message: String, style: SyncFeedback.Style) {
      showFeedback(title: title, message: message, style: style)
   }

   func beginSyncOperation(phase: SyncOperationPhase = .sendingLocalChanges) {
      guard effectiveSyncMode == .syncEverywhere || preferredSyncMode == .syncEverywhere else { return }
      lastSyncErrorMessage = nil
      lastFailedSyncPhase = nil
      currentSyncPhase = phase
      syncActivityState = .syncing
      log("Sync started: \(phase.title)")
   }

   func beginSyncActivation(phase: SyncOperationPhase = .activating) {
      guard effectiveSyncMode == .syncEverywhere || preferredSyncMode == .syncEverywhere else { return }
      lastSyncErrorMessage = nil
      lastFailedSyncPhase = nil
      currentSyncPhase = phase
      syncActivityState = .activating
      log("Sync activation started: \(phase.title)")
   }

   func updateSyncPhase(_ phase: SyncOperationPhase) {
      guard effectiveSyncMode == .syncEverywhere || preferredSyncMode == .syncEverywhere else { return }
      currentSyncPhase = phase
      log("Sync phase: \(phase.title)")
   }

   func completeSyncOperation(at date: Date = .now) {
      lastSuccessfulSyncAt = date
      lastSyncErrorMessage = nil
      lastFailedSyncPhase = nil
      currentSyncPhase = .listeningForUpdates
      syncActivityState = .synced
      userDefaults.set(date.timeIntervalSince1970, forKey: AppPreferences.Keys.lastSuccessfulSyncAt)
      WatchConnectivityService.shared.refreshSnapshot()
      log("Sync completed")
   }

   func failSyncOperation(_ error: Error) {
      lastFailedSyncPhase = currentSyncPhase
      lastSyncErrorMessage = Self.syncErrorMessage(for: error)
      currentSyncPhase = nil
      syncActivityState = .failed
      log("Sync failed: \(lastSyncErrorMessage ?? "Unknown error")")
   }

   private func resolvedMode(for preferredMode: SyncMode, userID: UUID?) -> SyncMode {
      guard preferredMode.requiresAuthenticatedAccount else {
         return preferredMode
      }

      return userID == nil ? .deviceOnly : preferredMode
   }

   @discardableResult
   private func transition(to mode: SyncMode, userID: UUID?) async -> Bool {
      let nextBackend: any ToDoSyncBackend
      if let activeBackend, activeBackend.syncMode == mode {
         nextBackend = activeBackend
      } else {
         nextBackend = backend(for: mode)
      }

      let didActivate = await nextBackend.activate(userID: userID)
      guard didActivate else {
         nextBackend.deactivate()
         let detail = lastSyncErrorMessage.map { " \($0)" } ?? ""
         showFeedback(
            title: "Sync Not Activated",
            message: "ToDo stayed on \(effectiveSyncMode.title) because \(mode.title) could not finish setup.\(detail)",
            style: .failure
         )
         return false
      }

      if activeBackend !== nextBackend {
         activeBackend?.deactivate()
         activeBackend = nextBackend
      }
      effectiveSyncMode = mode
      if mode != .syncEverywhere {
         syncActivityState = .idle
         lastSyncErrorMessage = nil
      } else if syncActivityState == .idle {
         syncActivityState = .activating
         currentSyncPhase = .activating
      }
      return true
   }

   private func backend(for mode: SyncMode) -> any ToDoSyncBackend {
      switch mode {
      case .deviceOnly:
         return localBackend
      case .iCloud:
         return cloudKitBackend
      case .syncEverywhere:
         return supabaseBackend
      }
   }

   private func canApplyWithoutRelaunch(_ mode: SyncMode) -> Bool {
      mode.usesCloudKit == configuredStoreSyncMode.usesCloudKit
   }

   private func showFeedback(title: String, message: String, style: SyncFeedback.Style) {
      clearFeedbackTask?.cancel()
      syncFeedback = SyncFeedback(title: title, message: message, style: style)
      clearFeedbackTask = Task { [weak self] in
         try? await Task.sleep(nanoseconds: 3_200_000_000)
         guard !Task.isCancelled else { return }
         await MainActor.run {
            self?.syncFeedback = nil
         }
      }
   }

   private func log(_ message: String) {
#if DEBUG
      AppLog.info("ToDo Sync: \(message)", logger: AppLog.sync)
#endif
   }

   private static func syncErrorMessage(for error: Error) -> String {
      let localizedDescription = error.localizedDescription
      let rawDescription = String(describing: error)

      if localizedDescription == "The operation couldn’t be completed. (Supabase.PostgrestError error 0.)",
         rawDescription.isEmpty == false {
         return rawDescription
      }

      if localizedDescription == "The operation couldn’t be completed.",
         rawDescription.isEmpty == false {
         return rawDescription
      }

      return localizedDescription
   }

   private func successMessage(for mode: SyncMode, userID: UUID?, didTransferData: Bool) -> String {
      let transferPrefix = didTransferData ? "" : String(localized: "ToDo started this sync mode without moving existing ToDos. ")
      switch mode {
      case .deviceOnly:
         return transferPrefix + String(localized: "ToDo now keeps what matters on this device.")
      case .iCloud:
         return transferPrefix + String(localized: "ToDo now uses iCloud to keep Apple devices in step.")
      case .syncEverywhere:
         return userID == nil
         ? String(format: String(localized: "%@ is selected. Sign in to finish turning it on."), mode.title)
         : transferPrefix + String(localized: "ToDo now uses your account to keep iPhone, Android, and web in step.")
      }
   }
}

@MainActor
private final class LocalDeviceSyncBackend: ToDoSyncBackend {
   let syncMode: SyncMode = .deviceOnly

   func configure(modelContainer: ModelContainer) {}
   func activate(userID: UUID?) async -> Bool { true }
   func deactivate() {}
   func scheduleLocalSync() {}
}
