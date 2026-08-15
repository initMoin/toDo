import SwiftUI
import SwiftData
import CoreGraphics
import ImageIO
import PhotosUI

struct AccountView: View {
   private enum AccountSheet: Identifiable {
      case sync
      case collab(ToDoCollab)

      var id: String {
         switch self {
         case .sync: "sync"
         case .collab(let collab): "collab-\(collab.id.uuidString)"
         }
      }
   }

   @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
   @Environment(\.colorScheme) private var colorScheme
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
   @EnvironmentObject private var collaborationService: ToDoCollaborationService
   @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
   @StateObject private var syncCoordinator = SyncCoordinator.shared
   @State private var activeSheet: AccountSheet?
   @State private var isShowingProfile = false
   @State private var isShowingRelaunchNotice = false
   @State private var isCreatingCollab = false
   @State private var newCollabName = ""
   @State private var collabActionID: UUID?

   var body: some View {
      accountBody
      .scrollIndicators(.hidden)
      .background(AppColor.surface)
      .tint(AppColor.actionPrimary)
      .appBaseTypography()
      .sheet(item: $activeSheet) { sheet in
         switch sheet {
         case .sync:
            SyncSettingsView()
         case .collab(let collab):
            CollabUsersView(collab: collab)
               .presentationDetents([.medium, .large])
               .presentationDragIndicator(.visible)
         }
      }
      .fullScreenCover(isPresented: $isShowingProfile, onDismiss: {
         Task { await authStore.refreshProfile() }
      }) {
         MyProfileView()
      }
      .alert("Sync Choice Saved", isPresented: $isShowingRelaunchNotice) {
         Button("Keep Open", role: .cancel) {}
      } message: {
         Text(relaunchNoticeMessage)
      }
      .alert("New Collab", isPresented: $isCreatingCollab) {
         TextField("Collab Name", text: $newCollabName)
         Button("Cancel", role: .cancel) {
            newCollabName = ""
         }
         Button("Create") {
            createCollab()
         }
         .disabled(newCollabName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      } message: {
         Text("Name the shared space you will use with other users.")
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
      .task(id: authStore.resolvedAccountID) {
         guard authStore.hasResolvedAccount else { return }
         await collaborationService.refresh()
      }
   }

   @ViewBuilder
   private var accountBody: some View {
      if settingsDetailPresentation == .sidePanel {
         SettingsSubmenuContainer(title: "Account") {
            accountContent
         }
      } else {
         ScrollView {
            accountContent
               .padding(.horizontal, 16)
               .padding(.top, 16)
               .padding(.bottom, 24)
         }
         .settingsNativeNavigationTitle("Account", colorScheme: colorScheme, background: AppColor.main)
      }
   }

   private var accountContent: some View {
      VStack(alignment: .leading, spacing: 24) {
         if authStore.isAuthenticated && !authStore.hasResolvedAccount {
            AccountSetupView()
         } else {
            accountSummarySection
            if authStore.hasResolvedAccount {
               ToDoSignInMethodsSection()
            }
            if authStore.hasResolvedAccount, collaborationService.isBackendAvailable {
               collabsSection
            }
            syncOverviewSection

            if authStore.hasResolvedAccount {
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
   }

   private var accountSummarySection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Account")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         Button {
            guard authStore.isAuthenticated else { return }
            isShowingProfile = true
         } label: {
            HStack(alignment: .center, spacing: 12) {
               ProfileAvatarView(
                  profile: authStore.profile,
                  email: authStore.signedInEmail,
                  size: 46,
                  localUserID: authStore.currentUserID,
                  localImageRevision: authStore.profileImageRevision
               )

               VStack(alignment: .leading, spacing: 5) {
                  Text(authStore.accountDisplayName)
                     .font(.appBodyStrong(18, relativeTo: .body))
                     .foregroundStyle(AppColor.textPrimary)
                     .lineLimit(1)

                  if authStore.isAuthenticated {
                     Text(purchaseManager.hasPlus ? "toDō+" : "toDō")
                        .font(.appBadge(12, relativeTo: .caption))
                        .foregroundStyle(AppColor.textSecondary)
                  }
               }

               Spacer(minLength: 12)

               if authStore.isAuthenticating {
                  ProgressView()
                     .tint(AppColor.secondary)
               } else if authStore.isAuthenticated {
                  Image(systemName: "arrow.up.right.circle.fill")
                     .font(.appDisplay(22, relativeTo: .title3))
                     .foregroundStyle(AppColor.actionPrimary)
               }
            }
         }
         .buttonStyle(.plain)
         .disabled(!authStore.isAuthenticated)
         .accessibilityLabel(authStore.isAuthenticated ? "My Profile" : "Account")
         .accessibilityHint(authStore.isAuthenticated ? "Opens your profile." : "Sign in to create a profile.")
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(16)
         .containerShape(.rect(cornerRadius: 24))
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      }
   }

   private var collabsSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(spacing: 10) {
            Text("Collabs")
               .font(.appDisplay(22, relativeTo: .title3))
               .foregroundStyle(AppColor.secondary)

            Spacer(minLength: 8)

            Button {
               isCreatingCollab = true
            } label: {
               Label("New Collab", systemImage: "person.badge.plus")
                  .font(.appButton(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.brandYellowForeground(for: colorScheme))
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(AppColor.main, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Collab")
            .accessibilityHint("Creates a shared space for toDō users.")
         }

         if collaborationService.isLoading,
            !collaborationService.hasLoadedSnapshot,
            collaborationService.collabs.isEmpty,
            collaborationService.incomingInvitations.isEmpty {
            ProgressView("Loading Collabs")
               .frame(maxWidth: .infinity, alignment: .leading)
               .padding(16)
               .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
         } else {
            VStack(spacing: 0) {
               if collaborationService.collabs.isEmpty,
                  collaborationService.incomingInvitations.isEmpty,
                  collaborationService.outgoingInvitations.isEmpty {
                  Text("Create a Collab when you are ready to work with another user.")
                     .font(.appBody(14, relativeTo: .subheadline))
                     .foregroundStyle(AppColor.textSecondary)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding(16)
               }

               ForEach(Array(collaborationService.collabs.enumerated()), id: \.element.id) { index, collab in
                  if index > 0 {
                     Divider()
                  }

                  Button {
                     activeSheet = .collab(collab)
                  } label: {
                     HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                           .font(.appDisplay(15, relativeTo: .subheadline))
                           .foregroundStyle(AppColor.actionPrimary)
                           .frame(width: 24)

                        VStack(alignment: .leading, spacing: 3) {
                           Text(collab.name)
                              .font(.appBodyStrong(16, relativeTo: .body))
                              .foregroundStyle(AppColor.textPrimary)
                              .lineLimit(1)
                           Text(collabMembershipLabel(for: collab))
                              .font(.appBody(12, relativeTo: .caption))
                              .foregroundStyle(AppColor.textSecondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                           .font(.appDisplay(12, relativeTo: .caption))
                           .foregroundStyle(AppColor.textSecondary)
                     }
                     .padding(.horizontal, 14)
                     .padding(.vertical, 12)
                     .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel(String(format: String(localized: "%@ collab users"), collab.name))
               }

               ForEach(collaborationService.incomingInvitations) { invitation in
                  Divider()
                  incomingInvitationRow(invitation)
               }

               ForEach(collaborationService.outgoingInvitations.filter { $0.status == .pending }) { invitation in
                  Divider()
                  outgoingInvitationRow(invitation)
               }
            }
            .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
         }

         if let error = collaborationService.errorMessage, !error.isEmpty {
            Label(error, systemImage: "exclamationmark.triangle.fill")
               .font(.appBodyStrong(13, relativeTo: .footnote))
               .foregroundStyle(AppColor.actionDestructive)
         }
      }
   }

   private func incomingInvitationRow(_ invitation: ToDoCollabInvitation) -> some View {
      VStack(alignment: .leading, spacing: 10) {
         Label(
            String(format: String(localized: "Invitation to %@"), collabName(for: invitation.collabID)),
            systemImage: "person.badge.plus"
         )
         .font(.appBodyStrong(15, relativeTo: .subheadline))

         HStack(spacing: 10) {
            Button("Decline", role: .destructive) {
               performCollabAction(id: invitation.id) {
                  try await collaborationService.declineInvitation(id: invitation.id)
               }
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .cancel))

            Button("Join") {
               performCollabAction(id: invitation.id) {
                  try await collaborationService.acceptInvitation(id: invitation.id)
               }
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .proceed))
         }
         .disabled(collabActionID == invitation.id)
      }
      .padding(14)
   }

   private func outgoingInvitationRow(_ invitation: ToDoCollabInvitation) -> some View {
      HStack(spacing: 12) {
         VStack(alignment: .leading, spacing: 3) {
            Text("Invitation Pending")
               .font(.appBodyStrong(15, relativeTo: .subheadline))
            Text(invitation.inviteeEmail)
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
               .lineLimit(1)
         }

         Spacer(minLength: 8)

         Button("Cancel", role: .destructive) {
            performCollabAction(id: invitation.id) {
               try await collaborationService.cancelInvitation(id: invitation.id)
            }
         }
         .buttonStyle(AppSemanticTextButtonStyle(intent: .cancel))
         .disabled(collabActionID == invitation.id)
      }
      .padding(14)
   }

   private func collabName(for id: UUID) -> String {
      collaborationService.collabs.first(where: { $0.id == id })?.name
         ?? String(localized: "Collab")
   }

   private func collabMembershipLabel(for collab: ToDoCollab) -> String {
      guard collab.ownerUserID == authStore.currentUserID else {
         return String(localized: "User")
      }

      let acceptedCount = collaborationService.invitations.filter {
         $0.collabID == collab.id && $0.inviterUserID == authStore.currentUserID && $0.status == .accepted
      }.count
      if acceptedCount > 0 {
         return String(format: String(localized: "Owner · %lld joined"), acceptedCount)
      }
      return String(localized: "Owner")
   }

   private func createCollab() {
      let name = newCollabName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return }
      newCollabName = ""
      Task {
         do {
            let collab = try await collaborationService.createCollab(name: name)
            activeSheet = .collab(collab)
         } catch {
            collaborationService.errorMessage = error.localizedDescription
         }
      }
   }

   private func performCollabAction(
      id: UUID,
      action: @escaping @MainActor () async throws -> Void
   ) {
      collabActionID = id
      Task {
         do {
            try await action()
         } catch {
            collaborationService.errorMessage = error.localizedDescription
         }
         collabActionID = nil
      }
   }

   private var syncOverviewSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Where to Save")
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(AppColor.secondary)

         VStack(alignment: .leading, spacing: 14) {
            Button {
               activeSheet = .sync
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
            .disabled(!connectivityMonitor.isAvailable)

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

         SyncHealthStatusView(
            syncCoordinator: syncCoordinator,
            isAccountAuthenticated: authStore.isAuthenticated,
            isNetworkAvailable: connectivityMonitor.isAvailable,
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

struct MyProfileView: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.modelContext) private var modelContext
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
   @State private var isEditing = false
   @State private var displayName = ""
   @State private var username = ""
   @State private var selectedAvatarItem: PhotosPickerItem?
   @State private var pendingAvatarData: Data?
   @State private var displayedAvatarData: Data?
   @State private var editableAvatarData: Data?
   @State private var avatarOffset = CGSize.zero
   @State private var isAdjustingAvatar = false
   @State private var isChoosingAvatarSource = false
   @State private var isChoosingPhoto = false
   @State private var isChoosingAvatarScope = false
   @State private var isEnteringAvatarLink = false
   @State private var selectedAvatarScope: ToDoProfileImageScope?
   @State private var isConfirmingAvatar = false
   @State private var isChangingAvatarScope = false
   @State private var currentAvatarScope: ToDoProfileImageScope?
   @State private var hasStoredAvatarImage = false
   @State private var isShowingDeleteAccountConfirmation = false
   @State private var isDeletingAccount = false
   @State private var accountDeletionError: String?

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(alignment: .leading, spacing: 22) {
               profileIdentity
               profileDetails
               editSection
               deleteAccountSection
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(20)
         }
         .background(AppColor.surface)
         .navigationTitle("My Profile")
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
            ToolbarItem(placement: .topBarLeading) {
               Button {
                  dismiss()
               } label: {
                  Image(systemName: "xmark")
                     .font(.system(size: 15, weight: .black))
               }
               .buttonStyle(AppCircleActionButtonStyle(
                  intent: .cancel,
                  size: 34,
                  tint: AppColor.actionDestructive
               ))
               .accessibilityLabel("Close Profile")
            }

            ToolbarItem(placement: .topBarTrailing) {
               if !isEditing {
                  Button("Edit") {
                     displayName = ToDoProfilePolicy.resolvedDisplayName(
                        profile: authStore.profile,
                        email: authStore.signedInEmail
                     )
                     username = authStore.profile?.username ?? ""
                     isEditing = true
                  }
                  .accessibilityHint("Edits your display name.")
               }
            }
         }
      }
      .appBaseTypography()
      .tint(AppColor.actionPrimary)
      .confirmationDialog(
         "Delete Account",
         isPresented: $isShowingDeleteAccountConfirmation,
         titleVisibility: .visible
      ) {
         Button("Delete Account", role: .destructive) {
            deleteAccount()
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This permanently deletes your toDōs, profile, owned shared lists, collaboration access, and account-linked purchases. This cannot be undone.")
      }
      .alert("Account Deletion Failed", isPresented: Binding(
         get: { accountDeletionError != nil },
         set: { if !$0 { accountDeletionError = nil } }
      )) {
         Button("OK", role: .cancel) {}
      } message: {
         Text(accountDeletionError ?? "Try again when you have a reliable connection.")
      }
      .onAppear {
         displayName = ToDoProfilePolicy.resolvedDisplayName(
            profile: authStore.profile,
            email: authStore.signedInEmail
         )
         username = authStore.profile?.username ?? ""
      }
      .onChange(of: selectedAvatarItem) { _, item in
         guard let item else { return }
         Task {
            do {
               guard let data = try await item.loadTransferable(type: Data.self) else { return }
               let normalizedData = await Task.detached(priority: .userInitiated) {
                  ToDoProfileImageStore.normalizedJPEGData(from: data)
               }.value
               guard let normalizedData else {
                  authStore.reportProfileError(String(localized: "The profile image could not be read. Try another image."))
                  return
               }
               guard normalizedData.count <= 5 * 1024 * 1024 else {
                  authStore.reportProfileError(String(localized: "Choose an image smaller than 5 MB."))
                  return
               }
               pendingAvatarData = normalizedData
               displayedAvatarData = normalizedData
               avatarOffset = .zero
               presentAvatarScopeSelection()
            } catch {
               authStore.reportProfileError(String(localized: "The profile image could not be read. Try another image."))
            }
         }
      }
      .sheet(isPresented: $isChoosingAvatarSource) {
         ProfileImageSourceSheet(
            onPhotos: {
               isChoosingAvatarSource = false
               Task { @MainActor in
                  await Task.yield()
                  isChoosingPhoto = true
               }
            },
            onLink: {
               isChoosingAvatarSource = false
               Task { @MainActor in
                  await Task.yield()
                  isEnteringAvatarLink = true
               }
            }
         )
         .presentationDetents([.height(290)])
         .presentationDragIndicator(.visible)
      }
      .confirmationDialog(
         "Where should this image be used?",
         isPresented: $isChoosingAvatarScope,
         titleVisibility: .visible
      ) {
         Button("This Device Only") {
            prepareAvatarSave(scope: .thisDevice)
         }
         if canUseAppleDeviceImageScope {
            Button("Apple Devices (iCloud)") {
               prepareAvatarSave(scope: .appleDevices)
            }
         }
         if canUseAllDeviceImageScope {
            Button("All Devices") {
               prepareAvatarSave(scope: .allDevices)
            }
         }
         Button("Cancel", role: .cancel) {
            discardPendingAvatar()
         }
      } message: {
         Text(avatarScopeMessage)
      }
      .confirmationDialog(
         "Image Availability",
         isPresented: $isChangingAvatarScope,
         titleVisibility: .visible
      ) {
         Button("This Device Only") {
            changeAvatarScope(to: .thisDevice)
         }
         if canUseAppleDeviceImageScope {
            Button("Apple Devices (iCloud)") {
               changeAvatarScope(to: .appleDevices)
            }
         }
         if canUseAllDeviceImageScope {
            Button("All Devices") {
               changeAvatarScope(to: .allDevices)
            }
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("Choose where your current profile image should be available. You can change this later if your devices or sync setup changes.")
      }
      .sheet(isPresented: $isEnteringAvatarLink) {
         ProfileImageLinkSheet { data in
            pendingAvatarData = data
            displayedAvatarData = data
            avatarOffset = .zero
            presentAvatarScopeSelection()
         }
         .presentationDetents([.medium])
         .presentationDragIndicator(.visible)
      }
      .photosPicker(
         isPresented: $isChoosingPhoto,
         selection: $selectedAvatarItem,
         matching: .images
      )
      .sheet(isPresented: $isAdjustingAvatar) {
         if let data = displayedAvatarData ?? editableAvatarData {
            ProfileImagePositionEditor(data: data, initialOffset: avatarOffset, title: "Adjust Profile Image") { newOffset in
               avatarOffset = newOffset
               authStore.updateProfileImageOffset(newOffset)
               isAdjustingAvatar = false
            } onCancel: {
               isAdjustingAvatar = false
            }
         }
      }
      .sheet(isPresented: $isConfirmingAvatar) {
         if let data = pendingAvatarData, let scope = selectedAvatarScope {
            ProfileImagePositionEditor(
               data: data,
               initialOffset: avatarOffset,
               title: "Confirm Profile Image",
               subtitle: scopeConfirmationText(for: scope)
            ) { newOffset in
               avatarOffset = newOffset
               saveAvatar(scope: scope, offset: newOffset)
            } onCancel: {
               discardPendingAvatar()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
         }
      }
      .task(id: authStore.profileImageRevision) {
         guard let userID = authStore.currentUserID else {
            editableAvatarData = nil
            avatarOffset = .zero
            hasStoredAvatarImage = false
            return
         }

         let loaded = await Task.detached(priority: .utility) {
            (ToDoProfileImageStore.load(for: userID), ToDoProfileImageStore.loadOffset(for: userID))
         }.value
         editableAvatarData = loaded.0
         hasStoredAvatarImage = loaded.0 != nil
         if !hasStoredAvatarImage {
            hasStoredAvatarImage = await Task.detached(priority: .utility) {
               ToDoProfileImageStore.hasStoredImage(for: userID)
            }.value
         }
         currentAvatarScope = ToDoProfileImageStore.scope(
            for: userID,
            remoteAvatarURL: authStore.profile?.avatarURL
         )
         if displayedAvatarData == nil {
            avatarOffset = loaded.1
         }
      }
   }

   private var profileIdentity: some View {
      HStack(spacing: 14) {
         ZStack(alignment: .bottomTrailing) {
            ProfileAvatarView(
               profile: authStore.profile,
               email: authStore.signedInEmail,
               size: 54,
               localUserID: authStore.currentUserID,
               localImageDataOverride: displayedAvatarData,
               localImageRevision: authStore.profileImageRevision,
               localImageOffsetOverride: avatarOffset
            )

            Button {
               if (displayedAvatarData ?? editableAvatarData) != nil {
                  isAdjustingAvatar = true
               } else {
                  isChoosingAvatarSource = true
               }
            } label: {
               Image(systemName: (displayedAvatarData ?? editableAvatarData) == nil ? "plus" : "crop")
                  .font(.system(size: 11, weight: .black))
            }
            .buttonStyle(AppCircleActionButtonStyle(
               intent: .proceed,
               size: 24,
               tint: AppColor.main
            ))
            .accessibilityLabel((displayedAvatarData ?? editableAvatarData) == nil ? "Choose profile image" : "Adjust profile image")
            .accessibilityHint((displayedAvatarData ?? editableAvatarData) == nil
               ? "Choose an image and select whether it stays on this device or is available on your devices."
               : "Adjust the profile image crop.")
         }

         VStack(alignment: .leading, spacing: 4) {
            Text(ToDoProfilePolicy.resolvedDisplayName(
               profile: authStore.profile,
               email: authStore.signedInEmail
            ))
            .font(.appBodyStrong(21, relativeTo: .title3))
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

            if let username = ToDoProfilePolicy.displayUsername(authStore.profile?.username) {
               Text(username)
                  .font(.appBody(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Text(purchaseManager.hasPlus ? "toDō+" : "toDō")
               .font(.appBadge(13, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }

         Spacer(minLength: 0)

         if authStore.isLoadingProfile {
            ProgressView()
               .accessibilityLabel("Loading Profile")
         }
      }
      .accessibilityElement(children: .combine)
   }

   private var profileDetails: some View {
      VStack(spacing: 0) {
         if let email = authStore.signedInEmail {
            ProfileInfoRow(title: "Email", value: email, systemName: "envelope")
            Divider()
         }

         if let method = authStore.signInMethodLabel {
            ProfileInfoRow(title: "Sign-in Method", value: method, systemName: "person.crop.circle.badge.checkmark")
            Divider()
         }

         if let username = ToDoProfilePolicy.displayUsername(authStore.profile?.username) {
            ProfileInfoRow(title: "Username", value: username, systemName: "at")
            Divider()
         }

         ProfileInfoRow(
            title: "Membership",
            value: purchaseManager.membershipLabel,
            systemName: purchaseManager.hasPlus ? "plus.circle.fill" : "checkmark.circle"
         )

         if let currentAvatarScope {
            Divider()
            Button {
               isChangingAvatarScope = true
            } label: {
               ProfileInfoRow(
                  title: "Image Availability",
                  value: avatarScopeTitle(currentAvatarScope),
                  systemName: "photo.badge.checkmark"
               )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Changes where your current profile image is available.")
         } else if hasStoredAvatarImage {
            Divider()
            Button {
               isChangingAvatarScope = true
            } label: {
               ProfileInfoRow(
                  title: "Image Availability",
                  value: "Choose availability",
                  systemName: "photo.badge.checkmark"
               )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose where your current profile image is available.")
         }
      }
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 22))
   }

   private var deleteAccountSection: some View {
      VStack(alignment: .leading, spacing: 10) {
         Text("Account")
            .font(.appDisplay(20, relativeTo: .headline))
            .foregroundStyle(AppColor.secondary)

         Button {
            isShowingDeleteAccountConfirmation = true
         } label: {
            HStack(spacing: 12) {
               if isDeletingAccount {
                  ProgressView()
                     .tint(AppColor.actionDestructive)
               } else {
                  Image(systemName: "person.crop.circle.badge.xmark")
                     .font(.appDisplay(15, relativeTo: .subheadline))
               }

               Text("Delete Account")
                  .font(.appButton(17, relativeTo: .headline))

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
         .disabled(isDeletingAccount)
         .accessibilityHint("Permanently deletes your account and account data.")
      }
   }

   @ViewBuilder
   private var editSection: some View {
      if isEditing {
         VStack(alignment: .leading, spacing: 12) {
            Text("Display Name")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(AppColor.secondary)

            TextField("Display Name", text: $displayName)
               .font(.appUserEntry(17, relativeTo: .body))
               .textInputAutocapitalization(.words)
               .submitLabel(.done)
               .accessibilityLabel("Display Name")
               .padding(.horizontal, 14)
               .padding(.vertical, 12)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))

            Text("Username")
               .font(.appDisplay(20, relativeTo: .headline))
               .foregroundStyle(AppColor.secondary)

            TextField("Username", text: $username)
               .font(.appUserEntry(17, relativeTo: .body))
               .textInputAutocapitalization(.never)
               .autocorrectionDisabled()
               .submitLabel(.done)
               .accessibilityLabel("Username")
               .padding(.horizontal, 14)
               .padding(.vertical, 12)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 16))

            Text("Use 3–30 letters, numbers, periods, or underscores. Your username is how collaborators recognize you.")
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
               Button("Cancel") {
                  isEditing = false
               }
               .buttonStyle(AppSemanticTextButtonStyle(intent: .neutral))

               Button {
                  Task {
                     if await authStore.updateProfile(displayName: displayName, username: username) {
                        isEditing = false
                     }
                  }
               } label: {
                  if authStore.isSavingProfile {
                     ProgressView()
                        .frame(maxWidth: .infinity)
                  } else {
                     Text("Save Profile")
                        .frame(maxWidth: .infinity)
                  }
               }
               .buttonStyle(AppSemanticTextButtonStyle(intent: .proceed))
               .disabled(authStore.isSavingProfile)
               .accessibilityLabel("Save Profile")
            }

            if let error = authStore.profileErrorMessage {
               Label(error, systemImage: "exclamationmark.triangle.fill")
                  .font(.appBodyStrong(13, relativeTo: .footnote))
                  .foregroundStyle(AppColor.actionDestructive)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }
      } else if let message = authStore.profileStatusMessage {
         Label(message, systemImage: "checkmark.circle.fill")
            .font(.appBodyStrong(13, relativeTo: .footnote))
            .foregroundStyle(AppColor.actionSuccess)
            .accessibilityLabel(message)
      }
   }

   private var avatarScopeMessage: String {
      if canUseAppleDeviceImageScope {
         return String(localized: "Keep it on this device, or share it with your Apple devices through iCloud.")
      }
      return String(localized: "Keep it on this device, or share it across signed-in devices through toDō.")
   }

   private var canUseAppleDeviceImageScope: Bool {
      authStore.effectiveSyncMode == .iCloud && ToDoProfileImageStore.isICloudAvailable
   }

   private var canUseAllDeviceImageScope: Bool {
      authStore.isAuthenticated && !canUseAppleDeviceImageScope
   }

   private func saveAvatar(scope: ToDoProfileImageScope) {
      saveAvatar(scope: scope, offset: avatarOffset)
   }

   private func prepareAvatarSave(scope: ToDoProfileImageScope) {
      selectedAvatarScope = scope
      isChoosingAvatarScope = false
      // Let the native confirmation dialog finish dismissing before asking
      // SwiftUI to present the image editor sheet.
      Task { @MainActor in
         await Task.yield()
         guard selectedAvatarScope == scope else { return }
         isConfirmingAvatar = true
      }
   }

   private func presentAvatarScopeSelection() {
      Task { @MainActor in
         // The Photos picker or link sheet must finish dismissing before the
         // next presentation is requested, otherwise SwiftUI can drop it.
         await Task.yield()
         guard pendingAvatarData != nil else { return }
         isChoosingAvatarScope = true
      }
   }

   private func discardPendingAvatar() {
      pendingAvatarData = nil
      displayedAvatarData = nil
      selectedAvatarScope = nil
      isConfirmingAvatar = false
      selectedAvatarItem = nil
   }

   private func scopeConfirmationText(for scope: ToDoProfileImageScope) -> String {
      switch scope {
      case .thisDevice:
         return String(localized: "Save this image on this device only.")
      case .appleDevices:
         return String(localized: "Save this image for your Apple devices through iCloud.")
      case .allDevices:
         return String(localized: "Save this image across your signed-in toDō devices.")
      }
   }

   private func saveAvatar(scope: ToDoProfileImageScope, offset: CGSize) {
      guard let data = pendingAvatarData else { return }
      Task {
         let didSave = await authStore.updateProfileImage(data, scope: scope)
         guard didSave, let userID = authStore.currentUserID else {
            return
         }
         ToDoProfileImageStore.saveOffset(offset, for: userID)
         authStore.updateProfileImageOffset(offset)
         await authStore.refreshProfile()
         editableAvatarData = data
         displayedAvatarData = data
         currentAvatarScope = scope
         hasStoredAvatarImage = true
         pendingAvatarData = nil
         selectedAvatarItem = nil
         selectedAvatarScope = nil
         isConfirmingAvatar = false
      }
   }

   private func deleteAccount() {
      guard let account = authStore.commerceAccount else { return }
      isDeletingAccount = true

      Task { @MainActor in
         defer { isDeletingAccount = false }
         do {
            try await SupabaseAccountDeletionService.deleteAccount(
               accessToken: account.accessToken
            )
            try ToDoLocalAccountDeletionService.clearAll(
               userID: account.id,
               in: modelContext
            )
            await authStore.completeAccountDeletion()
            dismiss()
         } catch {
            accountDeletionError = error.localizedDescription
         }
      }
   }

   private func changeAvatarScope(to scope: ToDoProfileImageScope) {
      Task {
         if await authStore.updateProfileImageScope(scope) {
            currentAvatarScope = scope
            hasStoredAvatarImage = true
         }
      }
   }

   private func avatarScopeTitle(_ scope: ToDoProfileImageScope) -> String {
      switch scope {
      case .thisDevice:
         return String(localized: "This device")
      case .appleDevices:
         return canUseAppleDeviceImageScope
            ? String(localized: "Apple devices")
            : String(localized: "Apple devices (unavailable here)")
      case .allDevices:
         return String(localized: "All signed-in devices")
      }
   }
}

private struct ProfileImageSourceSheet: View {
   @Environment(\.colorScheme) private var colorScheme
   let onPhotos: () -> Void
   let onLink: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 18) {
         VStack(alignment: .leading, spacing: 5) {
            Text("Add a Profile Image")
               .font(.appDisplay(24, relativeTo: .title2))
               .foregroundStyle(AppColor.textPrimary)
            Text("Choose where the image comes from.")
               .font(.appBody(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
         }

         HStack(spacing: 12) {
            sourceButton(
               title: "Photos",
               systemName: "photo.on.rectangle",
               tint: AppColor.actionPrimary,
               action: onPhotos
            )
            sourceButton(
               title: "Image Link",
               systemName: "link",
               tint: AppColor.actionSecondary,
               action: onLink
            )
         }
      }
      .padding(22)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(AppColor.surface.ignoresSafeArea())
      .appBaseTypography()
   }

   private func sourceButton(
      title: LocalizedStringKey,
      systemName: String,
      tint: Color,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         VStack(spacing: 8) {
            Image(systemName: systemName)
               .font(.system(size: 20, weight: .bold))
            Text(title)
               .font(.appButton(14, relativeTo: .subheadline))
               .fontWeight(.semibold)
         }
         .foregroundStyle(AppColor.brandYellowForeground(for: colorScheme))
         .frame(maxWidth: .infinity)
         .padding(.vertical, 16)
         .background(tint, in: .rect(cornerRadius: 18))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(title)
   }
}

private struct ProfileImageLinkSheet: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.colorScheme) private var colorScheme
   @State private var link = ""
   @State private var isLoading = false
   @State private var errorMessage: String?
   let onImport: (Data) -> Void

   var body: some View {
      NavigationStack {
         VStack(alignment: .leading, spacing: 16) {
            Text("Use an Image Link")
               .font(.appDisplay(22, relativeTo: .title2))
               .foregroundStyle(AppColor.secondary)

            Text("Use a secure image link. toDō downloads a local copy before asking where to use it.")
               .font(.appBody(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
               .fixedSize(horizontal: false, vertical: true)

            TextField("https://…", text: $link)
               .textInputAutocapitalization(.never)
               .keyboardType(.URL)
               .autocorrectionDisabled()
               .font(.appUserEntry(16, relativeTo: .body))
               .padding(12)
               .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 14))

            if let errorMessage {
               Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                  .font(.appBodyStrong(13, relativeTo: .footnote))
                  .foregroundStyle(AppColor.actionDestructive)
                  .fixedSize(horizontal: false, vertical: true)
            }

            Button {
               importImage()
            } label: {
               if isLoading {
                  ProgressView()
                     .frame(width: 48, height: 48)
               } else {
                  Image(systemName: "checkmark")
                     .font(.system(size: 18, weight: .black))
                     .frame(width: 48, height: 48)
               }
            }
            .buttonStyle(AppCircleActionButtonStyle(
               intent: .proceed,
               size: 48,
               tint: AppColor.actionSuccess,
               foreground: AppColor.brandYellowForeground(for: colorScheme)
            ))
            .disabled(isLoading || URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
            .accessibilityLabel("Use Image Link")

            Spacer(minLength: 0)
         }
         .padding(20)
         .background(AppColor.surface)
         .toolbar {
            ToolbarItem(placement: .topBarLeading) {
               Button {
                  dismiss()
               } label: {
                  Image(systemName: "xmark")
                     .font(.system(size: 15, weight: .black))
               }
               .buttonStyle(AppCircleActionButtonStyle(
                  intent: .cancel,
                  size: 34,
                  tint: AppColor.actionDestructive
               ))
               .accessibilityLabel("Close")
            }
         }
      }
      .appBaseTypography()
   }

   private func importImage() {
      guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme?.lowercased() == "https",
            url.host != nil else {
         errorMessage = String(localized: "Enter a valid secure image link.")
         return
      }

      isLoading = true
      errorMessage = nil
      Task {
         do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
               throw ProfileImageLinkError.invalidResponse
            }
            guard data.count <= 5 * 1024 * 1024,
                  CGImageSourceCreateWithData(data as CFData, nil) != nil else {
               throw ProfileImageLinkError.invalidImage
            }
            onImport(data)
            dismiss()
         } catch {
            errorMessage = error.localizedDescription
            isLoading = false
         }
      }
   }
}

private enum ProfileImageLinkError: LocalizedError {
   case invalidResponse
   case invalidImage

   var errorDescription: String? {
      switch self {
      case .invalidResponse:
         String(localized: "That image link could not be loaded.")
      case .invalidImage:
         String(localized: "Use an image smaller than 5 MB.")
      }
   }
}

private struct ProfileInfoRow: View {
   let title: LocalizedStringKey
   let value: String
   let systemName: String

   var body: some View {
      HStack(spacing: 12) {
         Image(systemName: systemName)
            .font(.appDisplay(14, relativeTo: .subheadline))
            .foregroundStyle(AppColor.actionPrimary)
            .frame(width: 24)

         Text(title)
            .font(.appBodyStrong(14, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textSecondary)

         Spacer(minLength: 12)

         Text(value)
            .font(.appBodyStrong(14, relativeTo: .subheadline))
            .foregroundStyle(AppColor.textPrimary)
            .multilineTextAlignment(.trailing)
            .textSelection(.enabled)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 13)
      .accessibilityElement(children: .combine)
   }
}

private struct ProfileImagePositionEditor: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.colorScheme) private var colorScheme
   @EnvironmentObject private var authStore: SupabaseAuthStore
   let data: Data
   let onSave: (CGSize) -> Void
   let onCancel: () -> Void
   let title: String
   let subtitle: String
   @State private var offset: CGSize
   @State private var gestureStart: CGSize

   init(
      data: Data,
      initialOffset: CGSize,
      title: String = String(localized: "Adjust Profile Image"),
      subtitle: String = String(localized: "Drag the image to choose the center point."),
      onSave: @escaping (CGSize) -> Void,
      onCancel: @escaping () -> Void
   ) {
      self.data = data
      self.onSave = onSave
      self.onCancel = onCancel
      self.title = title
      self.subtitle = subtitle
      _offset = State(initialValue: initialOffset)
      _gestureStart = State(initialValue: initialOffset)
   }

   var body: some View {
      NavigationStack {
         VStack(spacing: 18) {
            if let image = ProfileRasterImage(data: data)?.image {
               image
                  .resizable()
                  .scaledToFill()
                  .frame(width: 230, height: 230)
                  .offset(offset)
                  .clipShape(Circle())
                  .overlay {
                     Circle().stroke(AppColor.secondary, lineWidth: 3)
                  }
                  .contentShape(Circle())
                  .gesture(
                     DragGesture()
                        .onChanged { value in
                           offset = clamped(
                              CGSize(
                                 width: gestureStart.width + value.translation.width,
                                 height: gestureStart.height + value.translation.height
                              )
                           )
                        }
                        .onEnded { _ in
                           gestureStart = offset
                        }
                  )
            }

            Text(subtitle)
               .font(.appBody(15, relativeTo: .body))
               .foregroundStyle(AppColor.textSecondary)
               .multilineTextAlignment(.center)
               .frame(maxWidth: 300)

            Button("Reset") {
               offset = .zero
               gestureStart = .zero
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .neutral))

            Button {
               onSave(offset)
            } label: {
               Group {
                  if authStore.isSavingProfile {
                     ProgressView()
                  } else {
                     Label("Confirm", systemImage: "checkmark")
                  }
               }
               .font(.appButton(16, relativeTo: .body))
               .frame(maxWidth: .infinity)
               .padding(.vertical, 14)
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .proceed))
            .disabled(authStore.isSavingProfile)
            .accessibilityLabel(authStore.isSavingProfile ? "Saving Profile Image" : "Confirm Profile Image")

            if let error = authStore.profileErrorMessage {
               Label(error, systemImage: "exclamationmark.triangle.fill")
                  .font(.appBodyStrong(13, relativeTo: .footnote))
                  .foregroundStyle(AppColor.actionDestructive)
                  .multilineTextAlignment(.center)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .padding(24)
         .background(AppColor.surface)
         .navigationTitle(title)
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
            ToolbarItem(placement: .cancellationAction) {
               Button {
                  onCancel()
                  dismiss()
               } label: {
                  Image(systemName: "xmark")
                     .font(.system(size: 15, weight: .black))
               }
               .buttonStyle(AppCircleActionButtonStyle(intent: .cancel, size: 36, tint: AppColor.actionDestructive, foreground: AppColor.brandYellowForeground(for: colorScheme)))
               .accessibilityLabel("Cancel")
            }
         }
      }
      .appBaseTypography()
   }

   private func clamped(_ proposed: CGSize) -> CGSize {
      let limit: CGFloat = 82
      return CGSize(
         width: min(max(proposed.width, -limit), limit),
         height: min(max(proposed.height, -limit), limit)
      )
   }
}

struct ProfileAvatarView: View {
   let displayName: String
   let avatarURL: URL?
   let size: CGFloat
   let localUserID: UUID?
   let localImageDataOverride: Data?
   let localImageRevision: Int
   let localImageOffsetOverride: CGSize?
   @State private var localImageData: Data?
   @State private var localImageOffset = CGSize.zero
   @State private var localImageRefreshID = 0
   @State private var isLoadingLocalImage = false

   init(
      profile: SupabaseProfileRecord?,
      email: String?,
      size: CGFloat,
      localUserID: UUID? = nil,
      localImageDataOverride: Data? = nil,
      localImageRevision: Int = 0,
      localImageOffsetOverride: CGSize? = nil
   ) {
      displayName = ToDoProfilePolicy.resolvedDisplayName(profile: profile, email: email)
      avatarURL = ToDoProfilePolicy.avatarURL(from: profile?.avatarURL)
      self.size = size
      self.localUserID = localUserID
      self.localImageDataOverride = localImageDataOverride
      self.localImageRevision = localImageRevision
      self.localImageOffsetOverride = localImageOffsetOverride
      _localImageData = State(initialValue: nil)
   }

   init(
      displayName: String?,
      avatarURL: String?,
      size: CGFloat,
      localUserID: UUID? = nil,
      localImageRevision: Int = 0,
      localImageOffsetOverride: CGSize? = nil
   ) {
      let normalizedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.displayName = normalizedName.flatMap { $0.isEmpty ? nil : $0 }
         ?? String(localized: "toDō User")
      self.avatarURL = ToDoProfilePolicy.avatarURL(from: avatarURL)
      self.size = size
      self.localUserID = localUserID
      self.localImageDataOverride = nil
      self.localImageRevision = localImageRevision
      self.localImageOffsetOverride = localImageOffsetOverride
      _localImageData = State(initialValue: nil)
   }

   var body: some View {
      Group {
         if localImageDataOverride != nil {
            localImageOrInitials
         } else if prefersRemoteAvatar, let avatarURL {
            remoteAvatar(avatarURL)
         } else if localImageData != nil || isLoadingLocalImage {
            localImageOrInitials
         } else if let avatarURL {
            remoteAvatar(avatarURL)
         } else {
            localImageOrInitials
         }
      }
      .frame(width: size, height: size)
      .clipShape(Circle())
      .accessibilityLabel(String(format: String(localized: "%@ profile image"), displayName))
      .task(id: "\(localUserID?.uuidString ?? "none")-\(avatarURL?.absoluteString ?? "none")-\(localImageRevision)-\(localImageRefreshID)") {
         guard let localUserID else {
            localImageData = nil
            localImageOffset = .zero
            return
         }

         localImageData = nil
         isLoadingLocalImage = true
         defer { isLoadingLocalImage = false }
         let loaded = await Task.detached(priority: .utility) {
            (ToDoProfileImageStore.load(for: localUserID), ToDoProfileImageStore.loadOffset(for: localUserID))
         }.value
         localImageData = loaded.0
         localImageOffset = loaded.1
      }
      .onReceive(NotificationCenter.default.publisher(for: ToDoProfileImageStore.didChangeNotification)) { notification in
         guard let localUserID,
               let changedUserID = notification.object as? UUID,
               changedUserID == localUserID else { return }
         localImageRefreshID &+= 1
      }
   }

   private var prefersRemoteAvatar: Bool {
      guard let localUserID, let avatarURL else { return false }
      return ToDoProfileImageStore.scope(
         for: localUserID,
         remoteAvatarURL: avatarURL.absoluteString
      ) == .allDevices
   }

   @ViewBuilder
   private func remoteAvatar(_ url: URL) -> some View {
      AsyncImage(url: url) { phase in
         if case .success(let image) = phase {
            image
               .resizable()
               .scaledToFill()
               .frame(width: size, height: size)
               .offset(displayImageOffset)
         } else {
            localImageOrInitials
         }
      }
   }

   private var initials: some View {
      ZStack {
         Circle()
            .fill(AppColor.actionPrimary.opacity(0.16))
         Text(ToDoProfilePolicy.initials(from: displayName))
            .font(.appBodyStrong(size * 0.34, relativeTo: .headline))
            .foregroundStyle(AppColor.actionPrimary)
            .minimumScaleFactor(0.7)
      }
   }

   @ViewBuilder
   private var localImageOrInitials: some View {
      if let imageData = localImageDataOverride ?? localImageData,
         let localImage = ProfileRasterImage(data: imageData) {
         localImage.image
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .offset(displayImageOffset)
      } else {
         initials
      }
   }

   private var displayImageOffset: CGSize {
      let sourceOffset = localImageOffsetOverride ?? localImageOffset
      return ToDoProfileImageStore.displayOffset(sourceOffset, for: size)
   }
}

private struct ProfileRasterImage {
   let image: Image

   init?(data: Data) {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
         return nil
      }
      image = Image(decorative: cgImage, scale: 1)
   }
}

struct CollabInvitationReviewView: View {
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var collaborationService: ToDoCollaborationService
   let invitationID: UUID
   let onFinished: () -> Void
   @State private var details: ToDoCollabInvitationDetails?
   @State private var isLoading = true
   @State private var isWorking = false
   @State private var errorMessage: String?

