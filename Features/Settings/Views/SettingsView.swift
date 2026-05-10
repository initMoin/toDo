import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @Environment(\.openURL) private var openURL
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Query private var tags: [Tag]
   @Query private var toDos: [ToDo]
   @Query private var nanoDos: [NanoDo]
   @Query private var syncConflicts: [SyncConflict]

   @AppStorage(AppPreferences.Keys.toDoListSortOption) private var toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
   @AppStorage(AppPreferences.Keys.toDoListSortReversed) private var isToDoListSortReversed = false
   @AppStorage(AppPreferences.Keys.createToDoTagsEnabledByDefault) private var createToDoTagsEnabledByDefault = false
   @AppStorage(AppPreferences.Keys.doneSwipePrimaryAction) private var doneSwipePrimaryActionRaw = AppPreferences.DoneSwipePrimaryAction.archive.rawValue
   @AppStorage(AppPreferences.Keys.appTimeSource) private var appTimeSourceRaw = AppTimeSource.location.rawValue
   @AppStorage(AppPreferences.Keys.locationTimeZoneIdentifier) private var locationTimeZoneIdentifier = AppTimePreferences.appleParkTimeZoneIdentifier
   @AppStorage(AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly) private var mirrorSyncDeletesToDeviceOnly = true
   
   @State private var isShowingDeleteUnusedTagsConfirmation = false
   @State private var isSortMenuExpanded = false
   @State private var isDoneSwipeMenuExpanded = false
   @State private var isTimeSourceMenuExpanded = false
   @StateObject private var notificationManager = NotificationManager.shared
   @StateObject private var locationTimeZoneService = LocationTimeZoneService()
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   private let brandWebsiteURL = URL(string: "https://iamshift.dev")!
   private let appSettingsURL = URL(string: "app-settings:")!
   private let onClose: (() -> Void)?

   init(onClose: (() -> Void)? = nil) {
      self.onClose = onClose
   }

   private var visibleOwnerUserID: UUID? {
      guard authStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return authStore.currentUserID
   }

   private var scopedTags: [Tag] {
      tags.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var scopedToDos: [ToDo] {
      toDos.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var scopedNanoDos: [NanoDo] {
      nanoDos.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var unresolvedSyncConflicts: [SyncConflict] {
      syncConflicts
         .filter { !$0.isResolved && $0.userID == visibleOwnerUserID }
         .sorted { $0.createdAt > $1.createdAt }
   }
   
   var body: some View {
      ZStack(alignment: .top) {
         ScrollView {
            VStack(alignment: .leading, spacing: 24) {
               settingsSection("Account") {
                  NavigationLink {
                     if authStore.isAuthenticated {
                        AccountView()
                     } else {
                        AuthenticationScreenView()
                     }
                  } label: {
                     settingsNavigationRow(
                        authStore.isAuthenticated ? "Profile & Session" : "Set Up Account",
                        detail: authStore.signedInEmail ?? authStore.accountStatusLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  Text("Manage your ToDo identity, sign-in methods, and the account currently connected to this device.")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               settingsSection("Sync") {
                  syncStatusBlock

                  if !unresolvedSyncConflicts.isEmpty {
                     NavigationLink {
                        SyncConflictReviewView(
                           conflicts: unresolvedSyncConflicts,
                           toDos: scopedToDos
                        )
                     } label: {
                        syncReviewRow
                     }
                     .foregroundStyle(AppColor.textPrimary)
                  }
                  
                  NavigationLink {
                     SyncSettingsView()
                  } label: {
                     settingsNavigationRow(
                        "Storage & Sync",
                        detail: syncCoordinator.pendingRestartSyncMode != nil ? "Needs relaunch" : syncCoordinator.preferredSyncMode.title
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     SyncDiagnosticsView(
                        toDos: scopedToDos,
                        tags: scopedTags,
                        nanoDos: scopedNanoDos,
                        unresolvedConflictCount: unresolvedSyncConflicts.count
                     )
                  } label: {
                     settingsNavigationRow(
                        "Sync Diagnostics",
                        detail: syncDiagnosticsSummary
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  syncDeletionPreferenceToggle

                  Text("Choose where ToDo stores and syncs your ToDos: on this device, in iCloud for Apple devices, or through ToDo Sync.")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)

                  Text("ToDo Sync can be signed in with Apple or Google, depending on which path you prefer.")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               settingsSection("Preferences") {
               settingsSortDropdown

               timeSourceDropdown

               doneSwipeActionDropdown

               NavigationLink {
                  SnoozeOptionsView()
               } label: {
                  settingsNavigationRow(
                     "Snooze Options",
                     detail: "Manage presets"
                  )
               }
               .foregroundStyle(AppColor.textPrimary)

               notificationSettingsBlock
               }

               settingsSection("Tags") {
                  Toggle(isOn: $createToDoTagsEnabledByDefault) {
                     Text("Enable Tags by Default")
                        .foregroundStyle(AppColor.textPrimary)
                  }

                  NavigationLink {
                     TagManagementView()
                  } label: {
                     settingsNavigationRow(
                        "Tag Management",
                        detail: "\(customTagCount) custom"
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               NavigationLink {
                  ArchivesView()
               } label: {
                  settingsStandaloneNavigationButton(
                     "Archives",
                     detail: archiveCountLabel
                  )
               }
               .foregroundStyle(AppColor.textPrimary)
               .padding(.top, -4)

               settingsSection("Data Controls") {
                  settingsActionRow(
                     systemName: "arrow.counterclockwise",
                     title: "Reset Preferences",
                     detail: "Restore sorting and default tag-entry behavior to the app defaults."
                  ) {
                     resetPreferences()
                  }

                  settingsActionRow(
                     systemName: "tag.slash",
                     title: "Delete Unused Tags",
                     detail: "Permanently remove tags that are no longer linked to any ToDo or nanoDo.",
                     foregroundStyle: AppColor.actionDestructive,
                     backgroundStyle: AppColor.actionDestructive.opacity(0.08),
                     isDisabled: unusedTagCount == 0
                  ) {
                     isShowingDeleteUnusedTagsConfirmation = true
                  }
               }

               madeByBrandView
                  .frame(maxWidth: .infinity)
                  .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 86)
            .padding(.bottom, 24)
         }
         
         pinnedTitleHeader
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .appNavigationChrome()
      .toolbar {
         ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
               if let onClose {
                  onClose()
               } else {
                  dismiss()
               }
            }
         }
      }
      .confirmationDialog("Delete unused tags?", isPresented: $isShowingDeleteUnusedTagsConfirmation, titleVisibility: .visible) {
         Button("Delete", role: .destructive) {
            deleteUnusedTags()
         }
      } message: {
         Text("\(unusedTagCount) unused tag(s) will be permanently removed.")
      }
      .onChange(of: locationTimeZoneService.authorizationStatus) { _, newStatus in
         if newStatus == .authorizedAlways || newStatus == .authorizedWhenInUse {
            locationTimeZoneService.requestLocationTimeZoneAccess()
         }
      }
      .task {
         await notificationManager.refreshAuthorizationStatus()
      }
   }
   
   private var madeByBrandView: some View {
      VStack(spacing: 10) {
         VStack(spacing: 2) {
            Text("ToDo what matters")
               .font(.appSubtitle(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
               .padding(.bottom, 11)
            
            Spacer()

            HStack(spacing: 6) {
               Text("intention")
                  .font(.appBody(14, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Image(systemName: "arrow.right")
                  .font(.system(size: 11, weight: .semibold, design: .serif))
                  .foregroundStyle(AppColor.textPrimary)

               Text("build")
                  .font(.appBody(14, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Image(systemName: "arrow.right")
                  .font(.system(size: 11, weight: .semibold, design: .serif))
                  .foregroundStyle(AppColor.textPrimary)

               Text("shift •")
                  .font(.appBody(14, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("standard defines. craft refines.")
               .font(.appBody(14, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Text("and then some.")
               .font(.appBody(14, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)
         }
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity)
         
         Spacer()

         Text("Designed & developed, with love")
            .font(.appBody(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.textSecondary)

         Link(destination: brandWebsiteURL) {
            Image("brand-logomark")
               .resizable()
               .scaledToFit()
               .frame(width: 52, height: 52)
               .aspectRatio(1, contentMode: .fit)
         }
         .buttonStyle(.plain)
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.top, 6)
      .padding(.bottom, 8)
   }

   private var pinnedTitleHeader: some View {
      VStack(spacing: 0) {
         Text("Settings")
            .font(.appTitle(34, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .background(AppColor.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(title)
            .font(.appSubtitle(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 14) {
            content()
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(
            Color.white,
            in: .rect(cornerRadius: 24)
         )
      }
   }

   private func settingsNavigationRow(
      _ title: String,
      detail: String,
      detailForeground: Color = AppColor.textSecondary,
      detailFont: Font = .appBodyStrong(17, relativeTo: .body)
   ) -> some View {
      HStack(spacing: 12) {
         Text(title)
            .foregroundStyle(AppColor.textPrimary)

         Spacer(minLength: 12)

         Text(detail)
            .font(detailFont)
            .foregroundStyle(detailForeground)

         Image(systemName: "chevron.right")
            .font(.appBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
   }

   private func settingsStandaloneNavigationButton(
      _ title: String,
      detail: String
   ) -> some View {
      settingsNavigationRow(
         title,
         detail: detail,
         detailForeground: AppColor.textPrimary
      )
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .containerShape(.rect(cornerRadius: 24))
      .background(
         Color.white,
         in: .rect(cornerRadius: 24)
      )
   }
   
   private var archivedToDos: [ToDo] {
      scopedToDos
         .filter(\.isArchived)
         .sorted { $0.createdAt > $1.createdAt }
   }

   private var archiveCountLabel: String {
      let count = archivedToDos.count
      return count == 1 ? "1 toDo" : "\(count) toDos"
   }
   
   private var unusedTagCount: Int {
      scopedTags.filter { tag in
         !scopedToDos.contains(where: { toDo in
            toDo.effectiveTags.contains(where: { $0.id == tag.id })
         })
         && !scopedNanoDos.contains(where: { $0.tag?.id == tag.id })
      }.count
   }
   
   private var customTagCount: Int {
      let defaultNames = Set(TagManagementView.defaultTagNames.map { $0.lowercased() })
      return scopedTags.filter { !defaultNames.contains($0.name.lowercased()) }.count
   }

   private var resolvedSortOption: AppPreferences.ToDoListSortOption {
      AppPreferences.ToDoListSortOption(rawValue: toDoListSortOption) ?? .dueDate
   }

   private var resolvedDoneSwipePrimaryAction: AppPreferences.DoneSwipePrimaryAction {
      AppPreferences.DoneSwipePrimaryAction(rawValue: doneSwipePrimaryActionRaw) ?? .archive
   }

   private var resolvedTimeSource: AppTimeSource {
      AppTimePreferences.resolvedTimeSource(from: appTimeSourceRaw)
   }

   private var notificationAuthorizationStatusLabel: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return "Allowed"
      case .denied:
         return "Denied"
      case .notDetermined:
         return "Off"
      @unknown default:
         return "Off"
      }
   }

   private var notificationDetailCopy: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return "\(timeSensitiveStatusCopy) Due reminders can alert you with quick snooze and mark-done actions. \(notificationManager.registrationState.statusText). \(notificationManager.pushReadinessDetail)"
      case .denied:
         return "Notification access is disabled, so due reminders and push registration are unavailable."
      case .notDetermined:
         return "Enable notifications to receive due reminders, time-sensitive alerts, and quick snooze actions."
      @unknown default:
         return "Enable notifications to receive due reminders, time-sensitive alerts, and quick snooze actions."
      }
   }

   private var notificationActionTitle: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return "Refresh Push Registration"
      case .denied:
         return "Open Notification Settings"
      case .notDetermined:
         return "Enable Notifications"
      @unknown default:
         return "Enable Notifications"
      }
   }

   private var notificationActionDetail: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return "Re-register for push notifications, refresh scheduled reminders, and re-check time-sensitive delivery."
      case .denied:
         return "Open system Settings to allow notifications for ToDo."
      case .notDetermined:
         return "Allow alerts, sounds, notification actions, and time-sensitive delivery for due reminders."
      @unknown default:
         return "Allow alerts, sounds, notification actions, and time-sensitive delivery for due reminders."
      }
   }

   private var timeSensitiveStatusCopy: String {
      switch notificationManager.timeSensitiveSetting {
      case .enabled:
         return "Time-sensitive delivery is enabled."
      case .disabled:
         return "Time-sensitive delivery is turned off in system settings."
      case .notSupported:
         return "Time-sensitive delivery is unavailable on this device."
      default:
         return "Time-sensitive delivery follows the system notification settings."
      }
   }

   private var notificationActionSystemName: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return "bell.badge"
      case .denied:
         return "gearshape"
      case .notDetermined:
         return "bell.badge"
      @unknown default:
         return "bell.badge"
      }
   }

   private var timeSourceDetail: String {
      switch resolvedTimeSource {
      case .system:
         return TimeZone.current.identifier
      case .location:
         if locationTimeZoneIdentifier == AppTimePreferences.appleParkTimeZoneIdentifier,
            !(locationTimeZoneService.authorizationStatus == .authorizedAlways || locationTimeZoneService.authorizationStatus == .authorizedWhenInUse) {
            return AppTimePreferences.appleParkLabel
         }
         return locationTimeZoneIdentifier
      }
   }

   private var locationAccessButtonTitle: String {
      switch locationTimeZoneService.authorizationStatus {
      case .authorizedAlways, .authorizedWhenInUse:
         return "Refresh Location Time"
      case .notDetermined:
         return "Use Current Location"
      case .denied, .restricted:
         return "Location Access Disabled"
      @unknown default:
         return "Use Current Location"
      }
   }

   private var locationStatusCopy: String {
      switch locationTimeZoneService.authorizationStatus {
      case .authorizedAlways, .authorizedWhenInUse:
         return "Current timezone updates from your location when you refresh it."
      case .notDetermined:
         return "Using Apple Park until location access is granted."
      case .denied, .restricted:
         return "Location access is unavailable, so the app stays on Apple Park time."
      @unknown default:
         return "Using Apple Park until location access is available."
      }
   }

   private var syncStatusTitle: String {
      syncCoordinator.effectiveSyncMode.title
   }

   private var syncStatusDetail: String {
      if let pendingMode = syncCoordinator.pendingRestartSyncMode {
         return "Close and reopen ToDo to finish activating \(pendingMode.title)."
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
         return "\(syncCoordinator.preferredSyncMode.title) is selected. Open Account to finish sign-in."
      }

      return syncCoordinator.effectiveSyncMode.subtitle
   }
   
   private func resetPreferences() {
      AppPreferences.resetToDefaults()
   }

   private func deleteUnusedTags() {
      let unusedTags = scopedTags.filter { tag in
         !scopedToDos.contains(where: { toDo in
            toDo.effectiveTags.contains(where: { $0.id == tag.id })
         })
         && !scopedNanoDos.contains(where: { $0.tag?.id == tag.id })
      }
      for tag in unusedTags {
         SyncTombstoneStore.recordDelete(
            table: .tags,
            recordID: tag.cloudID,
            userID: tag.ownerUserID
         )
         context.delete(tag)
      }
      persistChanges("Failed to delete unused tags")
   }

   private func persistChanges(_ message: String) {
      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()
      } catch {
         print("\(message): \(error)")
      }
   }

   private func handleNotificationAction() {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         notificationManager.registerForRemoteNotifications()
         notificationManager.scheduleRefresh()
      case .denied:
         openURL(appSettingsURL)
      case .notDetermined:
         Task {
            await notificationManager.requestAuthorizationFlow()
         }
      @unknown default:
         Task {
            await notificationManager.requestAuthorizationFlow()
         }
      }
   }

   private func manualSyncRefresh() {
      guard authStore.effectiveSyncMode == .syncEverywhere,
            let userID = authStore.currentUserID else { return }

      Task {
         await syncCoordinator.refreshFromRemote(userID: userID)
         await NotificationManager.shared.syncScheduledNotifications()
      }
   }

   private func settingsActionRow(
      systemName: String,
      title: String,
      detail: String,
      foregroundStyle: Color = AppColor.textPrimary,
      backgroundStyle: Color = AppColor.surfaceMuted,
      contentVerticalAlignment: VerticalAlignment = .top,
      isDisabled: Bool = false,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         HStack(alignment: contentVerticalAlignment, spacing: 12) {
            Image(systemName: systemName)
               .font(.appDisplay(15, relativeTo: .subheadline))
               .foregroundStyle(foregroundStyle)
               .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
               Text(title)
                  .font(.appBodyStrong(15, relativeTo: .subheadline))
                  .foregroundStyle(foregroundStyle)

               Text(detail)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 0)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.horizontal, 14)
         .padding(.vertical, 12)
         .contentShape(.rect(cornerRadius: 18))
         .containerShape(.rect(cornerRadius: 18))
         .background(
            backgroundStyle,
            in: .rect(corners: .concentric, isUniform: true)
         )
         .clipShape(.rect(cornerRadius: 18))
      }
      .buttonStyle(.plain)
      .disabled(isDisabled)
      .opacity(isDisabled ? 0.45 : 1)
   }

   private var syncStatusBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 12) {
            Text("Current Sync")
               .font(.appBody(17, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)

            Text(syncStatusTitle)
               .font(.appBodyStrong(17, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
         }

         Text(syncStatusDetail)
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)

         SyncHealthStatusView(
            syncCoordinator: syncCoordinator,
            isAccountAuthenticated: authStore.isAuthenticated,
            unresolvedConflictCount: unresolvedSyncConflicts.count,
            onRefresh: manualSyncRefresh
         )
         .padding(.top, 2)
      }
   }

   private var syncReviewRow: some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: "exclamationmark.triangle.fill")
            .font(.appDisplay(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.secondary)
            .frame(width: 18, height: 18)

         VStack(alignment: .leading, spacing: 4) {
            Text("Sync Needs Review")
               .font(.appBodyStrong(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)

            Text(syncReviewDetail)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }

         Spacer(minLength: 0)

         Image(systemName: "chevron.right")
            .font(.appBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(
         AppColor.secondary.opacity(0.1),
         in: .rect(corners: .concentric, isUniform: true)
      )
   }

   private var syncReviewDetail: String {
      let count = unresolvedSyncConflicts.count
      return count == 1
         ? "1 ToDo changed in two places. Choose which version to keep."
         : "\(count) ToDos changed in two places. Choose which versions to keep."
   }

   private var syncDiagnosticsSummary: String {
      if !unresolvedSyncConflicts.isEmpty {
         return "Needs review"
      }

      if syncCoordinator.syncActivityState == .failed {
         return "Sync failed"
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere && !authStore.isAuthenticated {
         return "Needs sign in"
      }

      return syncCoordinator.syncActivityState == .synced ? "Healthy" : syncCoordinator.effectiveSyncMode.title
   }

   private var syncDeletionPreferenceToggle: some View {
      Toggle(isOn: $mirrorSyncDeletesToDeviceOnly) {
         VStack(alignment: .leading, spacing: 4) {
            Text("Mirror Sync Deletes Locally")
               .font(.appBodyStrong(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)

            Text("When on, deleting a ToDo while signed in also removes the matching This Device Only copy. Turn it off if you want local backups to survive sign-out.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
      .tint(AppColor.actionSecondary)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(
         AppColor.surfaceMuted,
         in: .rect(corners: .concentric, isUniform: true)
      )
   }

   private var notificationSettingsBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 12) {
            Text("Notifications")
               .font(.appBody(17, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)

            Text(notificationAuthorizationStatusLabel)
               .font(.appBodyStrong(17, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
         }

         Text(notificationDetailCopy)
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)

         settingsActionRow(
            systemName: notificationActionSystemName,
            title: notificationActionTitle,
            detail: notificationActionDetail,
            contentVerticalAlignment: .center
         ) {
            handleNotificationAction()
         }
      }
   }

   private var settingsSortDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               isSortMenuExpanded.toggle()
            }
         } label: {
            HStack(alignment: .center, spacing: 12) {
               Text("Sorting")
                  .font(.appBody(17, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Spacer(minLength: 12)

               HStack(spacing: 8) {
                  Text(resolvedSortOption.title)
                     .font(.appBodyStrong(17, relativeTo: .body))
                     .foregroundStyle(AppColor.textSecondary)

                  Image(systemName: "chevron.right")
                     .font(.appBodyStrong(11, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
                     .rotationEffect(.degrees(isSortMenuExpanded ? 90 : 0))
               }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
         }
         .buttonStyle(.plain)

         VStack(alignment: .leading, spacing: 12) {
            compactSortOptionsRow(
               title: "Order",
               options: AppPreferences.ToDoListSortOption.orderingOptions
            )

            compactSortOptionsRow(
               title: "Group",
               options: AppPreferences.ToDoListSortOption.groupingOptions
            )
         }
         .frame(maxHeight: isSortMenuExpanded ? 108 : 0, alignment: .top)
         .opacity(isSortMenuExpanded ? 1 : 0)
         .scaleEffect(y: isSortMenuExpanded ? 1 : 0.96, anchor: .top)
         .clipped()
         .allowsHitTesting(isSortMenuExpanded)
      }
   }

   private func compactSortOptionsRow(
      title: String,
      options: [AppPreferences.ToDoListSortOption]
   ) -> some View {
      VStack(alignment: .leading, spacing: 6) {
         Text(title)
            .font(.appDisplay(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)

         ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
               ForEach(options) { option in
                  compactSortChip(
                     title: option.title,
                     isSelected: option == resolvedSortOption,
                     direction: option == resolvedSortOption ? currentSortDirectionSymbol : nil
                  ) {
                     handleSortSelection(option)
                  }
               }
            }
            .padding(.vertical, 1)
         }
      }
   }

   private func compactSortChip(
      title: String,
      isSelected: Bool,
      direction: String? = nil,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         HStack(spacing: 6) {
            Text(title)
               .font(isSelected ? .appSubtitle(13, relativeTo: .caption) : .appBodyStrong(13, relativeTo: .caption))

            if let direction {
               Image(systemName: direction)
                  .font(.appBodyStrong(10, relativeTo: .caption))
            }
         }
         .foregroundStyle(isSelected ? AppColor.onAction : AppColor.textPrimary)
         .padding(.horizontal, 12)
         .padding(.vertical, 8)
         .background(
            Capsule()
               .fill(isSelected ? AppColor.actionSecondary : AppColor.surfaceMuted)
         )
         .overlay {
            Capsule()
               .stroke(isSelected ? AppColor.actionSecondary : AppColor.border.opacity(0.4), lineWidth: 1)
         }
      }
      .buttonStyle(.plain)
   }

   private var currentSortDirectionSymbol: String {
      isToDoListSortReversed ? "arrow.up" : "arrow.down"
   }

   private func handleSortSelection(_ option: AppPreferences.ToDoListSortOption) {
      if resolvedSortOption == option {
         isToDoListSortReversed.toggle()
      } else {
         toDoListSortOption = option.rawValue
         isToDoListSortReversed = false
      }
      withAnimation(AppAnimation.snappyFast) {
         isSortMenuExpanded = false
      }
   }

   private var timeSourceDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               isTimeSourceMenuExpanded.toggle()
            }
         } label: {
            HStack(alignment: .center, spacing: 12) {
               Text("Time Based On")
                  .font(.appBody(17, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Spacer(minLength: 12)

               HStack(spacing: 8) {
                  Text(resolvedTimeSource.title)
                     .font(.appBodyStrong(17, relativeTo: .body))
                     .foregroundStyle(AppColor.textSecondary)

                  Image(systemName: "chevron.right")
                     .font(.appBodyStrong(11, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
                     .rotationEffect(.degrees(isTimeSourceMenuExpanded ? 90 : 0))
               }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
         }
         .buttonStyle(.plain)

         Text(timeSourceDetail)
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)

         VStack(alignment: .leading, spacing: 6) {
            ForEach(AppTimeSource.allCases) { source in
               Button {
                  appTimeSourceRaw = source.rawValue
                  withAnimation(AppAnimation.snappyFast) {
                     isTimeSourceMenuExpanded = false
                  }
               } label: {
                  HStack(spacing: 10) {
                     Text(source.title)
                        .font(source == resolvedTimeSource ? .appSubtitle(14, relativeTo: .subheadline) : .appBodyStrong(14, relativeTo: .subheadline))
                        .foregroundStyle(source == resolvedTimeSource ? AppColor.textPrimary : AppColor.textSecondary)

                     Spacer(minLength: 8)

                     if source == resolvedTimeSource {
                        Image(systemName: "checkmark")
                           .font(.appBodyStrong(12, relativeTo: .caption))
                           .foregroundStyle(AppColor.secondary)
                     }
                  }
                  .padding(.horizontal, 14)
                  .padding(.vertical, 12)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .containerShape(.rect(cornerRadius: 18))
                  .background(
                     (source == resolvedTimeSource ? AppColor.surfaceMuted : Color.white),
                     in: .rect(corners: .concentric, isUniform: true)
                  )
               }
               .buttonStyle(.plain)
            }
         }
         .frame(height: isTimeSourceMenuExpanded ? nil : 0, alignment: .top)
         .clipped()
         .opacity(isTimeSourceMenuExpanded ? 1 : 0)

         if resolvedTimeSource == .location {
            settingsActionRow(
               systemName: "location",
               title: locationAccessButtonTitle,
               detail: locationStatusCopy,
               foregroundStyle: AppColor.actionDestructive,
               backgroundStyle: AppColor.actionDestructive.opacity(0.08),
               contentVerticalAlignment: .center,
               isDisabled: locationTimeZoneService.authorizationStatus == .denied || locationTimeZoneService.authorizationStatus == .restricted
            ) {
               locationTimeZoneService.requestLocationTimeZoneAccess()
            }
         }
      }
   }

   private var doneSwipeActionDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               isDoneSwipeMenuExpanded.toggle()
            }
         } label: {
            HStack(alignment: .center, spacing: 12) {
               Text("Remove Done ToDo")
                  .font(.appBody(17, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Spacer(minLength: 12)

               HStack(spacing: 8) {
                  Text(resolvedDoneSwipePrimaryAction.title)
                     .font(.appBodyStrong(17, relativeTo: .body))
                     .foregroundStyle(AppColor.textSecondary)

                  Image(systemName: "chevron.right")
                     .font(.appBodyStrong(11, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
                     .rotationEffect(.degrees(isDoneSwipeMenuExpanded ? 90 : 0))
               }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
         }
         .buttonStyle(.plain)

         VStack(alignment: .leading, spacing: 6) {
            ForEach(AppPreferences.DoneSwipePrimaryAction.allCases) { action in
               Button {
                  doneSwipePrimaryActionRaw = action.rawValue
                  withAnimation(AppAnimation.snappyFast) {
                     isDoneSwipeMenuExpanded = false
                  }
               } label: {
                  HStack(spacing: 10) {
                     Text(action.title)
                        .font(action == resolvedDoneSwipePrimaryAction ? .appSubtitle(14, relativeTo: .subheadline) : .appBodyStrong(14, relativeTo: .subheadline))
                        .foregroundStyle(action == resolvedDoneSwipePrimaryAction ? AppColor.textPrimary : AppColor.textSecondary)

                     Spacer(minLength: 8)

                     if action == resolvedDoneSwipePrimaryAction {
                        Image(systemName: "checkmark")
                           .font(.appBodyStrong(12, relativeTo: .caption))
                           .foregroundStyle(AppColor.secondary)
                     }
                  }
                  .padding(.horizontal, 14)
                  .padding(.vertical, 12)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .containerShape(.rect(cornerRadius: 18))
                  .background(
                     (action == resolvedDoneSwipePrimaryAction ? AppColor.surfaceMuted : Color.white),
                     in: .rect(corners: .concentric, isUniform: true)
                  )
               }
               .buttonStyle(.plain)
            }
         }
         .frame(height: isDoneSwipeMenuExpanded ? nil : 0, alignment: .top)
         .clipped()
         .opacity(isDoneSwipeMenuExpanded ? 1 : 0)
      }
   }
}

struct SyncConflictReviewView: View {
   @Environment(\.modelContext) private var context
   @State private var resolvingConflictIDs = Set<UUID>()
   @State private var resolutionErrorMessage: String?
   @State private var pendingResolution: PendingConflictResolution?
   let conflicts: [SyncConflict]
   let toDos: [ToDo]

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
               Text("Sync Needs Review")
                  .font(.appTitle(34, relativeTo: .largeTitle))
                  .foregroundStyle(AppColor.textPrimary)

               Text("These ToDos changed on another device while this device had unsynced edits. Choose the version that should continue syncing.")
                  .font(.appBody(14, relativeTo: .footnote))
                  .foregroundStyle(AppColor.textSecondary)
            }

            if let resolutionErrorMessage {
               Label {
                  Text(resolutionErrorMessage)
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textPrimary)
               } icon: {
                  Image(systemName: "exclamationmark.circle.fill")
                     .foregroundStyle(AppColor.actionDestructive)
               }
               .padding(12)
               .background(AppColor.actionDestructive.opacity(0.08), in: .rect(cornerRadius: 16))
            }

            if unresolvedConflicts.isEmpty {
               allClearCard
            }

            ForEach(unresolvedConflicts) { conflict in
               conflictCard(conflict)
            }
         }
         .padding(16)
      }
      .background(AppColor.surface)
      .appBaseTypography()
      .appNavigationChrome()
      .alert("Confirm Sync Choice", isPresented: isShowingPendingResolution) {
         Button("Cancel", role: .cancel) {}
         if let pendingResolution {
            Button(pendingResolution.actionTitle) {
               resolve(pendingResolution.conflict, as: pendingResolution.resolution)
            }
         }
      } message: {
         Text(pendingResolution?.message ?? "")
      }
   }

   private var unresolvedConflicts: [SyncConflict] {
      conflicts.filter { !$0.isResolved }
   }

   private var isShowingPendingResolution: Binding<Bool> {
      Binding {
         pendingResolution != nil
      } set: { isPresented in
         if !isPresented {
            pendingResolution = nil
         }
      }
   }

   private var allClearCard: some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: "checkmark.circle.fill")
            .font(.appDisplay(18, relativeTo: .headline))
            .foregroundStyle(AppColor.tertiary)

         VStack(alignment: .leading, spacing: 4) {
            Text("All Clear")
               .font(.appBodyStrong(16, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Text("No ToDos need sync review right now.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.white, in: .rect(cornerRadius: 24))
   }

   private func conflictCard(_ conflict: SyncConflict) -> some View {
      let isResolving = resolvingConflictIDs.contains(conflict.id)

      return VStack(alignment: .leading, spacing: 14) {
         HStack(alignment: .top, spacing: 12) {
            Image(systemName: conflict.severity == .destructive ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
               .font(.appDisplay(18, relativeTo: .headline))
               .foregroundStyle(conflict.severity == .destructive ? AppColor.actionDestructive : AppColor.secondary)
               .symbolEffect(.pulse, value: conflict.id)

            VStack(alignment: .leading, spacing: 4) {
               Text(conflict.title)
                  .font(.appBodyStrong(16, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Text(conflict.message)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
         }

         versionBlock(
            title: "This Device",
            summary: conflict.localSummary,
            updatedAt: conflict.localUpdatedAt
         )
         versionBlock(
            title: "Synced Version",
            summary: conflict.syncedSummary,
            updatedAt: conflict.syncedUpdatedAt
         )

         HStack(spacing: 10) {
            Button {
               pendingResolution = PendingConflictResolution(
                  conflict: conflict,
                  resolution: .keepDeviceVersion
               )
            } label: {
               Label("Keep This Device", systemImage: "iphone")
                  .font(.appBodyStrong(13, relativeTo: .footnote))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppColor.actionSecondary)
            .disabled(isResolving)

            Button {
               pendingResolution = PendingConflictResolution(
                  conflict: conflict,
                  resolution: .useSyncedVersion
               )
            } label: {
               Label("Use Synced", systemImage: "checkmark.icloud")
                  .font(.appBodyStrong(13, relativeTo: .footnote))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.actionPrimary)
            .disabled(isResolving)
         }

         if isResolving {
            HStack(spacing: 8) {
               ProgressView()
                  .controlSize(.mini)
                  .tint(AppColor.actionPrimary)

               Text("Saving your choice and syncing it now.")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
         }
      }
      .padding(16)
      .background(Color.white, in: .rect(cornerRadius: 24))
      .overlay {
         RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(AppColor.secondary.opacity(0.18), lineWidth: 1)
      }
   }

   private func versionBlock(title: String, summary: String, updatedAt: Date?) -> some View {
      VStack(alignment: .leading, spacing: 5) {
         Text(title)
            .font(.appSubtitle(12, relativeTo: .caption))
            .foregroundStyle(AppColor.secondary)

         Text(summary)
            .font(.appBodyStrong(14, relativeTo: .footnote))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

         if let updatedAt {
            Text("Changed \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
               .font(.appBody(11, relativeTo: .caption2))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
      .padding(12)
      .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))
   }

   private func resolve(_ conflict: SyncConflict, as resolution: SyncConflictResolution) {
      guard !resolvingConflictIDs.contains(conflict.id) else { return }

      resolvingConflictIDs.insert(conflict.id)
      resolutionErrorMessage = nil

      Task { @MainActor in
         do {
            try SyncConflictStore.resolve(conflict, resolution: resolution, toDos: toDos, in: context)
            if let userID = conflict.userID {
               await SyncCoordinator.shared.flushLocalSync(userID: userID)
            }
            SyncCoordinator.shared.showTransientFeedback(
               title: "Sync Choice Saved",
               message: "ToDo is syncing the version you selected.",
               style: .success
            )
         } catch {
            resolutionErrorMessage = "Could not save that sync choice. \(error.localizedDescription)"
            print("Failed to resolve sync conflict: \(error)")
         }

         resolvingConflictIDs.remove(conflict.id)
      }
   }

   private struct PendingConflictResolution: Identifiable {
      let conflict: SyncConflict
      let resolution: SyncConflictResolution

      var id: String {
         "\(conflict.id)-\(actionTitle)"
      }

      var actionTitle: String {
         switch resolution {
         case .keepDeviceVersion:
            return "Keep This Device"
         case .useSyncedVersion:
            return "Use Synced"
         }
      }

      var message: String {
         switch resolution {
         case .keepDeviceVersion:
            return "ToDo will keep this device's version and send it back to ToDo Sync."
         case .useSyncedVersion:
            return "ToDo will replace this device's version with the synced version."
         }
      }
   }
}

struct SyncDiagnosticsView: View {
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   @StateObject private var notificationManager = NotificationManager.shared
   let toDos: [ToDo]
   let tags: [Tag]
   let nanoDos: [NanoDo]
   let unresolvedConflictCount: Int

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
               Text("Sync Diagnostics")
                  .font(.appTitle(34, relativeTo: .largeTitle))
                  .foregroundStyle(AppColor.textPrimary)

               Text("Use this as the quick device-to-device QA panel before deeper Supabase checks.")
                  .font(.appBody(14, relativeTo: .footnote))
                  .foregroundStyle(AppColor.textSecondary)
            }

            diagnosticsSection("Mode") {
               diagnosticsRow("Preferred", value: syncCoordinator.preferredSyncMode.title)
               diagnosticsRow("Active", value: syncCoordinator.effectiveSyncMode.title)
               diagnosticsRow("State", value: syncStateLabel)
               diagnosticsRow("Last Sync", value: lastSyncLabel)
            }

            diagnosticsSection("Account") {
               diagnosticsRow("Signed In", value: authStore.isAuthenticated ? "Yes" : "No")
               diagnosticsRow("Method", value: authStore.signInMethodLabel ?? "None")
               diagnosticsRow("Email", value: authStore.signedInEmail ?? "None")
            }

            diagnosticsSection("Device Data") {
               diagnosticsRow("ToDos", value: "\(toDos.count)")
               diagnosticsRow("Tags", value: "\(tags.count)")
               diagnosticsRow("NanoDos", value: "\(nanoDos.count)")
               diagnosticsRow("Conflicts", value: unresolvedConflictCount == 0 ? "None" : "\(unresolvedConflictCount) need review")
            }

            diagnosticsSection("Push") {
               diagnosticsRow("Permission", value: notificationPermissionLabel)
               diagnosticsRow("APNs", value: notificationManager.registrationState.statusText)

               Text(notificationManager.pushReadinessDetail)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }

            Button {
               runManualRefresh()
            } label: {
               Label("Refresh ToDo Sync Now", systemImage: "arrow.clockwise")
                  .font(.appBodyStrong(14, relativeTo: .subheadline))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 12)
                  .foregroundStyle(AppColor.onAction)
                  .background(AppColor.actionPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(authStore.effectiveSyncMode != .syncEverywhere || authStore.currentUserID == nil)
            .opacity(authStore.effectiveSyncMode == .syncEverywhere && authStore.currentUserID != nil ? 1 : 0.45)
         }
         .padding(16)
      }
      .background(AppColor.surface)
      .appBaseTypography()
      .appNavigationChrome()
      .task {
         await notificationManager.refreshAuthorizationStatus()
      }
   }

   private var syncStateLabel: String {
      if syncCoordinator.effectiveSyncMode == .syncEverywhere && !authStore.isAuthenticated {
         return "Needs Sign In"
      }

      if unresolvedConflictCount > 0 {
         return "Needs Review"
      }

      switch syncCoordinator.syncActivityState {
      case .idle:
         return "Active"
      case .activating:
         return "Activating"
      case .syncing:
         return syncCoordinator.currentSyncPhase == .queuedLocalChanges ? "Waiting to Sync" : "Syncing"
      case .synced:
         return "Active"
      case .failed:
         return "Sync Failed"
      }
   }

   private var lastSyncLabel: String {
      guard let lastSuccessfulSyncAt = syncCoordinator.lastSuccessfulSyncAt else {
         return "Not yet"
      }

      return lastSuccessfulSyncAt.formatted(date: .abbreviated, time: .shortened)
   }

   private var notificationPermissionLabel: String {
      switch notificationManager.authorizationStatus {
      case .authorized:
         return "Allowed"
      case .provisional:
         return "Provisional"
      case .ephemeral:
         return "Ephemeral"
      case .denied:
         return "Denied"
      case .notDetermined:
         return "Not Requested"
      @unknown default:
         return "Unknown"
      }
   }

   private func diagnosticsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(title)
            .font(.appSubtitle(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 10) {
            content()
         }
         .padding(16)
         .frame(maxWidth: .infinity, alignment: .leading)
         .background(Color.white, in: .rect(cornerRadius: 24))
      }
   }

   private func diagnosticsRow(_ title: String, value: String) -> some View {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
         Text(title)
            .font(.appBody(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.textSecondary)

         Spacer(minLength: 12)

         Text(value)
            .font(.appBodyStrong(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.textPrimary)
            .multilineTextAlignment(.trailing)
      }
   }

   private func runManualRefresh() {
      guard authStore.effectiveSyncMode == .syncEverywhere,
            let userID = authStore.currentUserID else { return }

      Task {
         await syncCoordinator.refreshFromRemote(userID: userID)
         await notificationManager.syncScheduledNotifications()
      }
   }
}

#Preview {
   let container = PreviewSupport.makeModelContainer()
   NavigationStack {
      SettingsView()
   }
   .modelContainer(container)
   .environmentObject(SupabaseAuthStore.preview)
}

#Preview("Sync Diagnostics") {
   let container = PreviewSupport.makeModelContainer()
   NavigationStack {
      SyncDiagnosticsView(
         toDos: [],
         tags: [],
         nanoDos: [],
         unresolvedConflictCount: 0
      )
   }
   .modelContainer(container)
   .environmentObject(SupabaseAuthStore.preview)
}
