import SwiftUI

struct SyncHealthStatusView: View {
    @ObservedObject var syncCoordinator: SyncCoordinator
    let isAccountAuthenticated: Bool
    var unresolvedConflictCount: Int = 0
    var onRefresh: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(statusTitle)
                        .font(.appBodyStrong(13, relativeTo: .footnote))
                        .foregroundStyle(statusColor)

                    if syncCoordinator.syncActivityState == .activating || syncCoordinator.syncActivityState == .syncing {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(statusColor)
                    }
                }

                Text(statusDetail)
                    .font(.appBody(12, relativeTo: .caption))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 0)

            if canRefresh {
                Button {
                    onRefresh?()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.appBodyStrong(12, relativeTo: .caption))

                        if syncCoordinator.syncActivityState == .failed {
                            Text("Retry")
                                .font(.appBodyStrong(12, relativeTo: .caption))
                        }
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, syncCoordinator.syncActivityState == .failed ? 10 : 0)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(syncCoordinator.syncActivityState == .failed ? "Retry toDō Sync" : "Refresh toDō Sync")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.08), in: .rect(cornerRadius: 18))
    }

    private var statusIcon: some View {
        Image(systemName: statusSystemName)
            .font(.appDisplay(13, relativeTo: .caption))
            .foregroundStyle(statusColor)
    }

    private var statusTitle: String {
        if syncCoordinator.pendingRestartSyncMode != nil {
            return String(localized: "Ready After Restart")
        }

        if syncCoordinator.preferredSyncMode == .syncEverywhere,
           !isAccountAuthenticated {
            return String(localized: "Sign In Needed")
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return String(localized: "Getting Ready")
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return String(localized: "Active")
        }

        if unresolvedConflictCount > 0 {
            return String(localized: "Needs Review")
        }

        switch syncCoordinator.syncActivityState {
        case .idle:
            return String(localized: "Active")
        case .activating:
            return syncCoordinator.currentSyncPhase == .queuedLocalChanges
                ? String(localized: "Waiting")
                : String(localized: "Getting Ready")
        case .syncing:
            return syncCoordinator.currentSyncPhase == .queuedLocalChanges
                ? String(localized: "Waiting")
                : syncCoordinator.currentSyncPhase?.title ?? String(localized: "Syncing")
        case .synced:
            return String(localized: "Active")
        case .failed:
            return String(localized: "Sync Failed")
        }
    }

    private var canRefresh: Bool {
        onRefresh != nil
            && syncCoordinator.effectiveSyncMode == .syncEverywhere
            && isAccountAuthenticated
            && syncCoordinator.syncActivityState != .activating
            && syncCoordinator.syncActivityState != .syncing
    }

    private var statusDetail: String {
        if let pendingMode = syncCoordinator.pendingRestartSyncMode {
            return String(format: String(localized: "%@ is saved. Close and reopen toDō when you are ready to use it."), pendingMode.title)
        }

        if syncCoordinator.preferredSyncMode == .syncEverywhere,
           !isAccountAuthenticated {
            return String(format: String(localized: "toDō Sync is selected. Sign in to turn it on; until then, toDō stays with %@."), syncCoordinator.effectiveSyncMode.title)
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return String(format: String(localized: "%@ is selected. toDō will keep using %@ until the switch is finished."), syncCoordinator.preferredSyncMode.title, syncCoordinator.effectiveSyncMode.title)
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return String(format: String(localized: "toDō is using %@."), syncCoordinator.effectiveSyncMode.title)
        }

        if unresolvedConflictCount > 0 {
            return unresolvedConflictCount == 1
                ? String(localized: "1 toDō changed on more than one device. Choose which version to keep.")
                : String(format: String(localized: "%@ toDōs changed on more than one device. Choose which versions to keep."), AppLocalization.numberString(unresolvedConflictCount))
        }

        switch syncCoordinator.syncActivityState {
        case .idle:
            return syncCoordinator.lastSuccessfulSyncAt.map(lastSyncMessage)
                ?? String(localized: "toDō Sync is on and ready.")
        case .activating:
            return syncCoordinator.currentSyncPhase?.detail
                ?? String(localized: "Getting this device ready.")
        case .syncing:
            return syncCoordinator.currentSyncPhase?.detail
                ?? String(localized: "Sharing changes and checking for updates.")
        case .synced:
            return syncCoordinator.lastSuccessfulSyncAt.map(lastSyncMessage)
                ?? String(localized: "toDō Sync is on and up to date.")
        case .failed:
            let phasePrefix = syncCoordinator.lastFailedSyncPhase.map { "\($0.title): " } ?? ""
            return syncCoordinator.lastSyncErrorMessage.map {
                String(format: String(localized: "The last sync did not finish. %@%@"), phasePrefix, $0)
            } ?? String(localized: "The last sync did not finish. Tap refresh to try again.")
        }
    }

    private var statusColor: Color {
        if syncCoordinator.pendingRestartSyncMode != nil {
            return AppColor.secondary
        }

        if syncCoordinator.preferredSyncMode == .syncEverywhere,
           !isAccountAuthenticated {
            return AppColor.secondary
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return AppColor.actionPrimary
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return AppColor.textSecondary
        }

        if unresolvedConflictCount > 0 {
            return AppColor.secondary
        }

        switch syncCoordinator.syncActivityState {
        case .idle:
            return AppColor.textSecondary
        case .activating:
            return AppColor.actionPrimary
        case .syncing:
            return AppColor.actionPrimary
        case .synced:
            return AppColor.tertiary
        case .failed:
            return AppColor.actionDestructive
        }
    }

    private var statusSystemName: String {
        if syncCoordinator.pendingRestartSyncMode != nil {
            return "arrow.clockwise.circle.fill"
        }

        if syncCoordinator.preferredSyncMode == .syncEverywhere,
           !isAccountAuthenticated {
            return "person.crop.circle.badge.exclamationmark"
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return "arrow.triangle.2.circlepath"
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return "iphone"
        }

        if unresolvedConflictCount > 0 {
            return "exclamationmark.triangle.fill"
        }

        switch syncCoordinator.syncActivityState {
        case .idle:
            return "clock"
        case .activating:
            return "arrow.triangle.2.circlepath"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.icloud"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocalization.displayLocale
        formatter.calendar = AppLocalization.displayCalendar
        formatter.unitsStyle = .full
        return formatter
    }

    private var absoluteDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.displayLocale
        formatter.calendar = AppLocalization.displayCalendar
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    private func lastSyncMessage(for date: Date) -> String {
        String(
            format: String(localized: "Last synced %@ at %@."),
            relativeDateFormatter.localizedString(for: date, relativeTo: .now),
            absoluteDateFormatter.string(from: date)
        )
    }
}

#Preview("Sync Status") {
    VStack(spacing: 14) {
        SyncHealthStatusView(
            syncCoordinator: .shared,
            isAccountAuthenticated: true,
            unresolvedConflictCount: 0
        )

        SyncHealthStatusView(
            syncCoordinator: .shared,
            isAccountAuthenticated: true,
            unresolvedConflictCount: 2
        )

        SyncHealthStatusView(
            syncCoordinator: .shared,
            isAccountAuthenticated: false,
            unresolvedConflictCount: 0
        )
    }
    .padding()
    .background(AppColor.surface)
    .appBaseTypography()
}