   var body: some View {
      NavigationStack {
         Group {
            if !authStore.isAuthenticated {
               ContentUnavailableView {
                  Label("Sign In to Review", systemImage: "person.crop.circle.badge.plus")
               } description: {
                  Text("Sign in to the account that received this invitation to review it.")
               }
            } else if isLoading {
               ProgressView("Loading Invitation")
            } else if let details {
               invitationContent(details)
            } else {
               ContentUnavailableView {
                  Label("Invitation Unavailable", systemImage: "link.badge.plus")
               } description: {
                  Text(errorMessage ?? "This invitation may have expired, been canceled, or belong to another account.")
               }
            }
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .background(AppColor.surface)
         .navigationTitle("Collab Invitation")
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
            ToolbarItem(placement: .topBarLeading) {
               Button {
                  onFinished()
                  dismiss()
               } label: {
                  Image(systemName: "xmark")
                     .font(.system(size: 15, weight: .black))
               }
               .buttonStyle(AppCircleActionButtonStyle(
                  intent: .cancel,
                  size: 34,
                  tint: AppColor.actionDestructive
               ))
               .accessibilityLabel("Close Invitation")
            }
         }
      }
      .appBaseTypography()
      .task(id: "\(invitationID.uuidString)-\(authStore.currentUserID?.uuidString ?? "signed-out")") {
         guard authStore.isAuthenticated else {
            isLoading = false
            return
         }
         isLoading = true
         do {
            details = try await collaborationService.loadInvitationDetails(id: invitationID)
            errorMessage = nil
         } catch {
            details = nil
            errorMessage = error.localizedDescription
         }
         isLoading = false
      }
   }

