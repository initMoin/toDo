import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import OSLog
import Supabase
import SwiftUI

#if os(macOS)
import AppKit
#endif

private let macAuthLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "dev.iamshift.toDo",
    category: "MacAuth"
)

private struct MacUsernameRPCParameters: Encodable, Sendable {
    let requestedUsername: String

    enum CodingKeys: String, CodingKey {
        case requestedUsername = "requested_username"
    }
}

private struct MacUsernameClaimResponse: Decodable, Sendable {
    let accountID: UUID
    let username: String
    let accountSetupVersion: Int

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case username
        case accountSetupVersion = "account_setup_version"
    }
}

@MainActor
final class ToDoMacAuthStore: ObservableObject {
    static let shared = ToDoMacAuthStore()

    enum ProviderInProgress: Equatable {
        case apple
        case google
        case callback
    }

    @Published private(set) var isStarted = false
    @Published private(set) var providerInProgress: ProviderInProgress?
    @Published private(set) var session: Session?
    @Published private(set) var currentUser: User?
    @Published private(set) var profile: SupabaseProfileRecord?
    @Published private(set) var profileImageRevision = 0
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isSavingProfile = false
    @Published private(set) var profileStatusMessage: String?
    @Published private(set) var profileErrorMessage: String?
    @Published private(set) var accountResolution: ToDoAccountResolutionState = .signedOut
    @Published private(set) var linkedProviders: Set<String> = []
    @Published private(set) var isSigningOut = false
    @Published var lastErrorMessage: String?

    private lazy var supabase = SupabaseService.shared
    private var authStateTask: Task<Void, Never>?
    private var startupSyncTask: Task<Void, Never>?
    private var isDeferringStartupSync = false
    private var appleAuthorizationCoordinator: MacAppleAuthorizationCoordinator?
    private var oauthWebAuthenticationSession: ASWebAuthenticationSession?
    private var oauthPresentationContextProvider: MacWebAuthenticationPresentationContextProvider?
    private var lastAppliedSyncKey: String?
    private var pendingAuthenticationIntent: ToDoAccountAuthenticationIntent = .restoreSession
    private var pendingExpectedUsername: String?
    private static let resolvedUsernameKey = "toDo.resolvedUsername"

    private init() {}

    var isAuthenticated: Bool {
        activeSession != nil
    }

    var isAuthenticating: Bool {
        providerInProgress != nil || isSigningOut
    }

    var hasResolvedAccount: Bool {
        if case .resolved = accountResolution { return true }
        return false
    }

    var resolvedAccountID: UUID? {
        guard case .resolved(let accountID, _) = accountResolution else { return nil }
        return accountID
    }

    /// Mac account consumers receive only the resolved canonical UUID. The
    /// raw provider UUID remains private to the resolver below.
    var currentUserID: UUID? {
        resolvedAccountID
    }

    var scopedOwnerUserID: UUID? {
        ToDoDataScope(resolvedAccountID: resolvedAccountID).ownerUserID
    }

    private var authenticatedUserID: UUID? {
        activeSession?.user.id
    }

    func isProviderLinked(_ provider: String) -> Bool {
        linkedProviders.contains(provider.lowercased())
    }

    var commerceAccount: ToDoCommerceAccount? {
        guard hasResolvedAccount, let activeSession else { return nil }
        return ToDoCommerceAccount(
            id: activeSession.user.id,
            accessToken: activeSession.accessToken
        )
    }

