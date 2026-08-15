import SwiftUI
import SwiftData
import CoreLocation
import UniformTypeIdentifiers

private enum SettingsDetailRoute: Hashable, Identifiable {
   case account
   case plus
   case conflicts
   case sync
   case appearance
   case behavior
   case notifications
   case tags
   case dataControls
   case archives
   case trash
   case about

   var id: Self { self }
}

private struct AppReleaseNote: Identifiable {
   let version: String
   let isCurrent: Bool
   let notes: [LocalizedStringKey]
   let highlightCount: Int

   var id: String { version }
}

private struct AppReleaseHistorySheet: View {
   @Environment(\.dismiss) private var dismiss

   let currentVersion: String

   private var releases: [AppReleaseNote] {
      [
         AppReleaseNote(
            version: currentVersion,
            isCurrent: true,
            notes: [
               "Added toDō+ membership and expanded personal Collab options.",
               "Added custom reminder sounds and improved completion feedback.",
               "Improved voice entry, NanoDo reminders, onboarding, and accessibility.",
               "Unified the experience across iPhone, iPad, Apple Watch, and Mac.",
               "And much more, shaped around the way you work."
            ],
            highlightCount: 2
         ),
         AppReleaseNote(
            version: "3.0.1",
            isCurrent: false,
            notes: [
               "Improved sync reliability across devices.",
               "Refined notifications, widgets, Live Activities, and localization.",
               "Fixed stability and presentation issues reported after 3.0."
            ],
            highlightCount: 0
         ),
         AppReleaseNote(
            version: "3.0",
            isCurrent: false,
            notes: [
               "Introduced Home, Momentum, and the redesigned toDō workflow.",
               "Added toDō Sync, Apple Watch, Mac, widgets, and Live Activities.",
               "Rebuilt the app around a consistent cross-platform design."
            ],
            highlightCount: 0
         )
      ]
   }

   var body: some View {
      VStack(spacing: 0) {
         HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
               Text("Release History")
                  .font(.appDisplay(32, relativeTo: .title))
                  .foregroundStyle(AppColor.textPrimary)

               Text("See what changed, release by release.")
                  .font(.appBody(14, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 12)

            Button {
               dismiss()
            } label: {
               Image(systemName: "xmark")
                  .font(.system(size: 15, weight: .black))
            }
            .buttonStyle(AppCircleActionButtonStyle(
               intent: .cancel,
               size: 38,
               tint: AppColor.actionDestructive
            ))
            .accessibilityLabel("Close")
         }
         .padding(.horizontal, 20)
         .padding(.top, 24)
         .padding(.bottom, 16)

         ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
               ForEach(releases) { release in
                  VStack(alignment: .leading, spacing: 12) {
                     HStack(spacing: 10) {
                        Text(verbatim: release.version)
                           .font(.appDisplay(25, relativeTo: .title2))
                           .foregroundStyle(AppColor.textPrimary)

                        if release.isCurrent {
                           Text("Latest")
                              .font(.appBodyStrong(12, relativeTo: .caption))
                              .foregroundStyle(AppColor.onAction)
                              .padding(.horizontal, 10)
                              .padding(.vertical, 5)
                              .background(AppColor.actionPrimary, in: Capsule())
                        }
                     }

                     VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(release.notes.enumerated()), id: \.offset) { index, note in
                           HStack(alignment: .firstTextBaseline, spacing: 10) {
                              Circle()
                                 .fill(AppColor.main)
                                 .frame(width: 6, height: 6)

                              Text(note)
                                 .font(.system(.body, design: .monospaced))
                                 .fontWeight(index < release.highlightCount ? .bold : .regular)
                                 .foregroundStyle(AppColor.textPrimary)
                                 .fixedSize(horizontal: false, vertical: true)
                           }
                        }
                     }
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(18)
                  .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
               }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
         }
         .scrollIndicators(.hidden)
      }
      .background(AppColor.surface)
      .appBaseTypography()
   }
}

struct SettingsView: View {
   @Environment(\.modelContext) private var context
   @Environment(\.dismiss) private var dismiss
   @Environment(\.openURL) private var openURL
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
   @Environment(\.appReduceMotion) private var reduceMotion
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
   @EnvironmentObject private var collaborationService: ToDoCollaborationService
   @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
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
   @AppStorage(AppPreferences.Keys.defaultDueTimeMinutes) private var defaultDueTimeMinutes = AppPreferences.defaultDueTimeMinutes
   @AppStorage(AppPreferences.Keys.locationTimeZoneIdentifier) private var locationTimeZoneIdentifier = AppTimePreferences.appleParkTimeZoneIdentifier
   @AppStorage(AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly) private var mirrorSyncDeletesToDeviceOnly = true
   @AppStorage(AppPreferences.Keys.appIconBadgePolicy) private var appIconBadgePolicyRaw = AppPreferences.AppIconBadgePolicy.overdue.rawValue
   @AppStorage(AppPreferences.Keys.notificationSoundOption) private var notificationSoundOptionRaw = AppPreferences.NotificationSoundOption.defaultSound.rawValue
   @AppStorage(AppPreferences.Keys.customNotificationSoundName) private var customNotificationSoundName = ""
   @AppStorage(AppPreferences.Keys.customNotificationSoundDisplayName) private var customNotificationSoundDisplayName = ""
   @AppStorage(AppPreferences.Keys.completionSoundOption) private var completionSoundOptionRaw = AppPreferences.CompletionSoundOption.off.rawValue
   @AppStorage(AppPreferences.Keys.appTheme) private var appThemeRaw = AppThemeOption.classic.rawValue
   @AppStorage(AppPreferences.Keys.appAppearanceMode) private var appAppearanceModeRaw = AppPreferences.AppAppearanceMode.system.rawValue
   @AppStorage("trashAutoEmptyInterval") private var trashAutoEmptyIntervalRaw = TrashAutoEmptyInterval.oneMonth.rawValue