   @ViewBuilder
   private func invitationContent(_ details: ToDoCollabInvitationDetails) -> some View {
      VStack(alignment: .leading, spacing: 20) {
         Label(details.collabName, systemImage: "person.2.fill")
            .font(.appDisplay(25, relativeTo: .title2))
            .foregroundStyle(AppColor.textPrimary)

         VStack(alignment: .leading, spacing: 8) {
            Text("You have been invited to collaborate with this user.")
               .font(.appBodyStrong(16, relativeTo: .body))
            if let inviter = inviterLabel(details) {
               Text("From \(inviter)")
                  .font(.appBody(14, relativeTo: .subheadline))
                  .foregroundStyle(AppColor.textSecondary)
            }
            Text("You can review or decline this invitation before joining the shared list.")
               .font(.appBody(14, relativeTo: .subheadline))
               .foregroundStyle(AppColor.textSecondary)
         }

         if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
               .font(.appBodyStrong(13, relativeTo: .footnote))
               .foregroundStyle(AppColor.actionDestructive)
               .fixedSize(horizontal: false, vertical: true)
         }

         Spacer(minLength: 0)

         HStack(spacing: 12) {
            Button("Decline", role: .destructive) {
               respond(accept: false)
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .cancel))

            Button("Accept") {
               respond(accept: true)
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .proceed))
         }
         .disabled(isWorking)
      }
      .padding(24)
   }

   private func inviterLabel(_ details: ToDoCollabInvitationDetails) -> String? {
      if let username = ToDoProfilePolicy.displayUsername(details.inviterUsername) {
         return username
      }
      return details.inviterDisplayName
   }

   private func respond(accept: Bool) {
      isWorking = true
      errorMessage = nil
      Task {
         do {
            if accept {
               try await collaborationService.acceptInvitation(id: invitationID)
            } else {
               try await collaborationService.declineInvitation(id: invitationID)
            }
            onFinished()
            dismiss()
         } catch {
            errorMessage = error.localizedDescription
            isWorking = false
         }
      }
   }
}

