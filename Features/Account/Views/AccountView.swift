import SwiftUI
import SwiftData

struct AccountView: View {
   @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   @State private var isShowingSyncSettings = false
   @State private var isShowingRelaunchNotice = false

   var body: some View {
      accountBody
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .appNavigationChrome()
      .sheet(isPresented: $isShowingSyncSettings) {
         SyncSettingsView()
      }
      .alert("Sync Choice Saved", isPresented: $isShowingRelaunchNotice) {
         Button("Keep Open", role: .cancel) {}
      } message: {
         Text(relaunchNoticeMessage)
      }
      .overlay(alignment: .top) {
         if let feedback = syncCoordinator.syncFeedback {
            SyncFeedbackToast(feedback: feedback) {
               syncCoordinator.clearFeedback()
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
         }
      }
      .animation(.snappy(duration: 0.28), value: syncCoordinator.syncFeedback?.id)
      .onChange(of: syncCoordinator.pendingRestartSyncMode) { _, newValue in
         if newValue != nil {
            isShowingRelaunchNotice = true
         }
      }
   }

   @ViewBuilder
   private var accountBody: some View {
      if settingsDetailPresentation == .sidePanel {
         SettingsSubmenuContainer(title: "Account") {
            accountContent
         }
      } else {
         ZStack(alignment: .top) {
            ScrollView {
               accountContent
                  .padding(.horizontal, 16)
                  .padding(.top, 86)
                  .padding(.bottom, 24)
            }

            pinnedTitleHeader
         }
      }
   }

   private var accountContent: some View {
      VStack(alignment: .leading, spacing: 24) {
         accountSummarySection
         syncOverviewSection

         if authStore.isAuthenticated {
            accountActionsSection
         } else {
            AuthenticationView()
         }

         if authStore.isAuthenticated,
            let lastErrorMessage = authStore.lastErrorMessage,
            !lastErrorMessage.isEmpty {
            errorSection(message: lastErrorMessage)
         }
      }
   }

   private var pinnedTitleHeader: some View {
      AppSettingsDetailHeader(title: "Account")
   }

   private var accountSummarySection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Account")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
               Text(authStore.accountDisplayName)
                  .font(.appBodyStrong(18, relativeTo: .body))
                  .foregroundStyle(AppColor.textPrimary)

               Spacer(minLength: 12)

               if authStore.isAuthenticating {
                  ProgressView()
                     .tint(AppColor.secondary)
               }
            }

            if let email = authStore.signedInEmail {
               Label {
                  Text(email)
                     .font(.appBodyStrong(14, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textPrimary)
               } icon: {
                  Image(systemName: "envelope")
                     .font(.appDisplay(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.actionPrimary)
               }
            }

            if let signInMethodLabel = authStore.signInMethodLabel {
               Label {
                  Text(signInMethodLabel)
                     .font(.appBodyStrong(13, relativeTo: .footnote))
                     .foregroundStyle(AppColor.textPrimary)
               } icon: {
                  Image(systemName: "person.crop.circle.badge.checkmark")
                     .font(.appDisplay(12, relativeTo: .caption))
                     .foregroundStyle(AppColor.actionPrimary)
               }
               .accessibilityLabel("Signed in using \(signInMethodLabel)")
            }

         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
   }

   private var syncOverviewSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Where to Save")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 14) {
            Button {
               isShowingSyncSettings = true
            } label: {
               HStack(spacing: 12) {
                  Image(systemName: "arrow.trianglehead.branch")
                     .font(.appDisplay(15, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.actionPrimary)

                  VStack(alignment: .leading, spacing: 3) {
                     Text("Change Where to Save")
                        .font(.appButton(17, relativeTo: .headline))
                        .foregroundStyle(AppColor.textPrimary)
                  }

                  Spacer(minLength: 0)

                  Image(systemName: "chevron.right")
                     .font(.system(size: 12, weight: .semibold))
                     .foregroundStyle(AppColor.textSecondary)
               }
               .padding(.horizontal, 14)
               .padding(.vertical, 12)
               .frame(maxWidth: .infinity, alignment: .leading)
               .containerShape(.rect(cornerRadius: 18))
               .background(
                  AppColor.surfaceMuted,
                  in: .rect(corners: .concentric, isUniform: true)
               )
            }
            .buttonStyle(.plain)

            syncStatusBlock
         }
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
   }