   @State private var isShowingDeleteUnusedTagsConfirmation = false
   @State private var isSortMenuExpanded = false
   @State private var isDoneSwipeMenuExpanded = false
   @State private var isTimeSourceMenuExpanded = false
   @State private var selectedDetailRoute: SettingsDetailRoute?
   @State private var pendingDetailRoute: SettingsDetailRoute?
   @State private var compactNavigationRoute: SettingsDetailRoute?
   @State private var notificationSoundPreviewStatus: String?
   @State private var isImportingNotificationSound = false
   @State private var isShowingCustomSoundHelp = false
   @State private var isShowingReleaseHistory = false
   @State private var isShowingCalendarRemovalConfirmation = false
   @State private var isShowingFinalCalendarRemovalConfirmation = false
   @State private var isRemovingCalendarEvents = false
   @State private var isShowingDataResetConfirmation = false
   @State private var isShowingSharedListResetChoice = false
   @State private var isResettingToDoData = false
   @State private var dataResetResultMessage = ""
   @State private var isShowingDataResetResult = false
   @State private var viewportWidth: CGFloat = 0
   @StateObject private var onboardingManager = GuidedOnboardingManager.shared
   @StateObject private var notificationManager = NotificationManager.shared
   @StateObject private var locationTimeZoneService = LocationTimeZoneService()
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   private let brandWebsiteURL = URL(string: "https://yourtodo.today")!
   private let shiftWebsiteURL = URL(string: "https://iamshift.dev")!
   private let privacyPolicyURL = URL(string: "https://yourtodo.today/legal/privacy.html")!
   private let termsOfUseURL = URL(string: "https://yourtodo.today/legal/terms.html")!
   private let supportURL = URL(string: "mailto:support@iamshift.dev")!
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
      Tag.canonicalTags(from: tags.filter { $0.ownerUserID == visibleOwnerUserID })
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
         && viewportWidth >= AppAdaptiveLayout.sideBySideMinimumWidth
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
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, settingsDashboardHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .animation(reduceMotion ? nil : AppAnimation.snappySection, value: isSettingsDetailPanelVisible)
         } else {
            settingsList
         }
      }
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { viewportWidth = $0 }
      .tint(AppColor.main)
      .appBaseTypography()
      .settingsNativeNavigationTitle("Settings", colorScheme: colorScheme, background: AppColor.main)
      .appReducedMotionBackButton(enabled: reduceMotion)
      .navigationDestination(item: $compactNavigationRoute) { route in
         settingsDetailView(route)
            .appReducedMotionBackButton(enabled: reduceMotion)
      }
      .fileImporter(
         isPresented: $isImportingNotificationSound,
         allowedContentTypes: NotificationSoundLibrary.supportedFileTypes,
         allowsMultipleSelection: false
      ) { result in
         handleNotificationSoundImport(result)
      }
      .sheet(isPresented: $isShowingCustomSoundHelp) {
         CustomNotificationSoundHelpView()
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColor.surface)
      }
      .sheet(isPresented: $isShowingReleaseHistory) {
         AppReleaseHistorySheet(currentVersion: appVersion)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColor.surface)
      }
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
      .confirmationDialog(
         "Reset all personal toDō data?",
         isPresented: $isShowingDataResetConfirmation,
         titleVisibility: .visible
      ) {
         Button("Continue", role: .destructive) {
            if hasJoinedSharedLists {
               isShowingSharedListResetChoice = true
            } else {
               resetToDoData(sharedListChoice: .keep)
            }
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This permanently deletes every personal toDō and NanoDo on this device and synced account. Your account, tags, preferences, purchases, and shared lists stay intact.")
      }
      .confirmationDialog(
         "What should happen to shared lists?",
         isPresented: $isShowingSharedListResetChoice,
         titleVisibility: .visible
      ) {
         Button("Keep Shared Lists") {
            resetToDoData(sharedListChoice: .keep)
         }
         Button("Leave Shared Lists", role: .destructive) {
            resetToDoData(sharedListChoice: .leave)
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("Keeping preserves the lists and your permissions. Leaving removes your access to lists shared with you. Shared lists you own remain in place.")
      }
      .alert("toDō Data Reset", isPresented: $isShowingDataResetResult) {
         Button("OK", role: .cancel) {}
      } message: {
         Text(dataResetResultMessage)
      }
      .confirmationDialog(
         "Stop adding due toDōs to Calendar?",
         isPresented: $isShowingCalendarRemovalConfirmation,
         titleVisibility: .visible
      ) {
         Button("Continue", role: .destructive) {
            isShowingFinalCalendarRemovalConfirmation = true
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This also removes Calendar events previously created by toDō. Your toDōs and their due dates stay unchanged.")
      }
      .alert("Remove toDō Calendar events?", isPresented: $isShowingFinalCalendarRemovalConfirmation) {
         Button("Remove Events", role: .destructive) {
            removeMirroredCalendarEvents()
         }
         Button("Keep Calendar Sync", role: .cancel) {}
      } message: {
         Text("This is the final confirmation. Calendar events created by toDō will be removed from Calendar.")
      }
      .onChange(of: locationTimeZoneService.authorizationStatus) { _, newStatus in
         if newStatus == .authorizedAlways || newStatus == .authorizedWhenInUse {
            locationTimeZoneService.requestLocationTimeZoneAccess()
         }
      }
      .task {
         await notificationManager.refreshAuthorizationStatus()
         routeOnboardingDestination(for: onboardingManager.currentStep)
      }
      .onChange(of: onboardingManager.currentStep) { _, newStep in
         routeOnboardingDestination(for: newStep)
      }
   }

   private func routeOnboardingDestination(for step: GuidedOnboardingStep) {
      switch step {
      case .signInAndSync:
         selectedDetailRoute = .sync
         compactNavigationRoute = .sync
      case .notificationPermission:
         selectedDetailRoute = .notifications
         compactNavigationRoute = .notifications
      case .archiveVsDelete:
         selectedDetailRoute = .behavior
         compactNavigationRoute = .behavior
      default:
         break
      }
   }

   private var settingsList: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 24) {
            settingsSection(String(localized: "Account")) {
               settingsDetailLink(.account) {
                  settingsNavigationRow(
                     authStore.isAuthenticated ? String(localized: "Account") : String(localized: "Sign In"),
                     detail: accountSummaryDetail
                  )
                  .onboardingSpotlightAnchor(.settingsAccount)
               }
               .foregroundStyle(AppColor.textPrimary)
            }

            settingsSection("toDō+") {
               settingsDetailLink(.plus) {
                  settingsNavigationRow(
                     "Membership",
                     detail: purchaseManager.displayedMembershipLabel,
                     detailForeground: purchaseManager.displayedHasPlus || purchaseManager.displayedIsPioneer || purchaseManager.displayedIsFoundingSupporter
                        ? AppColor.secondary
                        : AppColor.textSecondary,
                     detailFont: purchaseManager.displayedHasPlus || purchaseManager.displayedIsPioneer || purchaseManager.displayedIsFoundingSupporter
                        ? .appBodyStrong(16, relativeTo: .body)
                        : .appBody(16, relativeTo: .body)
                  )
               }
               .foregroundStyle(AppColor.textPrimary)
            }

            settingsSection(String(localized: "Sync")) {
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

               settingsDetailLink(.tags) {
                  settingsNavigationRow(
                     String(localized: "Tags"),
                     detail: customTagCountLabel
                  )
               }
               .foregroundStyle(AppColor.textPrimary)
            }

            settingsSection(String(localized: "Workflow")) {
               settingsDetailLink(.behavior) {
                  settingsNavigationRow(
                     String(localized: "Behavior"),
                     detail: resolvedDoneSwipePrimaryAction.compactTitle
                  )
                  .onboardingSpotlightAnchor(.settingsBehavior)
               }
               .foregroundStyle(AppColor.textPrimary)

               settingsDetailLink(.notifications) {
                  settingsNavigationRow(
                     String(localized: "Notifications"),
                     detail: notificationAuthorizationStatusLabel
                  )
                  .onboardingSpotlightAnchor(.settingsNotifications)
               }
               .foregroundStyle(AppColor.textPrimary)

            }

            settingsActionRow(
               systemName: "sparkles",
               title: String(localized: "Guided Tour"),
               detail: String(localized: "Replay the setup guide for creating a toDō, choosing sync, and enabling notifications.")
            ) {
               onboardingManager.restart()
               closeView()
            }
            .padding(4)
            .background(AppColor.secondary.opacity(0.08), in: .rect(cornerRadius: 20))
            .overlay {
               RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .stroke(AppColor.secondary.opacity(0.28), lineWidth: 1)
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

            settingsSection(String(localized: "About")) {
               settingsDetailLink(.about) {
                  settingsNavigationRow(
                     String(localized: "About toDō"),
                     detail: appVersionLabel
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
         .frame(maxWidth: .infinity, alignment: .top)
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
               .id(selectedDetailRoute)
               .frame(maxWidth: .infinity, alignment: .top)
               .clipShape(.rect(cornerRadius: 24))
               .padding(14)

            closeSettingsDetailButton
               .padding(.top, 16)
               .padding(.trailing, 16)
         }
         .frame(maxWidth: .infinity, alignment: .top)
         .fixedSize(horizontal: false, vertical: true)
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 30))
         .clipShape(.rect(cornerRadius: 30))
         .shadow(color: AppColor.shadow, radius: 18, x: 0, y: 8)
      }
   }

   private var closeSettingsDetailButton: some View {
      Button {
         withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
            selectedDetailRoute = nil
            pendingDetailRoute = nil
         }
      } label: {
         Image(systemName: "xmark")
            .font(.system(size: 16, weight: .black))
      }
      .buttonStyle(AppCircleActionButtonStyle(
         intent: .cancel,
         size: 44,
         tint: AppColor.actionDestructive
      ))
      .accessibilityLabel(Text("Close"))
   }

   @ViewBuilder
   private func settingsDetailLink<Label: View>(
      _ route: SettingsDetailRoute,
      @ViewBuilder label: () -> Label
   ) -> some View {
         if usesSettingsDetailLayout {
            Button {
               selectDetailRoute(route)
            } label: {
            label()
         }
         .buttonStyle(.plain)
         .accessibilityAddTraits(selectedDetailRoute == route ? [.isSelected] : [])
      } else {
         if reduceMotion {
            Button {
               navigateWithoutMotion(to: route)
            } label: {
               label()
            }
            .buttonStyle(.plain)
         } else {
            NavigationLink {
               settingsDetailView(route)
            } label: {
               label()
            }
         }
      }
   }

   @ViewBuilder
   private func settingsFullNavigationLink<Label: View>(
      _ route: SettingsDetailRoute,
      @ViewBuilder label: () -> Label
   ) -> some View {
      if reduceMotion {
         Button {
            navigateWithoutMotion(to: route)
         } label: {
            label()
         }
         .buttonStyle(.plain)
      } else {
         NavigationLink {
            settingsDetailView(route)
         } label: {
            label()
         }
      }
   }

   private func navigateWithoutMotion(to route: SettingsDetailRoute) {
      var transaction = Transaction()
      transaction.animation = nil
      transaction.disablesAnimations = true
      withTransaction(transaction) {
         compactNavigationRoute = route
      }
   }

   private func selectDetailRoute(_ route: SettingsDetailRoute) {
      guard selectedDetailRoute != route else { return }

      guard selectedDetailRoute != nil else {
         withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
            selectedDetailRoute = route
         }
         return
      }

      pendingDetailRoute = route
      withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
         selectedDetailRoute = nil
      }

      guard !reduceMotion else {
         selectedDetailRoute = route
         pendingDetailRoute = nil
         return
      }

      Task { @MainActor in
         try? await Task.sleep(for: .seconds(0.28))
         guard pendingDetailRoute == route else { return }
         pendingDetailRoute = nil
         withAnimation(AppAnimation.snappyStandard) {
            selectedDetailRoute = route
         }
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
      case .plus:
         return AnyView(ToDoPlusView())
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
      case .dataControls:
         return AnyView(dataControlsSettingsScreen)
      case .archives:
         return AnyView(ArchivesView())
      case .trash:
         return AnyView(TrashView())
      case .about:
         return AnyView(aboutSettingsScreen)
      }
   }

   private var aboutSettingsScreen: some View {
      SettingsSubmenuContainer(title: "About toDō") {
         VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
               Text("toDō is a productivity system built for the user to help you stay organized without getting in your way. From everyday tasks and shopping lists to bigger plans and everything beyond, it’s designed to work the way you do.")
                  .font(.appBody(17, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
                  .lineSpacing(6)
                  .fixedSize(horizontal: false, vertical: true)

               Text("Take a little time to explore. Try different ways of organizing your tasks, make the app your own, and see what works best for you. Visit yourtodo.today to learn more about toDō, and follow my Substack for release notes, engineering talk, and the thinking behind each update.")
                  .font(.appBody(17, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
                  .lineSpacing(6)
                  .fixedSize(horizontal: false, vertical: true)

               Text("\(Text("Hi, I’m moin.").fontWeight(.heavy)) I built toDō because I wanted a productivity app that felt simple, thoughtful, and enjoyable to use every day. It’s been a long journey, and I’m still making it better with every release. If you’d like to learn more about my work, you’ll find me at iamshift.dev.")
                  .font(.appBody(17, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)
                  .lineSpacing(6)
                  .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.top, 20)
            .padding(.bottom, 4)

            Text("shift beneath the view")
               .font(.appBodyStrong(17, relativeTo: .body))
               .fontWeight(.black)
               .foregroundStyle(AppColor.textPrimary)
               .tracking(0.9)
               .padding(.top, 14)
               .padding(.horizontal, 8)
               .padding(.bottom, 2)
               .accessibilityAddTraits(.isHeader)

            aboutPlainSectionHeading("Release Notes")
            aboutReleasePreview

            aboutPlainSectionHeading("Made with Intention")
            HStack(spacing: 16) {
               aboutMoinLink
               aboutToDoLink
            }
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)

            aboutSupportRow(destination: supportURL)
               .frame(maxWidth: 280)
               .frame(maxWidth: .infinity)
               .padding(.top, 6)

            aboutPlainSectionHeading("Legal")
            HStack(spacing: 3) {
               aboutCompactExternalLink(title: "Privacy Policy", destination: privacyPolicyURL)
               aboutCompactExternalLink(title: "Terms of Use", destination: termsOfUseURL)
            }
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
         }
      }
   }

   private var aboutReleasePreview: some View {
      VStack(alignment: .leading, spacing: 8) {
         HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
               .font(.system(size: 18, weight: .bold))
               .foregroundStyle(AppColor.main)
               .frame(width: 18, height: 18)

            Text("Version")
               .font(.appBodyStrong(17, relativeTo: .subheadline))
               .fontWeight(.heavy)
               .foregroundStyle(AppColor.textPrimary)

            Text(verbatim: appVersion)
               .font(.system(.subheadline, design: .monospaced).weight(.bold))
               .foregroundStyle(AppColor.textSecondary)
         }

         ForEach(Array(appReleasePreviewNotes.enumerated()), id: \.offset) { index, note in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
               Circle()
                  .fill(AppColor.main)
                  .frame(width: 6, height: 6)
                  .frame(width: 18, alignment: .center)

               Text(note)
                  .font(.system(.subheadline, design: .monospaced))
                  .fontWeight(index < 2 ? .bold : .regular)
                  .foregroundStyle(AppColor.textPrimary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         Button {
            isShowingReleaseHistory = true
         } label: {
            HStack(spacing: 7) {
               Text("All Release History")
                  .font(.appBodyStrong(14, relativeTo: .subheadline))
               Image(systemName: "arrow.up.right")
                  .font(.system(size: 12, weight: .heavy))
                  .accessibilityHidden(true)
            }
            .foregroundStyle(AppColor.actionPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 14))
         }
         .buttonStyle(.plain)
         .accessibilityHint("Shows release notes for every version")
         .padding(.top, 6)
      }
   }

   private var appReleasePreviewNotes: [LocalizedStringKey] {
      [
         "Added toDō+ membership and expanded personal Collab options.",
         "Added custom reminder sounds and improved completion feedback.",
         "Improved voice entry, NanoDo reminders, onboarding, and accessibility.",
         "Unified the experience across iPhone, iPad, Apple Watch, and Mac.",
         "And much more, shaped around the way you work."
      ]
   }

   private var aboutMoinLink: some View {
      Link(destination: shiftWebsiteURL) {
         aboutBrandCardContent {
            Image("brand-logomark")
               .resizable()
               .scaledToFit()
               .frame(width: 50, height: 50)

            brandWordmark
               .font(.appBodyStrong(18, relativeTo: .subheadline))
         }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("moin.shift()")
   }

   private var aboutToDoLink: some View {
      Link(destination: brandWebsiteURL) {
         aboutBrandCardContent {
            Image("todo-today-logo")
               .resizable()
               .scaledToFit()
               .frame(width: 50, height: 50)

            Text("toDō today")
               .font(.appBrand(18, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
         }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("toDō today")
   }

   private func aboutBrandCardContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
      VStack(spacing: 8) {
         HStack {
            Spacer()
            Image(systemName: "arrow.up.right")
               .font(.system(size: 16, weight: .heavy))
               .foregroundStyle(AppColor.actionPrimary)
         }

         content()
            .frame(maxWidth: .infinity)
      }
      .padding(14)
      .frame(width: 132, height: 132)
   }

   private func aboutPlainSectionHeading(_ title: LocalizedStringKey) -> some View {
      Text(title)
         .font(.appDisplay(22, relativeTo: .title3))
         .foregroundStyle(AppColor.secondary)
         .lineLimit(1)
         .minimumScaleFactor(0.82)
         .padding(.top, 22)
         .padding(.bottom, 6)
   }

   private func aboutSupportRow(
      destination: URL
   ) -> some View {
      Link(destination: destination) {
         HStack(spacing: 6) {
            Image(systemName: "envelope.fill")
               .font(.system(size: 15, weight: .bold))

            Text(verbatim: "support@iamshift.dev")
               .font(.appBodyStrong(16, relativeTo: .body))
               .lineLimit(1)
               .minimumScaleFactor(0.7)
               .layoutPriority(1)

         }
         .foregroundStyle(AppColor.onAction)
         .padding(.horizontal, 14)
         .padding(.vertical, 12)
         .frame(maxWidth: .infinity, alignment: .center)
         .background(AppColor.actionPrimary, in: .rect(cornerRadius: 18))
         .contentShape(.rect(cornerRadius: 18))
      }
      .buttonStyle(.plain)
   }

   private func aboutCompactExternalLink(
      title: LocalizedStringKey,
      destination: URL
   ) -> some View {
      Link(destination: destination) {
         HStack(spacing: 1) {
            Text(title)
               .font(.appBodyStrong(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)
               .lineLimit(1)
               .minimumScaleFactor(0.78)

            Image(systemName: "arrow.up.right")
               .font(.system(size: 11, weight: .heavy))
               .foregroundStyle(AppColor.actionPrimary)
               .accessibilityHidden(true)
         }
         .padding(.horizontal, 12)
         .padding(.vertical, 12)
         .frame(maxWidth: .infinity, alignment: .center)
         .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
         .contentShape(.rect(cornerRadius: 18))
      }
      .buttonStyle(.plain)
   }

   private var appVersionLabel: String {
      String(format: String(localized: "Version %@"), appVersion)
   }

   private var appVersion: String {
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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

            HStack(spacing: 12) {
               VStack(alignment: .leading, spacing: 4) {
                  Text("Default Due Time")
                     .font(.appBodyStrong(17, relativeTo: .body))
                     .foregroundStyle(AppColor.textPrimary)

                  Text("Used when you choose a due date without choosing a time.")
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               Spacer(minLength: 12)

               DatePicker(
                  "Default Due Time",
                  selection: defaultDueTimeBinding,
                  displayedComponents: .hourAndMinute
               )
               .labelsHidden()
               .datePickerStyle(.compact)
               .environment(\.locale, AppLocalization.displayLocale)
               .environment(\.calendar, AppLocalization.displayCalendar)
               .tint(AppColor.actionPrimary)
            }
            .padding(.vertical, 6)
         }

         settingsSection("Remove from View") {
            doneSwipeActionDropdown
         }

         settingsSection("Calendar") {
            calendarMirrorToggle
         }
      }
   }

   private var defaultDueTimeBinding: Binding<Date> {
      Binding(
         get: {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: .now)
            return calendar.date(
               byAdding: .minute,
               value: min(max(defaultDueTimeMinutes, 0), (24 * 60) - 1),
               to: start
            ) ?? start
         },
         set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            defaultDueTimeMinutes = (components.hour ?? 9) * 60 + (components.minute ?? 0)
         }
      )
   }

   private func handleOnboardingPrimaryAction(_ step: GuidedOnboardingStep) {
      switch step {
      case .signInAndSync:
         selectedDetailRoute = .notifications
         compactNavigationRoute = .notifications
         onboardingManager.advance(to: .notificationPermission)
      case .notificationPermission:
         Task { @MainActor in
            await notificationManager.requestAuthorizationFlow()
            selectedDetailRoute = .behavior
            compactNavigationRoute = .behavior
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

         settingsSection("Start Fresh") {
            settingsActionRow(
               systemName: isResettingToDoData ? "hourglass" : "trash.slash.fill",
               title: "Reset toDō Data",
               detail: String(localized: "Permanently deletes personal toDōs and NanoDos without deleting your account, tags, or purchases."),
               foregroundStyle: AppColor.actionDestructive,
               backgroundStyle: AppColor.actionDestructive.opacity(0.1),
               isDisabled: isResettingToDoData
            ) {
               isShowingDataResetConfirmation = true
            }
         }
      }
   }

   private var calendarMirrorToggle: some View {
      Toggle(isOn: calendarMirrorBinding) {
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
      .disabled(isRemovingCalendarEvents)
   }

   private var calendarMirrorBinding: Binding<Bool> {
      Binding(
         get: { mirrorDueDatesToCalendar },
         set: { isEnabled in
            if isEnabled {
               mirrorDueDatesToCalendar = true
               Task {
                  do {
                     _ = try await CalendarIntegrationService.shared.requestWriteAccess()
                  } catch {
                     mirrorDueDatesToCalendar = false
                     AppLog.error("Failed to request Calendar write access: \(error)", logger: AppLog.calendar)
                  }
               }
            } else {
               isShowingCalendarRemovalConfirmation = true
            }
         }
      )
   }

   private func removeMirroredCalendarEvents() {
      isRemovingCalendarEvents = true
      Task { @MainActor in
         do {
            try CalendarIntegrationService.shared.removeCalendarEvents(for: scopedToDos)
            try context.save()
            mirrorDueDatesToCalendar = false
         } catch {
            AppLog.error("Failed to remove mirrored Calendar events: \(error)", logger: AppLog.calendar)
         }
         isRemovingCalendarEvents = false
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
         Text("\(Text("toDō").font(.appBrand(18, relativeTo: .subheadline)).foregroundStyle(AppColor.main).bold()) \(Text(String(localized: "what matters")))")
            .font(.appSubtitle(16, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textPrimary)
            .multilineTextAlignment(.center)

         Link(destination: brandWebsiteURL) {
            Text(verbatim: "yourtodo.today")
               .font(.appBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(AppColor.actionPrimary)
         }
         .buttonStyle(.plain)

         VStack(spacing: 8) {
            Text(verbatim: "by")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)

            Link(destination: shiftWebsiteURL) {
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
            .buttonStyle(.plain)
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
         Text(verbatim: "mo")
            .font(brandWordmarkFont)
         Text(verbatim: "i").italic()
            .font(brandWordmarkItalicFont)
         Text(verbatim: "n.")
            .font(brandWordmarkFont)
         Text(verbatim: "sh").italic()
            .font(brandWordmarkItalicFont)
         Text(verbatim: "i")
            .font(brandWordmarkFont)
         Text(verbatim: "ft()").italic()
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

         Text(verbatim: detail)
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

   private var resolvedNotificationSoundTitle: String {
      guard resolvedNotificationSoundOption == .custom else {
         return resolvedNotificationSoundOption.title
      }

      return String(localized: "custom")
   }

   private var hasCustomNotificationSound: Bool {
      !customNotificationSoundName.isEmpty
   }

   private var resolvedCompletionSoundOption: AppPreferences.CompletionSoundOption {
      AppPreferences.CompletionSoundOption(rawValue: completionSoundOptionRaw) ?? .off
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

   private var hasJoinedSharedLists: Bool {
      guard let userID = authStore.currentUserID else { return false }
      return collaborationService.collabs.contains { $0.ownerUserID != userID }
   }

   private func resetToDoData(sharedListChoice: ToDoDataResetSharedListChoice) {
      guard !isResettingToDoData else { return }
      isResettingToDoData = true

      Task { @MainActor in
         do {
            let report = try await ToDoDataResetService.reset(
               toDos: toDos,
               accountUserID: authStore.currentUserID,
               sharedListChoice: sharedListChoice,
               collaborationService: collaborationService,
               in: context
            )
            WatchConnectivityService.shared.refreshSnapshot()
            dataResetResultMessage = dataResetMessage(for: report)
         } catch {
            dataResetResultMessage = String(
               format: String(localized: "Your toDō data could not be reset: %@"),
               error.localizedDescription
            )
         }
         isResettingToDoData = false
         isShowingDataResetResult = true
      }
   }

   private func dataResetMessage(for report: ToDoDataResetReport) -> String {
      var parts = [
         String(
            format: String(localized: "%@ personal toDōs were permanently deleted."),
            AppLocalization.numberString(report.deletedPersonalToDoCount)
         )
      ]
      if report.leftSharedListCount > 0 {
         parts.append(String(
            format: String(localized: "You left %@ shared lists."),
            AppLocalization.numberString(report.leftSharedListCount)
         ))
      }
      if report.preservedOwnedSharedListCount > 0 {
         parts.append(String(
            format: String(localized: "%@ shared lists you own were preserved."),
            AppLocalization.numberString(report.preservedOwnedSharedListCount)
         ))
      }
      return parts.joined(separator: " ")
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

   private func selectNotificationSoundOption(_ option: AppPreferences.NotificationSoundOption) {
      guard option != .custom || hasCustomNotificationSound else {
         notificationSoundPreviewStatus = String(localized: "Import a custom sound first.")
         isImportingNotificationSound = true
         return
      }

      withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
         notificationSoundOptionRaw = option.rawValue
      }
      NotificationManager.shared.scheduleRefresh()
   }

   private func handleNotificationSoundImport(_ result: Result<[URL], Error>) {
      switch result {
      case .success(let urls):
         guard let url = urls.first else { return }

         notificationSoundPreviewStatus = String(localized: "Checking custom sound...")
         Task {
            do {
               _ = try await NotificationSoundLibrary.importSound(from: url)
               await MainActor.run {
                  withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
                     notificationSoundOptionRaw = AppPreferences.NotificationSoundOption.custom.rawValue
                  }
                  notificationSoundPreviewStatus = String(localized: "Custom sound selected. Sending a sound test...")
                  NotificationManager.shared.scheduleRefresh()
                  scheduleNotificationSoundPreview()
               }
            } catch {
               await MainActor.run {
                  notificationSoundPreviewStatus = error.localizedDescription
                  AppLog.error("Failed to import notification sound: \(error)", logger: AppLog.notifications)
               }
            }
         }
      case .failure(let error):
         notificationSoundPreviewStatus = String(localized: "Could not import that sound.")
         AppLog.error("Notification sound import cancelled or failed: \(error)", logger: AppLog.notifications)
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

               Text(verbatim: detail)
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
      .accessibilityLabel(LocalizedStringKey(title))
      .accessibilityHint(LocalizedStringKey(detail))
      .accessibilityInputLabels([
         Text(LocalizedStringKey(title)),
         Text("Open \(title)")
      ])
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

         SyncHealthStatusView(
            syncCoordinator: syncCoordinator,
            isAccountAuthenticated: authStore.isAuthenticated,
            isNetworkAvailable: connectivityMonitor.isAvailable,
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

         if notificationOptionsAreAvailable {
            Divider()
               .overlay(AppColor.border.opacity(0.5))

            VStack(alignment: .leading, spacing: 12) {
               Text("Sounds")
                  .font(.appDisplay(19, relativeTo: .headline))
                  .foregroundStyle(AppColor.secondary)

               notificationSoundDropdown
               customNotificationSoundBlock
               notificationSoundPreviewButton
               completionSoundDropdown
               reminderIntentSoundGuide
            }
            .transition(.opacity.combined(with: .move(edge: .top)))

            Divider()
               .overlay(AppColor.border.opacity(0.5))

            VStack(alignment: .leading, spacing: 12) {
               Text("Badge")
                  .font(.appDisplay(19, relativeTo: .headline))
                  .foregroundStyle(AppColor.secondary)

               badgePolicyDropdown
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
         }
      }
      .animation(reduceMotion ? nil : AppAnimation.snappySection, value: notificationOptionsAreAvailable)
   }

   private var notificationOptionsAreAvailable: Bool {
      switch notificationManager.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
         return true
      case .denied, .notDetermined:
         return false
      @unknown default:
         return false
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: appThemeRaw)
   }

   fileprivate func themeSwatchButton(_ theme: AppThemeOption) -> some View {
      let isSelected = theme == resolvedTheme
      let palette = theme.palette

      return Button {
         withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
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
               selectNotificationSoundOption(option)
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
                  Text(resolvedNotificationSoundTitle)
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: notificationSoundOptionRaw)
   }

   private var customNotificationSoundBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 14) {
            Image(systemName: "icloud.and.arrow.down.fill")
               .font(.appDisplay(16, relativeTo: .subheadline))
               .foregroundStyle(AppColor.iconAccent)
               .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 5) {
               Text("Custom Sound")
                  .font(.appBodyStrong(15, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textPrimary)

               Text(hasCustomNotificationSound ? customNotificationSoundDisplayName : String(localized: "Import from Files or iCloud Drive."))
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button {
               isShowingCustomSoundHelp = true
            } label: {
               Image(systemName: "questionmark.circle.fill")
                  .font(.appDisplay(24, relativeTo: .title3))
                  .foregroundStyle(AppColor.iconAccent)
                  .frame(width: 42, height: 42)
                  .background(AppColor.actionPrimary.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
         }

         HStack(spacing: 10) {
            Button {
               isImportingNotificationSound = true
            } label: {
               Label(hasCustomNotificationSound ? "Replace" : "Import", systemImage: "icloud.and.arrow.down.fill")
                  .font(.appButton(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.onAction)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(AppColor.actionPrimary, in: Capsule())
            }
            .buttonStyle(.plain)

            if hasCustomNotificationSound {
               Button {
                  selectNotificationSoundOption(.custom)
               } label: {
                  Label("Use Custom", systemImage: resolvedNotificationSoundOption == .custom ? "checkmark.circle.fill" : "speaker.wave.2.fill")
                     .font(.appButton(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.actionPrimary)
                     .padding(.horizontal, 12)
                     .padding(.vertical, 8)
                     .background(AppColor.actionPrimary.opacity(0.12), in: Capsule())
               }
               .buttonStyle(.plain)

               Button {
                  NotificationSoundLibrary.clearSelectedCustomSound()
                  withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
                     notificationSoundOptionRaw = AppPreferences.NotificationSoundOption.defaultSound.rawValue
                  }
                  notificationSoundPreviewStatus = String(localized: "Custom sound removed.")
                  NotificationManager.shared.scheduleRefresh()
               } label: {
                  Label("Remove", systemImage: "trash.fill")
                     .font(.appButton(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.actionDestructive)
                     .padding(.horizontal, 12)
                     .padding(.vertical, 8)
                     .background(AppColor.actionDestructive.opacity(0.12), in: Capsule())
               }
               .buttonStyle(.plain)

               Spacer(minLength: 0)
            }
         }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 15)
      .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 20))
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: customNotificationSoundName)
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

   private var completionSoundDropdown: some View {
      Menu {
         ForEach(AppPreferences.CompletionSoundOption.allCases) { option in
            Button {
               withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
                  completionSoundOptionRaw = option.rawValue
               }
            } label: {
               Label(
                  option.title,
                  systemImage: option == resolvedCompletionSoundOption ? "checkmark.circle.fill" : "circle"
               )
            }
         }
      } label: {
         VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
               Image(systemName: "checkmark.seal.fill")
                  .font(.appDisplay(16, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.actionSuccess)
                  .frame(width: 22, height: 22)

               VStack(alignment: .leading, spacing: 5) {
                  Text("Completion Sound")
                     .font(.appBodyStrong(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)

                  Text(resolvedCompletionSoundOption.detail)
                     .font(.appBody(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
               }

               Spacer(minLength: 12)

               HStack(spacing: 8) {
                  Text(resolvedCompletionSoundOption.title)
                     .font(.appBadge(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.onAction)
                     .padding(.horizontal, 10)
                     .padding(.vertical, 6)
                     .background(AppColor.actionSuccess, in: Capsule())
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
      .accessibilityLabel("Completion Sound")
      .accessibilityValue(resolvedCompletionSoundOption.title)
      .accessibilityInputLabels([
         Text("Completion Sound"),
         Text("Done Sound"),
         Text("Task Complete Sound")
      ])
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: completionSoundOptionRaw)
   }

   private var badgePolicyDropdown: some View {
      Menu {
         ForEach(AppPreferences.AppIconBadgePolicy.allCases) { policy in
            Button {
               withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: appIconBadgePolicyRaw)
   }

   private var settingsSortDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: isSortMenuExpanded)
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
      withAnimation(reduceMotion ? nil : AppAnimation.snappyFast) {
         isSortMenuExpanded = false
      }
   }

   private var timeSourceDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
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
                  withAnimation(reduceMotion ? nil : AppAnimation.snappyFast) {
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: isTimeSourceMenuExpanded)
   }

   private var doneSwipeActionDropdown: some View {
      VStack(alignment: .leading, spacing: 10) {
         Button {
            withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
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
                  withAnimation(reduceMotion ? nil : AppAnimation.snappyFast) {
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: isDoneSwipeMenuExpanded)
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
   @Environment(\.appReduceMotion) private var reduceMotion
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
      .animation(reduceMotion ? nil : AppAnimation.snappyStandard, value: appAppearanceModeRaw)
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
         withAnimation(reduceMotion ? nil : AppAnimation.snappyStandard) {
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

private struct CustomNotificationSoundHelpHeightKey: PreferenceKey {
   static var defaultValue: CGFloat = 520

   static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
   }
}

private struct CustomNotificationSoundHelpView: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.openURL) private var openURL
   @State private var contentHeight: CGFloat = 520

   private let appleFilesHelpURL = URL(string: "https://support.apple.com/en-us/102570")!

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         HStack(alignment: .top, spacing: 14) {
            Image(systemName: "waveform.circle.fill")
               .font(.appDisplay(34, relativeTo: .largeTitle))
               .foregroundStyle(AppColor.iconAccent)

            VStack(alignment: .leading, spacing: 6) {
               Text("Custom reminder sounds")
                  .font(.appDisplay(26, relativeTo: .title2))
                  .foregroundStyle(AppColor.textPrimary)

               Text("Pick a sound from Files or iCloud Drive. toDō selects it and sends a quick sound test right away.")
                  .font(.appBody(15, relativeTo: .body))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         VStack(alignment: .leading, spacing: 10) {
            Text("Simple steps")
               .font(.appDisplay(22, relativeTo: .title3))
               .foregroundStyle(AppColor.textPrimary)

            instructionRow("1.circle.fill", "Save or move the audio file into Files or iCloud Drive.")
            instructionRow("2.circle.fill", "Tap Import in toDō, choose the file, then listen for the test.")
            instructionRow("3.circle.fill", "If the test sounds right, future reminders use that sound.")
         }
         .padding(18)
         .background(AppColor.actionPrimary.opacity(0.18), in: .rect(cornerRadius: 24))
         .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
               .stroke(AppColor.actionPrimary.opacity(0.36), lineWidth: 1)
         }

         VStack(alignment: .leading, spacing: 10) {
            Text("Deeper look")
               .font(.appDisplay(18, relativeTo: .headline))
               .foregroundStyle(AppColor.textSecondary)

            Text("Supported imports: MP3, M4A, CAF, WAV, AIFF, and AIF. Use audio that is 30 seconds or shorter and smaller than 5 MB. toDō stores a local notification-ready copy so iOS can play it even when the app is closed.")
               .font(.appBody(14, relativeTo: .callout))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }
         .padding(16)
         .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 24))

         Button {
            openURL(appleFilesHelpURL)
         } label: {
            Label("How to find files in iCloud Drive", systemImage: "arrow.up.right.circle.fill")
               .font(.appButton(15, relativeTo: .body))
               .foregroundStyle(AppColor.onAction)
               .frame(maxWidth: .infinity)
               .padding(.vertical, 13)
               .background(AppColor.actionPrimary, in: .rect(cornerRadius: 18))
         }
         .buttonStyle(.plain)

         Button {
            dismiss()
         } label: {
            Text("Close")
               .font(.appButton(15, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)
               .frame(maxWidth: .infinity)
               .padding(.vertical, 13)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
         }
         .buttonStyle(.plain)
      }
      .padding(22)
      .background {
         GeometryReader { proxy in
            Color.clear
               .preference(key: CustomNotificationSoundHelpHeightKey.self, value: proxy.size.height)
         }
      }
      .onPreferenceChange(CustomNotificationSoundHelpHeightKey.self) { height in
         contentHeight = min(max(height, 360), 700)
      }
      .presentationDetents([.height(contentHeight)])
      .appBaseTypography()
   }

   private func instructionRow(_ icon: String, _ text: LocalizedStringKey) -> some View {
      HStack(alignment: .top, spacing: 10) {
         Image(systemName: icon)
            .font(.appBodyStrong(17, relativeTo: .body))
            .foregroundStyle(AppColor.iconAccent)
            .frame(width: 22)

         Text(text)
            .font(.appBody(14, relativeTo: .callout))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
      }
   }
}