    var signedInEmail: String? {
        activeSession?.user.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var accountDisplayName: String {
        ToDoProfilePolicy.resolvedDisplayName(profile: profile, email: signedInEmail)
    }

    var providerLabel: String? {
        guard let user = activeSession?.user else { return nil }
        var candidates = user.identities?
            .sorted { ($0.lastSignInAt ?? .distantPast) > ($1.lastSignInAt ?? .distantPast) }
            .compactMap(\.provider) ?? []
        if let provider = user.appMetadata["provider"]?.stringValue {
            candidates.append(provider)
        }
        candidates.append(contentsOf: user.appMetadata["providers"]?.arrayValue?.compactMap(\.stringValue) ?? [])
        return candidates.compactMap(normalizedProviderLabel).first
    }

    func start() async {
        guard !isStarted else { return }
        isStarted = true
        isDeferringStartupSync = true

        guard SupabaseConfig.isConfigured else {
            let message = SupabaseConfig.configurationIssue ?? String(localized: "toDō Sync is not configured for this build.")
            lastErrorMessage = message
            macAuthLog.error("\(message, privacy: .public)")
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            scheduleStartupSync(userID: nil)
            return
        }

        applyActiveSession(supabase.auth.currentSession)
        if let user = activeSession?.user {
            pendingAuthenticationIntent = .restoreSession
            pendingExpectedUsername = Self.storedResolvedUsername()
            await resolveAuthenticatedAccount(
                for: user,
                intent: .restoreSession,
                expectedUsername: pendingExpectedUsername
            )
        } else {
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
        }
        await supabase.auth.startAutoRefresh()
        startAuthStateListener()
        scheduleStartupSync(userID: resolvedAccountID)
    }

    func beginAuthentication(intent: ToDoAccountAuthenticationIntent, expectedUsername: String?) {
        pendingAuthenticationIntent = intent
        pendingExpectedUsername = normalizedExpectedUsername(expectedUsername)
        accountResolution = .authenticating(
            intent: intent,
            expectedUsername: pendingExpectedUsername
        )
        SyncCoordinator.shared.setAccountResolution(false)
    }

    func completeAccountSetup(username: String) async -> Bool {
        guard let user = activeSession?.user else { return false }
        guard await claimAccountUsername(username) else { return false }
        pendingAuthenticationIntent = .restoreSession
        pendingExpectedUsername = normalizedExpectedUsername(username)
        return await resolveAuthenticatedAccount(
            for: user,
            intent: .restoreSession,
            expectedUsername: pendingExpectedUsername
        )
    }

    func continueWithAuthenticatedAccount() async -> Bool {
        guard let user = activeSession?.user,
              let username = profile?.username else { return false }
        pendingAuthenticationIntent = .restoreSession
        pendingExpectedUsername = username
        return await resolveAuthenticatedAccount(
            for: user,
            intent: .restoreSession,
            expectedUsername: username
        )
    }

    func signInWithApple(
        intent: ToDoAccountAuthenticationIntent = .signIn,
        expectedUsername: String? = nil
    ) async {
        guard SupabaseConfig.isConfigured else {
            let message = SupabaseConfig.configurationIssue ?? String(localized: "toDō Sync is not configured for this build.")
            lastErrorMessage = message
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "toDō Sync Unavailable"),
                message: String(localized: "Account sync is not configured for this build."),
                style: .failure
            )
            return
        }

        providerInProgress = .apple
        beginAuthentication(intent: intent, expectedUsername: expectedUsername)
        lastErrorMessage = nil