   private var accountActionsSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Account Actions")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 14) {
            Button {
               Task {
                  await authStore.refreshProfile()
               }
            } label: {
               HStack(spacing: 12) {
                  Image(systemName: "arrow.clockwise")
                     .font(.appDisplay(15, relativeTo: .subheadline))

                  VStack(alignment: .leading, spacing: 3) {
                     Text("Refresh Account")
                        .font(.appButton(17, relativeTo: .headline))
                  }

                  Spacer(minLength: 0)
               }
               .foregroundStyle(AppColor.textPrimary)
               .padding(.horizontal, 14)
               .padding(.vertical, 12)
               .frame(maxWidth: .infinity, alignment: .leading)
               .containerShape(.rect(cornerRadius: 18))
               .background(
                  AppColor.surfaceMuted,
                  in: .rect(corners: .concentric, isUniform: true)
               )
            }
            .buttonStyle(.plain)

            Button {
               Task {
                  await authStore.signOut()
               }
            } label: {
               HStack(spacing: 12) {
                  Image(systemName: "rectangle.portrait.and.arrow.right")
                     .font(.appDisplay(15, relativeTo: .subheadline))

                  VStack(alignment: .leading, spacing: 3) {
                     Text("Sign Out")
                        .font(.appButton(17, relativeTo: .headline))
                  }

                  Spacer(minLength: 0)
               }
               .foregroundStyle(AppColor.actionDestructive)
               .padding(.horizontal, 14)
               .padding(.vertical, 12)
               .frame(maxWidth: .infinity, alignment: .leading)
               .containerShape(.rect(cornerRadius: 18))
               .background(
                  AppColor.actionDestructive.opacity(0.08),
                  in: .rect(corners: .concentric, isUniform: true)
               )
            }
            .buttonStyle(.plain)
         }
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
   }

   private func errorSection(message: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Account Issue")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         Text(message)
            .font(.appBody(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.actionDestructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .containerShape(.rect(cornerRadius: 24))
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
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
         return "Close and reopen toDō when you are ready to use \(pendingMode.title)."
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere,
         !authStore.isAuthenticated {
         return "\(syncCoordinator.preferredSyncMode.title) is selected. Sign in to activate it; until then, toDō stays on \(syncCoordinator.effectiveSyncMode.title)."
      }

      return syncCoordinator.effectiveSyncMode.subtitle
   }

   private var relaunchNoticeMessage: String {
      if let pendingMode = syncCoordinator.pendingRestartSyncMode {
         return "toDō saved this change. Close and reopen the app when you are ready to finish switching to \(pendingMode.title)."
      }

      return "toDō saved this change. Close and reopen the app when you are ready to finish the switch."
   }

   private var syncStatusBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 12) {
            Text("Current Sync")
               .font(.appBodyStrong(17, relativeTo: .body))
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
            onRefresh: manualSyncRefresh
         )
         .padding(.top, 2)
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

}

struct SyncSettingsView: View {
   @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @Query private var toDos: [ToDo]
   @Query private var syncConflicts: [SyncConflict]
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   @State private var pendingSyncMode: SyncMode?
   @State private var isShowingSyncModeReview = false
   @State private var isShowingRelaunchNotice = false
   @State private var highlightedMode: SyncMode?

