import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @Environment(\.openURL) private var openURL
   @Environment(\.colorScheme) private var colorScheme
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Query private var tags: [Tag]
   @Query private var toDos: [ToDo]
   @Query private var nanoDos: [NanoDo]
   @Query private var syncConflicts: [SyncConflict]

   @AppStorage(AppPreferences.Keys.toDoListSortOption) private var toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
   @AppStorage(AppPreferences.Keys.toDoListSortReversed) private var isToDoListSortReversed = false
   @AppStorage(AppPreferences.Keys.createToDoTagsEnabledByDefault) private var createToDoTagsEnabledByDefault = false
   @AppStorage(AppPreferences.Keys.mirrorDueDatesToCalendar) private var mirrorDueDatesToCalendar = false
   @AppStorage(AppPreferences.Keys.doneSwipePrimaryAction) private var doneSwipePrimaryActionRaw = AppPreferences.DoneSwipePrimaryAction.archive.rawValue
   @AppStorage(AppPreferences.Keys.appTimeSource) private var appTimeSourceRaw = AppTimeSource.location.rawValue
   @AppStorage(AppPreferences.Keys.locationTimeZoneIdentifier) private var locationTimeZoneIdentifier = AppTimePreferences.appleParkTimeZoneIdentifier
   @AppStorage(AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly) private var mirrorSyncDeletesToDeviceOnly = true
   @AppStorage(AppPreferences.Keys.appIconBadgePolicy) private var appIconBadgePolicyRaw = AppPreferences.AppIconBadgePolicy.overdue.rawValue
   @AppStorage(AppPreferences.Keys.notificationSoundOption) private var notificationSoundOptionRaw = AppPreferences.NotificationSoundOption.defaultSound.rawValue
   @AppStorage("trashAutoEmptyInterval") private var trashAutoEmptyIntervalRaw = TrashAutoEmptyInterval.oneMonth.rawValue

   @State private var isShowingDeleteUnusedTagsConfirmation = false
   @State private var isSortMenuExpanded = false
   @State private var isDoneSwipeMenuExpanded = false
   @State private var isTimeSourceMenuExpanded = false
   @StateObject private var onboardingManager = GuidedOnboardingManager.shared
   @StateObject private var notificationManager = NotificationManager.shared
   @StateObject private var locationTimeZoneService = LocationTimeZoneService()
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   private let brandWebsiteURL = URL(string: "https://yourtodo.today")!
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

   private var accountSummaryDetail: String {
      if let provider = authStore.accountProviderLabel {
         return provider
      }

      switch authStore.effectiveSyncMode {
      case .deviceOnly:
         return String(localized: "Local")
      case .iCloud:
         return "Apple"
      case .syncEverywhere:
         return authStore.isAuthenticated ? String(localized: "ToDo Sync") : authStore.accountStatusLabel
      }
   }

   var body: some View {
      ZStack(alignment: .top) {
         ScrollView {
            VStack(alignment: .leading, spacing: 24) {
               settingsSection(String(localized: "Account")) {
                  NavigationLink {
                     if authStore.isAuthenticated {
                        AccountView()
                     } else {
                        AuthenticationScreenView()
                     }
                  } label: {
                     settingsNavigationRow(
                        authStore.isAuthenticated ? String(localized: "Profile & Session") : String(localized: "Set Up Account"),
                        detail: accountSummaryDetail
                     )
                     .onboardingSpotlightAnchor(.settingsAccount)
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  Text(String(localized: "Manage your identity and the account connected to this device."))
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               settingsSection(String(localized: "Sync")) {
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
                        String(localized: "Storage & Sync"),
                        detail: syncCoordinator.pendingRestartSyncMode != nil ? String(localized: "Needs relaunch") : syncCoordinator.preferredSyncMode.title
                     )
                     .onboardingSpotlightAnchor(.settingsSync)
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     syncDetailsSettingsScreen
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Sync Details"),
                        detail: mirrorSyncDeletesToDeviceOnly ? String(localized: "Mirrors deletes") : String(localized: "Keeps local")
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Preferences")) {
                  NavigationLink {
                     behaviorSettingsScreen
                  } label: {
                     settingsNavigationRow(
                        String(localized: "ToDo Behavior"),
                        detail: resolvedSortOption.title
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     notificationSettingsScreen
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Notifications"),
                        detail: notificationAuthorizationStatusLabel
                     )
                     .onboardingSpotlightAnchor(.settingsNotifications)
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     tagSettingsScreen
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Tags"),
                        detail: customTagCountLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     StatsView(ownerUserID: visibleOwnerUserID)
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Stats"),
                        detail: statsSummaryDetail
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Data")) {
                  NavigationLink {
                     dataControlsSettingsScreen
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Data Controls"),
                        detail: String(localized: "Maintenance")
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     ArchivesView()
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Archives"),
                        detail: archiveCountLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  NavigationLink {
                     TrashView()
                  } label: {
                     settingsNavigationRow(
                        String(localized: "Trash"),
                        detail: trashCountLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               #if DEBUG
               settingsSection(String(localized: "Developer")) {
                  settingsActionRow(
                     systemName: "sparkles",
                     title: "Run Guided Onboarding",
                     detail: "Development-only trigger for testing the first-run guided setup."
                  ) {
                     onboardingManager.restartForTesting()
                     closeView()
                  }
               }
               #endif

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
      .tint(AppColor.main)
      .appBaseTypography()
      .appNavigationChrome()
      .toolbar(.hidden, for: .navigationBar)
      .overlayPreferenceValue(OnboardingSpotlightPreferenceKey.self) { anchors in
         if onboardingManager.blocksSettingsChrome {
            GuidedOnboardingOverlay(manager: onboardingManager, anchors: anchors) { step in
               handleOnboardingPrimaryAction(step)
            }
            .zIndex(1200)
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

   private var behaviorSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "ToDo Behavior",
         subtitle: "Tune how ToDos are ordered, timed, completed, and mirrored outside the app."
      ) {
         settingsSection("List") {
            settingsSortDropdown
         }

         settingsSection("Time") {
            timeSourceDropdown
         }

         settingsSection("Done ToDos") {
            doneSwipeActionDropdown

            NavigationLink {
               SnoozeOptionsView()
            } label: {
                  settingsNavigationRow(
                  "Snooze Options",
                  detail: String(localized: "Manage presets")
               )
            }
            .foregroundStyle(AppColor.textPrimary)
         }

         settingsSection("Calendar") {
            calendarMirrorToggle
         }
      }
   }

   private func handleOnboardingPrimaryAction(_ step: GuidedOnboardingStep) {
      switch step {
      case .signInAndSync:
         onboardingManager.advance(to: .notificationPermission)
      case .notificationPermission:
         Task { @MainActor in
            await notificationManager.requestAuthorizationFlow()
            onboardingManager.advance(to: .archiveVsDelete)
         }
      case .archiveVsDelete:
         onboardingManager.advance(to: .completion)
      case .completion:
         onboardingManager.complete()
         closeView()
      default:
         break
      }
   }

   private var notificationSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Notifications",
         subtitle: "Control reminders, time-sensitive alerts, push registration, and the app icon badge."
      ) {
         settingsSection("Reminder Alerts") {
            notificationSettingsBlock
         }
      }
   }

   private var tagSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Tags",
         subtitle: "Keep the main ToDo flow light while managing tag behavior and cleanup here."
      ) {
         settingsSection("Defaults") {
            Toggle(isOn: $createToDoTagsEnabledByDefault) {
               VStack(alignment: .leading, spacing: 4) {
                  Text("Enable Tags by Default")
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Text("New ToDos start with tag entry available instead of staying focused only on the task text.")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }
            }
            .tint(AppColor.actionSecondary)
         }

         settingsSection("Library") {
            NavigationLink {
               TagManagementView()
            } label: {
               settingsNavigationRow(
                  "Tag Management",
                  detail: customTagCountLabel
               )
            }
            .foregroundStyle(AppColor.textPrimary)

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
      }
   }

   private var syncDetailsSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Sync Details",
         subtitle: "Advanced sync behavior lives here so the main Settings view stays readable."
      ) {
         settingsSection("Local Copies") {
            syncDeletionPreferenceToggle
         }
      }
   }

   private var dataControlsSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Data Controls",
         subtitle: "Maintenance actions are grouped here because they change stored data or app defaults."
      ) {
         settingsSection("Trash") {
            trashAutoEmptyControl
         }

         settingsSection("Preferences") {
            settingsActionRow(
               systemName: "arrow.counterclockwise",
               title: "Reset Preferences",
               detail: "Restore sorting and default tag-entry behavior to the app defaults."
            ) {
               resetPreferences()
            }
         }
      }
   }

   private var calendarMirrorToggle: some View {
      Toggle(isOn: $mirrorDueDatesToCalendar) {
         VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
               Text("Mirror Due ToDos to Calendar")
                  .font(.appBodyStrong(15, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textPrimary)

               Text(mirrorDueDatesToCalendar ? "Active" : "Off")
                  .font(.appBodyStrong(10, relativeTo: .caption2))
                  .foregroundStyle(mirrorDueDatesToCalendar ? AppColor.onAction : AppColor.textSecondary)
                  .padding(.horizontal, 7)
                  .padding(.vertical, 3)
                  .background(
                     mirrorDueDatesToCalendar ? AppColor.actionSecondary : AppColor.surfaceMuted,
                     in: Capsule()
                  )
            }

            Text("Active due ToDos appear in Calendar. Completing, archiving, deleting, or removing a due date removes the mirrored event.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
      .tint(AppColor.actionSecondary)
   }

   private var trashAutoEmptyControl: some View {
      VStack(alignment: .leading, spacing: 10) {
         Menu {
            ForEach(TrashAutoEmptyInterval.allCases) { interval in
               Button {
                  trashAutoEmptyIntervalRaw = interval.rawValue
               } label: {
                  HStack {
                     Text(interval.title)
                     if interval == resolvedTrashInterval {
                        Image(systemName: "checkmark")
                     }
                  }
               }
            }
         } label: {
            settingsNavigationRow(
               "Auto-Empty Trash",
               detail: resolvedTrashInterval.title
            )
         }
         .buttonStyle(.plain)
         .padding(16)
         .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))

         Text("Deleted ToDos will be permanently removed after this much time in the trash.")
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 4)
      }
   }

   private var trashedToDos: [ToDo] {
      scopedToDos.filter { $0.lifecycleState == .trashed }
   }

   private var trashCountLabel: String {
      let count = trashedToDos.count
      return AppLocalization.localizedCount(count, singularKey: "%@ item", pluralKey: "%@ items")
   }

   private var resolvedTrashInterval: TrashAutoEmptyInterval {
      TrashAutoEmptyInterval(rawValue: trashAutoEmptyIntervalRaw) ?? .oneMonth
   }

   private var madeByBrandView: some View {
      VStack(spacing: 12) {
         Text("\(Text("toDō").foregroundStyle(AppColor.main).bold()) what matters")
            .font(.appSubtitle(16, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textPrimary)
            .multilineTextAlignment(.center)

         Link(destination: brandWebsiteURL) {
            Text("yourtodo.today")
               .font(.appBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(AppColor.actionPrimary)
         }
         .buttonStyle(.plain)

         VStack(spacing: 8) {
            Text("by")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: 10) {
               Image("brand-logomark")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 34, height: 34)
                  .aspectRatio(1, contentMode: .fit)

               brandWordmark
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .center)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("moin.shift()")
         }
         .padding(.top, 8)
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, -16)
      .padding(.top, 6)
      .padding(.bottom, 8)
   }

   private var brandWordmark: some View {
      HStack(spacing: 0) {
         Text("mo")
            .font(brandWordmarkFont)
         Text("i").italic()
            .font(brandWordmarkItalicFont)
         Text("n.")
            .font(brandWordmarkFont)
         Text("sh").italic()
            .font(brandWordmarkItalicFont)
         Text("i")
            .font(brandWordmarkFont)
         Text("ft()").italic()
            .font(brandWordmarkItalicFont)
      }
      .foregroundStyle(AppColor.textPrimary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("moin.shift()")
   }

   private var brandWordmarkFont: Font {
      .custom("Aleo-Bold", size: 17, relativeTo: .footnote)
   }

   private var brandWordmarkItalicFont: Font {
      .custom("Aleo-BoldItalic", size: 17, relativeTo: .footnote)
   }

   private var pinnedTitleHeader: some View {
      VStack(spacing: 0) {
         HStack(alignment: .center, spacing: 12) {
            Text("Settings")
               .font(.appTitle(34, relativeTo: .largeTitle))
               .foregroundStyle(colorScheme == .dark ? AppColor.black : AppColor.white)
               .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            Button {
               closeView()
            } label: {
               Image(systemName: "xmark")
                  .font(.appBodyStrong(21, relativeTo: .largeTitle))
                  .foregroundStyle(AppColor.main)
                  .frame(width: 34, height: 34)
                  .background(colorScheme == .dark ? AppColor.black : AppColor.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close settings")
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.horizontal, 16)
         .padding(.top, 8)
         .padding(.bottom, 14)
         .background(AppColor.main)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(LocalizedStringKey(title))
            .font(.appSubtitle(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.main)

         VStack(alignment: .leading, spacing: 14) {
            content()
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(
            AppColor.surfaceElevated,
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
         Text(LocalizedStringKey(title))
            .foregroundStyle(AppColor.textPrimary)

         Spacer(minLength: 12)

         Text(LocalizedStringKey(detail))
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
         AppColor.surfaceElevated,
         in: .rect(cornerRadius: 24)
      )
   }

   private var archivedToDos: [ToDo] {
      scopedToDos
         .filter { $0.isArchived || $0.lifecycleState == .done }
         .sorted { $0.createdAt > $1.createdAt }
   }

   private var archiveCountLabel: String {
      let count = archivedToDos.count
      return AppLocalization.localizedCount(count, singularKey: "%@ toDo", pluralKey: "%@ toDos")
   }

   private var unusedTagCount: Int {
      let usedTagIDs = scopedUsedTagIDs()
      return scopedTags.filter { tag in
         !usedTagIDs.contains(tag.id)
      }.count
   }

   private var customTagCount: Int {
      let defaultNames = Set(TagManagementView.defaultTagNames.map { $0.lowercased() })
      return scopedTags.filter { !defaultNames.contains($0.name.lowercased()) }.count
   }

   private var customTagCountLabel: String {
      AppLocalization.localizedCount(customTagCount, singularKey: "%@ custom", pluralKey: "%@ custom")
   }

   private var statsSummaryDetail: String {
      let activeCount = scopedToDos.filter(\.isActive).count
      let overdueCount = scopedToDos.filter(\.isLate).count

      if overdueCount > 0 {
         return AppLocalization.localizedCount(overdueCount, singularKey: "%@ overdue", pluralKey: "%@ overdue")
      }

      return AppLocalization.localizedCount(activeCount, singularKey: "%@ active", pluralKey: "%@ active")
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

   private var resolvedBadgePolicy: AppPreferences.AppIconBadgePolicy {
      AppPreferences.AppIconBadgePolicy(rawValue: appIconBadgePolicyRaw) ?? .overdue
   }

   private var resolvedNotificationSoundOption: AppPreferences.NotificationSoundOption {
      AppPreferences.NotificationSoundOption(rawValue: notificationSoundOptionRaw) ?? .defaultSound
   }

   private var notificationAuthorizationStatusLabel: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return String(localized: "Allowed")
      case .denied:
         return String(localized: "Denied")
      case .notDetermined:
         return String(localized: "Off")
      @unknown default:
         return String(localized: "Off")
      }
   }

   private var notificationDetailCopy: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return String(
            format: String(localized: "%@ Due reminders can alert you with quick snooze and mark-done actions. %@. %@"),
            timeSensitiveStatusCopy,
            notificationManager.registrationState.statusText,
            notificationManager.pushReadinessDetail
         )
      case .denied:
         return String(localized: "Notification access is disabled, so due reminders and push registration are unavailable.")
      case .notDetermined:
         return String(localized: "Enable notifications to receive due reminders, time-sensitive alerts, and quick snooze actions.")
      @unknown default:
         return String(localized: "Enable notifications to receive due reminders, time-sensitive alerts, and quick snooze actions.")
      }
   }

   private var notificationActionTitle: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return String(localized: "Refresh Push Registration")
      case .denied:
         return String(localized: "Open Notification Settings")
      case .notDetermined:
         return String(localized: "Enable Notifications")
      @unknown default:
         return String(localized: "Enable Notifications")
      }
   }

   private var notificationActionDetail: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return String(localized: "Re-register for push notifications, refresh scheduled reminders, and re-check time-sensitive delivery.")
      case .denied:
         return String(localized: "Open system Settings to allow notifications for ToDo.")
      case .notDetermined:
         return String(localized: "Allow alerts, sounds, notification actions, and time-sensitive delivery for due reminders.")
      @unknown default:
         return String(localized: "Allow alerts, sounds, notification actions, and time-sensitive delivery for due reminders.")
      }
   }

   private var timeSensitiveStatusCopy: String {
      switch notificationManager.timeSensitiveSetting {
      case .enabled:
         return String(localized: "Time-sensitive delivery is enabled.")
      case .disabled:
         return String(localized: "Time-sensitive delivery is turned off in system settings.")
      case .notSupported:
         return String(localized: "Time-sensitive delivery is unavailable on this device.")
      default:
         return String(localized: "Time-sensitive delivery follows the system notification settings.")
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
         return String(localized: "Refresh Location Time")
      case .notDetermined:
         return String(localized: "Use Current Location")
      case .denied, .restricted:
         return String(localized: "Location Access Disabled")
      @unknown default:
         return String(localized: "Use Current Location")
      }
   }

   private var locationStatusCopy: String {
      switch locationTimeZoneService.authorizationStatus {
      case .authorizedAlways, .authorizedWhenInUse:
         return String(localized: "Current timezone updates from your location when you refresh it.")
      case .notDetermined:
         return String(localized: "Using Apple Park until location access is granted.")
      case .denied, .restricted:
         return String(localized: "Location access is unavailable, so the app stays on Apple Park time.")
      @unknown default:
         return String(localized: "Using Apple Park until location access is available.")
      }
   }

   private var syncStatusTitle: String {
      if let pendingMode = syncCoordinator.pendingRestartSyncMode {
         return pendingMode.title
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere,
         !authStore.isAuthenticated {
         return syncCoordinator.preferredSyncMode.title
      }

      return syncCoordinator.effectiveSyncMode.title
   }

   private var syncStatusDetail: String {
      if let pendingMode = syncCoordinator.pendingRestartSyncMode {
         return String(format: String(localized: "Close and reopen ToDo to finish activating %@."), pendingMode.title)
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
         return String(
            format: String(localized: "%@ is selected. Open Settings to sign in; until then, ToDo stays on %@."),
            syncCoordinator.preferredSyncMode.title,
            syncCoordinator.effectiveSyncMode.title
         )
      }

      return syncCoordinator.effectiveSyncMode.subtitle
   }

   private func resetPreferences() {
      AppPreferences.resetToDefaults()
   }

   private func deleteUnusedTags() {
      let usedTagIDs = scopedUsedTagIDs()
      let unusedTags = scopedTags.filter { tag in
         !usedTagIDs.contains(tag.id)
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

   private func closeView() {
      if let onClose {
         onClose()
      } else {
         dismiss()
      }
   }

   private func scopedUsedTagIDs() -> Set<PersistentIdentifier> {
      var usedTagIDs = Set<PersistentIdentifier>()
      for toDo in scopedToDos {
         for tag in toDo.effectiveTags {
            usedTagIDs.insert(tag.id)
         }
      }
      for nanoDo in scopedNanoDos {
         if let tagID = nanoDo.tag?.id {
            usedTagIDs.insert(tagID)
         }
      }
      return usedTagIDs
   }

   private func persistChanges(_ message: String) {
      do {
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         SyncCoordinator.shared.scheduleLocalSync()

         WatchConnectivityService.shared.refreshSnapshot()
      } catch {
         AppLog.error("\(message): \(error)", logger: AppLog.app)
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
               Text(LocalizedStringKey(title))
                  .font(.appBodyStrong(15, relativeTo: .subheadline))
                  .foregroundStyle(foregroundStyle)

               Text(LocalizedStringKey(detail))
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
      .clipShape(.rect(cornerRadius: 18))
   }

   private var syncReviewDetail: String {
      let count = unresolvedSyncConflicts.count
      return count == 1
         ? "1 ToDo changed in two places. Choose which version to keep."
         : "\(count) ToDos changed in two places. Choose which versions to keep."
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
      .clipShape(.rect(cornerRadius: 18))
   }

   private var notificationSettingsBlock: some View {
      VStack(alignment: .leading, spacing: 14) {
         HStack(alignment: .center, spacing: 12) {
            Image(systemName: notificationActionSystemName)
               .font(.appDisplay(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.main)
               .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
               Text("Reminder Alerts")
                  .font(.appBodyStrong(15, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textPrimary)

               Text(notificationDetailCopy)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(notificationAuthorizationStatusLabel)
               .font(.appBodyStrong(11, relativeTo: .caption))
               .foregroundStyle(notificationAuthorizationStatusLabel == "Allowed" ? AppColor.onAction : AppColor.textSecondary)
               .padding(.horizontal, 9)
               .padding(.vertical, 5)
               .background(
                  notificationAuthorizationStatusLabel == "Allowed" ? AppColor.actionSecondary : AppColor.surfaceMuted,
                  in: Capsule()
               )
         }

         settingsActionRow(
            systemName: notificationActionSystemName,
            title: notificationActionTitle,
            detail: notificationActionDetail,
            contentVerticalAlignment: .center
         ) {
            handleNotificationAction()
         }

         Divider()
            .overlay(AppColor.border.opacity(0.5))

         notificationSoundDropdown

         Divider()
            .overlay(AppColor.border.opacity(0.5))

         badgePolicyDropdown
      }
   }

   private var notificationSoundDropdown: some View {
      Menu {
         ForEach(AppPreferences.NotificationSoundOption.allCases) { option in
            Button {
               withAnimation(AppAnimation.snappyStandard) {
                  notificationSoundOptionRaw = option.rawValue
               }
               NotificationManager.shared.scheduleRefresh()
            } label: {
               Label(
                  option.title,
                  systemImage: option == resolvedNotificationSoundOption ? "checkmark.circle.fill" : "circle"
               )
            }
         }
      } label: {
         VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
               Image(systemName: "speaker.wave.2.fill")
                  .font(.appDisplay(15, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.main)
                  .frame(width: 18, height: 18)

               VStack(alignment: .leading, spacing: 4) {
                  Text("Reminder Sound")
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Text(resolvedNotificationSoundOption.detail)
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               Spacer(minLength: 12)

               HStack(spacing: 8) {
                  Text(resolvedNotificationSoundOption.title)
                     .font(.appBodyStrong(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.onAction)
                     .padding(.horizontal, 10)
                     .padding(.vertical, 6)
                     .background(AppColor.actionPrimary, in: Capsule())
                     .contentTransition(.numericText())

                  Image(systemName: "chevron.up.chevron.down")
                     .font(.appBodyStrong(11, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }
            }
         }
      }
      .buttonStyle(.plain)
      .contentShape(.rect)
      .animation(AppAnimation.snappyStandard, value: notificationSoundOptionRaw)
   }

   private var badgePolicyDropdown: some View {
      Menu {
         ForEach(AppPreferences.AppIconBadgePolicy.allCases) { policy in
            Button {
               withAnimation(AppAnimation.snappyStandard) {
                  appIconBadgePolicyRaw = policy.rawValue
               }
               NotificationManager.shared.scheduleRefresh()
            } label: {
               Label(
                  policy.title,
                  systemImage: policy == resolvedBadgePolicy ? "checkmark.circle.fill" : "circle"
               )
            }
         }
      } label: {
         VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
               Image(systemName: "app.badge")
                  .font(.appDisplay(15, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.main)
                  .frame(width: 18, height: 18)

               VStack(alignment: .leading, spacing: 4) {
                  Text("App Icon Badge")
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Text(resolvedBadgePolicy.detail)
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               Spacer(minLength: 12)

               HStack(spacing: 8) {
                  Text(resolvedBadgePolicy.title)
                     .font(.appBodyStrong(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.onAction)
                     .padding(.horizontal, 10)
                     .padding(.vertical, 6)
                     .background(AppColor.actionPrimary, in: Capsule())
                     .contentTransition(.numericText())

                  Image(systemName: "chevron.up.chevron.down")
                     .font(.appBodyStrong(11, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }
            }
         }
      }
      .buttonStyle(.plain)
      .contentShape(.rect)
      .animation(AppAnimation.snappyStandard, value: appIconBadgePolicyRaw)
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
                     (source == resolvedTimeSource ? AppColor.surfaceMuted : AppColor.surfaceElevated),
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
                     (action == resolvedDoneSwipePrimaryAction ? AppColor.surfaceMuted : AppColor.surfaceElevated),
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
