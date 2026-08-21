import CoreGraphics
import Foundation
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct ToDoMacProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @State private var isEditing = false
    @State private var displayName = ""
    @State private var username = ""
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?
    @State private var isChoosingAvatarSource = false
    @State private var isChoosingPhoto = false
    @State private var isChoosingAvatarScope = false
    @State private var isEnteringAvatarLink = false
    @State private var selectedAvatarScope: ToDoProfileImageScope?
    @State private var isConfirmingAvatar = false
    @State private var avatarOffset = CGSize.zero
    @State private var isChangingAvatarScope = false
    @State private var currentAvatarScope: ToDoProfileImageScope?
    @State private var hasStoredAvatarImage = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var accountDeletionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                profileDetails
                editControls
                deleteAccountSection
                operationStatus
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(28)
        }
        .background(ToDoMacPalette.background)
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
            if let userID = authStore.currentUserID {
                hasStoredAvatarImage = ToDoProfileImageStore.hasStoredImage(for: userID)
                currentAvatarScope = ToDoProfileImageStore.scope(
                    for: userID,
                    remoteAvatarURL: authStore.profile?.avatarURL
                )
            }
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
                    avatarOffset = .zero
                    presentAvatarScopeSelection()
                } catch {
                    authStore.reportProfileError(String(localized: "The profile image could not be read. Try another image."))
                }
            }
        }
        .sheet(isPresented: $isChoosingAvatarSource) {
            ToDoMacProfileImageSourceSheet(
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
            .frame(minWidth: 460, idealWidth: 500, minHeight: 300, idealHeight: 320)
        }
        .confirmationDialog(
            "Where should this image be used?",
            isPresented: $isChoosingAvatarScope,
            titleVisibility: .visible
        ) {
            Button("This Device Only") { prepareAvatarSave(scope: .thisDevice) }
            if canUseAppleDeviceImageScope {
                Button("Apple Devices (iCloud)") { prepareAvatarSave(scope: .appleDevices) }
            }
            if canUseAllDeviceImageScope {
                Button("All Devices") { prepareAvatarSave(scope: .allDevices) }
            }
            Button("Cancel", role: .cancel) { discardPendingAvatar() }
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
            ToDoMacProfileImageLinkSheet { data in
                pendingAvatarData = data
                presentAvatarScopeSelection()
            }
            .frame(minWidth: 460, idealWidth: 500, minHeight: 300, idealHeight: 320)
        }
        .photosPicker(
            isPresented: $isChoosingPhoto,
            selection: $selectedAvatarItem,
            matching: .images
        )
        .sheet(isPresented: $isConfirmingAvatar) {
            if let data = pendingAvatarData, let scope = selectedAvatarScope {
                ToDoMacProfileImageConfirmationView(
                    data: data,
                    initialOffset: avatarOffset,
                    scopeText: scopeConfirmationText(for: scope),
                    onCancel: discardPendingAvatar
                ) { offset in
                    avatarOffset = offset
                    saveAvatar(scope: scope, offset: offset)
                }
                .frame(minWidth: 500, idealWidth: 560, minHeight: 660, idealHeight: 760)
            }
        }
    }

    private var profileDisplayName: String {
        ToDoProfilePolicy.resolvedDisplayName(
            profile: authStore.profile,
            email: authStore.signedInEmail
        )
    }

    private var header: some View {
        return HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                ToDoMacProfileAvatar(
                    displayName: profileDisplayName,
                    avatarURL: authStore.profile?.avatarURL,
                    size: 52,
                    localUserID: authStore.currentUserID,
                    localImageRevision: authStore.profileImageRevision
                )

                Button {
                    if hasStoredAvatarImage {
                        isChangingAvatarScope = true
                    } else {
                        isChoosingAvatarSource = true
                    }
                } label: {
                    Image(systemName: hasStoredAvatarImage ? "photo" : "plus")
                        .font(.todoMacSymbol(10, weight: .bold))
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.brandBlue,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .frame(width: 22, height: 22)
                .accessibilityLabel(hasStoredAvatarImage ? "Change profile image availability" : "Choose profile image")
                .accessibilityHint(hasStoredAvatarImage
                    ? "Changes where the current profile image is available."
                    : "Choose an image and select whether it stays on this Mac or is available on your devices.")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profileDisplayName)
                    .font(.todoMacUI(21, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.ink)

                if let username = ToDoProfilePolicy.displayUsername(authStore.profile?.username) {
                    Text(username)
                        .font(.todoMacUI(13, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }

                Text(purchaseManager.hasPlus ? String(localized: "toDō+") : String(localized: "toDō"))
                    .font(.todoMacUI(13, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            Spacer(minLength: 0)

            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.todoMacSymbol(14, weight: .black))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ToDoMacIconButtonStyle(
                color: ToDoMacPalette.urgent,
                foreground: ToDoMacPalette.actionForeground(for: colorScheme)
            ))
            .accessibilityLabel("Close Profile")
        }
    }

    private var profileDetails: some View {
        VStack(spacing: 0) {
            if let email = authStore.signedInEmail {
                ToDoMacProfileInfoRow(title: "Email", value: email, systemName: "envelope")
                Divider()
            }
            if let provider = authStore.providerLabel {
                ToDoMacProfileInfoRow(
                    title: "Sign-in Method",
                    value: provider,
                    systemName: "person.crop.circle.badge.checkmark"
                )
                Divider()
            }
            if let username = ToDoProfilePolicy.displayUsername(authStore.profile?.username) {
                ToDoMacProfileInfoRow(title: "Username", value: username, systemName: "at")
                Divider()
            }
            ToDoMacProfileInfoRow(
                title: "Membership",
                value: purchaseManager.membershipLabel,
                systemName: purchaseManager.hasPlus ? "plus.circle.fill" : "checkmark.circle"
            )

            if let currentAvatarScope {
                Divider()
                Button {
                    isChangingAvatarScope = true
                } label: {
                    ToDoMacProfileInfoRow(
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
                    ToDoMacProfileInfoRow(
                        title: "Image Availability",
                        value: "Choose availability",
                        systemName: "photo.badge.checkmark"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose where your current profile image is available.")
            }
        }
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var editControls: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 10) {
                Text("Display Name")
                    .font(.todoMacDisplay(20))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.ink)

                TextField("Display Name", text: $displayName)
                    .font(.todoMacEntry(16, weight: .medium))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Display Name")

                Text("Username")
                    .font(.todoMacDisplay(20))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.ink)

                TextField("Username", text: $username)
                    .font(.todoMacEntry(16, weight: .medium))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Username")

                HStack(spacing: 10) {
                    Button("Cancel") { isEditing = false }
                        .buttonStyle(ToDoMacPrimaryButtonStyle(
                            color: ToDoMacPalette.raised,
                            foreground: ToDoMacPalette.ink
                        ))

                    Button(action: saveProfile) {
                        Group {
                            if authStore.isSavingProfile {
                                ProgressView()
                            } else {
                                Text("Save Profile")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(
                        color: ToDoMacPalette.done,
                        foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                    ))
                    .disabled(authStore.isSavingProfile)
                }
            }
        } else {
            Button(action: beginEditing) {
                    Label("Edit Display Name", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(
                color: ToDoMacPalette.brandBlue,
                foreground: ToDoMacPalette.actionForeground(for: colorScheme)
            ))
        }
    }

    @ViewBuilder
    private var operationStatus: some View {
        if let message = authStore.profileStatusMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.todoMacUI(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.done)
        }
        if let error = authStore.profileErrorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.todoMacUI(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.urgent)
        }
    }

    private var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.todoMacDisplay(20))
                .tracking(0.7)
                .foregroundStyle(ToDoMacPalette.ink)

            Button {
                isShowingDeleteAccountConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    if isDeletingAccount {
                        ProgressView()
                            .controlSize(.small)
                            .tint(ToDoMacPalette.urgent)
                    } else {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.todoMacSymbol(16, weight: .bold))
                    }

                    Text("Delete Account")
                        .font(.todoMacUI(15, weight: .bold))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(ToDoMacPalette.urgent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(
                color: ToDoMacPalette.urgent.opacity(0.12),
                foreground: ToDoMacPalette.urgent
            ))
            .disabled(isDeletingAccount)
            .accessibilityHint("Permanently deletes your account and account data.")
        }
    }

    private func beginEditing() {
        displayName = profileDisplayName
        username = authStore.profile?.username ?? ""
        isEditing = true
    }

    private func saveProfile() {
        Task {
            if await authStore.updateProfile(displayName: displayName, username: username) {
                isEditing = false
            }
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

    private var avatarScopeMessage: String {
        if canUseAppleDeviceImageScope {
            return String(localized: "Keep it on this Mac, or share it with your Apple devices through iCloud.")
        }
        return String(localized: "Keep it on this Mac, or share it across signed-in devices through toDō.")
    }

    private var canUseAppleDeviceImageScope: Bool {
        SyncCoordinator.shared.effectiveSyncMode == .iCloud && ToDoProfileImageStore.isICloudAvailable
    }

    private var canUseAllDeviceImageScope: Bool {
        authStore.isAuthenticated && !canUseAppleDeviceImageScope
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
        selectedAvatarScope = nil
        selectedAvatarItem = nil
        isConfirmingAvatar = false
        avatarOffset = .zero
    }

    private func scopeConfirmationText(for scope: ToDoProfileImageScope) -> String {
        switch scope {
        case .thisDevice:
            return String(localized: "Save this image on this Mac only.")
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
            guard didSave, let userID = authStore.currentUserID else { return }
            ToDoProfileImageStore.saveOffset(offset, for: userID)
            authStore.updateProfileImageOffset(offset)
            await authStore.refreshProfile()
            currentAvatarScope = scope
            hasStoredAvatarImage = true
            pendingAvatarData = nil
            selectedAvatarScope = nil
            selectedAvatarItem = nil
            isConfirmingAvatar = false
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

@MainActor
private struct ToDoMacProfileImageSourceSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let onPhotos: () -> Void
    let onLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Add a Profile Image")
                    .font(.todoMacViewTitle(24))
                    .foregroundStyle(ToDoMacPalette.ink)
                Text("Choose where the image comes from.")
                    .font(.todoMacBody(14))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            HStack(spacing: 12) {
                sourceButton(
                    title: "Photos",
                    systemName: "photo.on.rectangle",
                    tint: ToDoMacPalette.brandBlue,
                    action: onPhotos
                )
                sourceButton(
                    title: "Image Link",
                    systemName: "link",
                    tint: ToDoMacPalette.brandYellow,
                    action: onLink
                )
            }
        }
        .padding(22)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ToDoMacPalette.background.ignoresSafeArea())
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
                    .font(.todoMacSymbol(20, weight: .bold))
                Text(title)
                    .font(.todoMacUI(14, weight: .heavy))
            }
            .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

@MainActor
private struct ToDoMacProfileImageConfirmationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    let data: Data
    let scopeText: String
    let onCancel: () -> Void
    let onSave: (CGSize) -> Void
    @State private var offset: CGSize
    @State private var gestureStart: CGSize

    init(
        data: Data,
        initialOffset: CGSize,
        scopeText: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (CGSize) -> Void
    ) {
        self.data = data
        self.scopeText = scopeText
        self.onCancel = onCancel
        self.onSave = onSave
        _offset = State(initialValue: initialOffset)
        _gestureStart = State(initialValue: initialOffset)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 18) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.todoMacSymbol(14, weight: .black))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ToDoMacIconButtonStyle(
                        color: ToDoMacPalette.urgent,
                        foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                    ))
                    .accessibilityLabel("Cancel")

                    Spacer(minLength: 0)
                }

                Text("Confirm Profile Image")
                    .font(.todoMacViewTitle(28))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .center)

                if let image = ToDoMacProfileRasterImage(data: data)?.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 250, height: 250)
                        .offset(offset)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ToDoMacPalette.brandYellow, lineWidth: 3))
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
                                .onEnded { _ in gestureStart = offset }
                        )
                }

                Text("Drag the image to choose the center point.")
                    .font(.todoMacBody(15))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .multilineTextAlignment(.center)

                Text(scopeText)
                    .font(.todoMacBody(13))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                Button {
                    offset = .zero
                    gestureStart = .zero
                } label: {
                    Label("Reset Position", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(
                    color: ToDoMacPalette.raised,
                    foreground: ToDoMacPalette.ink
                ))

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
                    .font(.todoMacUI(16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(
                    color: ToDoMacPalette.done,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .disabled(authStore.isSavingProfile)
                .accessibilityLabel(authStore.isSavingProfile ? "Saving Profile Image" : "Confirm Profile Image")

                if let error = authStore.profileErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.todoMacUI(13, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.urgent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(28)
        }
        .background(ToDoMacPalette.background)
    }

    private func clamped(_ proposed: CGSize) -> CGSize {
        let limit: CGFloat = 88
        return CGSize(
            width: min(max(proposed.width, -limit), limit),
            height: min(max(proposed.height, -limit), limit)
        )
    }
}

@MainActor
private struct ToDoMacProfileInfoRow: View {
    let title: LocalizedStringKey
    let value: String
    let systemName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.todoMacSymbol(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.brandBlue)
                .frame(width: 22)
            Text(title)
                .font(.todoMacUI(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.mutedInk)
            Spacer(minLength: 12)
            Text(value)
                .font(.todoMacUI(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct ToDoMacProfileAvatar: View {
    let displayName: String
    let avatarURL: String?
    let size: CGFloat
    let localUserID: UUID?
    let localImageRevision: Int
    @State private var localImageData: Data?
    @State private var localImageRefreshID = 0
    @State private var localImageOffset = CGSize.zero
    @State private var isLoadingLocalImage = false

    init(
        displayName: String,
        avatarURL: String?,
        size: CGFloat,
        localUserID: UUID? = nil,
        localImageRevision: Int = 0
    ) {
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.size = size
        self.localUserID = localUserID
        self.localImageRevision = localImageRevision
    }

    var body: some View {
        Group {
            if prefersRemoteAvatar, let url = ToDoProfilePolicy.avatarURL(from: avatarURL) {
                remoteAvatar(url)
            } else if localImageData != nil || isLoadingLocalImage {
                localImageOrInitials
            } else if let url = ToDoProfilePolicy.avatarURL(from: avatarURL) {
                remoteAvatar(url)
            } else {
                localImageOrInitials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(String(format: String(localized: "%@ profile image"), displayName))
        .task(id: "\(localUserID?.uuidString ?? "none")-\(localImageRevision)-\(localImageRefreshID)") {
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
            remoteAvatarURL: avatarURL
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

    private var initialsText: String {
        ToDoProfilePolicy.initials(from: displayName)
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(Color("appBrandSecondary").opacity(0.18))
            Text(initialsText)
                .font(.todoMacUI(size * 0.34, weight: .heavy, relativeTo: .body))
                .foregroundStyle(Color("appBrandSecondary"))
        }
    }

    private var displayImageOffset: CGSize {
        ToDoProfileImageStore.displayOffset(localImageOffset, for: size)
    }

    @ViewBuilder
    private var localImageOrInitials: some View {
        if let localImageData, let image = ToDoMacProfileRasterImage(data: localImageData) {
            image.image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .offset(displayImageOffset)
        } else {
            initialsView
        }
    }
}

private struct ToDoMacProfileRasterImage {
    let image: Image

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        image = Image(decorative: cgImage, scale: 1)
    }
}

@MainActor
private struct ToDoMacProfileImageLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var link = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    let onImport: (Data) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use an Image Link")
                .font(.todoMacDisplay(22))
                .foregroundStyle(ToDoMacPalette.ink)

            Text("Use a secure image link. toDō downloads a local copy before asking where to use it.")
                .font(.todoMacUI(14, weight: .medium))
                .foregroundStyle(ToDoMacPalette.mutedInk)

            TextField("https://…", text: $link)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.urgent)
            }

            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(14, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Cancel")

                Spacer()

                Button {
                    importImage()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.todoMacSymbol(16, weight: .black))
                            .frame(width: 48, height: 48)
                    }
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.done,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Use Image Link")
                .disabled(isLoading || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }

    private func importImage() {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https" else {
            errorMessage = String(localized: "Use a secure https image link.")
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
                guard let imageData = await Task.detached(priority: .userInitiated, operation: {
                    ToDoProfileImageStore.normalizedJPEGData(from: data)
                }).value,
                imageData.count <= 5 * 1024 * 1024 else {
                    throw ProfileImageLinkError.invalidImage
                }
                onImport(imageData)
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

@MainActor
private struct ToDoMacRemoteProfileAvatar: View {
    let url: URL
    let initials: String

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Circle().fill(Color("appBrandSecondary").opacity(0.18))
                Text(initials)
                    .font(.todoMacUI(17, weight: .heavy, relativeTo: .body))
                    .foregroundStyle(Color("appBrandSecondary"))
            }
        }
    }
}

@MainActor
struct ToDoMacCollabsCard: View {
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    @State private var selectedCollab: ToDoCollab?
    @State private var isCreatingCollab = false
    @State private var newCollabName = ""
    @State private var actionID: UUID?
    let onSelectCollab: ((ToDoCollab) -> Void)?

    init(onSelectCollab: ((ToDoCollab) -> Void)? = nil) {
        self.onSelectCollab = onSelectCollab
    }

    var body: some View {
        if authStore.currentUserID != nil, collaborationService.isBackendAvailable {
            VStack(alignment: .leading, spacing: 10) {
                Text("Collabs")
                    .font(.todoMacDisplay(20))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.ink)

                VStack(spacing: 0) {
                    Button {
                        isCreatingCollab = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.todoMacSymbol(14, weight: .black))
                                .foregroundStyle(ToDoMacPalette.ink)
                                .frame(width: 28, height: 28)
                                .background(ToDoMacPalette.brandYellow, in: Circle())

                            Text("New Collab")
                                .font(.todoMacUI(14, weight: .bold))
                                .foregroundStyle(ToDoMacPalette.ink)

                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Collab")
                    .accessibilityHint("Creates a shared space for toDō users.")

                    ForEach(Array(collaborationService.collabs.enumerated()), id: \.element.id) { index, collab in
                        if index > 0 || !collaborationService.collabs.isEmpty {
                            Divider()
                        }

                        Button {
                            if let onSelectCollab {
                                onSelectCollab(collab)
                            } else {
                                selectedCollab = collab
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.2.fill")
                                    .font(.todoMacSymbol(13, weight: .bold))
                                    .foregroundStyle(ToDoMacPalette.brandBlue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(collab.name)
                                        .font(.todoMacUI(14, weight: .bold))
                                        .foregroundStyle(ToDoMacPalette.ink)
                                        .lineLimit(1)
                                    Text(collabMembershipLabel(for: collab))
                                        .font(.todoMacUI(11, weight: .medium))
                                        .foregroundStyle(ToDoMacPalette.mutedInk)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.todoMacSymbol(11, weight: .bold))
                                    .foregroundStyle(ToDoMacPalette.mutedInk)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: String(localized: "%@ collab users"), collab.name))
                    }
                }
                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if collaborationService.collabs.isEmpty,
                   collaborationService.incomingInvitations.isEmpty,
                   !collaborationService.isLoading {
                    Text("Create a Collab to organize shared work with other users.")
                        .font(.todoMacUI(13, weight: .medium))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                        .padding(.vertical, 4)
                }

                ForEach(collaborationService.incomingInvitations) { invitation in
                    incomingInvitationRow(invitation)
                }

                ForEach(collaborationService.outgoingInvitations.filter { $0.status == .pending }) { invitation in
                    outgoingInvitationRow(invitation)
                }

                if let errorMessage = collaborationService.errorMessage {
                    Text(errorMessage)
                        .font(.todoMacUI(12, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.urgent)
                }
            }
            .task(id: authStore.currentUserID) {
                guard authStore.currentUserID != nil else { return }
                await collaborationService.refresh()
            }
            .sheet(item: $selectedCollab) { collab in
                ToDoMacCollabUsersSheet(collab: collab)
            }
            .alert("New Collab", isPresented: $isCreatingCollab) {
                TextField("Collab Name", text: $newCollabName)
                Button("Cancel", role: .cancel) { newCollabName = "" }
                Button("Create", action: createCollab)
                    .disabled(newCollabName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Name the shared space you want to use with other users.")
            }
        }
    }

    private func incomingInvitationRow(_ invitation: ToDoCollabInvitation) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Collab Invitation")
                    .font(.todoMacUI(14, weight: .heavy))
                Text(collabName(for: invitation.collabID))
                    .font(.todoMacUI(12, weight: .medium))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }
            Spacer()
            Button("Decline") {
                perform(id: invitation.id) {
                    try await collaborationService.declineInvitation(id: invitation.id)
                }
            }
            .buttonStyle(.borderless)
            Button("Join") {
                perform(id: invitation.id) {
                    try await collaborationService.acceptInvitation(id: invitation.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(ToDoMacPalette.brandBlue)
        }
        .disabled(actionID == invitation.id)
        .padding(12)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func outgoingInvitationRow(_ invitation: ToDoCollabInvitation) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Invitation Pending")
                    .font(.todoMacUI(14, weight: .heavy))
                Text(invitation.inviteeEmail)
                    .font(.todoMacUI(12, weight: .medium))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }
            Spacer()
            Button("Cancel", role: .destructive) {
                perform(id: invitation.id) {
                    try await collaborationService.cancelInvitation(id: invitation.id)
                }
            }
            .buttonStyle(.borderless)
        }
        .disabled(actionID == invitation.id)
        .padding(12)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func collabName(for id: UUID) -> String {
        collaborationService.collabs.first(where: { $0.id == id })?.name
            ?? String(localized: "Collab")
    }

    private func collabMembershipLabel(for collab: ToDoCollab) -> String {
        guard collab.ownerUserID == authStore.currentUserID else {
            return String(localized: "User")
        }

        let acceptedCount = collaborationService.invitations.count { invitation in
            invitation.collabID == collab.id
                && invitation.inviterUserID == authStore.currentUserID
                && invitation.status == .accepted
        }
        guard acceptedCount > 0 else { return String(localized: "Owner") }
        return String(format: String(localized: "Owner · %lld joined"), acceptedCount)
    }

    private func createCollab() {
        let name = newCollabName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        newCollabName = ""
        Task {
            do {
                selectedCollab = try await collaborationService.createCollab(name: name)
            } catch {
                collaborationService.errorMessage = error.localizedDescription
            }
        }
    }

    private func perform(
        id: UUID,
        action: @escaping @MainActor () async throws -> Void
    ) {
        actionID = id
        Task {
            defer { actionID = nil }
            do {
                try await action()
            } catch {
                collaborationService.errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
struct ToDoMacCollabUsersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    let collab: ToDoCollab
    let onClose: (() -> Void)?
    @State private var selectedProfile: ToDoCollabUserProfile?
    @State private var selectedProfileForSheet: ToDoCollabUserProfile?
    @State private var isInvitingUser = false
    @State private var inviteEmail = ""
    @State private var isSendingInvite = false
    @State private var inviteError: String?
    @State private var inviteNotice: String?
    @State private var lastInvitedEmail: String?
    @State private var lastInvitation: ToDoCollabInvitation?

    init(collab: ToDoCollab, onClose: (() -> Void)? = nil) {
        self.collab = collab
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: 16) {
                header
                peopleContent
            }

            if onClose != nil, let selectedProfile {
                ToDoMacCollabUserProfileSheet(
                    profile: selectedProfile,
                    canRemove: canRemove(selectedProfile),
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                            self.selectedProfile = nil
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(ToDoMacPalette.background)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .padding(20)
        .frame(width: onClose == nil ? 480 : nil, height: onClose == nil ? 420 : nil)
        .background(ToDoMacPalette.background)
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
        .sheet(item: $selectedProfileForSheet) { profile in
            ToDoMacCollabUserProfileSheet(
                profile: profile,
                canRemove: canRemove(profile)
            )
        }
        .alert("Invite User", isPresented: $isInvitingUser) {
            TextField("Email", text: $inviteEmail)
            Button("Cancel", role: .cancel) {
                inviteEmail = ""
                inviteError = nil
            }
            Button("Send", action: sendInvite)
                .disabled(inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(inviteError ?? "Invite another toDō user to this Collab. The invitation will remain pending if they have not joined yet.")
        }
    }

    private var profiles: [ToDoCollabUserProfile] {
        collaborationService.profiles(for: collab.id)
    }

    private var header: some View {
        HStack(spacing: 14) {
            if onClose == nil {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close Collab")
            }

            Text(collab.name)
                .font(.todoMacDisplay(26))
                .tracking(0.8)
                .foregroundStyle(ToDoMacPalette.ink)
            Spacer()
            if collab.ownerUserID == authStore.currentUserID {
                Button {
                    isInvitingUser = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.todoMacSymbol(15, weight: .black))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.brandBlue,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Invite User")
                .disabled(isSendingInvite)
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var peopleContent: some View {
        if collaborationService.loadingProfileCollabIDs.contains(collab.id), profiles.isEmpty {
            ProgressView("Loading People")
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if let error = collaborationService.profileErrorsByCollabID[collab.id], profiles.isEmpty {
            VStack(spacing: 12) {
                Label("People Unavailable", systemImage: "person.2.slash")
                Text(error)
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                Button("Try Again", action: reloadProfiles)
            }
            .font(.todoMacUI(14, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            ScrollView {
                LazyVStack(spacing: 9) {
                    if let inviteNotice {
                        HStack(spacing: 10) {
                            Label(inviteNotice, systemImage: "paperplane.fill")
                                .font(.todoMacUI(12, weight: .bold))
                                .foregroundStyle(ToDoMacPalette.done)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let email = lastInvitedEmail {
                                if let mailURL = inviteMailURL(for: email) {
                                    Button {
                                        openURL(mailURL)
                                    } label: {
                                        Image(systemName: "envelope.fill")
                                            .frame(width: 34, height: 34)
                                    }
                                    .buttonStyle(ToDoMacIconButtonStyle(
                                        color: ToDoMacPalette.done,
                                        foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                                    ))
                                    .accessibilityLabel("Email Invite")
                                }

                                ShareLink(item: inviteShareMessage(for: email)) {
                                    Image(systemName: "square.and.arrow.up")
                                        .frame(width: 34, height: 34)
                                }
                                .buttonStyle(ToDoMacIconButtonStyle(
                                    color: ToDoMacPalette.brandBlue,
                                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                                ))
                                .accessibilityLabel("Share Invite")
                            }
                        }
                        .padding(10)
                        .background(ToDoMacPalette.done.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    ForEach(profiles) { profile in
                        ToDoMacCollabUserRow(
                            profile: profile,
                            localUserID: profile.userID == authStore.currentUserID ? profile.userID : nil,
                            localImageRevision: profile.userID == authStore.currentUserID
                                ? authStore.profileImageRevision
                                : 0
                        ) {
                            if onClose == nil {
                                selectedProfileForSheet = profile
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                    selectedProfile = profile
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func reloadProfiles() {
        Task {
            await collaborationService.loadCollabUsers(collabID: collab.id, force: true)
        }
    }

    private func canRemove(_ profile: ToDoCollabUserProfile) -> Bool {
        collab.ownerUserID == authStore.currentUserID
            && profile.role == .user
            && profile.userID != authStore.currentUserID
    }

    private func sendInvite() {
        let email = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { return }
        inviteEmail = ""
        inviteError = nil
        inviteNotice = nil
        lastInvitedEmail = nil
        lastInvitation = nil
        isSendingInvite = true
        Task {
            defer { isSendingInvite = false }
            do {
                let invitation = try await collaborationService.sendInvitation(
                    collabID: collab.id,
                    email: email,
                    capabilities: purchaseManager.capabilities
                )
                inviteNotice = String(localized: "Invitation sent. Choose Email or Share to send it from this Mac.")
                lastInvitedEmail = email
                lastInvitation = invitation
            } catch {
                inviteError = error.localizedDescription
                isInvitingUser = true
            }
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
            URLQueryItem(name: "subject", value: String(localized: "toDō Collab Invite!")),
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
        return String(format: String(localized: "toDō Collab Invitation for %@\n\n%@\n\nInvitee: %@"), email, instructions, email)
    }
}

@MainActor
private struct ToDoMacCollabUserRow: View {
    let profile: ToDoCollabUserProfile
    let localUserID: UUID?
    let localImageRevision: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ToDoMacProfileAvatar(
                    displayName: resolvedMacProfileName(profile),
                    avatarURL: profile.avatarURL,
                    size: 40,
                    localUserID: localUserID,
                    localImageRevision: localImageRevision
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(resolvedMacProfileName(profile))
                        .font(.todoMacUI(15, weight: .heavy))
                    if let username = ToDoProfilePolicy.displayUsername(profile.username) {
                        Text(username)
                            .font(.todoMacUI(12, weight: .bold))
                            .foregroundStyle(ToDoMacPalette.mutedInk)
                    }
                    Label(macRoleTitle(profile.role), systemImage: macRoleIcon(profile.role))
                        .font(.todoMacUI(11, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(ToDoMacPalette.ink)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityLabel(String(
            format: String(localized: "%@, %@"),
            resolvedMacProfileName(profile),
            macRoleTitle(profile.role)
        ))
    }
}

@MainActor
struct ToDoMacCollabUserProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    let profile: ToDoCollabUserProfile
    let canRemove: Bool
    let onClose: (() -> Void)?
    @State private var isConfirmingRemoval = false
    @State private var isRemoving = false
    @State private var removalError: String?

    init(
        profile: ToDoCollabUserProfile,
        canRemove: Bool,
        onClose: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.canRemove = canRemove
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Label(sharedCollabText, systemImage: "person.2.fill")
                .font(.todoMacUI(14, weight: .bold))

            if canRemove {
                Button {
                    isConfirmingRemoval = true
                } label: {
                    if isRemoving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Remove User", systemImage: "person.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .disabled(isRemoving)
            }

            if let removalError {
                Text(removalError)
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.urgent)
            }
        }
        .padding(20)
        .frame(width: onClose == nil ? 420 : nil)
        .background(ToDoMacPalette.background)
        .alert("Remove User?", isPresented: $isConfirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: removeUser)
        } message: {
            Text("They will lose access to this collab.")
        }
    }

    private var sharedCollabText: String {
        String(format: String(localized: "Shared in %@"), profile.collabName)
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.todoMacSymbol(13, weight: .black))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ToDoMacIconButtonStyle(
                color: ToDoMacPalette.urgent,
                foreground: ToDoMacPalette.actionForeground(for: colorScheme)
            ))
            .accessibilityLabel("Close User Profile")

            ToDoMacProfileAvatar(
                displayName: resolvedMacProfileName(profile),
                avatarURL: profile.avatarURL,
                size: 50,
                localUserID: profile.userID == authStore.currentUserID ? profile.userID : nil,
                localImageRevision: profile.userID == authStore.currentUserID
                    ? authStore.profileImageRevision
                    : 0
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedMacProfileName(profile))
                    .font(.todoMacUI(20, weight: .heavy))
                if let username = ToDoProfilePolicy.displayUsername(profile.username) {
                    Text(username)
                        .font(.todoMacUI(13, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }
                Label(macRoleTitle(profile.role), systemImage: macRoleIcon(profile.role))
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }
            Spacer()
        }
    }

    private func removeUser() {
        isRemoving = true
        removalError = nil
        Task {
            do {
                try await collaborationService.removeUser(collabID: profile.collabID, userID: profile.userID)
                dismiss()
            } catch {
                removalError = error.localizedDescription
                isRemoving = false
            }
        }
    }
}

@MainActor
struct ToDoMacCollabInvitationReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    let invitationID: UUID
    let onFinished: () -> Void
    @State private var details: ToDoCollabInvitationDetails?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    finish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close Invitation")

                Text("Collab Invitation")
                    .font(.todoMacDisplay(25))
                    .foregroundStyle(ToDoMacPalette.ink)
                Spacer()
            }

            Group {
                if !authStore.isAuthenticated {
                    invitationState(
                        title: "Sign In to Review",
                        message: "Sign in to the account that received this invitation to review it.",
                        symbol: "person.crop.circle.badge.plus"
                    )
                } else if isLoading {
                    ProgressView("Loading Invitation")
                        .frame(maxWidth: .infinity, minHeight: 190)
                } else if let details {
                    invitationContent(details)
                } else {
                    invitationState(
                        title: "Invitation Unavailable",
                        message: errorMessage ?? "This invitation may have expired, been canceled, or belong to another account.",
                        symbol: "link.badge.plus"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .frame(minWidth: 500, idealWidth: 500, maxWidth: 500, minHeight: 360)
        .background(ToDoMacPalette.background)
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

    private func invitationState(title: String, message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.todoMacUI(18, weight: .heavy))
            Text(message)
                .font(.todoMacUI(14, weight: .bold))
                .foregroundStyle(ToDoMacPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func invitationContent(_ details: ToDoCollabInvitationDetails) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(details.collabName, systemImage: "person.2.fill")
                .font(.todoMacDisplay(24))
                .foregroundStyle(ToDoMacPalette.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("You have been invited to collaborate with this user.")
                    .font(.todoMacUI(16, weight: .heavy))
                if let inviter = inviterLabel(details) {
                    Text("From \(inviter)")
                        .font(.todoMacUI(14, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }
                Text("Review the shared list before you decide whether to join it.")
                    .font(.todoMacUI(14, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.todoMacUI(13, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.urgent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                Button("Decline", role: .destructive) {
                    respond(accept: false)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))

                Button("Accept") {
                    respond(accept: true)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(
                    color: ToDoMacPalette.done,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
            }
            .disabled(isWorking)
        }
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
                finish()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func finish() {
        onFinished()
        dismiss()
    }
}

private func resolvedMacProfileName(_ profile: ToDoCollabUserProfile) -> String {
    let name = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "toDō User")
}

private func macRoleTitle(_ role: ToDoCollaborationRole) -> String {
    switch role {
    case .owner: String(localized: "Owner")
    case .user: String(localized: "User")
    }
}

private func macRoleIcon(_ role: ToDoCollaborationRole) -> String {
    switch role {
    case .owner: "crown.fill"
    case .user: "person.fill"
    }
}