   var body: some View {
      syncSettingsBody
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .appNavigationChrome()
      .sheet(isPresented: $isShowingSyncModeReview) {
         if let pendingSyncMode {
            SyncMigrationReviewSheet(
               mode: pendingSyncMode,
               currentCountLabel: currentVisibleToDoCountLabel,
               doneCountLabel: currentDoneToDoCountLabel,
               primaryDescription: syncModePrimaryDescription(for: pendingSyncMode),
               destinationDescription: syncModeDestinationDescription(for: pendingSyncMode),
               warningMessage: syncModeFinalConfirmationMessage,
               transferActionTitle: syncModeTransferActionTitle,
               destinationActionTitle: syncModeUseDestinationActionTitle,
               hasMigrationPlan: pendingSyncModeHasMigrationPlan,
               requiresRelaunch: requiresRelaunchToApply(pendingSyncMode),
               onCancel: {
                  isShowingSyncModeReview = false
                  self.pendingSyncMode = nil
               },
               onTransfer: {
                  confirmSyncModeChange(shouldTransferData: true)
                  isShowingSyncModeReview = false
               },
               onUseDestination: {
                  confirmSyncModeChange(shouldTransferData: false)
                  isShowingSyncModeReview = false
               }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
         }
      }
      .onChange(of: isShowingSyncModeReview) { _, isPresented in
         if !isPresented {
            pendingSyncMode = nil
         }
      }
      .alert("Sync Choice Saved", isPresented: $isShowingRelaunchNotice) {
         Button("Later", role: .cancel) {
            if let mode = syncCoordinator.pendingRestartSyncMode {
               triggerSuccessHighlight(for: mode)
            }
         }
         Button("Keep Open") {
            if let mode = syncCoordinator.pendingRestartSyncMode {
               triggerSuccessHighlight(for: mode)
            }
         }
      } message: {
         Text(relaunchNoticeMessage)
      }
      .overlay(alignment: .top) {
         if let feedback = syncCoordinator.syncFeedback {
            SyncFeedbackToast(feedback: feedback) {
               syncCoordinator.clearFeedback()
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
         }
      }
      .animation(.snappy(duration: 0.28), value: syncCoordinator.syncFeedback?.id)
      .animation(.spring(response: 0.34, dampingFraction: 0.72), value: highlightedMode)
      .onChange(of: syncCoordinator.pendingRestartSyncMode) { _, newValue in
         if newValue != nil {
            isShowingRelaunchNotice = true
         }
      }
   }

   @ViewBuilder
   private var syncSettingsBody: some View {
      if settingsDetailPresentation == .sidePanel {
         SettingsSubmenuContainer(title: "Sync") {
            syncSettingsContent
         }
      } else {
         ZStack(alignment: .top) {
            ScrollView {
               syncSettingsContent
                  .padding(.horizontal, 16)
                  .padding(.top, 86)
                  .padding(.bottom, 24)
            }

            pinnedTitleHeader
         }
      }
   }

   private var syncSettingsContent: some View {
      VStack(alignment: .leading, spacing: 24) {
         syncOverviewSection
         syncModesSection

         if syncCoordinator.preferredSyncMode == .syncEverywhere && !authStore.isAuthenticated {
            AuthenticationView()
         }

         if !(syncCoordinator.preferredSyncMode == .syncEverywhere && !authStore.isAuthenticated),
            let lastErrorMessage = authStore.lastErrorMessage,
            !lastErrorMessage.isEmpty {
            errorSection(message: lastErrorMessage)
         }
      }
   }

   private var pinnedTitleHeader: some View {
      AppSettingsDetailHeader(title: "Sync")
   }

   private var syncOverviewSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Current Choice")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 12) {
            syncStatusBlock

            if !unresolvedSyncConflicts.isEmpty {
               Divider()
               NavigationLink {
                  SyncConflictReviewView(
                     conflicts: unresolvedSyncConflicts,
                     toDos: scopedToDos
                  )
               } label: {
                  syncReviewBlock
               }
               .foregroundStyle(AppColor.textPrimary)
            }

            if syncCoordinator.preferredSyncMode == .syncEverywhere {
               Divider()
               syncIdentityBlock
            }
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
   }

   private var syncModesSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Choices")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 14) {
            syncMigrationGuideCard

            ForEach(syncCoordinator.availableOptions(isAuthenticated: authStore.isAuthenticated)) { option in
               syncModeButton(option)
            }

            iCloudRecommendationNote
         }
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
   }

   private var syncMigrationGuideCard: some View {
      VStack(alignment: .leading, spacing: 12) {
         HStack(alignment: .top, spacing: 11) {
            Image(systemName: "info.circle.fill")
               .font(.appDisplay(16, relativeTo: .subheadline))
               .foregroundStyle(AppColor.secondary)
               .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 5) {
               Text("Before you switch")
                  .font(.appBodyStrong(14, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textPrimary)

               Text(syncMigrationGuideMessage)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         HStack(spacing: 8) {
            syncCountPill(title: String(localized: "Current"), value: currentVisibleToDoCountLabel)
            syncCountPill(title: String(localized: "Done"), value: currentDoneToDoCountLabel)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(AppColor.secondary.opacity(0.08), in: .rect(cornerRadius: 18))
      .overlay {
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppColor.secondary.opacity(0.18), lineWidth: 1)
      }
   }

   private func syncCountPill(title: String, value: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(title)
            .font(.appBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(AppColor.textSecondary)
         Text(value)
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(AppColor.surfaceElevated.opacity(0.72), in: .rect(cornerRadius: 14))
   }

   private var iCloudRecommendationNote: some View {
      HStack(alignment: .top, spacing: 11) {
         Image(systemName: "icloud.fill")
            .font(.appDisplay(14, relativeTo: .subheadline))
            .foregroundStyle(AppColor.actionPrimary)
            .frame(width: 18, height: 18)

         VStack(alignment: .leading, spacing: 4) {
            Text("Only using Apple devices?")
               .font(.appBodyStrong(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)

            Text("Choose iCloud for Apple-only syncing. Choose toDō Sync for Android or web access too.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(AppColor.actionPrimary.opacity(0.08), in: .rect(cornerRadius: 18))
   }

   private func errorSection(message: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Sync Issue")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         Text(message)
            .font(.appBody(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.actionDestructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .containerShape(.rect(cornerRadius: 24))
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
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
         return String(
            format: String(localized: "Close and reopen toDō when you are ready to use %@."),
            pendingMode.title
         )
      }

      if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
         return String(
            format: String(localized: "%@ is selected. Sign in below to turn it on; until then, toDō stays with %@."),
            syncCoordinator.preferredSyncMode.title,
            syncCoordinator.effectiveSyncMode.title
         )
      }

      return syncCoordinator.effectiveSyncMode.subtitle
   }

   private var syncModeConfirmationTitle: String {
      guard let pendingSyncMode else { return "Switch Sync Mode?" }
      return "Switch to \(pendingSyncMode.title)?"
   }

   private var syncModeConfirmationMessage: String {
      guard let pendingSyncMode else { return "" }

      var parts = [syncModePrimaryDescription(for: pendingSyncMode)]

      if let plan = syncCoordinator.migrationPlan(for: pendingSyncMode) {
         parts.append(plan.summary)
         parts.append(
            String(
               format: String(localized: "Shown here now: %@."),
               currentVisibleToDoCountLabel
            )
         )
      }

      if requiresRelaunchToApply(pendingSyncMode) {
         parts.append("This change takes effect after you close and reopen toDō.")
      }

      if pendingSyncMode == .syncEverywhere, !authStore.isAuthenticated {
         parts.append("toDō will keep you here so you can finish account setup.")
      }

      return parts.joined(separator: " ")
   }

   private var syncModeFinalConfirmationTitle: String {
      guard let pendingSyncMode else { return "Confirm Sync Mode" }
      return "Confirm \(pendingSyncMode.title)"
   }

   private var syncModeFinalConfirmationMessage: String {
      guard let pendingSyncMode else { return "" }
      var parts = [
         syncModePrimaryDescription(for: pendingSyncMode),
         syncModeDestinationDescription(for: pendingSyncMode)
      ]
      if pendingSyncModeHasMigrationPlan {
         parts.append(
            String(
               format: String(localized: "This device currently shows %@. Choose carefully: copying these toDōs into %@ can create duplicates if the same toDōs already exist there from another device."),
               currentVisibleToDoCountLabel,
               pendingSyncMode.title
            )
         )
         parts.append(
            String(
               format: String(localized: "If you already used %@ on another device, choose the existing-destination option first."),
               pendingSyncMode.title
            )
         )
      }
      return parts.joined(separator: " ")
   }

   private var syncModeTransferActionTitle: String {
      guard let pendingSyncMode else { return String(localized: "Copy Current toDōs") }
      return String(
         format: String(localized: "Copy This Device's toDōs to %@"),
         pendingSyncMode.title
      )
   }

   private var syncModeUseDestinationActionTitle: String {
      guard let pendingSyncMode else { return String(localized: "Use What Is Already There") }
      switch pendingSyncMode {
      case .deviceOnly:
         return String(localized: "Do Not Copy; Keep This Device As Is")
      case .iCloud:
         return String(localized: "Do Not Copy; Use iCloud as It Is")
      case .syncEverywhere:
         return String(localized: "Do Not Copy; Use toDō Sync as It Is")
      }
   }

   private var syncMigrationGuideMessage: String {
      String(
         format: String(localized: "This device currently shows %@. iCloud and toDō Sync are separate places, so they may already have toDōs from another device."),
         currentVisibleToDoCountLabel
      )
   }

   private var syncModeFinalConfirmationActionTitle: String {
      guard let pendingSyncMode else { return String(localized: "Confirm") }
      return requiresRelaunchToApply(pendingSyncMode) ? String(localized: "Save Mode") : String(localized: "Switch")
   }

   private var pendingSyncModeHasMigrationPlan: Bool {
      guard let pendingSyncMode else { return false }
      return syncCoordinator.migrationPlan(for: pendingSyncMode) != nil
   }

   private var syncStatusBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 12) {
            Text("Selected")
               .font(.appDisplay(19, relativeTo: .headline))
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
            unresolvedConflictCount: unresolvedSyncConflicts.count,
            onRefresh: manualSyncRefresh
         )
         .padding(.top, 2)
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

   private var visibleOwnerUserID: UUID? {
      guard authStore.effectiveSyncMode == .syncEverywhere else { return nil }
      return authStore.scopedOwnerUserID
   }

   private var scopedToDos: [ToDo] {
      toDos.filter { $0.ownerUserID == visibleOwnerUserID }
   }

   private var currentVisibleToDoCountLabel: String {
      AppLocalization.localizedCount(scopedToDos.count, singularKey: "%@ toDō", pluralKey: "%@ toDōs")
   }

   private var currentDoneToDoCountLabel: String {
      let count = scopedToDos.filter { $0.lifecycleState == .done }.count
      return AppLocalization.localizedCount(count, singularKey: "%@ done", pluralKey: "%@ done")
   }

   private var unresolvedSyncConflicts: [SyncConflict] {
      syncConflicts
         .filter { !$0.isResolved && $0.userID == visibleOwnerUserID }
         .sorted { $0.createdAt > $1.createdAt }
   }

   private var syncReviewBlock: some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: "exclamationmark.triangle.fill")
            .font(.appDisplay(15, relativeTo: .subheadline))
            .foregroundStyle(AppColor.secondary)
            .frame(width: 18, height: 18)

         VStack(alignment: .leading, spacing: 4) {
            Text("Choose a Version")
               .font(.appBodyStrong(15, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)

            Text(unresolvedSyncConflicts.count == 1
                 ? "1 toDō changed in two places. Choose which version to keep."
                 : "\(unresolvedSyncConflicts.count) toDōs changed in two places. Choose which versions to keep.")
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

   private var syncIdentityBlock: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 12) {
            Text("Account")
               .font(.appBodyStrong(17, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Spacer(minLength: 12)

            Text(authStore.accountStateTitle)
               .font(.appBodyStrong(17, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)
         }

         if let email = authStore.signedInEmail {
            Text(email)
               .font(.appBodyStrong(13, relativeTo: .footnote))
               .foregroundStyle(AppColor.textPrimary)
         }

      }
   }

   private func syncModeButton(_ option: SyncModeOption) -> some View {
      let isPreferred = syncCoordinator.preferredSyncMode == option.mode
      let isEffective = syncCoordinator.effectiveSyncMode == option.mode
      let isPending = syncCoordinator.pendingRestartSyncMode == option.mode
      let isHighlighted = highlightedMode == option.mode

      return Button {
         beginSyncModeChange(option.mode)
      } label: {
         HStack(alignment: .top, spacing: 12) {
            Image(systemName: syncModeSymbol(for: option.mode, isEffective: isEffective))
               .font(.appDisplay(15, relativeTo: .subheadline))
               .foregroundStyle(isPreferred ? AppColor.actionPrimary : AppColor.textPrimary)
               .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
               HStack(spacing: 8) {
                  Text(option.mode.title)
                     .font(.appButton(17, relativeTo: .headline))
                     .foregroundStyle(AppColor.textPrimary)

                  if isEffective {
                     syncModeBadge("Active", foreground: AppColor.onAction, background: AppColor.actionPrimary)
                  } else if isPending {
                     syncModeBadge("Ready After Restart", foreground: AppColor.onAction, background: AppColor.secondary)
                  } else if !option.isAvailable {
                     syncModeBadge("Unavailable", foreground: AppColor.onAction, background: AppColor.textSecondary)
                  } else if isPreferred && option.mode == .syncEverywhere && !authStore.isAuthenticated {
                     syncModeBadge("Selected", foreground: AppColor.onAction, background: AppColor.tertiary)
                  }
               }

               Text(option.detailText)
                  .font(.appBody(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 0)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.horizontal, 14)
         .padding(.vertical, 12)
         .scaleEffect(isHighlighted ? 1.015 : 1)
         .contentShape(.rect(cornerRadius: 18))
         .containerShape(.rect(cornerRadius: 18))
         .background {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(syncModeBackground(isPreferred: isPreferred, isHighlighted: isHighlighted))
            }
         }
         .appInteractiveRoundedGlass(
            tint: syncModeBackground(isPreferred: isPreferred, isHighlighted: isHighlighted),
            cornerRadius: 18
         )
         .overlay {
            if #unavailable(iOS 26.0) {
               RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .stroke(isHighlighted ? AppColor.tertiary.opacity(0.55) : Color.clear, lineWidth: 1.5)
            }
         }
      }
      .buttonStyle(.plain)
      .disabled(!option.isAvailable)
      .opacity(option.isAvailable ? 1 : 0.5)
   }

   private func syncModeBadge(_ title: String, foreground: Color, background: Color) -> some View {
      Text(title)
         .font(.appBadge(12, relativeTo: .caption))
         .foregroundStyle(foreground)
         .padding(.horizontal, 8)
         .padding(.vertical, 4)
         .background(background, in: Capsule())
   }

   private func syncModeSymbol(for mode: SyncMode, isEffective: Bool) -> String {
      switch mode {
      case .deviceOnly:
         return isEffective ? "externaldrive.fill" : "externaldrive"
      case .iCloud:
         return isEffective ? "icloud.fill" : "icloud"
      case .syncEverywhere:
         return isEffective ? "globe.americas.fill" : "globe.americas"
      }
   }

   private func beginSyncModeChange(_ mode: SyncMode) {
      guard mode != syncCoordinator.preferredSyncMode else {
         retryPreferredSyncMode(mode)
         return
      }
      pendingSyncMode = mode
      isShowingSyncModeReview = true
   }

   private func retryPreferredSyncMode(_ mode: SyncMode) {
      guard mode == .syncEverywhere else {
         triggerSuccessHighlight(for: mode)
         return
      }

      guard authStore.isAuthenticated else {
         SyncCoordinator.shared.showTransientFeedback(
            title: "toDō Sync Selected",
            message: "Sign in below to activate toDō Sync.",
            style: .warning
         )
         triggerSuccessHighlight(for: mode)
         return
      }

      Task {
         await syncCoordinator.setPreferredSyncMode(
            mode,
            userID: authStore.currentUserID,
            shouldTransferData: true
         )
         await MainActor.run {
            triggerSuccessHighlight(for: mode)
         }
      }
   }

   private func confirmSyncModeChange(shouldTransferData: Bool) {
      guard let pendingSyncMode else { return }
      let targetMode = pendingSyncMode
      self.pendingSyncMode = nil

      Task {
         await syncCoordinator.setPreferredSyncMode(
            targetMode,
            userID: authStore.currentUserID,
            shouldTransferData: shouldTransferData
         )
         let wasAccepted = syncCoordinator.preferredSyncMode == targetMode
         || syncCoordinator.effectiveSyncMode == targetMode
         || syncCoordinator.pendingRestartSyncMode == targetMode
         if wasAccepted {
            await MainActor.run {
               triggerSuccessHighlight(for: targetMode)
            }
         }
         if syncCoordinator.pendingRestartSyncMode == targetMode {
            isShowingRelaunchNotice = true
         }
      }
   }

   private func requiresRelaunchToApply(_ mode: SyncMode) -> Bool {
      syncCoordinator.migrationPlan(for: mode)?.requiresRelaunchToApply == true
   }

   private func syncModePrimaryDescription(for mode: SyncMode) -> String {
      switch mode {
      case .deviceOnly:
         return "toDō will keep your toDōs only on this device."
      case .iCloud:
         return "toDō will use iCloud to keep your Apple devices in step."
      case .syncEverywhere:
         return "toDō Sync keeps your toDōs available across iPhone, Android, and web."
      }
   }

   private func syncModeDestinationDescription(for mode: SyncMode) -> String {
      switch mode {
      case .deviceOnly:
         return "This device is separate from iCloud and toDō Sync."
      case .iCloud:
         return "iCloud is separate from this device and toDō Sync."
      case .syncEverywhere:
         return "toDō Sync is separate from this device and iCloud."
      }
   }

   private var relaunchNoticeMessage: String {
      if let pendingMode = syncCoordinator.pendingRestartSyncMode {
         return "toDō saved this choice. Close and reopen the app when you are ready to use \(pendingMode.title)."
      }

      return "toDō saved this choice. Close and reopen the app when you are ready to finish."
   }

   private func syncModeBackground(isPreferred: Bool, isHighlighted: Bool) -> Color {
      if isHighlighted {
         return AppColor.tertiary.opacity(0.12)
      }
      return isPreferred ? AppColor.actionPrimary.opacity(0.08) : AppColor.surfaceMuted
   }

   private func triggerSuccessHighlight(for mode: SyncMode) {
      withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
         highlightedMode = mode
      }

      Task {
         try? await Task.sleep(nanoseconds: 1_600_000_000)
         guard !Task.isCancelled else { return }
         await MainActor.run {
            withAnimation(.easeOut(duration: 0.24)) {
               if highlightedMode == mode {
                  highlightedMode = nil
               }
            }
         }
      }
   }
}

private struct SyncMigrationReviewSheet: View {
   let mode: SyncMode
   let currentCountLabel: String
   let doneCountLabel: String
   let primaryDescription: String
   let destinationDescription: String
   let warningMessage: String
   let transferActionTitle: String
   let destinationActionTitle: String
   let hasMigrationPlan: Bool
   let requiresRelaunch: Bool
   let onCancel: () -> Void
   let onTransfer: () -> Void
   let onUseDestination: () -> Void

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 18) {
            header
            currentDataCard
            destinationCard
            decisionCard
            actionButtons
         }
         .padding(.horizontal, 18)
         .padding(.top, 22)
         .padding(.bottom, 28)
      }
      .background(AppColor.surface)
      .appBaseTypography()
   }

   private var header: some View {
      HStack(alignment: .top, spacing: 14) {
         Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
            .font(.appDisplay(28, relativeTo: .title2))
            .foregroundStyle(AppColor.secondary)
            .symbolEffect(.pulse.byLayer)

         VStack(alignment: .leading, spacing: 5) {
            Text(String(format: String(localized: "Switch to %@?"), mode.title))
               .font(.appDisplay(26, relativeTo: .title2))
               .foregroundStyle(AppColor.textPrimary)

            Text(primaryDescription)
               .font(.appBody(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }

         Spacer(minLength: 0)

         Button {
            onCancel()
         } label: {
            Image(systemName: "xmark")
               .font(.appDisplay(13, relativeTo: .caption))
               .frame(width: 32, height: 32)
         }
         .buttonStyle(.plain)
         .foregroundStyle(AppColor.textSecondary)
         .background {
            if #unavailable(iOS 26.0) {
               Circle()
                  .fill(AppColor.surfaceMuted)
            }
         }
         .appInteractiveCircleGlass(tint: AppColor.surfaceMuted)
         .accessibilityLabel("Cancel")
      }
   }

   private var currentDataCard: some View {
      VStack(alignment: .leading, spacing: 12) {
         Text("Current Choice")
            .font(.appDisplay(20, relativeTo: .headline))
            .foregroundStyle(AppColor.textPrimary)

         HStack(spacing: 10) {
            metricPill(title: String(localized: "Current"), value: currentCountLabel)
            metricPill(title: String(localized: "Done"), value: doneCountLabel)
         }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 22))
      .overlay {
         RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppColor.border, lineWidth: 1)
      }
   }

   private var destinationCard: some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: destinationSymbol)
            .font(.appDisplay(18, relativeTo: .headline))
            .foregroundStyle(AppColor.actionPrimary)
            .frame(width: 22, height: 22)

         VStack(alignment: .leading, spacing: 5) {
            Text(mode.title)
               .font(.appButton(17, relativeTo: .headline))
               .foregroundStyle(AppColor.textPrimary)

            Text(destinationDescription)
               .font(.appBody(13, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)

            if requiresRelaunch {
               Text("Close and reopen toDō to use this choice.")
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.secondary)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.actionPrimary.opacity(0.08), in: .rect(cornerRadius: 20))
   }

   private var decisionCard: some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: "exclamationmark.triangle.fill")
            .font(.appDisplay(17, relativeTo: .headline))
            .foregroundStyle(AppColor.secondary)
            .frame(width: 22, height: 22)

         Text(warningMessage)
            .font(.appBody(13, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.secondary.opacity(0.1), in: .rect(cornerRadius: 20))
   }

   private var actionButtons: some View {
      VStack(spacing: 10) {
         if hasMigrationPlan {
            Button {
               onUseDestination()
            } label: {
               actionLabel(
                  title: destinationActionTitle,
                  subtitle: String(localized: "Use what is already there first to avoid duplicates."),
                  systemName: "tray.and.arrow.down.fill"
               )
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.textPrimary)
            .background {
               if #unavailable(iOS 26.0) {
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                     .fill(AppColor.surfaceElevated)
               }
            }
            .appInteractiveRoundedGlass(tint: AppColor.surfaceElevated, cornerRadius: 20)
            .overlay {
               if #unavailable(iOS 26.0) {
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                     .stroke(AppColor.border, lineWidth: 1)
               }
            }

            Button {
               onTransfer()
            } label: {
               actionLabel(
                  title: transferActionTitle,
                  subtitle: String(localized: "Copy this device's visible toDōs into the new choice."),
                  systemName: "square.and.arrow.up.fill"
               )
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.textPrimary)
            .background {
               if #unavailable(iOS 26.0) {
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                     .fill(AppColor.secondary.opacity(0.12))
               }
            }
            .appInteractiveRoundedGlass(tint: AppColor.secondary.opacity(0.12), cornerRadius: 20)
         } else {
            Button {
               onTransfer()
            } label: {
               actionLabel(
                  title: requiresRelaunch ? String(localized: "Save Mode") : String(localized: "Switch"),
                  subtitle: primaryDescription,
                  systemName: "checkmark.circle.fill"
               )
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.textPrimary)
            .background {
               if #unavailable(iOS 26.0) {
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                     .fill(AppColor.actionPrimary.opacity(0.12))
               }
            }
            .appInteractiveRoundedGlass(tint: AppColor.actionPrimary.opacity(0.12), cornerRadius: 20)
         }

         Button("Cancel", role: .cancel) {
            onCancel()
         }
         .buttonStyle(.plain)
         .font(.appBodyStrong(14, relativeTo: .subheadline))
         .foregroundStyle(AppColor.textSecondary)
         .frame(maxWidth: .infinity)
         .padding(.vertical, 10)
      }
   }

   private func metricPill(title: String, value: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(title)
            .font(.appBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(AppColor.textSecondary)
         Text(value)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.textPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 11)
      .padding(.vertical, 9)
      .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 15))
   }

   private func actionLabel(title: String, subtitle: String, systemName: String) -> some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: systemName)
            .font(.appDisplay(16, relativeTo: .subheadline))
            .foregroundStyle(AppColor.actionPrimary)
            .frame(width: 22, height: 22)

         VStack(alignment: .leading, spacing: 4) {
            Text(title)
               .font(.appBodyStrong(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)

            Text(subtitle)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
         }

         Spacer(minLength: 0)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect(cornerRadius: 20))
   }

   private var destinationSymbol: String {
      switch mode {
      case .deviceOnly:
         return "externaldrive.fill"
      case .iCloud:
         return "icloud.fill"
      case .syncEverywhere:
         return "globe.americas.fill"
      }
   }
}

