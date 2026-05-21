import SwiftUI
import SwiftData

struct AccountView: View {
    @EnvironmentObject private var authStore: SupabaseAuthStore
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @State private var isShowingSyncSettings = false
    @State private var isShowingRelaunchNotice = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
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
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $isShowingSyncSettings) {
            SyncSettingsView()
        }
        .alert("Sync Mode Saved", isPresented: $isShowingRelaunchNotice) {
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

    private var pinnedTitleHeader: some View {
        AppSettingsDetailHeader(title: "Account")
    }

    private var accountSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Identity")
                .font(.appSubtitle(15, relativeTo: .subheadline))
                .foregroundStyle(AppColor.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(authStore.accountDisplayName)
                        .font(.appBodyStrong(18, relativeTo: .body))
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer(minLength: 12)

                    accountStateBadge

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

                Text(authStore.accountDetailText)
                    .font(.appBody(13, relativeTo: .footnote))
                    .foregroundStyle(AppColor.textSecondary)

                Text(authStore.dataModeDescription)
                    .font(.appBody(13, relativeTo: .footnote))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .containerShape(.rect(cornerRadius: 24))
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
        }
    }

    private var syncOverviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Storage & Sync")
                .font(.appSubtitle(15, relativeTo: .subheadline))
                .foregroundStyle(AppColor.secondary)

            VStack(alignment: .leading, spacing: 14) {
                syncStatusBlock
                
                Button {
                    isShowingSyncSettings = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.trianglehead.branch")
                            .font(.appDisplay(15, relativeTo: .subheadline))
                            .foregroundStyle(AppColor.actionPrimary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Manage Storage & Sync")
                                .font(.appBodyStrong(15, relativeTo: .subheadline))
                                .foregroundStyle(AppColor.textPrimary)

                            Text("Choose where ToDo stores and syncs your ToDos: on this device, in iCloud, or through ToDo Sync.")
                                .font(.appBody(12, relativeTo: .caption))
                                .foregroundStyle(AppColor.textSecondary)
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
            }
            .padding(16)
            .containerShape(.rect(cornerRadius: 24))
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
        }
    }

    private var accountActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session")
                .font(.appSubtitle(15, relativeTo: .subheadline))
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
                            Text("Refresh Profile")
                                .font(.appBodyStrong(15, relativeTo: .subheadline))
                            Text("Re-fetch your Supabase profile and session-backed account state.")
                                .font(.appBody(12, relativeTo: .caption))
                                .foregroundStyle(AppColor.textSecondary)
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
                                .font(.appBodyStrong(15, relativeTo: .subheadline))
                            Text("End the current Supabase session and return this device to local mode.")
                                .font(.appBody(12, relativeTo: .caption))
                                .foregroundStyle(AppColor.textSecondary)
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
            Text("Auth State")
                .font(.appSubtitle(15, relativeTo: .subheadline))
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
            return "Close and reopen ToDo to finish switching to \(pendingMode.title)."
        }

        if syncCoordinator.preferredSyncMode == .syncEverywhere,
           !authStore.isAuthenticated {
            return "\(syncCoordinator.preferredSyncMode.title) is selected. Sign in to activate it; until then, ToDo stays on \(syncCoordinator.effectiveSyncMode.title)."
        }

        return syncCoordinator.effectiveSyncMode.subtitle
    }

    private var relaunchNoticeMessage: String {
        if let pendingMode = syncCoordinator.pendingRestartSyncMode {
            return "ToDo saved this change. Close and reopen the app when you are ready to finish switching to \(pendingMode.title)."
        }

        return "ToDo saved this change. Close and reopen the app when you are ready to finish the switch."
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

    private var accountStateBadge: some View {
        Text(authStore.accountStateTitle)
            .font(.appBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(accountStateBadgeForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accountStateBadgeBackground, in: Capsule())
    }

    private var accountStateBadgeForeground: Color {
        switch syncCoordinator.effectiveSyncMode {
        case .deviceOnly, .iCloud:
            return AppColor.white
        case .syncEverywhere:
            return authStore.isAuthenticated ? AppColor.white : AppColor.textPrimary
        }
    }

    private var accountStateBadgeBackground: Color {
        switch syncCoordinator.effectiveSyncMode {
        case .deviceOnly:
            return AppColor.textSecondary
        case .iCloud:
            return AppColor.secondary
        case .syncEverywhere:
            return authStore.isAuthenticated ? AppColor.tertiary : AppColor.surfaceMuted
        }
    }
}

struct SyncSettingsView: View {
    @EnvironmentObject private var authStore: SupabaseAuthStore
    @Query private var toDos: [ToDo]
    @Query private var syncConflicts: [SyncConflict]
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @State private var pendingSyncMode: SyncMode?
    @State private var isShowingSyncModeConfirmation = false
    @State private var isShowingSyncModeFinalConfirmation = false
    @State private var isShowingRelaunchNotice = false
    @State private var highlightedMode: SyncMode?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
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
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .confirmationDialog(syncModeConfirmationTitle, isPresented: $isShowingSyncModeConfirmation, titleVisibility: .visible) {
            Button("Continue") {
                isShowingSyncModeFinalConfirmation = true
            }

            Button("Cancel", role: .cancel) {
                pendingSyncMode = nil
            }
        } message: {
            Text(syncModeConfirmationMessage)
        }
        .alert(syncModeFinalConfirmationTitle, isPresented: $isShowingSyncModeFinalConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingSyncMode = nil
            }

            if pendingSyncModeHasMigrationPlan {
                Button("Move Current ToDos") {
                    confirmSyncModeChange(shouldTransferData: true)
                }

                Button("Start Fresh") {
                    confirmSyncModeChange(shouldTransferData: false)
                }
            } else {
                Button(syncModeFinalConfirmationActionTitle) {
                    confirmSyncModeChange(shouldTransferData: true)
                }
            }
        } message: {
            Text(syncModeFinalConfirmationMessage)
        }
        .alert("Sync Mode Saved", isPresented: $isShowingRelaunchNotice) {
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

    private var pinnedTitleHeader: some View {
        AppSettingsDetailHeader(
            title: "Sync",
            backAccessibilityLabel: "Go back to Account"
        )
    }

    private var syncOverviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Setup")
                .font(.appSubtitle(15, relativeTo: .subheadline))
                .foregroundStyle(AppColor.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose where ToDo stores and syncs your ToDos.")
                    .font(.appBodyStrong(16, relativeTo: .body))
                    .foregroundStyle(AppColor.textPrimary)

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
            Text("Modes")
                .font(.appSubtitle(15, relativeTo: .subheadline))
                .foregroundStyle(AppColor.secondary)

            VStack(alignment: .leading, spacing: 14) {
                iCloudRecommendationNote

                ForEach(syncCoordinator.availableOptions(isAuthenticated: authStore.isAuthenticated)) { option in
                    syncModeButton(option)
                }
            }
            .padding(16)
            .containerShape(.rect(cornerRadius: 24))
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
        }
    }

    private var iCloudRecommendationNote: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "icloud.fill")
                .font(.appDisplay(14, relativeTo: .subheadline))
                .foregroundStyle(AppColor.actionPrimary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("Apple-only devices?")
                    .font(.appBodyStrong(14, relativeTo: .subheadline))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Use Sync with iCloud for Apple-only devices. Use ToDo Sync when you also want Android or web access.")
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
            Text("Sync State")
                .font(.appSubtitle(15, relativeTo: .subheadline))
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
            return "Close and reopen ToDo to finish activating \(pendingMode.title)."
        }

        if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
            return "\(syncCoordinator.preferredSyncMode.title) is selected. Sign in below to activate it; until then, ToDo stays on \(syncCoordinator.effectiveSyncMode.title)."
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
        }

        if requiresRelaunchToApply(pendingSyncMode) {
            parts.append("This change takes effect after you close and reopen ToDo.")
        }

        if pendingSyncMode == .syncEverywhere, !authStore.isAuthenticated {
            parts.append("ToDo will keep you here so you can finish account setup.")
        }

        return parts.joined(separator: " ")
    }

    private var syncModeFinalConfirmationTitle: String {
        guard let pendingSyncMode else { return "Confirm Sync Mode" }
        return "Confirm \(pendingSyncMode.title)"
    }

    private var syncModeFinalConfirmationMessage: String {
        guard let pendingSyncMode else { return "" }
        var parts = [syncModePrimaryDescription(for: pendingSyncMode)]
        if pendingSyncModeHasMigrationPlan {
            parts.append("Choose whether to move the ToDos from your current storage mode into \(pendingSyncMode.title), or start \(pendingSyncMode.title) fresh.")
        }
        return parts.joined(separator: " ")
    }

    private var syncModeFinalConfirmationActionTitle: String {
        guard let pendingSyncMode else { return "Confirm" }
        return requiresRelaunchToApply(pendingSyncMode) ? "Save Mode" : "Switch"
    }

    private var pendingSyncModeHasMigrationPlan: Bool {
        guard let pendingSyncMode else { return false }
        return syncCoordinator.migrationPlan(for: pendingSyncMode) != nil
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
        return authStore.currentUserID
    }

    private var scopedToDos: [ToDo] {
        toDos.filter { $0.ownerUserID == visibleOwnerUserID }
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
                Text("Sync Needs Review")
                    .font(.appBodyStrong(15, relativeTo: .subheadline))
                    .foregroundStyle(AppColor.textPrimary)

                Text(unresolvedSyncConflicts.count == 1
                     ? "1 ToDo changed in two places. Choose which version to keep."
                     : "\(unresolvedSyncConflicts.count) ToDos changed in two places. Choose which versions to keep.")
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
                    .font(.appBody(17, relativeTo: .body))
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

            Text(authStore.accountDetailText)
                .font(.appBody(12, relativeTo: .caption))
                .foregroundStyle(AppColor.textSecondary)
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
                            .font(.appBodyStrong(15, relativeTo: .subheadline))
                            .foregroundStyle(AppColor.textPrimary)

                        if isEffective {
                            syncModeBadge("Active", foreground: AppColor.white, background: AppColor.actionPrimary)
                        } else if isPending {
                            syncModeBadge("Needs Relaunch", foreground: AppColor.white, background: AppColor.secondary)
                        } else if !option.isAvailable {
                            syncModeBadge("Unavailable", foreground: AppColor.white, background: AppColor.textSecondary)
                        } else if isPreferred && option.mode == .syncEverywhere && !authStore.isAuthenticated {
                            syncModeBadge("Selected", foreground: AppColor.white, background: AppColor.tertiary)
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
            .background(
                syncModeBackground(isPreferred: isPreferred, isHighlighted: isHighlighted),
                in: .rect(corners: .concentric, isUniform: true)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isHighlighted ? AppColor.tertiary.opacity(0.55) : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(!option.isAvailable)
        .opacity(option.isAvailable ? 1 : 0.5)
    }

    private func syncModeBadge(_ title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.appBodyStrong(10, relativeTo: .caption2))
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
        isShowingSyncModeConfirmation = true
    }

    private func retryPreferredSyncMode(_ mode: SyncMode) {
        guard mode == .syncEverywhere else {
            triggerSuccessHighlight(for: mode)
            return
        }

        guard authStore.isAuthenticated else {
            SyncCoordinator.shared.showTransientFeedback(
                title: "ToDo Sync Selected",
                message: "Sign in below to activate ToDo Sync.",
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
            return "ToDo will keep your ToDos only on this device and stop using remote sync."
        case .iCloud:
            return "ToDo will use your private iCloud storage to keep Apple devices in step."
        case .syncEverywhere:
            return "ToDo will use ToDo Sync to keep your ToDos available across iPhone, Android, and web."
        }
    }

    private var relaunchNoticeMessage: String {
        if let pendingMode = syncCoordinator.pendingRestartSyncMode {
            return "ToDo saved this change. Close and reopen the app when you are ready to activate \(pendingMode.title)."
        }

        return "ToDo saved this change. Close and reopen the app when you are ready to finish the switch."
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
