import SwiftUI
import SwiftData

enum SettingsDetailPresentation {
   case pushed
   case sidePanel
}

private struct SettingsDetailPresentationKey: EnvironmentKey {
   static let defaultValue: SettingsDetailPresentation = .pushed
}

extension EnvironmentValues {
   var settingsDetailPresentation: SettingsDetailPresentation {
      get { self[SettingsDetailPresentationKey.self] }
      set { self[SettingsDetailPresentationKey.self] = newValue }
   }
}

struct SettingsSubmenuContainer<Content: View>: View {
   @Environment(\.settingsDetailPresentation) private var presentation
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
   let title: String
   @ViewBuilder let content: () -> Content

   private var pushedContentMaxWidth: CGFloat {
      horizontalSizeClass == .regular ? 760 : .infinity
   }

   var body: some View {
      if presentation == .sidePanel {
         sidePanelBody
      } else {
         pushedBody
      }
   }

   private var pushedBody: some View {
      VStack(spacing: 0) {
         AppSettingsDetailHeader(title: title)

         ScrollView {
            contentStack
               .frame(maxWidth: pushedContentMaxWidth, alignment: .topLeading)
               .frame(maxWidth: .infinity, alignment: .top)
               .padding(.horizontal, 16)
               .padding(.top, 4)
               .padding(.bottom, 28)
         }
         .scrollIndicators(.hidden)
      }
      .background(AppColor.surface)
      .tint(AppColor.main)
      .appBaseTypography()
      .appNavigationChrome()
   }

   private var sidePanelBody: some View {
      ViewThatFits(in: .vertical) {
         VStack(spacing: 0) {
            sidePanelHeader

            contentStack
               .padding(.horizontal, 16)
               .padding(.top, 4)
               .padding(.bottom, 18)
         }

         VStack(spacing: 0) {
            sidePanelHeader

            ScrollView {
               contentStack
                  .padding(.horizontal, 16)
                  .padding(.top, 4)
                  .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
         }
      }
      .background(AppColor.surface)
      .tint(AppColor.main)
      .appBaseTypography()
      .appNavigationChrome()
   }

   private var contentStack: some View {
      VStack(alignment: .leading, spacing: 24) {
         content()
      }
   }

   private var sidePanelHeader: some View {
      HStack(spacing: 10) {
         Capsule()
            .fill(AppColor.main)
            .frame(width: 5, height: 28)

         Text(LocalizedStringKey(title))
            .font(.appDisplay(28, relativeTo: .title2))
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 12)
      .background(AppColor.surface)
      .accessibilityAddTraits(.isHeader)
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
               Text("Choose a Version")
                  .font(.appTitle(34, relativeTo: .largeTitle))
                  .foregroundStyle(AppColor.textPrimary)
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
      .alert("Keep This Version?", isPresented: isShowingPendingResolution) {
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

            Text("No toDōs need sync review right now.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
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
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      .overlay {
         RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(AppColor.secondary.opacity(0.18), lineWidth: 1)
      }
   }

   private func versionBlock(title: String, summary: String, updatedAt: Date?) -> some View {
      VStack(alignment: .leading, spacing: 5) {
         Text(LocalizedStringKey(title))
            .font(.appSubtitle(12, relativeTo: .caption))
            .foregroundStyle(AppColor.secondary)

         Text(summary)
            .font(.appBodyStrong(14, relativeTo: .footnote))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

         if let updatedAt {
            Text(String(format: String(localized: "Changed %@"), AppLocalization.dateTimeString(updatedAt)))
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
               title: "Choice Saved",
               message: "toDō is sharing the version you selected.",
               style: .success
            )
         } catch {
            resolutionErrorMessage = String(
               format: String(localized: "Could not save that sync choice. %@"),
               error.localizedDescription
            )
            AppLog.error("Failed to resolve sync conflict: \(error)", logger: AppLog.sync)
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
            return String(localized: "Keep This Device")
         case .useSyncedVersion:
            return String(localized: "Use Synced")
         }
      }

      var message: String {
         switch resolution {
         case .keepDeviceVersion:
            return String(localized: "toDō will keep this device's version.")
         case .useSyncedVersion:
            return String(localized: "toDō will use the version from your other device.")
         }
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
