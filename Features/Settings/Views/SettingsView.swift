import SwiftUI
import SwiftData
import CoreLocation

private enum SettingsDetailRoute: Hashable {
   case account
   case conflicts
   case sync
   case appearance
   case behavior
   case notifications
   case tags
   case stats
   case dataControls
   case archives
   case trash
}

struct SettingsView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @Environment(\.openURL) private var openURL
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
   @AppStorage(AppPreferences.Keys.appTheme) private var appThemeRaw = AppThemeOption.classic.rawValue
   @AppStorage(AppPreferences.Keys.appAppearanceMode) private var appAppearanceModeRaw = AppPreferences.AppAppearanceMode.system.rawValue
   @AppStorage("trashAutoEmptyInterval") private var trashAutoEmptyIntervalRaw = TrashAutoEmptyInterval.oneMonth.rawValue

   @State private var isShowingDeleteUnusedTagsConfirmation = false
   @State private var isSortMenuExpanded = false
   @State private var isDoneSwipeMenuExpanded = false
   @State private var isTimeSourceMenuExpanded = false
   @State private var selectedDetailRoute: SettingsDetailRoute?
   @State private var notificationSoundPreviewStatus: String?
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
      return authStore.scopedOwnerUserID
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

   private var settingsContentMaxWidth: CGFloat {
      horizontalSizeClass == .regular ? 760 : .infinity
   }

   private var usesSettingsDetailLayout: Bool {
      horizontalSizeClass == .regular
   }

   private var isSettingsDetailPanelVisible: Bool {
      usesSettingsDetailLayout && selectedDetailRoute != nil
   }

   private var settingsDashboardMaxWidth: CGFloat {
      1320
   }

   private var settingsDashboardCurrentMaxWidth: CGFloat {
      isSettingsDetailPanelVisible ? settingsDashboardMaxWidth : settingsContentMaxWidth
   }

   private var settingsWorkingPanelMaxWidth: CGFloat {
      isSettingsDetailPanelVisible ? 620 : settingsContentMaxWidth
   }

   private var settingsDetailPanelWidth: CGFloat {
      480
   }

   private var settingsPanelSpacing: CGFloat {
      18
   }

   private var settingsDashboardHorizontalPadding: CGFloat {
      32
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
         return authStore.isAuthenticated ? String(localized: "toDō Sync") : authStore.accountStatusLabel
      }
   }

   var body: some View {
      ZStack(alignment: .top) {
         if usesSettingsDetailLayout {
            HStack(alignment: .top, spacing: settingsPanelSpacing) {
               settingsListPanel
                  .frame(maxWidth: settingsWorkingPanelMaxWidth)

               if isSettingsDetailPanelVisible {
                  settingsDetailPanel
                     .frame(width: settingsDetailPanelWidth)
                     .transition(.opacity.combined(with: .move(edge: .trailing)))
               }
            }
            .frame(maxWidth: settingsDashboardCurrentMaxWidth, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, settingsDashboardHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .animation(AppAnimation.snappySection, value: isSettingsDetailPanelVisible)
            .animation(AppAnimation.snappySection, value: selectedDetailRoute)
         } else {
            settingsList
         }
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.main)
      .appBaseTypography()
      .settingsNativeNavigationTitle("Settings", colorScheme: colorScheme, background: AppColor.main)
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
         Text(String(format: String(localized: "%@ unused tag(s) will be permanently removed."), AppLocalization.numberString(unusedTagCount)))
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

   private var settingsList: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 24) {
               settingsSection(String(localized: "Account & Sync")) {
                  settingsDetailLink(.account) {
                     settingsNavigationRow(
                        authStore.isAuthenticated ? String(localized: "Account") : String(localized: "Sign In"),
                        detail: accountSummaryDetail
                     )
                     .onboardingSpotlightAnchor(.settingsAccount)
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  syncStatusBlock

                  if !unresolvedSyncConflicts.isEmpty {
                     settingsDetailLink(.conflicts) {
                        syncReviewRow
                     }
                     .foregroundStyle(AppColor.textPrimary)
                  }

                  settingsDetailLink(.sync) {
                     settingsNavigationRow(
                        String(localized: "Where to Save"),
                        detail: syncCoordinator.pendingRestartSyncMode != nil ? String(localized: "Ready after restart") : syncCoordinator.preferredSyncMode.title
                     )
                     .onboardingSpotlightAnchor(.settingsSync)
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  syncDeletionPreferenceToggle
               }

               settingsSection(String(localized: "Look & Feel")) {
                  settingsDetailLink(.appearance) {
                     settingsNavigationRow(
                        String(localized: "Appearance"),
                        detail: resolvedTheme.title,
                        detailForeground: AppColor.iconAccent
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Behavior")) {
                  settingsDetailLink(.behavior) {
                     settingsNavigationRow(
                        String(localized: "Behavior"),
                        detail: resolvedDoneSwipePrimaryAction.compactTitle
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Notifications")) {
                  settingsDetailLink(.notifications) {
                     settingsNavigationRow(
                        String(localized: "Notifications"),
                        detail: notificationAuthorizationStatusLabel
                     )
                     .onboardingSpotlightAnchor(.settingsNotifications)
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Tags")) {
                  settingsDetailLink(.tags) {
                     settingsNavigationRow(
                        String(localized: "Tags"),
                        detail: customTagCountLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Setup")) {
                  settingsActionRow(
                     systemName: "sparkles",
                     title: "Guided Tour",
                     detail: "Replay the setup guide for creating a toDō, choosing sync, and enabling notifications."
                  ) {
                     onboardingManager.restart()
                     closeView()
                  }
               }

               settingsSection(String(localized: "Stats")) {
                  NavigationLink {
                     StatsView(ownerUserID: visibleOwnerUserID)
                  } label: {
                     statsEntryCard
                  }
                  .buttonStyle(.plain)
                  .foregroundStyle(AppColor.textPrimary)
               }

               settingsSection(String(localized: "Manage Your Data")) {
                  settingsFullNavigationLink(.dataControls) {
                     settingsNavigationRow(
                        String(localized: "Data Controls"),
                        detail: String(localized: "Clean up")
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  settingsFullNavigationLink(.archives) {
                     settingsNavigationRow(
                        String(localized: "Archives"),
                        detail: archiveCountLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)

                  settingsFullNavigationLink(.trash) {
                     settingsNavigationRow(
                        String(localized: "Trash"),
                        detail: trashCountLabel
                     )
                  }
                  .foregroundStyle(AppColor.textPrimary)
               }

               madeByBrandView
                  .frame(maxWidth: .infinity)
                  .padding(.top, 4)
         }
         .frame(maxWidth: settingsContentMaxWidth, alignment: .top)
         .frame(maxWidth: .infinity, alignment: .top)
         .padding(.horizontal, 16)
         .padding(.top, 18)
         .padding(.bottom, 24)
      }
   }

   private var settingsListPanel: some View {
      settingsList
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
         .clipShape(.rect(cornerRadius: 30))
         .shadow(color: AppColor.shadow, radius: 18, x: 0, y: 8)
   }

   @ViewBuilder
   private var settingsDetailPanel: some View {
      if let selectedDetailRoute {
         ZStack(alignment: .topTrailing) {
            settingsDetailView(selectedDetailRoute)
               .environment(\.settingsDetailPresentation, .sidePanel)
               .frame(maxWidth: .infinity, alignment: .top)
               .clipShape(.rect(cornerRadius: 24))
               .padding(14)

            closeSettingsDetailButton
               .padding(.top, 16)
               .padding(.trailing, 16)
         }
         .frame(maxWidth: .infinity, alignment: .top)
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
         .clipShape(.rect(cornerRadius: 30))
         .shadow(color: AppColor.shadow, radius: 18, x: 0, y: 8)
         .animation(AppAnimation.snappySection, value: selectedDetailRoute)
      }
   }

   private var closeSettingsDetailButton: some View {
      Button {
         withAnimation(AppAnimation.snappyStandard) {
            selectedDetailRoute = nil
         }
      } label: {
         Image(systemName: "xmark.circle.fill")
            .font(.appDisplay(30, relativeTo: .title2))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(AppColor.textSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("Close"))
   }

   private var statsEntryCard: some View {
      HStack(spacing: 14) {
         ZStack {
            Circle()
               .fill(AppColor.actionSuccess.opacity(0.95))
               .frame(width: 44, height: 44)

            Image(systemName: "chart.bar.xaxis")
               .font(.appDisplay(19, relativeTo: .headline))
               .foregroundStyle(AppColor.textPrimary)
         }

         VStack(alignment: .leading, spacing: 5) {
            Text("Stats")
               .font(.appBodyStrong(17, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Text(statsSummaryDetail)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }

         Spacer(minLength: 12)

         Image(systemName: "chevron.right")
            .font(.appBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
         LinearGradient(
            colors: [
               AppColor.actionSuccess.opacity(0.16),
               AppColor.surfaceMuted
            ],
            startPoint: .leading,
            endPoint: .trailing
         ),
         in: .rect(cornerRadius: 24)
      )
   }

   @ViewBuilder
   private func settingsDetailLink<Label: View>(
      _ route: SettingsDetailRoute,
      @ViewBuilder label: () -> Label
   ) -> some View {
      if usesSettingsDetailLayout {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               selectedDetailRoute = route
            }
         } label: {
            label()
         }
         .buttonStyle(.plain)
         .accessibilityAddTraits(selectedDetailRoute == route ? [.isSelected] : [])
      } else {
         NavigationLink {
            settingsDetailView(route)
         } label: {
            label()
         }
      }
   }

   private func settingsFullNavigationLink<Label: View>(
      _ route: SettingsDetailRoute,
      @ViewBuilder label: () -> Label
   ) -> some View {
      NavigationLink {
         settingsDetailView(route)
      } label: {
         label()
      }
   }

   private func settingsDetailView(_ route: SettingsDetailRoute) -> AnyView {
      switch route {
      case .account:
         if authStore.isAuthenticated {
            return AnyView(AccountView())
         } else {
            return AnyView(AuthenticationScreenView())
         }
      case .conflicts:
         return AnyView(SyncConflictReviewView(
            conflicts: unresolvedSyncConflicts,
            toDos: scopedToDos
         ))
      case .sync:
         return AnyView(SyncSettingsView())
      case .appearance:
         return AnyView(themeSettingsScreen)
      case .behavior:
         return AnyView(behaviorSettingsScreen)
      case .notifications:
         return AnyView(notificationSettingsScreen)
      case .tags:
         return AnyView(tagSettingsScreen)
      case .stats:
         return AnyView(StatsView(ownerUserID: visibleOwnerUserID))
      case .dataControls:
         return AnyView(dataControlsSettingsScreen)
      case .archives:
         return AnyView(ArchivesView())
      case .trash:
         return AnyView(TrashView())
      }
   }

   private var themeSettingsScreen: some View {
      ThemeSettingsScreen(
         appThemeRaw: $appThemeRaw,
         appAppearanceModeRaw: $appAppearanceModeRaw
      )
   }

   private var behaviorSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Behavior"
      ) {
         settingsSection("Order") {
            settingsSortDropdown
         }

         settingsSection("Timing") {
            timeSourceDropdown
         }

         settingsSection("Remove from View") {
            doneSwipeActionDropdown
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
         title: "Notifications"
      ) {
         settingsSection("Reminder Alerts") {
            notificationSettingsBlock
         }

         settingsSection("Snooze") {
            NavigationLink {
               SnoozeOptionsView()
            } label: {
               settingsNavigationRow(
                  "Snooze Options",
                  detail: String(localized: "Quick choices")
               )
            }
            .foregroundStyle(AppColor.textPrimary)
         }
      }
   }

   private var tagSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Tags"
      ) {
         settingsSection("Defaults") {
            Toggle(isOn: $createToDoTagsEnabledByDefault) {
               VStack(alignment: .leading, spacing: 4) {
                  Text("Show Tags While Creating")
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Text("Show the tag field when creating a toDō.")
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
                  "Manage Tags",
                  detail: customTagCountLabel
               )
            }
            .foregroundStyle(AppColor.textPrimary)

            settingsActionRow(
               systemName: "tag.slash",
               title: "Remove Unused Tags",
               detail: "Deletes tags that are not attached to a toDō or nanoDo.",
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
         title: "Delete Behavior"
      ) {
         settingsSection("Local Copies") {
            syncDeletionPreferenceToggle
         }
      }
   }

   private var dataControlsSettingsScreen: some View {
      SettingsSubmenuContainer(
         title: "Data Controls"
      ) {
         settingsSection("Trash") {
            trashAutoEmptyControl
         }

         settingsSection("Preferences") {
            settingsActionRow(
               systemName: "arrow.counterclockwise",
               title: "Reset Choices",
               detail: "Restores sorting, tag entry, and timing choices."
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
               Text("Add Due toDōs to Calendar")
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

            Text("Adds due toDōs to Calendar and removes them when they are finished, archived, deleted, or no longer due.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
      .tint(AppColor.actionSecondary)
      .onChange(of: mirrorDueDatesToCalendar) { _, isEnabled in
         guard isEnabled else { return }
         Task {
            do {
               _ = try await CalendarIntegrationService.shared.requestWriteAccess()
            } catch {
               AppLog.error("Failed to request Calendar write access: \(error)", logger: AppLog.calendar)
            }
         }
      }
   }

   private var trashAutoEmptyControl: some View {
      VStack(alignment: .leading, spacing: 12) {
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

         Text("Deleted toDōs will be permanently removed after this much time in the trash.")
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
         Text("\(Text("toDō").foregroundStyle(AppColor.main).bold()) \(Text(String(localized: "what matters")))")
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
      .custom("Aleo", size: 17, relativeTo: .footnote)
         .weight(.medium)
   }

   private var brandWordmarkItalicFont: Font {
      .custom("Aleo", size: 17, relativeTo: .footnote)
         .weight(.regular)
         .italic()
   }

   private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text(LocalizedStringKey(title))
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)

         VStack(alignment: .leading, spacing: 20) {
            content()
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(18)
         .containerShape(.rect(cornerRadius: 26))
         .background(
            AppColor.surfaceElevated,
            in: .rect(cornerRadius: 26)
         )
      }
   }

   private func settingsNavigationRow(
      _ title: String,
      detail: String,
      detailForeground: Color = AppColor.textSecondary,
      detailFont: Font = .appBody(16, relativeTo: .body)
   ) -> some View {
      HStack(spacing: 14) {
         Text(LocalizedStringKey(title))
            .font(.appBodyStrong(17, relativeTo: .body))
            .foregroundStyle(AppColor.textPrimary)

         Spacer(minLength: 14)

         Text(LocalizedStringKey(detail))
            .font(detailFont)
            .foregroundStyle(detailForeground)

         Image(systemName: "chevron.right")
            .font(.appBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .padding(.vertical, 7)
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
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 24, style: .continuous)
                  .fill(AppColor.surfaceElevated)
            }
         }
         .appInteractiveRoundedGlass(tint: AppColor.surfaceElevated, cornerRadius: 24)
   }

   private var archivedToDos: [ToDo] {
      scopedToDos
         .filter { $0.isArchived || $0.lifecycleState == .done }
         .sorted { $0.createdAt > $1.createdAt }
   }

   private var archiveCountLabel: String {
      let count = archivedToDos.count
      return AppLocalization.localizedCount(count, singularKey: "%@ toDō", pluralKey: "%@ toDōs")
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

   private var resolvedTheme: AppThemeOption {
      AppThemeOption(rawValue: appThemeRaw) ?? .classic
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
            format: String(localized: "%@ Due reminders can play a sound and show quick actions."),
            timeSensitiveStatusCopy
         )
      case .denied:
         return String(localized: "Notifications are off, so toDō cannot alert you when something is due.")
      case .notDetermined:
         return String(localized: "Enable reminders, sounds, and Time-Sensitive alerts.")
      @unknown default:
         return String(localized: "Enable reminders, sounds, and Time-Sensitive alerts.")
      }
   }

   private var notificationActionTitle: String {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return String(localized: "Refresh Reminders")
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
         return String(localized: "Refresh upcoming reminder alerts.")
      case .denied:
         return String(localized: "Open system Settings to allow notifications for toDō.")
      case .notDetermined:
         return String(localized: "Allow reminder alerts, sounds, and Time-Sensitive delivery.")
      @unknown default:
         return String(localized: "Allow reminder alerts, sounds, and Time-Sensitive delivery.")
      }
   }

   private var timeSensitiveStatusCopy: String {
      switch notificationManager.timeSensitiveSetting {
      case .enabled:
         return String(localized: "Time-Sensitive is allowed.")
      case .disabled:
         return String(localized: "Time-Sensitive is off in Settings.")
      case .notSupported:
         return String(localized: "Time-Sensitive is not available here.")
      default:
         return String(localized: "Time-Sensitive follows device settings.")
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
         return String(localized: "Uses your current timezone when refreshed.")
      case .notDetermined:
         return String(localized: "Using Apple Park until location access is granted.")
      case .denied, .restricted:
         return String(localized: "Location is off, so toDō stays on Apple Park time.")
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
         return String(format: String(localized: "Close and reopen toDō when you are ready to use %@."), pendingMode.title)
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
         return String(
            format: String(localized: "%@ is selected. Sign in to turn it on; until then, toDō stays with %@."),
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

   private func scheduleNotificationSoundPreview() {
      notificationSoundPreviewStatus = String(localized: "Sending a sound test...")

      Task {
         if notificationManager.authorizationStatus == .notDetermined {
            await notificationManager.requestAuthorizationFlow()
         }

         switch notificationManager.authorizationStatus {
         case .authorized, .provisional, .ephemeral:
            do {
               try await notificationManager.scheduleSoundPreviewNotification()
               notificationSoundPreviewStatus = String(localized: "Sound test sent. Make sure the device is not muted.")
            } catch {
               notificationSoundPreviewStatus = String(localized: "Could not schedule the sample reminder.")
               AppLog.error("Failed to schedule notification sound preview: \(error)", logger: AppLog.notifications)
            }
         case .denied:
            notificationSoundPreviewStatus = String(localized: "Notifications are off. Open Settings to allow reminder sounds.")
         case .notDetermined:
            notificationSoundPreviewStatus = String(localized: "Allow notifications before testing a sound.")
         @unknown default:
            notificationSoundPreviewStatus = String(localized: "Allow notifications before testing a sound.")
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
         HStack(alignment: contentVerticalAlignment, spacing: 14) {
            Image(systemName: systemName)
               .font(.appDisplay(16, relativeTo: .subheadline))
               .foregroundStyle(foregroundStyle)
               .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 5) {
               Text(LocalizedStringKey(title))
                  .font(.appButton(17, relativeTo: .headline))
                  .foregroundStyle(foregroundStyle)

               Text(LocalizedStringKey(detail))
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 0)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.horizontal, 16)
         .padding(.vertical, 15)
         .contentShape(.rect(cornerRadius: 20))
         .containerShape(.rect(cornerRadius: 20))
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .fill(backgroundStyle)
            }
         }
         .appInteractiveRoundedGlass(tint: backgroundStyle, cornerRadius: 20)
         .clipShape(.rect(cornerRadius: 20))
      }
      .buttonStyle(.plain)
      .disabled(isDisabled)
      .opacity(isDisabled ? 0.45 : 1)
   }

   private var syncStatusBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 12) {
            Text("Current Sync")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)

            Text(syncStatusTitle)
               .font(.appBadge(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
               .padding(.horizontal, 10)
               .padding(.vertical, 6)
               .background(AppColor.surfaceMuted, in: Capsule())
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
      HStack(alignment: .top, spacing: 14) {
         Image(systemName: "exclamationmark.triangle.fill")
            .font(.appDisplay(16, relativeTo: .subheadline))
            .foregroundStyle(AppColor.secondary)
            .frame(width: 22, height: 22)

         VStack(alignment: .leading, spacing: 5) {
            Text("Choose a Version")
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
      .padding(.horizontal, 16)
      .padding(.vertical, 15)
      .background(
         AppColor.secondary.opacity(0.1),
         in: .rect(corners: .concentric, isUniform: true)
      )
      .clipShape(.rect(cornerRadius: 20))
   }

   private var syncReviewDetail: String {
      let count = unresolvedSyncConflicts.count
      return count == 1
         ? "1 toDō changed in two places. Choose which version to keep."
         : "\(count) toDōs changed in two places. Choose which versions to keep."
   }

   private var syncDeletionPreferenceToggle: some View {
      Toggle(isOn: $mirrorSyncDeletesToDeviceOnly) {
         VStack(alignment: .leading, spacing: 5) {
            Text("Match Deletes Everywhere")
               .font(.appBodyStrong(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
         }
      }
      .tint(AppColor.actionSecondary)
      .padding(.horizontal, 16)
      .padding(.vertical, 15)
      .background(
         AppColor.surfaceMuted,
         in: .rect(corners: .concentric, isUniform: true)
      )
      .clipShape(.rect(cornerRadius: 20))
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
         notificationSoundPreviewButton

         reminderIntentSoundGuide

         Divider()
            .overlay(AppColor.border.opacity(0.5))

         badgePolicyDropdown
      }
   }

   fileprivate var themePickerBlock: some View {
      VStack(alignment: .leading, spacing: 18) {
         VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
               Image(systemName: "paintpalette.fill")
                  .font(.appDisplay(18, relativeTo: .headline))
                  .foregroundStyle(AppColor.iconAccent)
                  .frame(width: 24, height: 24)

               Text("Selected Look")
                  .font(.appBodyStrong(16, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
            }

            Text(resolvedTheme.title)
               .font(.appTitle(34, relativeTo: .largeTitle))
               .foregroundStyle(AppColor.textPrimary)

            Text(resolvedTheme.subtitle)
               .font(.appBody(13, relativeTo: .footnote))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }
         .padding(18)
         .frame(maxWidth: .infinity, alignment: .leading)
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 26))
         .overlay(alignment: .topTrailing) {
            HStack(spacing: -6) {
               Circle().fill(resolvedTheme.palette.main)
               Circle().fill(resolvedTheme.palette.secondary)
               Circle().fill(resolvedTheme.palette.tertiary)
            }
            .frame(width: 74, height: 24)
            .padding(18)
         }

         LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(AppThemeOption.allCases) { theme in
               themeSwatchButton(theme)
            }
         }
      }
      .animation(AppAnimation.snappyStandard, value: appThemeRaw)
   }

   fileprivate func themeSwatchButton(_ theme: AppThemeOption) -> some View {
      let isSelected = theme == resolvedTheme
      let palette = theme.palette

      return Button {
         withAnimation(AppAnimation.snappyStandard) {
            appThemeRaw = theme.rawValue
         }
      } label: {
         VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
               Circle().fill(palette.main)
               Circle().fill(palette.secondary)
               Circle().fill(palette.tertiary)
            }
            .frame(height: 18)

            HStack(spacing: 6) {
               Text(theme.title)
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textPrimary)
                  .lineLimit(1)

               Spacer(minLength: 0)

               if isSelected {
                  Image(systemName: "checkmark.circle.fill")
                     .font(.appBodyStrong(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.iconAccent)
               }
            }

            Text(theme.subtitle)
               .font(.appBody(11, relativeTo: .caption2))
               .foregroundStyle(AppColor.textSecondary)
               .lineLimit(2)
               .multilineTextAlignment(.leading)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(12)
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(AppColor.surfaceElevated)
            }
         }
         .appInteractiveRoundedGlass(tint: AppColor.surfaceElevated, cornerRadius: 16)
         .overlay {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .stroke(isSelected ? AppColor.iconAccent : AppColor.border.opacity(0.35), lineWidth: isSelected ? 1.6 : 1)
            }
         }
      }
      .buttonStyle(.plain)
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
            HStack(alignment: .center, spacing: 14) {
               Image(systemName: "speaker.wave.2.fill")
                  .font(.appDisplay(16, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.main)
                  .frame(width: 22, height: 22)

               VStack(alignment: .leading, spacing: 5) {
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
                     .font(.appBadge(12, relativeTo: .caption))
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
         .padding(.horizontal, 16)
         .padding(.vertical, 15)
         .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 20))
      }
      .buttonStyle(.plain)
      .contentShape(.rect(cornerRadius: 20))
      .animation(AppAnimation.snappyStandard, value: notificationSoundOptionRaw)
   }

   private var notificationSoundPreviewButton: some View {
      let previewBlue = Color(red: 0.16, green: 0.43, blue: 0.88)
      return Button {
         scheduleNotificationSoundPreview()
      } label: {
         HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(AppColor.onAction)
               .frame(width: 28, height: 28)

            Text(notificationSoundPreviewStatus ?? String(localized: "Test Sound"))
               .font(.appButton(16, relativeTo: .subheadline))
               .foregroundStyle(AppColor.onAction)

            Spacer(minLength: 8)

         }
         .padding(.horizontal, 14)
         .padding(.vertical, 10)
         .background(previewBlue, in: .rect(cornerRadius: 16))
      }
      .buttonStyle(.plain)
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
            HStack(alignment: .center, spacing: 14) {
               Image(systemName: "app.badge")
                  .font(.appDisplay(16, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.main)
                  .frame(width: 22, height: 22)

               VStack(alignment: .leading, spacing: 5) {
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
                     .font(.appBadge(12, relativeTo: .caption))
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
         .padding(.horizontal, 16)
         .padding(.vertical, 15)
         .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 20))
      }
      .buttonStyle(.plain)
      .contentShape(.rect(cornerRadius: 20))
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
                  .font(.appBodyStrong(17, relativeTo: .body))
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
         .frame(maxHeight: isSortMenuExpanded ? 118 : 0, alignment: .top)
         .opacity(isSortMenuExpanded ? 1 : 0)
         .clipped()
         .allowsHitTesting(isSortMenuExpanded)
      }
      .animation(AppAnimation.snappyStandard, value: isSortMenuExpanded)
   }

   private func compactSortOptionsRow(
      title: String,
      options: [AppPreferences.ToDoListSortOption]
   ) -> some View {
      VStack(alignment: .leading, spacing: 6) {
         Text(LocalizedStringKey(title))
            .font(.appBodyStrong(11, relativeTo: .caption))
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
               .font(.appBadge(15, relativeTo: .subheadline))

            if let direction {
               Image(systemName: direction)
                  .font(.appBodyStrong(10, relativeTo: .caption))
            }
         }
         .foregroundStyle(isSelected ? AppColor.onAction : AppColor.textPrimary)
         .padding(.horizontal, 12)
         .padding(.vertical, 8)
         .background {
            if #unavailable(iOS 26.0) {
               Capsule()
                  .fill(isSelected ? AppColor.actionSecondary : AppColor.surfaceMuted)
            }
         }
         .appInteractiveCapsuleGlass(tint: isSelected ? AppColor.actionSecondary : AppColor.surfaceMuted)
         .overlay {
            if #unavailable(iOS 26.0) {
               Capsule()
                  .stroke(isSelected ? AppColor.actionSecondary : AppColor.border.opacity(0.4), lineWidth: 1)
            }
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
               Text("Time Zone")
                  .font(.appBodyStrong(17, relativeTo: .body))
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
         .frame(maxHeight: isTimeSourceMenuExpanded ? 112 : 0, alignment: .top)
         .opacity(isTimeSourceMenuExpanded ? 1 : 0)
         .clipped()
         .allowsHitTesting(isTimeSourceMenuExpanded)

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
      .animation(AppAnimation.snappyStandard, value: isTimeSourceMenuExpanded)
   }

   private var doneSwipeActionDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(AppAnimation.snappyStandard) {
               isDoneSwipeMenuExpanded.toggle()
            }
         } label: {
            HStack(alignment: .center, spacing: 12) {
               Text("Remove Action")
                  .font(.appBodyStrong(17, relativeTo: .body))
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
         .frame(maxHeight: isDoneSwipeMenuExpanded ? 112 : 0, alignment: .top)
         .opacity(isDoneSwipeMenuExpanded ? 1 : 0)
         .clipped()
         .allowsHitTesting(isDoneSwipeMenuExpanded)
      }
      .animation(AppAnimation.snappyStandard, value: isDoneSwipeMenuExpanded)
   }

   private var reminderIntentSoundGuide: some View {
      TagPillFlowLayout(spacing: 8, rowSpacing: 8) {
         intentGuideChip("Quiet", systemName: "bell.slash", tint: AppColor.textSecondary)
         intentGuideChip("Due", systemName: "bell", tint: AppColor.actionPrimary)
         intentGuideChip("Time-Sensitive", systemName: "flame", tint: AppColor.actionDestructive)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func intentGuideChip(_ title: String, systemName: String, tint: Color) -> some View {
      Label(title, systemImage: systemName)
         .font(.appBodyStrong(11, relativeTo: .caption))
         .foregroundStyle(tint)
         .padding(.horizontal, 10)
         .padding(.vertical, 7)
         .background(tint.opacity(0.10), in: Capsule())
   }

}

private struct ThemeSettingsScreen: View {
   @Environment(\.dismiss) private var dismiss
   @Binding var appThemeRaw: String
   @Binding var appAppearanceModeRaw: String

   private var resolvedTheme: AppThemeOption {
      AppThemeOption(rawValue: appThemeRaw) ?? .classic
   }

   private var resolvedAppearanceMode: AppPreferences.AppAppearanceMode {
      AppPreferences.AppAppearanceMode(rawValue: appAppearanceModeRaw) ?? .system
   }

   var body: some View {
      SettingsSubmenuContainer(
         title: "Appearance"
      ) {
         appearanceModeBlock
         themePickerBlock
      }
      .preferredColorScheme(preferredAppearanceColorScheme)
   }

   private var appearanceModeBlock: some View {
      VStack(alignment: .leading, spacing: 12) {
         HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
               .font(.appDisplay(18, relativeTo: .headline))
               .foregroundStyle(AppColor.iconAccent)
               .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
               Text("Display Mode")
                  .font(.appBodyStrong(16, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Text("Use the device setting, or keep toDō light or dark.")
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         HStack(spacing: 8) {
            ForEach(AppPreferences.AppAppearanceMode.allCases) { mode in
               appearanceModeButton(mode)
            }
         }

         Text(resolvedAppearanceMode.detail)
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .contentTransition(.opacity)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      .animation(AppAnimation.snappyStandard, value: appAppearanceModeRaw)
   }

   private var preferredAppearanceColorScheme: ColorScheme? {
      switch resolvedAppearanceMode {
      case .system:
         return nil
      case .light:
         return .light
      case .dark:
         return .dark
      }
   }

   private func appearanceModeButton(_ mode: AppPreferences.AppAppearanceMode) -> some View {
      let isSelected = mode == resolvedAppearanceMode

      return Button {
         withAnimation(AppAnimation.snappyStandard) {
            appAppearanceModeRaw = mode.rawValue
         }
      } label: {
         VStack(spacing: 7) {
            Image(systemName: appearanceModeSymbol(mode))
               .font(.appDisplay(17, relativeTo: .headline))
            Text(mode.title)
               .font(.appBadge(14, relativeTo: .caption))
         }
         .foregroundStyle(isSelected ? AppColor.onAction : AppColor.textPrimary)
         .frame(maxWidth: .infinity)
         .padding(.vertical, 12)
         .background(isSelected ? AppColor.actionPrimary : AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
   }

   private func appearanceModeSymbol(_ mode: AppPreferences.AppAppearanceMode) -> String {
      switch mode {
      case .system:
         return "iphone"
      case .light:
         return "sun.max.fill"
      case .dark:
         return "moon.fill"
      }
   }

   private var themePickerBlock: some View {
      VStack(alignment: .leading, spacing: 18) {
         VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
               Image(systemName: "paintpalette.fill")
                  .font(.appDisplay(18, relativeTo: .headline))
                  .foregroundStyle(AppColor.iconAccent)
                  .frame(width: 24, height: 24)

               Text("Selected Look")
                  .font(.appBodyStrong(16, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
            }

            Text(resolvedTheme.title)
               .font(.appTitle(34, relativeTo: .largeTitle))
               .foregroundStyle(AppColor.textPrimary)

         }
         .padding(18)
         .frame(maxWidth: .infinity, alignment: .leading)
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 26))
         .overlay(alignment: .topTrailing) {
            HStack(spacing: -6) {
               Circle().fill(resolvedTheme.palette.main)
               Circle().fill(resolvedTheme.palette.secondary)
               Circle().fill(resolvedTheme.palette.tertiary)
            }
            .frame(width: 74, height: 24)
            .padding(18)
         }

         LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(AppThemeOption.allCases) { theme in
               themeSwatchButton(theme)
            }
         }
      }
   }

   private func themeSwatchButton(_ theme: AppThemeOption) -> some View {
      let isSelected = theme == resolvedTheme
      let palette = theme.palette

      return Button {
         guard !isSelected else {
            dismiss()
            return
         }

         let selectedThemeRaw = theme.rawValue
         dismiss()
         Task { @MainActor in
            appThemeRaw = selectedThemeRaw
         }
      } label: {
         VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
               Circle().fill(palette.main)
               Circle().fill(palette.secondary)
               Circle().fill(palette.tertiary)
            }
            .frame(height: 24)

            HStack(spacing: 10) {
               Text(theme.title)
                  .font(.appBodyStrong(16, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
                  .lineLimit(1)

               Spacer(minLength: 0)

               if isSelected {
                  Image(systemName: "checkmark.circle.fill")
                     .font(.appBodyStrong(19, relativeTo: .headline))
                     .foregroundStyle(AppColor.iconAccent)
               }
            }
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(14)
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(AppColor.surfaceElevated)
            }
         }
         .appInteractiveRoundedGlass(tint: AppColor.surfaceElevated, cornerRadius: 16)
         .overlay {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .stroke(isSelected ? AppColor.iconAccent : AppColor.border.opacity(0.35), lineWidth: isSelected ? 1.6 : 1)
            }
         }
      }
      .buttonStyle(.plain)
   }
}