        do {
            let rawNonce = try MacAuthNonceGenerator.random()
            let appleResult = try await requestAppleAuthorization(rawNonce: rawNonce)
            let authSession = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: appleResult.idToken,
                    nonce: rawNonce
                )
            )

            applyActiveSession(authSession)
            providerInProgress = nil
            if await resolveAuthenticatedAccount(
                for: authSession.user,
                intent: pendingAuthenticationIntent,
                expectedUsername: pendingExpectedUsername
            ) {
                SyncCoordinator.shared.showTransientFeedback(
                    title: String(localized: "Signed In: Apple"),
                    message: successMessage(for: authSession.user, providerName: "Apple"),
                    style: .success
                )
            }
        } catch where Self.isCancellation(error) {
            providerInProgress = nil
            lastErrorMessage = nil
        } catch {
            providerInProgress = nil
            let message = authErrorMessage(for: error, providerName: "Apple")
            lastErrorMessage = message
            macAuthLog.error("Mac Apple sign-in failed: \(String(describing: error), privacy: .public)")
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sign In Failed"),
                message: message,
                style: .failure
            )
        }
    }

    func signInWithGoogle(
        intent: ToDoAccountAuthenticationIntent = .signIn,
        expectedUsername: String? = nil
    ) async {
        await signInWithOAuth(
            provider: .google,
            label: "Google",
            progress: .google,
            intent: intent,
            expectedUsername: expectedUsername
        )
    }

    /// Links Apple to the already-resolved Mac account. The returned session
    /// must retain the immutable Supabase account UUID.
    @discardableResult
    func linkAppleIdentity() async -> Bool {
        guard hasResolvedAccount, let accountID = resolvedAccountID else {
            lastErrorMessage = String(localized: "Resolve your toDō account before connecting another sign-in method.")
            return false
        }

        providerInProgress = .apple
        defer { providerInProgress = nil }

        do {
            let rawNonce = try MacAuthNonceGenerator.random()
            let authorization = try await requestAppleAuthorization(rawNonce: rawNonce)
            let linkedSession = try await supabase.auth.linkIdentityWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: authorization.idToken,
                    nonce: rawNonce
                )
            )
            guard linkedSession.user.id == accountID else {
                lastErrorMessage = String(localized: "That sign-in method belongs to another toDō account.")
                return false
            }
            applyActiveSession(linkedSession)
            await refreshLinkedProviders()
            profileStatusMessage = String(localized: "Sign-in method connected.")
            return true
        } catch where Self.isCancellation(error) {
            lastErrorMessage = nil
            return false
        } catch {
            lastErrorMessage = authErrorMessage(for: error, providerName: "Apple")
            macAuthLog.error("Mac Apple identity linking failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Links Google through Supabase's PKCE identity-linking flow. The
    /// callback is exchanged as a session and must retain the current UUID.
    @discardableResult
    func linkGoogleIdentity() async -> Bool {
        guard hasResolvedAccount, let accountID = resolvedAccountID else {
            lastErrorMessage = String(localized: "Resolve your toDō account before connecting another sign-in method.")
            return false
        }

        providerInProgress = .google
        defer { providerInProgress = nil }

        do {
            let oauthURL = try await supabase.auth.getLinkIdentityURL(
                provider: .google,
                redirectTo: SupabaseConfig.redirectURL
            )
            let callbackURL = try await launchOAuthSession(url: oauthURL.url)
            let linkedSession = try await supabase.auth.session(from: callbackURL)
            guard linkedSession.user.id == accountID else {
                lastErrorMessage = String(localized: "That sign-in method belongs to another toDō account.")
                return false
            }
            applyActiveSession(linkedSession)
            await refreshLinkedProviders()
            profileStatusMessage = String(localized: "Sign-in method connected.")
            return true
        } catch where Self.isCancellation(error) {
            lastErrorMessage = nil
            return false
        } catch {
            lastErrorMessage = authErrorMessage(for: error, providerName: "Google")
            macAuthLog.error("Mac Google identity linking failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func refreshLinkedProviders() async {
        guard let currentUser = activeSession?.user, hasResolvedAccount else {
            linkedProviders = []
            return
        }

        do {
            let identities = try await supabase.auth.userIdentities()
            guard identities.allSatisfy({ $0.userId == currentUser.id }) else {
                linkedProviders = []
                lastErrorMessage = String(localized: "The connected sign-in methods could not be verified.")
                return
            }
            linkedProviders = Set(identities.map { $0.provider.lowercased() })
        } catch {
            macAuthLog.error("Mac linked provider refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func handleIncomingURL(_ url: URL) async {
        guard SupabaseConfig.isConfigured else { return }
        guard url.scheme?.caseInsensitiveCompare(SupabaseConfig.callbackScheme) == .orderedSame else { return }
        providerInProgress = .callback
        await finishAuthCallback(url)
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        guard SupabaseConfig.isConfigured else {
            await finishSignedOutBoundary()
            return
        }

        let previousUserID = resolvedAccountID
        guard await prepareAccountCacheForSignOut(userID: previousUserID) else { return }
        do {
            try await supabase.auth.signOut()
            await finishSignedOutBoundary()
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Signed Out"),
                message: String(localized: "Account toDōs stay private and return after you sign in again."),
                style: .warning
            )
        } catch {
            if supabase.auth.currentSession == nil {
                await finishSignedOutBoundary()
                SyncCoordinator.shared.showTransientFeedback(
                    title: String(localized: "Signed Out"),
                    message: String(localized: "Account toDōs stay private and return after you sign in again."),
                    style: .warning
                )
                return
            }
            if let previousUserID {
                await applyPreferredSyncModeIfNeeded(userID: previousUserID, force: true)
            }
            lastErrorMessage = error.localizedDescription
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sign Out Failed"),
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    @discardableResult
    func continueWithoutSigningIn() async -> Bool {
        guard !isSigningOut else { return false }
        isSigningOut = true
        defer { isSigningOut = false }

        guard await prepareAccountCacheForSignOut(userID: resolvedAccountID) else { return false }

        if SupabaseConfig.isConfigured, activeSession != nil {
            do {
                try await supabase.auth.signOut(scope: .local)
            } catch where supabase.auth.currentSession != nil {
                lastErrorMessage = String(localized: "Could not continue without signing in. Try again.")
                return false
            } catch {
                // The SDK has already removed the local session.
            }
        }

        await finishSignedOutBoundary()
        return true
    }

    private func prepareAccountCacheForSignOut(userID: UUID?) async -> Bool {
        guard SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere,
              let userID
        else {
            return true
        }

        SyncCoordinator.shared.showTransientFeedback(
            title: String(localized: "Keeping Everything in Step"),
            message: String(localized: "Your latest toDōs are still syncing. We’ll sign you out as soon as everything is safely in place."),
            style: .warning
        )

        guard await SyncCoordinator.shared.flushLocalSync(userID: userID) else {
            let message = String(localized: "Your latest toDōs have not finished syncing, so you’re still signed in. Check your connection and try again.")
            lastErrorMessage = message
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "A Little More Time"),
                message: message,
                style: .failure
            )
            return false
        }

        do {
            try SyncCoordinator.shared.purgeLocalAccountCache(userID: userID)
            return true
        } catch {
            macAuthLog.error("Mac signed-out account cache cleanup failed: \(String(describing: error), privacy: .public)")
            let message = String(localized: "Your latest toDōs are safe, but this device could not finish signing out. Try again.")
            lastErrorMessage = message
            await applyPreferredSyncModeIfNeeded(userID: userID, force: true)
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sign-Out Paused"),
                message: message,
                style: .failure
            )
            return false
        }
    }

    /// Clears the in-memory account boundary after the server has confirmed
    /// permanent deletion. The caller purges the Mac SwiftData store first.
    func completeAccountDeletion() async {
        authStateTask?.cancel()
        startupSyncTask?.cancel()
        clearLocalSession()
        lastAppliedSyncKey = nil
        await ToDoCollaborationService.shared.updateAccount(nil)
        await ToDoPurchaseManager.shared.updateAccount(nil)
        await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
    }

    private func signInWithOAuth(
        provider: Provider,
        label: String,
        progress: ProviderInProgress,
        intent: ToDoAccountAuthenticationIntent,
        expectedUsername: String?
    ) async {
        guard SupabaseConfig.isConfigured else {
            let message = SupabaseConfig.configurationIssue ?? String(localized: "toDō Sync is not configured for this build.")
            lastErrorMessage = message
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "toDō Sync Unavailable"),
                message: String(localized: "Account sync is not configured for this build."),
                style: .failure
            )
            return
        }

        providerInProgress = progress
        beginAuthentication(intent: intent, expectedUsername: expectedUsername)
        lastErrorMessage = nil

        do {
            // Supabase's convenience overload gives its callback a MainActor
            // isolation context, but macOS invokes ASWebAuthenticationSession's
            // completion on SafariLaunchAgent. Launch the browser session here so
            // the callback remains actor-neutral, then let Supabase exchange the
            // returned PKCE URL for a session.
            let oauthURL = try supabase.auth.getOAuthSignInURL(
                provider: provider,
                redirectTo: SupabaseConfig.redirectURL
            )
            let callbackURL = try await launchOAuthSession(url: oauthURL)
            let authSession = try await supabase.auth.session(from: callbackURL)
            applyActiveSession(authSession)
            providerInProgress = nil
            if await resolveAuthenticatedAccount(
                for: authSession.user,
                intent: pendingAuthenticationIntent,
                expectedUsername: pendingExpectedUsername
            ) {
                SyncCoordinator.shared.showTransientFeedback(
                    title: String(format: String(localized: "Signed In: %@"), label),
                    message: successMessage(for: authSession.user, providerName: label),
                    style: .success
                )
            }
        } catch where Self.isCancellation(error) {
            providerInProgress = nil
            lastErrorMessage = nil
        } catch {
            providerInProgress = nil
            let message = authErrorMessage(for: error, providerName: label)
            lastErrorMessage = message
            macAuthLog.error("Mac OAuth sign-in failed: \(String(describing: error), privacy: .public)")
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sign In Failed"),
                message: message,
                style: .failure
            )
        }
    }

    private func launchOAuthSession(url: URL) async throws -> URL {
        defer {
            oauthWebAuthenticationSession = nil
            oauthPresentationContextProvider = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let callbackBox = MacOAuthCallbackBox(continuation: continuation)
            let callbackHandler = MacOAuthCallbackHandler.handler(for: callbackBox)
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(SupabaseConfig.callbackScheme),
                completionHandler: callbackHandler
            )
            let presentationProvider = MacWebAuthenticationPresentationContextProvider()

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = presentationProvider
            oauthWebAuthenticationSession = session
            oauthPresentationContextProvider = presentationProvider

            guard session.start() else {
                callbackBox.finish(error: MacOAuthSessionError.couldNotStart)
                return
            }
        }
    }

    private func finishAuthCallback(_ url: URL) async {
        do {
            let authSession = try await supabase.auth.session(from: url)
            applyActiveSession(authSession)
            providerInProgress = nil
            if await resolveAuthenticatedAccount(
                for: authSession.user,
                intent: pendingAuthenticationIntent,
                expectedUsername: pendingExpectedUsername
            ) {
                SyncCoordinator.shared.showTransientFeedback(
                    title: String(localized: "Signed In"),
                    message: successMessage(for: authSession.user, providerName: providerLabel),
                    style: .success
                )
            }
        } catch {
            providerInProgress = nil
            let message = authErrorMessage(for: error, providerName: String(localized: "your account"))
            lastErrorMessage = message
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sign In Failed"),
                message: message,
                style: .failure
            )
        }
    }

    private var activeSession: Session? {
        guard let session, !session.isExpired else { return nil }
        return session
    }

    private func applyActiveSession(_ newSession: Session?, shouldClearWhenInactive: Bool = true) {
        guard let newSession, !newSession.isExpired else {
            guard shouldClearWhenInactive else { return }
            clearLocalSession()
            return
        }

        if currentUser?.id != newSession.user.id {
            profile = nil
            profileImageRevision = 0
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            resetProfileOperationState()
        }
        session = newSession
        currentUser = newSession.user
        linkedProviders = Set((newSession.user.identities ?? []).map { $0.provider.lowercased() })
    }

    private func clearLocalSession() {
        session = nil
        currentUser = nil
        profile = nil
        profileImageRevision = 0
        linkedProviders = []
        accountResolution = .signedOut
        SyncCoordinator.shared.setAccountResolution(false)
        resetProfileOperationState()
        lastErrorMessage = nil
    }

    private func finishSignedOutBoundary(applySyncMode: Bool = true) async {
        clearLocalSession()
        pendingAuthenticationIntent = .restoreSession
        pendingExpectedUsername = nil
        await ToDoCollaborationService.shared.updateAccount(nil)
        await ToDoPurchaseManager.shared.updateAccount(nil)
        if applySyncMode {
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
        }
    }

    private func startAuthStateListener() {
        authStateTask?.cancel()
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await state in supabase.auth.authStateChanges {
                await self.handleAuthStateChange(event: state.event, session: state.session)
            }
        }
    }

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery:
            applyActiveSession(session, shouldClearWhenInactive: false)
            if let user = activeSession?.user {
                await resolveAuthenticatedAccount(
                    for: user,
                    intent: pendingAuthenticationIntent,
                    expectedUsername: pendingExpectedUsername
                )
            }
            guard !isDeferringStartupSync else {
                scheduleStartupSync(userID: resolvedAccountID)
                return
            }
            await applyPreferredSyncModeIfNeeded(userID: resolvedAccountID)
        case .signedOut:
            await finishSignedOutBoundary(applySyncMode: false)
            guard !isDeferringStartupSync else {
                scheduleStartupSync(userID: nil)
                return
            }
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
        default:
            applyActiveSession(session, shouldClearWhenInactive: false)
        }
    }

    private func scheduleStartupSync(userID: UUID?) {
        startupSyncTask?.cancel()
        startupSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled else { return }
            self.isDeferringStartupSync = false
            await self.applyPreferredSyncModeIfNeeded(userID: self.resolvedAccountID ?? userID, force: true)
        }
    }

    func refreshProfile() async {
        guard let user = activeSession?.user else { return }
        await bootstrapProfile(for: user)
    }

    func reportProfileError(_ message: String) {
        profileErrorMessage = message
    }

    @discardableResult
    func updateDisplayName(_ value: String) async -> Bool {
        await updateProfile(displayName: value, username: profile?.username)
    }

    @discardableResult
    func updateProfile(displayName value: String, username usernameValue: String?) async -> Bool {
        profileStatusMessage = nil
        profileErrorMessage = nil

        let displayName: String
        let requestedUsername: String?
        do {
            displayName = try ToDoProfilePolicy.validatedDisplayName(value)
            if let usernameValue, !usernameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                requestedUsername = try ToDoProfilePolicy.validatedUsername(usernameValue)
            } else {
                requestedUsername = nil
            }
        } catch {
            profileErrorMessage = error.localizedDescription
            return false
        }

        guard let userID = resolvedAccountID else {
            profileErrorMessage = String(localized: "Sign in to edit your profile.")
            return false
        }

        if let requestedUsername,
           let currentUsername = profile?.username,
           (try? ToDoProfilePolicy.validatedUsername(currentUsername)) != requestedUsername {
            profileErrorMessage = String(localized: "Your username is your account locator and cannot be changed here.")
            return false
        }

        isSavingProfile = true
        defer {
            if authenticatedUserID == userID {
                isSavingProfile = false
            }
        }

        do {
            let record: SupabaseProfileRecord = try await supabase
                .from("profiles")
                .update(ToDoProfileDisplayNamePayload(displayName: displayName))
                .eq("id", value: userID)
                .select()
                .single()
                .execute()
                .value

            guard authenticatedUserID == userID, record.id == userID else { return false }
            profile = record
            profileStatusMessage = String(localized: "Profile saved.")
            return true
        } catch {
            guard authenticatedUserID == userID else { return false }
            profileErrorMessage = error.localizedDescription.contains("profiles_username_unique_idx")
                ? String(localized: "That username is already in use. Choose another one.")
                : String(localized: "Your profile could not be saved. Try again.")
            macAuthLog.error("Mac profile update failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    @discardableResult
    func updateProfileImage(_ data: Data, scope: ToDoProfileImageScope) async -> Bool {
        guard let userID = resolvedAccountID else {
            profileErrorMessage = String(localized: "Sign in to edit your profile.")
            return false
        }

        let preparation: ToDoProfileImagePreparation
        do {
            preparation = try await Task.detached(priority: .userInitiated) {
                try ToDoProfileImagePreparation.prepare(
                    sourceData: data,
                    userID: userID,
                    scope: scope
                )
            }.value
        } catch ToDoProfileImagePreparation.PreparationError.unreadableImage {
            profileErrorMessage = String(localized: "The profile image could not be read. Try another image.")
            return false
        } catch ToDoProfileImagePreparation.PreparationError.tooLarge {
            profileErrorMessage = String(localized: "Choose an image smaller than 5 MB.")
            return false
        } catch ToDoProfileImagePreparation.PreparationError.iCloudUnavailable {
            profileErrorMessage = String(localized: "iCloud profile images are unavailable on this Mac. Choose this Mac or all signed-in devices.")
            return false
        } catch {
            profileErrorMessage = String(localized: "The profile image could not be prepared. Try another image.")
            return false
        }

        isSavingProfile = true
        defer {
            if authenticatedUserID == userID {
                isSavingProfile = false
            }
        }

        do {
            switch scope {
            case .thisDevice, .appleDevices:
                let record: SupabaseProfileRecord = try await supabase
                    .from("profiles")
                    .update(ToDoProfileAvatarPayload(avatarURL: nil))
                    .eq("id", value: userID)
                    .select()
                    .single()
                    .execute()
                    .value

                guard authenticatedUserID == userID, record.id == userID else { return false }
                try ToDoProfileImageStore.save(preparation.data, for: userID, scope: scope)
                ToDoProfileImageStore.saveScope(scope, for: userID)
                profile = record
                profileImageRevision = ToDoProfileImageStore.bumpRevision(for: userID)

                // Clear the previous shared object when switching to a private scope.
                _ = try? await supabase.storage
                    .from("profile-images")
                    .remove(paths: ["\(userID.uuidString.lowercased())/avatar.jpg"])

            case .allDevices:
                // Storage folder policies compare this component with the
                // lowercase text representation of auth.uid().
                let storage = supabase.storage.from("profile-images")
                try await storage.upload(
                    preparation.remotePath,
                    data: preparation.data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
                let avatarURL = try storage.getPublicURL(
                    path: preparation.remotePath,
                    cacheNonce: UUID().uuidString
                )
                let record: SupabaseProfileRecord = try await supabase
                    .from("profiles")
                    .update(ToDoProfileAvatarPayload(avatarURL: avatarURL.absoluteString))
                    .eq("id", value: userID)
                    .select()
                    .single()
                    .execute()
                    .value

                guard authenticatedUserID == userID, record.id == userID else { return false }
                try? ToDoProfileImageStore.save(preparation.data, for: userID, scope: .thisDevice)
                ToDoProfileImageStore.saveScope(scope, for: userID)
                profile = record
                profileImageRevision = ToDoProfileImageStore.bumpRevision(for: userID)
            }

            profileStatusMessage = String(localized: "Profile image saved.")
            return true
        } catch {
            guard authenticatedUserID == userID else { return false }
            profileErrorMessage = String(localized: "Your profile image could not be saved. Try again.")
            macAuthLog.error("Mac profile image update failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    @discardableResult
    func updateProfileImageScope(_ scope: ToDoProfileImageScope) async -> Bool {
        guard let userID = resolvedAccountID else {
            profileErrorMessage = String(localized: "Sign in to change image availability.")
            return false
        }

        var imageData = await Task.detached(priority: .utility) {
            ToDoProfileImageStore.load(for: userID)
        }.value

        if imageData == nil,
           let remoteURL = ToDoProfilePolicy.avatarURL(from: profile?.avatarURL) {
            do {
                let (data, response) = try await URLSession.shared.data(from: remoteURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    profileErrorMessage = String(localized: "The current profile image could not be downloaded. Try again.")
                    return false
                }
                imageData = await Task.detached(priority: .userInitiated) {
                    ToDoProfileImageStore.normalizedJPEGData(from: data)
                }.value
            } catch {
                profileErrorMessage = String(localized: "The current profile image could not be downloaded. Try again.")
                return false
            }
        }

        guard let imageData else {
            profileErrorMessage = String(localized: "Choose a profile image before changing its availability.")
            return false
        }
        return await updateProfileImage(imageData, scope: scope)
    }

    func updateProfileImageOffset(_ offset: CGSize) {
        guard let userID = resolvedAccountID else { return }
        ToDoProfileImageStore.saveOffset(offset, for: userID)
        profileImageRevision = ToDoProfileImageStore.bumpRevision(for: userID)
    }

    private func bootstrapProfile(for user: User) async {
        profileErrorMessage = nil
        isLoadingProfile = true
        defer {
            if authenticatedUserID == user.id {
                isLoadingProfile = false
            }
        }

        let payload = ToDoProfileBootstrapPayload(
            id: user.id,
            displayName: metadataValue("full_name", from: user)
                ?? metadataValue("name", from: user),
            givenName: metadataValue("given_name", from: user),
            familyName: metadataValue("family_name", from: user),
            preferredTimeZone: TimeZone.current.identifier
        )

        do {
            try await supabase
                .from("profiles")
                .upsert(payload, onConflict: "id", ignoreDuplicates: true)
                .execute()

            let record = try await fetchProfile(userID: user.id)

            guard authenticatedUserID == user.id, record.id == user.id else { return }
            profile = record
            profileErrorMessage = nil
        } catch {
            guard authenticatedUserID == user.id else { return }
            profileErrorMessage = String(localized: "Your profile could not be loaded. Try again.")
            macAuthLog.error("Mac profile refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func fetchProfile(userID: UUID) async throws -> SupabaseProfileRecord {
        let records: [SupabaseProfileRecord] = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        guard let record = records.first else {
            throw ToDoProfileStoreError.missingProfile
        }
        return record
    }

    @discardableResult
    private func resolveAuthenticatedAccount(
        for user: User,
        intent: ToDoAccountAuthenticationIntent,
        expectedUsername: String?
    ) async -> Bool {
        guard authenticatedUserID == user.id else { return false }
        accountResolution = .resolving(
            intent: intent,
            expectedUsername: normalizedExpectedUsername(expectedUsername)
        )
        SyncCoordinator.shared.setAccountResolution(false)
        await applyPreferredSyncModeIfNeeded(userID: nil, force: true)

        await bootstrapProfile(for: user)
        guard let currentProfile = profile, currentProfile.id == user.id else {
            accountResolution = .needsUsername(intent: intent)
            return false
        }

        if currentProfile.username == nil,
           intent == .createAccount,
           let expectedUsername,
           await claimAccountUsername(expectedUsername) {
            await bootstrapProfile(for: user)
        }

        guard let refreshedProfile = profile, refreshedProfile.id == user.id else {
            accountResolution = .needsUsername(intent: intent)
            return false
        }

        let resolution = ToDoAccountResolutionPolicy.state(
            profile: refreshedProfile,
            intent: intent,
            expectedUsername: expectedUsername
        )
        accountResolution = resolution
        guard case .resolved(let accountID, let username) = resolution,
              accountID == user.id else {
            SyncCoordinator.shared.setAccountResolution(false)
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
            return false
        }

        pendingAuthenticationIntent = .restoreSession
        pendingExpectedUsername = username
        Self.storeResolvedUsername(username)
        SyncCoordinator.shared.setAccountResolution(true)
        await applyPreferredSyncModeIfNeeded(userID: accountID, force: true)
        await ToDoPurchaseManager.shared.updateAccount(commerceAccount)
        await ToDoCollaborationService.shared.updateAccount(commerceAccount)
        return true
    }

    @discardableResult
    private func claimAccountUsername(_ value: String) async -> Bool {
        guard let username = try? ToDoProfilePolicy.validatedUsername(value) else {
            profileErrorMessage = String(localized: "Use a username with letters, numbers, periods, or underscores.")
            return false
        }

        do {
            let response: [MacUsernameClaimResponse] = try await supabase
                .rpc("claim_account_username", params: MacUsernameRPCParameters(requestedUsername: username))
                .execute()
                .value
            guard let claimed = response.first,
                  claimed.accountID == authenticatedUserID,
                  claimed.username == username else {
                profileErrorMessage = String(localized: "Your username could not be confirmed. Try again.")
                return false
            }
            profile = try await fetchProfile(userID: claimed.accountID)
            return true
        } catch {
            let message = String(describing: error).lowercased()
            if message.contains("already in use") || message.contains("reserved") {
                profileErrorMessage = String(localized: "That username is not available. Choose another one.")
            } else if message.contains("different username") {
                profileErrorMessage = String(localized: "This account already has a different username.")
            } else {
                profileErrorMessage = String(localized: "Your username could not be saved. Try again.")
            }
            macAuthLog.error("Mac username claim failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private func normalizedExpectedUsername(_ value: String?) -> String? {
        guard let value,
              let normalized = try? ToDoProfilePolicy.validatedUsername(value) else { return nil }
        return normalized
    }

    private static func storedResolvedUsername() -> String? {
        UserDefaults.standard.string(forKey: resolvedUsernameKey)
    }

    private static func storeResolvedUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: resolvedUsernameKey)
    }

    private func metadataValue(_ key: String, from user: User) -> String? {
        guard let value = user.userMetadata[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func resetProfileOperationState() {
        isLoadingProfile = false
        isSavingProfile = false
        profileStatusMessage = nil
        profileErrorMessage = nil
    }

    private func applyPreferredSyncModeIfNeeded(userID: UUID?, force: Bool = false) async {
        let resolvedUserID = hasResolvedAccount ? userID : nil
        let syncKey = "\(SyncCoordinator.shared.preferredSyncMode.rawValue)|\(resolvedUserID?.uuidString ?? "unresolved")"
        guard force || lastAppliedSyncKey != syncKey || SyncCoordinator.shared.preferredSyncMode == .syncEverywhere else { return }
        await SyncCoordinator.shared.applyPreferredSyncMode(userID: resolvedUserID)
        lastAppliedSyncKey = syncKey
    }

    private func successMessage(for user: User, providerName: String?) -> String {
        let account = user.email?.nilIfEmpty ?? String(localized: "your account")
        if let providerName {
            return String(format: String(localized: "%@ is connected through %@."), account, providerName)
        }
        return String(format: String(localized: "%@ is connected."), account)
    }

    private func authErrorMessage(for error: Error, providerName: String) -> String {
        let nsError = error as NSError
        if Self.isCancellation(error) {
            return String(localized: "Sign-in was canceled.")
        }
        if !nsError.localizedDescription.isEmpty {
            return nsError.localizedDescription
        }
        return String(format: String(localized: "Sign in with %@ could not finish. Try again."), providerName)
    }

    private func normalizedProviderLabel(from provider: String?) -> String? {
        guard let provider = provider?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !provider.isEmpty,
              !provider.contains("@")
        else {
            return nil
        }

        switch provider {
        case "google":
            return "Google"
        case "apple":
            return "Apple"
        case "email", "phone":
            return nil
        default:
            return provider.capitalized
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
            return true
        }
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        return false
    }

    private func requestAppleAuthorization(rawNonce: String) async throws -> MacAppleAuthorizationResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = MacAuthNonceGenerator.sha256(rawNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            let coordinator = MacAppleAuthorizationCoordinator(
                controller: controller,
                continuation: continuation,
                onFinish: { [weak self] in
                    self?.appleAuthorizationCoordinator = nil
                }
            )
            appleAuthorizationCoordinator = coordinator
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
        }
    }
}

private struct MacAppleAuthorizationResult {
    let idToken: String
}

private enum MacOAuthSessionError: LocalizedError {
    case couldNotStart
    case missingCallback

    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            return String(localized: "Google sign-in could not open the secure browser session. Try again.")
        case .missingCallback:
            return String(localized: "Google sign-in finished without returning a callback. Try again.")
        }
    }
}

/// Resumes the OAuth continuation from AuthenticationServices' callback queue.
/// The lock makes duplicate callback/error delivery harmless and keeps the box
/// independent from the MainActor-owned auth store.
nonisolated private final class MacOAuthCallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?

    init(continuation: CheckedContinuation<URL, Error>) {
        self.continuation = continuation
    }

    func finish(callbackURL: URL? = nil, error: Error? = nil) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        guard let continuation else { return }
        if let error {
            continuation.resume(throwing: error)
        } else if let callbackURL {
            continuation.resume(returning: callbackURL)
        } else {
            continuation.resume(throwing: MacOAuthSessionError.missingCallback)
        }
    }
}

/// Keeps AuthenticationServices' callback outside the MainActor-owned auth store.
/// macOS may deliver this callback from SafariLaunchAgent's XPC queue.
nonisolated private enum MacOAuthCallbackHandler {
    static func handler(
        for callbackBox: MacOAuthCallbackBox
    ) -> @Sendable (URL?, Error?) -> Void {
        { callbackURL, error in
            callbackBox.finish(callbackURL: callbackURL, error: error)
        }
    }
}

@MainActor
private final class MacWebAuthenticationPresentationContextProvider: NSObject,
    ASWebAuthenticationPresentationContextProviding
{
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ??
            NSApplication.shared.windows.first(where: { $0.isVisible }) ??
            ASPresentationAnchor()
    }
}

private enum MacAppleAuthorizationError: LocalizedError {
    case missingIDToken
    case invalidIDToken

    var errorDescription: String? {
        switch self {
        case .missingIDToken:
            return String(localized: "Apple did not return a sign-in token. Try again.")
        case .invalidIDToken:
            return String(localized: "Apple sign-in returned a token toDō could not read. Try again.")
        }
    }
}

private final class MacAppleAuthorizationCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let controller: ASAuthorizationController
    private let continuation: CheckedContinuation<MacAppleAuthorizationResult, Error>
    private let onFinish: () -> Void
    private var didFinish = false

    init(
        controller: ASAuthorizationController,
        continuation: CheckedContinuation<MacAppleAuthorizationResult, Error>,
        onFinish: @escaping () -> Void
    ) {
        self.controller = controller
        self.continuation = continuation
        self.onFinish = onFinish
        super.init()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !didFinish else { return }
        didFinish = true
        defer { onFinish() }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken
        else {
            continuation.resume(throwing: MacAppleAuthorizationError.missingIDToken)
            return
        }

        guard let idToken = String(data: identityToken, encoding: .utf8) else {
            continuation.resume(throwing: MacAppleAuthorizationError.invalidIDToken)
            return
        }

        continuation.resume(returning: MacAppleAuthorizationResult(idToken: idToken))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !didFinish else { return }
        didFinish = true
        defer { onFinish() }
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ??
            NSApplication.shared.windows.first(where: { $0.isVisible }) ??
            ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

private enum MacAuthNonceGenerator {
    static func random(length: Int = 32) throws -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = try (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    throw MacAuthNonceError.generationFailed(status)
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private enum MacAuthNonceError: LocalizedError {
    case generationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return String(localized: "Secure sign-in setup failed. Try again.")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