private struct SyncFeedbackToast: View {
   let feedback: SyncFeedback
   let onDismiss: () -> Void

   private var accent: Color {
      switch feedback.style {
      case .success:
         return AppColor.tertiary
      case .warning:
         return AppColor.secondary
      case .failure:
         return AppColor.actionDestructive
      }
   }

   var body: some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: symbolName)
            .font(.appDisplay(15, relativeTo: .subheadline))
            .foregroundStyle(accent)
            .padding(.top, 2)
            .symbolEffect(.bounce.byLayer, value: feedback.id)

         VStack(alignment: .leading, spacing: 4) {
            Text(feedback.title)
               .font(.appBodyStrong(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textPrimary)

            Text(feedback.message)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }

         Spacer(minLength: 0)

         Button {
            onDismiss()
         } label: {
            Image(systemName: "xmark")
               .font(.system(size: 11, weight: .semibold))
               .foregroundStyle(AppColor.textSecondary)
               .padding(8)
               .contentShape(Rectangle())
         }
         .buttonStyle(.plain)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
         AppColor.surfaceElevated,
         in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay {
         RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(accent.opacity(0.18), lineWidth: 1)
      }
      .shadow(color: AppColor.shadow, radius: 18, x: 0, y: 10)
      .accessibilityElement(children: .combine)
   }

   private var symbolName: String {
      switch feedback.style {
      case .success:
         return "checkmark.circle.fill"
      case .warning:
         return "arrow.trianglehead.clockwise"
      case .failure:
         return "exclamationmark.circle.fill"
      }
   }
}

#Preview {
   AccountView()
      .modelContainer(PreviewSupport.makeModelContainer())
      .environmentObject(SupabaseAuthStore.preview)
}

#Preview("Sync Settings") {
   SyncSettingsView()
      .modelContainer(PreviewSupport.makeModelContainer())
      .environmentObject(SupabaseAuthStore.preview)
}