private struct CollabUsersView: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.openURL) private var openURL
   @Environment(\.colorScheme) private var colorScheme
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
   @EnvironmentObject private var collaborationService: ToDoCollaborationService
   let collab: ToDoCollab
   @State private var selectedProfile: ToDoCollabUserProfile?
   @State private var isInvitingUser = false
   @State private var inviteEmail = ""
   @State private var isSendingInvite = false
   @State private var inviteError: String?
   @State private var inviteNotice: String?
   @State private var lastInvitedEmail: String?
   @State private var lastInvitation: ToDoCollabInvitation?
   @State private var isConfirmingCollabDeletion = false
   @State private var isDeletingCollab = false

   var body: some View {
      NavigationStack {
         Group {
            if collaborationService.loadingProfileCollabIDs.contains(collab.id), profiles.isEmpty {
               ProgressView("Loading People")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = collaborationService.profileErrorsByCollabID[collab.id], profiles.isEmpty {
               ContentUnavailableView {
                  Label("People Unavailable", systemImage: "person.2.slash")
               } description: {
                  Text(error)
               } actions: {
                  Button("Try Again") {
                     Task { await collaborationService.loadCollabUsers(collabID: collab.id, force: true) }
                  }
               }
            } else {
               ScrollView {
                  LazyVStack(spacing: 10) {
                     if let inviteError {
                        Label(inviteError, systemImage: "exclamationmark.triangle.fill")
                           .font(.appBodyStrong(13, relativeTo: .footnote))
                           .foregroundStyle(AppColor.actionDestructive)
                           .frame(maxWidth: .infinity, alignment: .leading)
                           .padding(14)
                           .background(AppColor.actionDestructive.opacity(0.08), in: .rect(cornerRadius: 18))
                     }

                     if let inviteNotice {
                        HStack(spacing: 12) {
                           Label(inviteNotice, systemImage: "paperplane.fill")
                              .font(.appBodyStrong(13, relativeTo: .footnote))
                              .foregroundStyle(AppColor.actionSuccess)
                              .frame(maxWidth: .infinity, alignment: .leading)

                           if let email = lastInvitedEmail {
                              if let mailURL = inviteMailURL(for: email) {
                                 Button {
                                    openURL(mailURL)
                                 } label: {
                                    Image(systemName: "envelope.fill")
                                 }
                                 .buttonStyle(AppCircleActionButtonStyle(
                                    intent: .proceed,
                                    size: 34,
                                    tint: AppColor.actionSuccess,
                                    foreground: AppColor.brandYellowForeground(for: colorScheme)
                                 ))
                                 .accessibilityLabel("Email Invite")
                              }

                              ShareLink(item: inviteShareMessage(for: email)) {
                                 Image(systemName: "square.and.arrow.up")
                              }
                              .buttonStyle(AppCircleActionButtonStyle(
                                 intent: .neutral,
                                 size: 34,
                                 tint: AppColor.actionPrimary,
                                 foreground: AppColor.brandYellowForeground(for: colorScheme)
                              ))
                              .accessibilityLabel("Share Invite")
                           }
                        }
                        .padding(14)
                        .background(AppColor.actionSuccess.opacity(0.08), in: .rect(cornerRadius: 18))
                     }

                     ForEach(profiles) { profile in
                        Button {
                           selectedProfile = profile
                        } label: {
                           collabUserRow(profile)
                        }
                        .buttonStyle(.plain)
                     }
                  }
                  .frame(maxWidth: 620)
                  .frame(maxWidth: .infinity)
                  .padding(20)
               }
            }
         }
         .background(AppColor.surface)
         .overlay {
            if isDeletingCollab {
               ZStack {
                  AppColor.surface.opacity(0.72)
                  ProgressView("Deleting Collab")
                     .font(.appBodyStrong(14, relativeTo: .subheadline))
                     .padding(.horizontal, 22)
                     .padding(.vertical, 16)
                     .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 18))
                     .shadow(radius: 12, y: 4)
               }
               .transition(.opacity)
               .accessibilityElement(children: .combine)
               .accessibilityLabel("Deleting Collab")
            }
         }
         .navigationTitle(collab.name)
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
            ToolbarItem(placement: .topBarLeading) {
               Button {
                  dismiss()
               } label: {
                  Image(systemName: "xmark")
                     .font(.system(size: 15, weight: .black))
               }
               .buttonStyle(AppCircleActionButtonStyle(
                  intent: .cancel,
                  size: 34,
                  tint: AppColor.actionDestructive
               ))
               .accessibilityLabel("Close Collab")
            }
            if collab.ownerUserID == authStore.currentUserID {
               ToolbarItem(placement: .topBarTrailing) {
                  Menu {
                     Button {
                        isInvitingUser = true
                     } label: {
                        Label("Invite User", systemImage: "person.badge.plus")
                     }

                     Button(role: .destructive) {
                        isConfirmingCollabDeletion = true
                     } label: {
                        Label("Delete Collab", systemImage: "trash")
                     }
                  } label: {
                     Image(systemName: "ellipsis.circle")
                  }
                  .accessibilityLabel("Collab actions")
                  .disabled(isSendingInvite || isDeletingCollab)
               }
            }
         }
         .sheet(item: $selectedProfile) { profile in
            CollabUserProfileView(
               profile: profile,
               canRemove: collab.ownerUserID == authStore.currentUserID
                  && profile.role == .user
                  && profile.userID != authStore.currentUserID
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
         }
      }
      .appBaseTypography()
      .tint(AppColor.actionPrimary)
      .alert("Invite User", isPresented: $isInvitingUser) {
         TextField("Email", text: $inviteEmail)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
         Button("Cancel", role: .cancel) {
            inviteEmail = ""
         }
         Button("Send") {
            sendInvite()
         }
         .disabled(inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      } message: {
         Text(inviteError ?? "Invite another toDō user to this Collab. If the address is not registered yet, the invitation will remain pending.")
      }
      .alert("Delete Collab?", isPresented: $isConfirmingCollabDeletion) {
         Button("Cancel", role: .cancel) {}
         Button("Delete", role: .destructive) {
            deleteCollab()
         }
      } message: {
         Text("This removes the shared list and its access for everyone. This cannot be undone.")
      }
      .task(id: collab.id.uuidString + "-" + (authStore.currentUserID?.uuidString ?? "signed-out")) {
         await collaborationService.loadCollabUsers(collabID: collab.id, force: true)
      }
      .onReceive(NotificationCenter.default.publisher(for: .toDoCollaborationInvitationReceived)) { _ in
         Task {
            await collaborationService.loadCollabUsers(collabID: collab.id, force: true)
         }
      }
      .onReceive(NotificationCenter.default.publisher(for: .toDoCollaborationMembershipDidChange)) { _ in
         Task {
            await collaborationService.loadCollabUsers(collabID: collab.id, force: true)
         }
      }
   }

   private var profiles: [ToDoCollabUserProfile] {
      collaborationService.profiles(for: collab.id)
   }

   private func sendInvite() {
      guard let email = ToDoCollaborationPolicy.normalizedInviteEmail(inviteEmail) else {
         inviteError = ToDoCollaborationError.invalidInviteEmail.localizedDescription
         return
      }
      inviteEmail = ""
      isSendingInvite = true
      inviteError = nil
      inviteNotice = nil
      lastInvitedEmail = nil
      lastInvitation = nil
      Task {
         do {
            let invitation = try await collaborationService.sendInvitation(
               collabID: collab.id,
               email: email,
               capabilities: purchaseManager.capabilities
            )
            inviteNotice = String(localized: "Invitation sent. If the address is not registered yet, it will remain pending until they join toDō.")
            lastInvitedEmail = email
            lastInvitation = invitation
         } catch {
            inviteError = error.localizedDescription
         }
         isSendingInvite = false
      }
   }

   private func inviteMailURL(for email: String) -> URL? {
      let inviteLink = lastInvitation
         .flatMap { ToDoCollaborationInviteLink.url(for: $0.id) }
         .map(\.absoluteString)
      let body: String
      if let inviteLink {
         body = String(
            format: String(localized: "Join me in %@ on toDō. Open this link to review the invitation:\n%@"),
            collab.name,
            inviteLink
         )
      } else {
         body = String(
            format: String(localized: "Join me in %@ on toDō. Open the app to accept the invitation."),
            collab.name
         )
      }
      var components = URLComponents()
      components.scheme = "mailto"
      components.path = email
      components.queryItems = [
         URLQueryItem(name: "subject", value: String(localized: "toDō Collab Invite")),
         URLQueryItem(name: "body", value: body)
      ]
      return components.url
   }

   private func inviteShareMessage(for email: String) -> String {
      let inviteLink = lastInvitation
         .flatMap { ToDoCollaborationInviteLink.url(for: $0.id) }
         .map(\.absoluteString)
      let instructions = if let inviteLink {
         String(format: String(localized: "Join me in %@ on toDō. Open this link to review the invitation:\n%@"), collab.name, inviteLink)
      } else {
         String(format: String(localized: "Join me in %@ on toDō. Open the app to accept the invitation."), collab.name)
      }
      return String(format: String(localized: "toDō collab invitation for %@\n\n%@\n\nInvitee: %@"), email, instructions, email)
   }

   private func deleteCollab() {
      isDeletingCollab = true
      inviteError = nil
      Task {
         do {
            try await collaborationService.deleteCollab(id: collab.id)
            dismiss()
         } catch {
            inviteError = error.localizedDescription
            isDeletingCollab = false
         }
      }
   }

   private func collabUserRow(_ profile: ToDoCollabUserProfile) -> some View {
      HStack(spacing: 12) {
         ProfileAvatarView(
            displayName: profile.displayName,
            avatarURL: profile.avatarURL,
            size: 44,
            localUserID: profile.userID == authStore.currentUserID ? profile.userID : nil,
            localImageRevision: profile.userID == authStore.currentUserID
               ? authStore.profileImageRevision
               : 0
         )

         VStack(alignment: .leading, spacing: 4) {
            Text(resolvedName(profile))
               .font(.appBodyStrong(17, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)
            if let username = ToDoProfilePolicy.displayUsername(profile.username) {
               Text(username)
                  .font(.appBody(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
            }
            Label(roleTitle(profile.role), systemImage: roleIcon(profile.role))
               .font(.appBodyStrong(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }

         Spacer(minLength: 8)

         Image(systemName: "chevron.right")
            .font(.appDisplay(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .padding(14)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 20))
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(resolvedName(profile)), \(roleTitle(profile.role))")
   }
}

struct CollabUserProfileView: View {
   @Environment(\.dismiss) private var dismiss
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var collaborationService: ToDoCollaborationService
   let profile: ToDoCollabUserProfile
   let canRemove: Bool
   @State private var isConfirmingRemoval = false
   @State private var isRemoving = false
   @State private var removalError: String?

   var body: some View {
      VStack(alignment: .leading, spacing: 20) {
         HStack(spacing: 14) {
            ProfileAvatarView(
               displayName: profile.displayName,
               avatarURL: profile.avatarURL,
               size: 52,
               localUserID: profile.userID == authStore.currentUserID ? profile.userID : nil,
               localImageRevision: profile.userID == authStore.currentUserID
                  ? authStore.profileImageRevision
                  : 0
            )

            VStack(alignment: .leading, spacing: 5) {
               Text(resolvedName(profile))
                  .font(.appBodyStrong(21, relativeTo: .title3))
                  .foregroundStyle(AppColor.textPrimary)
               if let username = ToDoProfilePolicy.displayUsername(profile.username) {
                  Text(username)
                     .font(.appBody(14, relativeTo: .footnote))
                     .foregroundStyle(AppColor.textSecondary)
               }
               Label(roleTitle(profile.role), systemImage: roleIcon(profile.role))
                  .font(.appBodyStrong(13, relativeTo: .footnote))
                  .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 0)

            Button {
               dismiss()
            } label: {
               Image(systemName: "xmark")
                  .font(.system(size: 15, weight: .black))
            }
            .buttonStyle(AppCircleActionButtonStyle(
               intent: .cancel,
               size: 34,
               tint: AppColor.actionDestructive
            ))
            .accessibilityLabel("Close User Profile")
         }

         Label(
            String(format: String(localized: "Shared in %@"), profile.collabName),
            systemImage: "person.2.fill"
         )
         .font(.appBodyStrong(15, relativeTo: .subheadline))
         .foregroundStyle(AppColor.textPrimary)

         if canRemove {
            Button {
               isConfirmingRemoval = true
            } label: {
               if isRemoving {
                  ProgressView()
                     .frame(maxWidth: .infinity)
               } else {
                  Label("Remove User", systemImage: "person.badge.minus")
                     .frame(maxWidth: .infinity)
               }
            }
            .buttonStyle(AppSemanticTextButtonStyle(intent: .cancel))
            .disabled(isRemoving)
         }

         if let removalError {
            Label(removalError, systemImage: "exclamationmark.triangle.fill")
               .font(.appBodyStrong(13, relativeTo: .footnote))
               .foregroundStyle(AppColor.actionDestructive)
         }
      }
      .padding(20)
      .background(AppColor.surface)
      .appBaseTypography()
      .tint(AppColor.actionPrimary)
      .alert("Remove User?", isPresented: $isConfirmingRemoval) {
         Button("Cancel", role: .cancel) {}
         Button("Remove", role: .destructive) {
            removeUser()
         }
      } message: {
         Text("They will lose access to this collab.")
      }
   }

   private func removeUser() {
      isRemoving = true
      removalError = nil
      Task {
         do {
            try await collaborationService.removeUser(
               collabID: profile.collabID,
               userID: profile.userID
            )
            dismiss()
         } catch {
            removalError = error.localizedDescription
            isRemoving = false
         }
      }
   }
}

private func resolvedName(_ profile: ToDoCollabUserProfile) -> String {
   let name = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
   if let name, !name.isEmpty {
      return name
   }
   return String(localized: "toDō User")
}

private func roleTitle(_ role: ToDoCollaborationRole) -> String {
   switch role {
   case .owner: String(localized: "Owner")
   case .user: String(localized: "User")
   }
}

private func roleIcon(_ role: ToDoCollaborationRole) -> String {
   switch role {
   case .owner: "crown.fill"
   case .user: "person.fill"
   }
}

struct SyncSettingsView: View {
   @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
   @EnvironmentObject private var authStore: SupabaseAuthStore
   @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
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

         if syncCoordinator.preferredSyncMode == .syncEverywhere && !authStore.hasResolvedAccount {
            AuthenticationView()
         }

         if !(syncCoordinator.preferredSyncMode == .syncEverywhere && !authStore.hasResolvedAccount),
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
            isNetworkAvailable: connectivityMonitor.isAvailable,
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
         Image(systemName: "arrow.triangle.2.circlepath")
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
