import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import GoogleSignIn
import OSLog
import SwiftUI
import Supabase
import UIKit

private let authLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "dev.iamshift.toDo",
    category: "Auth"
)

enum AuthProviderInProgress: Equatable {
    case apple
    case google
    case authCallback
}

private enum SecureNonceError: LocalizedError {
    case generationFailed(OSStatus)

    var errorDescription: String? {
        "Sign-in could not prepare securely. Try again."
    }
}

nonisolated private struct DeviceTokenUpsertPayload: Encodable, Sendable {
    let userID: UUID
    let installationID: String
    let platform: String
    let pushProvider: String
    let token: String
    let appBundleID: String?
    let environment: String
    let isActive: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case installationID = "installation_id"
        case platform
        case pushProvider = "push_provider"
        case token
        case appBundleID = "app_bundle_id"
        case environment
        case isActive = "is_active"
        case lastSeenAt = "last_seen_at"
    }
}

nonisolated private struct DeviceTokenDeactivatePayload: Encodable, Sendable {
    let isActive: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case lastSeenAt = "last_seen_at"
    }
}

private struct UsernameRPCParameters: Encodable, Sendable {
    let requestedUsername: String

    enum CodingKeys: String, CodingKey {
        case requestedUsername = "requested_username"
    }
}

private struct UsernameClaimResponse: Decodable, Sendable {
    let accountID: UUID
    let username: String

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case username
    }
}

enum LiveActivityTokenType: String {
    case pushToStart = "push_to_start"
    case update
}

nonisolated private struct LiveActivityTokenUpsertPayload: Encodable, Sendable {
    let userID: UUID
    let installationID: String
    let platform: String
    let tokenType: String
    let token: String
    let activityID: String?
    let toDoID: UUID?
    let toDoIdentifier: String?
    let appBundleID: String?
    let environment: String
    let isActive: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case installationID = "installation_id"
        case platform
        case tokenType = "token_type"
        case token
        case activityID = "activity_id"
        case toDoID = "todo_id"
        case toDoIdentifier = "todo_identifier"
        case appBundleID = "app_bundle_id"
        case environment
        case isActive = "is_active"
        case lastSeenAt = "last_seen_at"
    }
}

nonisolated private struct LiveActivityTokenDeactivatePayload: Encodable, Sendable {
    let isActive: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case lastSeenAt = "last_seen_at"
    }
}

@MainActor
final class SupabaseAuthStore: ObservableObject {
    static let shared = SupabaseAuthStore()
    static let preview = SupabaseAuthStore(isPreviewMode: true)

    @Published private(set) var isStarted = false
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var authProviderInProgress: AuthProviderInProgress?
    @Published private(set) var session: Session?
    @Published private(set) var currentUser: User?
    @Published private(set) var profile: SupabaseProfileRecord?
    /// Increments after a profile image write so every account surface can
    /// reload the local image without waiting for a view to be recreated.
    @Published private(set) var profileImageRevision = 0
    @Published private(set) var isSavingProfile = false
    @Published private(set) var profileStatusMessage: String?
    @Published private(set) var profileErrorMessage: String?
    @Published private(set) var accountResolution: ToDoAccountResolutionState = .signedOut
    @Published private(set) var linkedProviders: Set<String> = []
    @Published var lastErrorMessage: String?

    private lazy var supabase = SupabaseService.shared
    private let pushInstallationID = SupabaseAuthStore.resolvePushInstallationID()
    private var authStateTask: Task<Void, Never>?
    private var lastAppliedSyncKey: String?
    private var pendingAuthenticationIntent: ToDoAccountAuthenticationIntent = .restoreSession
    private var pendingExpectedUsername: String?
    private let isPreviewMode: Bool

    private static let resolvedUsernameKey = "toDo.resolvedUsername"

    private init(isPreviewMode: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
        self.isPreviewMode = isPreviewMode
        if isPreviewMode {
            isStarted = true
        }
    }

    var isAuthenticated: Bool {
        activeSession != nil
    }

    var hasResolvedAccount: Bool {
        if case .resolved = accountResolution { return true }
        return false
    }

    var resolvedAccountID: UUID? {
        guard case .resolved(let accountID, _) = accountResolution else { return nil }
        return accountID
    }

    var resolvedUsername: String? {
        guard case .resolved(_, let username) = accountResolution else { return nil }
        return username
    }

    var isAuthenticating: Bool {
        authProviderInProgress != nil
    }

    var isGoogleAuthenticating: Bool {
        authProviderInProgress == .google
    }

    var dataMode: DataMode {
        effectiveSyncMode.dataMode
    }

    var preferredSyncMode: SyncMode {
        SyncCoordinator.shared.preferredSyncMode
    }

    var effectiveSyncMode: SyncMode {
        SyncCoordinator.shared.effectiveSyncMode
    }

    /// The UUID exposed to account-scoped callers is available only after the
    /// provider session has resolved to a completed username account.
    var currentUserID: UUID? {
        resolvedAccountID
    }

    private var authenticatedUserID: UUID? {
        activeSession?.user.id
    }

    var commerceAccount: ToDoCommerceAccount? {
        guard hasResolvedAccount, let activeSession else { return nil }
        return ToDoCommerceAccount(
            id: activeSession.user.id,
            accessToken: activeSession.accessToken
        )
    }

    var scopedOwnerUserID: UUID? {
        guard effectiveSyncMode == .syncEverywhere else { return nil }
        return resolvedAccountID
    }

    var accountStatusLabel: String {
        effectiveSyncMode.accountStatusLabel
    }

    var signedInEmail: String? {
        guard let email = activeSession?.user.email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            return nil
        }
        return email
    }

    var accountProviderLabel: String? {
        guard let authenticatedUserID else { return nil }

        if let storedProvider = storedSignInProvider(for: authenticatedUserID) {
            return storedProvider
        }

        return inferredProviderLabel(for: activeSession?.user)
    }

    var signInMethodLabel: String? {
        guard isAuthenticated else { return nil }
        return accountProviderLabel.map { String(format: String(localized: "Sign In with %@"), $0) }
    }

    func isProviderLinked(_ provider: String) -> Bool {
        linkedProviders.contains(provider.lowercased())
    }

    var accountStateTitle: String {
        switch effectiveSyncMode {
        case .deviceOnly:
            return String(localized: "Local Only")
        case .iCloud:
            return String(localized: "iCloud")
        case .syncEverywhere:
            if let provider = accountProviderLabel {
                return String(format: String(localized: "Signed In: %@"), provider)
            }
            return isAuthenticated ? String(localized: "Signed In") : String(localized: "Needs Sign In")
        }
    }

    var accountDisplayName: String {
        guard isAuthenticated else {
            return effectiveSyncMode == .iCloud ? String(localized: "iCloud toDō") : String(localized: "Local toDō")
        }
        return ToDoProfilePolicy.resolvedDisplayName(profile: profile, email: signedInEmail)
    }

    var accountDetailText: String {
        guard effectiveSyncMode == .syncEverywhere else {
            return effectiveSyncMode.subtitle
        }
        guard isAuthenticated else {
            return String(format: String(localized: "Signed out. toDōs stay on this device until you sign in to %@."), effectiveSyncMode.title)
        }
        guard hasResolvedAccount else {
            return String(localized: "Finish account setup to keep toDō in sync.")
        }
        if let provider = accountProviderLabel {
            return String(format: String(localized: "Signed In: %@. %@ is ready."), provider, effectiveSyncMode.title)
        }
        return String(localized: "Signed in and ready to keep iPhone, Android, and web in step.")
    }

    var dataModeTitle: String {
        effectiveSyncMode.dataModeTitle
    }

    var dataModeDescription: String {
        effectiveSyncMode.dataModeDescription(isAuthenticated: hasResolvedAccount)
    }

    func start() async {
        guard !isStarted else { return }
        guard !isPreviewMode else {
            isStarted = true
            return
        }
        isStarted = true

        guard SupabaseConfig.isConfigured else {
            let message = SupabaseConfig.configurationIssue ?? "toDō Sync is not configured for this build."
            lastErrorMessage = message
            authLog.error("\(message, privacy: .public)")
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
            return
        }

        applyActiveSession(supabase.auth.currentSession)
        logAuthConfiguration()

        await supabase.auth.startAutoRefresh()
        startAuthStateListener()
        if let currentUser = activeSession?.user {
            pendingAuthenticationIntent = .restoreSession
            pendingExpectedUsername = Self.storedResolvedUsername()
            await resolveAuthenticatedAccount(
                for: currentUser,
                intent: .restoreSession,
                expectedUsername: pendingExpectedUsername
            )
        } else {
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isStarted else { return }
        guard !isPreviewMode else { return }
        guard SupabaseConfig.isConfigured else { return }
        switch phase {
        case .active:
            Task {
                await supabase.auth.startAutoRefresh()
                await SupabaseSyncService.shared.resumeRealtimeIfNeeded()
            }
        case .background, .inactive:
            SupabaseSyncService.shared.suspendRealtime()
            Task {
                await supabase.auth.stopAutoRefresh()
            }
        @unknown default:
            break
        }
    }

    private func prepareForConfiguredSupabaseAction() -> Bool {
        guard SupabaseConfig.isConfigured else {
            let message = SupabaseConfig.configurationIssue ?? "toDō Sync is not configured for this build."
            authProviderInProgress = nil
            lastErrorMessage = message
            authLog.error("\(message, privacy: .public)")
            SyncCoordinator.shared.showTransientFeedback(
                title: "toDō Sync Unavailable",
                message: "Account sync is not configured for this build.",
                style: .failure
            )
            return false
        }

        return true
    }

    func beginAuthentication(
        intent: ToDoAccountAuthenticationIntent,
        expectedUsername: String?
    ) {
        pendingAuthenticationIntent = intent
        pendingExpectedUsername = normalizedExpectedUsername(expectedUsername)
        accountResolution = .authenticating(
            intent: intent,
            expectedUsername: pendingExpectedUsername
        )
        SyncCoordinator.shared.setAccountResolution(false)
    }

    /// Claims the username entered during account setup and then re-runs the
    /// resolver. The RPC is the only client-facing path that can move a
    /// profile from provisional setup to the completed account contract.
    @discardableResult
    func completeAccountSetup(username value: String) async -> Bool {
        guard let user = activeSession?.user else {
            profileErrorMessage = String(localized: "Sign in before finishing account setup.")
            return false
        }

        guard !isLoadingProfile else { return false }
        profileErrorMessage = nil
        isLoadingProfile = true
        defer {
            if authenticatedUserID == user.id {
                isLoadingProfile = false
            }
        }

        guard await claimAccountUsername(value) else { return false }
        pendingAuthenticationIntent = .restoreSession
        pendingExpectedUsername = normalizedExpectedUsername(value)
        return await resolveAuthenticatedAccount(
            for: user,
            intent: .restoreSession,
            expectedUsername: pendingExpectedUsername
        )
    }

    /// Allows a user to continue with the authenticated provider account after
    /// the returning-user username check reports a mismatch. This never changes
    /// the username; it only accepts the account that the provider proved.
    @discardableResult
    func continueWithAuthenticatedAccount() async -> Bool {
        guard let user = activeSession?.user,
              let username = profile?.username else {
            return false
        }

        pendingAuthenticationIntent = .restoreSession
        pendingExpectedUsername = username
        return await resolveAuthenticatedAccount(
            for: user,
            intent: .restoreSession,
            expectedUsername: username
        )
    }

    func checkUsernameAvailability(_ value: String) async -> Bool {
        guard let username = try? ToDoProfilePolicy.validatedUsername(value),
              SupabaseConfig.isConfigured else {
            return false
        }

        do {
            return try await supabase
                .rpc("is_username_available", params: UsernameRPCParameters(requestedUsername: username))
                .execute()
                .value
        } catch {
            authLog.error("Username availability check failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Links a freshly-authenticated Apple identity to the already-resolved
    /// Supabase account. Supabase verifies the provider token; the client only
    /// accepts the link if the returned canonical UUID is unchanged.
    @discardableResult
    func linkAppleIdentity(idToken: String, rawNonce: String) async -> Bool {
        guard hasResolvedAccount, let accountID = resolvedAccountID else {
            lastErrorMessage = String(localized: "Resolve your toDō account before connecting another sign-in method.")
            return false
        }

        do {
            let linkedSession = try await supabase.auth.linkIdentityWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
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
        } catch {
            lastErrorMessage = authErrorMessage(for: error, providerName: "Apple")
            authLog.error("Apple identity linking failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Links Google from the already-resolved account using a fresh native token.
    /// The returned session must retain the current immutable account UUID.
    @discardableResult
    func linkGoogleIdentity() async -> Bool {
        guard hasResolvedAccount, let accountID = resolvedAccountID else {
            lastErrorMessage = String(localized: "Resolve your toDō account before connecting another sign-in method.")
            return false
        }

        authProviderInProgress = .google
        defer { authProviderInProgress = nil }

        do {
            let rawNonce = try AuthNonceGenerator.random()
            let tokens = try await requestNativeGoogleTokens(
                hashedNonce: AuthNonceGenerator.sha256(rawNonce)
            )
            let linkedSession = try await supabase.auth.linkIdentityWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: tokens.idToken,
                    accessToken: tokens.accessToken,
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
        } catch where Self.isGoogleCancellation(error) {
            lastErrorMessage = nil
            return false
        } catch {
            lastErrorMessage = authErrorMessage(for: error, providerName: "Google")
            authLog.error("Google identity linking failed: \(String(describing: error), privacy: .public)")
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
            authLog.error("Linked provider refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?,
        intent: ToDoAccountAuthenticationIntent? = nil,
        expectedUsername: String? = nil
    ) async {
        guard !isPreviewMode else { return }
        guard prepareForConfiguredSupabaseAction() else { return }
        if let intent {
            beginAuthentication(intent: intent, expectedUsername: expectedUsername)
        }
        authProviderInProgress = .apple
        lastErrorMessage = nil

        do {
            #if DEBUG
            authLog.notice("Apple sign-in token audience: \(Self.jwtStringClaim("aud", in: idToken) ?? "unknown", privacy: .public); app bundle: \(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public)")
            #endif
            let authSession = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce
                )
            )

            applyActiveSession(authSession)
            storeSignInProvider("Apple", userID: authSession.user.id)
            authProviderInProgress = nil
            let resolved = await resolveAuthenticatedAccount(
                for: authSession.user,
                fullName: fullName,
                intent: pendingAuthenticationIntent,
                expectedUsername: pendingExpectedUsername
            )
            if resolved {
                SyncCoordinator.shared.showTransientFeedback(
                    title: "Signed In: Apple",
                    message: successMessage(for: authSession.user, providerName: "Apple"),
                    style: .success
                )
            }
        } catch {
            authProviderInProgress = nil
            let message = authErrorMessage(for: error, providerName: "Apple")
            lastErrorMessage = message
            authLog.error("Apple sign-in failed: \(String(describing: error), privacy: .public)")
            SyncCoordinator.shared.showTransientFeedback(
                title: "Sign In Failed",
                message: message,
                style: .failure
            )
        }
    }

    func signInWithGoogle(
        intent: ToDoAccountAuthenticationIntent? = nil,
        expectedUsername: String? = nil
    ) async {
        guard !isPreviewMode else { return }
        guard prepareForConfiguredSupabaseAction() else { return }
        if let intent {
            beginAuthentication(intent: intent, expectedUsername: expectedUsername)
        }
        lastErrorMessage = nil
        authProviderInProgress = .google
        #if DEBUG
        authLog.notice("Google sign-in started with native GoogleSignIn.")
        #endif

        do {
            let rawNonce = try AuthNonceGenerator.random()
            let hashedNonce = AuthNonceGenerator.sha256(rawNonce)
            let authSession = try await signInWithNativeGoogle(
                rawNonce: rawNonce,
                hashedNonce: hashedNonce
            )

            applyActiveSession(authSession)
            storeSignInProvider("Google", userID: authSession.user.id)
            authProviderInProgress = nil
            let resolved = await resolveAuthenticatedAccount(
                for: authSession.user,
                intent: pendingAuthenticationIntent,
                expectedUsername: pendingExpectedUsername
            )
            if resolved {
                SyncCoordinator.shared.showTransientFeedback(
                    title: "Signed In: Google",
                    message: successMessage(for: authSession.user, providerName: "Google"),
                    style: .success
                )
            }
            #if DEBUG
            authLog.notice("Google sign-in succeeded for user: \(authSession.user.id.uuidString, privacy: .public)")
            #endif
        } catch where Self.isGoogleCancellation(error) {
            authProviderInProgress = nil
            lastErrorMessage = nil
            authLog.debug("Google sign-in was canceled by the user.")
        } catch {
            authProviderInProgress = nil
            let message = authErrorMessage(for: error, providerName: "Google")
            lastErrorMessage = message
            authLog.error("Google sign-in failed: \(String(describing: error), privacy: .public)")
            SyncCoordinator.shared.showTransientFeedback(
                title: "Sign In Failed",
                message: message,
                style: .failure
            )
        }
    }

    func handleIncomingURL(_ url: URL) async {
        guard !isPreviewMode else { return }
        guard SupabaseConfig.isConfigured else { return }
        authLog.debug("Incoming auth URL received. scheme=\(url.scheme ?? "none", privacy: .public) host=\(url.host ?? "none", privacy: .public)")
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        await handleAuthCallback(url)
    }

    func handleAuthCallback(_ url: URL) async {
        guard !isPreviewMode else { return }
        guard SupabaseConfig.isConfigured else { return }
        guard url.scheme?.caseInsensitiveCompare(SupabaseConfig.callbackScheme) == .orderedSame else { return }

        authProviderInProgress = .authCallback

        do {
            let authSession = try await supabase.auth.session(from: url)
            applyActiveSession(authSession)
            let provider = inferredProviderLabel(for: authSession.user)
            if let provider {
                storeSignInProvider(provider, userID: authSession.user.id)
            }
            authProviderInProgress = nil
            let resolved = await resolveAuthenticatedAccount(
                for: authSession.user,
                intent: pendingAuthenticationIntent,
                expectedUsername: pendingExpectedUsername
            )
            if resolved {
                SyncCoordinator.shared.showTransientFeedback(
                    title: provider.map { "Signed In: \($0)" } ?? "Signed In",
                    message: successMessage(for: authSession.user, providerName: provider),
                    style: .success
                )
            }
            authLog.notice("Supabase auth callback succeeded for user: \(authSession.user.id.uuidString, privacy: .public)")
        } catch {
            authProviderInProgress = nil
            let message = authErrorMessage(for: error, providerName: "your account")
            lastErrorMessage = message
            authLog.error("Supabase auth callback failed: \(String(describing: error), privacy: .public)")
            SyncCoordinator.shared.showTransientFeedback(
                title: "Sign In Failed",
                message: message,
                style: .failure
            )
        }
    }

    func signOut() async {
        guard !isPreviewMode else { return }
        guard SupabaseConfig.isConfigured else {
            session = nil
            currentUser = nil
            profile = nil
            profileImageRevision = 0
            linkedProviders = []
            lastErrorMessage = nil
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            clearStoredSignInProvider()
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
            return
        }

        let previousUserID = authenticatedUserID
        let shouldPrepareDeviceOnlySnapshot = effectiveSyncMode == .syncEverywhere
        do {
            if shouldPrepareDeviceOnlySnapshot, let previousUserID {
                await SyncCoordinator.shared.flushLocalSync(userID: previousUserID)
            }
            if let previousUserID {
                await deactivateCurrentDeviceTokenIfPossible(for: previousUserID)
            }
            GIDSignIn.sharedInstance.signOut()
            try await supabase.auth.signOut()
            if shouldPrepareDeviceOnlySnapshot, let previousUserID {
                await SyncCoordinator.shared.prepareDeviceOnlySnapshot(from: previousUserID)
            }
            session = nil
            currentUser = nil
            profile = nil
            profileImageRevision = 0
            lastErrorMessage = nil
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            clearStoredSignInProvider()
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
            SyncCoordinator.shared.showTransientFeedback(
                title: "Signed Out",
                message: "toDō now keeps what matters on this device.",
                style: .warning
            )
        } catch {
            await syncCurrentDeviceTokenIfPossible()
            lastErrorMessage = error.localizedDescription
            SyncCoordinator.shared.showTransientFeedback(
                title: "Sign-Out Failed",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    /// Clears the in-memory account boundary after the server has confirmed
    /// permanent deletion. The caller is responsible for purging SwiftData
    /// before invoking this method.
    func completeAccountDeletion() async {
        authStateTask?.cancel()
        GIDSignIn.sharedInstance.signOut()
        session = nil
        currentUser = nil
        profile = nil
        profileImageRevision = 0
        linkedProviders = []
        lastErrorMessage = nil
        accountResolution = .signedOut
        SyncCoordinator.shared.setAccountResolution(false)
        clearStoredSignInProvider()
        resetProfileOperationState()
        lastAppliedSyncKey = nil
        await ToDoCollaborationService.shared.updateAccount(nil)
        await ToDoPurchaseManager.shared.updateAccount(nil)
        await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
    }

    func syncCurrentDeviceTokenIfPossible() async {
        guard !isPreviewMode else { return }
        guard let userID = resolvedAccountID,
              let token = UserDefaults.standard.string(forKey: AppPreferences.Keys.remotePushDeviceToken),
              !token.isEmpty
        else {
            return
        }

        let payload = DeviceTokenUpsertPayload(
            userID: userID,
            installationID: pushInstallationID,
            platform: "ios",
            pushProvider: "apns",
            token: token,
            appBundleID: Bundle.main.bundleIdentifier,
            environment: appPushEnvironment,
            isActive: true,
            lastSeenAt: .now
        )

        do {
            try await supabase
                .from("device_tokens")
                .update(DeviceTokenDeactivatePayload(isActive: false, lastSeenAt: .now))
                .eq("user_id", value: userID)
                .eq("installation_id", value: pushInstallationID)
                .eq("platform", value: "ios")
                .eq("push_provider", value: "apns")
                .neq("token", value: token)
                .execute()

            try await supabase
                .from("device_tokens")
                .upsert(payload, onConflict: "push_provider,token")
                .execute()

           AppLog.info("APNs token synced to Supabase", logger: AppLog.auth)
        } catch {
            AppLog.error("Failed to sync APNs token: \(error)", logger: AppLog.auth)

            lastErrorMessage = error.localizedDescription
        }
    }

    func syncLiveActivityToken(
        token: String,
        tokenType: LiveActivityTokenType,
        activityID: String? = nil,
        toDoIdentifier: String? = nil,
        toDoCloudIdentifier: String? = nil
    ) async {
        guard !isPreviewMode else { return }
        guard let userID = resolvedAccountID, !token.isEmpty else { return }

        let payload = LiveActivityTokenUpsertPayload(
            userID: userID,
            installationID: pushInstallationID,
            platform: "ios",
            tokenType: tokenType.rawValue,
            token: token,
            activityID: activityID,
            toDoID: toDoCloudIdentifier.flatMap(UUID.init(uuidString:)),
            toDoIdentifier: toDoIdentifier,
            appBundleID: Bundle.main.bundleIdentifier,
            environment: appPushEnvironment,
            isActive: true,
            lastSeenAt: .now
        )

        do {
            try await supabase
                .from("live_activity_tokens")
                .update(LiveActivityTokenDeactivatePayload(isActive: false, lastSeenAt: .now))
                .eq("user_id", value: userID)
                .eq("installation_id", value: pushInstallationID)
                .eq("platform", value: "ios")
                .eq("token_type", value: tokenType.rawValue)
                .neq("token", value: token)
                .execute()

            try await supabase
                .from("live_activity_tokens")
                .upsert(payload, onConflict: "token_type,token")
                .execute()

            AppLog.info("Live Activity \(tokenType.rawValue) token synced to Supabase.", logger: AppLog.liveActivity)
        } catch {
            AppLog.error("Failed to sync Live Activity token: \(error)", logger: AppLog.liveActivity)
        }
    }

    func deactivateLiveActivityToken(activityID: String) async {
        guard !isPreviewMode else { return }
        guard let userID = resolvedAccountID else { return }

        do {
            try await supabase
                .from("live_activity_tokens")
                .update(LiveActivityTokenDeactivatePayload(isActive: false, lastSeenAt: .now))
                .eq("user_id", value: userID)
                .eq("activity_id", value: activityID)
                .execute()
        } catch {
            AppLog.error("Failed to deactivate Live Activity token: \(error)", logger: AppLog.liveActivity)
        }
    }

    private static func resolvePushInstallationID() -> String {
        let defaults = UserDefaults.standard
        if let existingID = defaults.string(forKey: AppPreferences.Keys.pushInstallationID),
           !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: AppPreferences.Keys.pushInstallationID)
        return newID
    }

    func refreshProfile() async {
        guard !isPreviewMode else { return }
        guard let currentUser = activeSession?.user else { return }
        await bootstrapProfile(for: currentUser)
    }

    func reportProfileError(_ message: String) {
        profileErrorMessage = message
    }

    @discardableResult
    func updateDisplayName(_ value: String) async -> Bool {
        let currentUsername = profile?.username
        return await updateProfile(displayName: value, username: currentUsername)
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

        guard !isPreviewMode, let userID = resolvedAccountID else {
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
            AppLog.error("Profile update failed: \(error)", logger: AppLog.app)
            return false
        }
    }

    func updateProfileImage(_ data: Data, scope: ToDoProfileImageScope) async -> Bool {
        guard !isPreviewMode, let userID = resolvedAccountID else {
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
            profileErrorMessage = String(localized: "iCloud profile images are unavailable on this device. Choose this device or all signed-in devices.")
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
                profile = record
                ToDoProfileImageStore.saveScope(scope, for: userID)
                profileImageRevision = ToDoProfileImageStore.bumpRevision(for: userID)

                // Clear the previous shared object when switching to a private scope.
                _ = try? await supabase.storage
                    .from("profile-images")
                    .remove(paths: ["\(userID.uuidString.lowercased())/avatar.jpg"])

            case .allDevices:
                // Supabase storage folder policies compare the first path
                // component with auth.uid() text, which is lowercase.
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
            AppLog.error("Profile image update failed: \(error)", logger: AppLog.app)
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
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
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

    private var activeSession: Session? {
        guard let session, !session.isExpired else { return nil }
        return session
    }

    private func applyActiveSession(_ newSession: Session?, shouldClearWhenInactive: Bool = true) {
        guard let newSession, !newSession.isExpired else {
            guard shouldClearWhenInactive else { return }
            session = nil
            currentUser = nil
            profile = nil
            profileImageRevision = 0
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            resetProfileOperationState()
            clearStoredSignInProvider()
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

    private func startAuthStateListener() {
        authStateTask?.cancel()
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await state in supabase.auth.authStateChanges {
                await self.handleAuthStateChange(event: state.event, session: state.session)
            }
        }
    }

    private func signInWithNativeGoogle(rawNonce: String, hashedNonce: String) async throws -> Session {
        let tokens = try await requestNativeGoogleTokens(hashedNonce: hashedNonce)

        #if DEBUG
        let audience = Self.jwtStringClaim("aud", in: tokens.idToken) ?? "unknown"
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let clientID = Self.infoPlistString("GIDClientID") ?? "missing"
        let serverClientID = Self.infoPlistString("GIDServerClientID") ?? "missing"
        authLog.notice("Google sign-in token audience: \(audience, privacy: .public); app bundle: \(bundleID, privacy: .public); iOS client: \(clientID, privacy: .public); server client: \(serverClientID, privacy: .public)")
        #endif
        return try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: tokens.idToken,
                accessToken: tokens.accessToken,
                nonce: rawNonce
            )
        )
    }

    private func requestNativeGoogleTokens(hashedNonce: String) async throws -> NativeGoogleSignInTokens {
        guard let presentingViewController = Self.currentPresentationViewController() else {
            throw NativeGoogleSignInError.missingPresentationContext
        }

        let tokens = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NativeGoogleSignInTokens, Error>) in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: NativeGoogleSignInError.missingResult)
                    return
                }

                guard let idToken = result.user.idToken?.tokenString else {
                    continuation.resume(throwing: NativeGoogleSignInError.missingIDToken)
                    return
                }

                continuation.resume(
                    returning: NativeGoogleSignInTokens(
                        idToken: idToken,
                        accessToken: result.user.accessToken.tokenString
                    )
                )
            }
        }

        return tokens
    }

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery:
            applyActiveSession(session, shouldClearWhenInactive: false)
            if let user = activeSession?.user {
                if storedSignInProvider(for: user.id) == nil,
                   let provider = inferredProviderLabel(for: user) {
                    storeSignInProvider(provider, userID: user.id)
                }
                await resolveAuthenticatedAccount(
                    for: user,
                    intent: pendingAuthenticationIntent,
                    expectedUsername: pendingExpectedUsername
                )
            } else {
                accountResolution = .signedOut
                SyncCoordinator.shared.setAccountResolution(false)
                await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
            }
        case .signedOut:
            self.session = nil
            currentUser = nil
            profile = nil
            profileImageRevision = 0
            linkedProviders = []
            accountResolution = .signedOut
            SyncCoordinator.shared.setAccountResolution(false)
            resetProfileOperationState()
            clearStoredSignInProvider()
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
        default:
            applyActiveSession(session, shouldClearWhenInactive: false)
        }
    }

    private func applyPreferredSyncModeIfNeeded(userID: UUID?, force: Bool = false) async {
        let resolvedUserID = hasResolvedAccount ? userID : nil
        let preferredMode = SyncCoordinator.shared.preferredSyncMode
        let effectiveMode = SyncCoordinator.shared.effectiveSyncMode
        let syncKey = "\(SyncCoordinator.shared.preferredSyncMode.rawValue)|\(resolvedUserID?.uuidString ?? "unresolved")"
        let shouldRetrySyncEverywhere = preferredMode == .syncEverywhere || effectiveMode == .syncEverywhere
        let shouldApply = force || shouldRetrySyncEverywhere || lastAppliedSyncKey != syncKey

        AppLog.info(
            "Auth requested sync apply: preferred=\(preferredMode.rawValue), effective=\(effectiveMode.rawValue), userID=\(userID?.uuidString ?? "nil"), force=\(force), retrySyncEverywhere=\(shouldRetrySyncEverywhere), willApply=\(shouldApply)",
            logger: AppLog.sync
        )

        guard shouldApply else { return }
        await SyncCoordinator.shared.applyPreferredSyncMode(userID: resolvedUserID)
        lastAppliedSyncKey = syncKey
    }

    private func deactivateCurrentDeviceTokenIfPossible(for userID: UUID) async {
        guard let token = UserDefaults.standard.string(forKey: AppPreferences.Keys.remotePushDeviceToken),
              !token.isEmpty
        else {
            return
        }

        do {
            try await supabase
                .from("device_tokens")
                .update(DeviceTokenDeactivatePayload(isActive: false, lastSeenAt: .now))
                .eq("user_id", value: userID)
                .eq("push_provider", value: "apns")
                .eq("token", value: token)
                .execute()
        } catch {
            authLog.error("Failed to deactivate APNs token on sign-out: \(String(describing: error), privacy: .public)")
        }
    }

    private func bootstrapProfile(for user: User, fullName: PersonNameComponents? = nil) async {
        profileErrorMessage = nil
        isLoadingProfile = true
        defer {
            if authenticatedUserID == user.id {
                isLoadingProfile = false
            }
        }

        let payload = ToDoProfileBootstrapPayload(
            id: user.id,
            displayName: resolvedDisplayName(from: user, fullName: fullName),
            givenName: resolvedGivenName(from: user, fullName: fullName),
            familyName: resolvedFamilyName(from: user, fullName: fullName),
            preferredTimeZone: TimeZone.current.identifier
        )

        do {
            try await supabase
                .from("profiles")
                .upsert(payload, onConflict: "id", ignoreDuplicates: true)
                .execute()

            let record = try await fetchProfile(for: user.id)

            guard authenticatedUserID == user.id, record.id == user.id else { return }
            profile = record
            profileErrorMessage = nil
        } catch {
            guard authenticatedUserID == user.id else { return }
            lastErrorMessage = error.localizedDescription
            profileErrorMessage = String(localized: "Your profile could not be loaded. Try again.")
        }
    }

    private func resetProfileOperationState() {
        isSavingProfile = false
        profileStatusMessage = nil
        profileErrorMessage = nil
    }

    private func fetchProfile(for userID: UUID) async throws -> SupabaseProfileRecord {
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

    /// Resolves an authenticated provider session against the profile owned by
    /// the same immutable auth UUID. A session is deliberately not enough to
    /// start sync or commerce; those services are released only in the
    /// `.resolved` branch below.
    @discardableResult
    private func resolveAuthenticatedAccount(
        for user: User,
        fullName: PersonNameComponents? = nil,
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

        await bootstrapProfile(for: user, fullName: fullName)
        guard authenticatedUserID == user.id, let currentProfile = profile else {
            accountResolution = .needsUsername(intent: intent)
            return false
        }

        // A provider can create auth.users before the user finishes the
        // username-first flow. Claiming is explicit and server-authoritative;
        // it never derives identity from an email address.
        if currentProfile.username == nil,
           intent == .createAccount,
           let expectedUsername,
           await claimAccountUsername(expectedUsername) {
            await bootstrapProfile(for: user)
        }

        guard let refreshedProfile = profile,
              refreshedProfile.id == user.id else {
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
        await syncCurrentDeviceTokenIfPossible()
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
        guard authenticatedUserID != nil else {
            profileErrorMessage = String(localized: "Sign in before choosing a username.")
            return false
        }

        let response: [UsernameClaimResponse]
        do {
            response = try await supabase
                .rpc("claim_account_username", params: UsernameRPCParameters(requestedUsername: username))
                .execute()
                .value
        } catch {
            let message = String(describing: error).lowercased()
            if message.contains("already in use") || message.contains("reserved") {
                profileErrorMessage = String(localized: "That username is not available. Choose another one.")
            } else if message.contains("different username") {
                profileErrorMessage = String(localized: "This account already has a different username.")
            } else if message.contains("schema cache")
                || message.contains("could not find the function")
                || message.contains("claim_account_username")
                || message.contains("42702") {
                profileErrorMessage = String(localized: "Account setup is temporarily unavailable. Check your connection and try again in a moment.")
            } else if message.contains("permission denied")
                || message.contains("not authorized")
                || message.contains("42501") {
                profileErrorMessage = String(localized: "Account setup could not be verified. Sign in again and try once more.")
            } else {
                profileErrorMessage = String(localized: "Your username could not be saved. Try again.")
            }
            authLog.error("Username claim failed: \(String(describing: error), privacy: .public)")
            return false
        }

        guard let claimed = response.first,
              claimed.accountID == authenticatedUserID,
              claimed.username == username else {
            profileErrorMessage = String(localized: "The account update was not confirmed by the server. Sign in again and try once more.")
            authLog.error("Username claim returned an unexpected response count: \(response.count, privacy: .public)")
            return false
        }

        do {
            profile = try await fetchProfile(for: claimed.accountID)
            return true
        } catch {
            profileErrorMessage = String(localized: "Your username was saved, but the account could not be refreshed. Try again.")
            authLog.error("Username claim profile refresh failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private func normalizedExpectedUsername(_ value: String?) -> String? {
        guard let value,
              let normalized = try? ToDoProfilePolicy.validatedUsername(value) else {
            return nil
        }
        return normalized
    }

    private static func storedResolvedUsername() -> String? {
        UserDefaults.standard.string(forKey: resolvedUsernameKey)
    }

    private static func storeResolvedUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: resolvedUsernameKey)
    }

    private func resolvedDisplayName(from user: User, fullName: PersonNameComponents?) -> String? {
        if let fullName {
            let formatter = PersonNameComponentsFormatter()
            let resolved = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            if !resolved.isEmpty { return resolved }
        }

        if let metadataName = user.userMetadata["full_name"]?.stringValue, !metadataName.isEmpty {
            return metadataName
        }

        if let metadataName = user.userMetadata["name"]?.stringValue, !metadataName.isEmpty {
            return metadataName
        }

        return nil
    }

    private func resolvedGivenName(from user: User, fullName: PersonNameComponents?) -> String? {
        if let givenName = fullName?.givenName, !givenName.isEmpty {
            return givenName
        }
        if let metadata = user.userMetadata["given_name"]?.stringValue, !metadata.isEmpty {
            return metadata
        }
        return nil
    }

    private func resolvedFamilyName(from user: User, fullName: PersonNameComponents?) -> String? {
        if let familyName = fullName?.familyName, !familyName.isEmpty {
            return familyName
        }
        if let metadata = user.userMetadata["family_name"]?.stringValue, !metadata.isEmpty {
            return metadata
        }
        return nil
    }

    private var appPushEnvironment: String {
        Self.apnsEnvironment
    }

    private static var apnsEnvironment: String {
        if let entitlementValue = embeddedAPNsEnvironment {
            switch entitlementValue {
            case "production":
                return "production"
            case "development":
                return "sandbox"
            default:
                break
            }
        }

        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private static var embeddedAPNsEnvironment: String? {
        guard let profileURL = Bundle.main.url(
            forResource: "embedded",
            withExtension: "mobileprovision"
        ),
        let profile = try? String(contentsOf: profileURL, encoding: .isoLatin1),
        let keyRange = profile.range(of: "<key>aps-environment</key>") else {
            return nil
        }

        let remainingProfile = profile[keyRange.upperBound...]
        guard let stringStart = remainingProfile.range(of: "<string>"),
              let stringEnd = remainingProfile[stringStart.upperBound...].range(of: "</string>")
        else {
            return nil
        }

        return String(remainingProfile[stringStart.upperBound..<stringEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func successMessage(for user: User, providerName: String?) -> String {
        let providerSuffix = providerName.map { " Signed In: \($0)." } ?? ""

        if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return "\(email) is now connected to \(SyncMode.syncEverywhere.title).\(providerSuffix)"
        }

        return "Your toDō Sync account is now connected.\(providerSuffix)"
    }

    private func authErrorMessage(for error: Error, providerName: String) -> String {
        let rawMessage = String(describing: error)
        let localizedMessage = error.localizedDescription
        let combinedMessage = "\(rawMessage) \(localizedMessage)".lowercased()

        if combinedMessage.contains("provider") && combinedMessage.contains("not enabled") {
            return "Sign In with \(providerName) is not available yet. Try another sign-in option or try again later."
        }

        if combinedMessage.contains("audience") || combinedMessage.contains("aud") || combinedMessage.contains("client_id") || combinedMessage.contains("invalid_client") {
            return "Sign In with \(providerName) could not connect to this version of toDō. Try again later."
        }

        if combinedMessage.contains("nonce") {
            return "Sign In with \(providerName) could not finish securely. Try again."
        }

        #if DEBUG
        if localizedMessage == "The operation couldn’t be completed." || localizedMessage == "The operation couldn’t be completed. (Supabase.AuthError error 0.)" {
            return rawMessage
        }
        #endif

        return localizedMessage
    }

    private func logAuthConfiguration() {
        #if DEBUG
        authLog.notice("Auth configuration: bundle=\(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public); redirect=\(SupabaseConfig.redirectURL.absoluteString, privacy: .public); callbackScheme=\(SupabaseConfig.callbackScheme, privacy: .public); googleClient=\(Self.infoPlistString("GIDClientID") ?? "missing", privacy: .public); googleServerClient=\(Self.infoPlistString("GIDServerClientID") ?? "missing", privacy: .public)")
        #endif
    }

    private static func infoPlistString(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static func jwtStringClaim(_ claim: String, in token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2,
              let payload = base64URLDecodedData(String(segments[1])),
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        else {
            return nil
        }

        if let string = object[claim] as? String {
            return string
        }
        if let strings = object[claim] as? [String] {
            return strings.joined(separator: ",")
        }
        return nil
    }

    private static func base64URLDecodedData(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = (4 - base64.count % 4) % 4
        if paddingLength > 0 {
            base64.append(String(repeating: "=", count: paddingLength))
        }
        return Data(base64Encoded: base64)
    }

    private func storeSignInProvider(_ provider: String, userID: UUID) {
        UserDefaults.standard.set(provider, forKey: AppPreferences.Keys.lastSignInProvider)
        UserDefaults.standard.set(userID.uuidString, forKey: AppPreferences.Keys.lastSignInProviderUserID)
    }

    static func lastKnownSignedInUserID() -> UUID? {
        UserDefaults.standard
            .string(forKey: AppPreferences.Keys.lastSignInProviderUserID)
            .flatMap(UUID.init(uuidString:))
    }

    private func storedSignInProvider(for userID: UUID) -> String? {
        let storedUserID = UserDefaults.standard.string(forKey: AppPreferences.Keys.lastSignInProviderUserID)
        guard storedUserID == userID.uuidString else { return nil }
        return normalizedProviderLabel(from: UserDefaults.standard.string(forKey: AppPreferences.Keys.lastSignInProvider))
    }

    private func clearStoredSignInProvider() {
        UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.lastSignInProvider)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.lastSignInProviderUserID)
    }

    private func inferredProviderLabel(for user: User?) -> String? {
        guard let user else { return nil }

        var providerCandidates: [String?] = user.identities?
            .sorted { ($0.lastSignInAt ?? .distantPast) > ($1.lastSignInAt ?? .distantPast) }
            .map(\.provider) ?? []
        providerCandidates.append(user.appMetadata["provider"]?.stringValue)
        providerCandidates.append(contentsOf: user.appMetadata["providers"]?.arrayValue?.map(\.stringValue) ?? [])

        for provider in providerCandidates {
            if let label = normalizedProviderLabel(from: provider) {
                return label
            }
        }

        return nil
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

    private static func currentPresentationViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let rootViewController = windowScene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? windowScene?.windows.first?.rootViewController
        else {
            return nil
        }

        return rootViewController.topMostPresentedViewController
    }

    private static func isGoogleCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.Code.canceled.rawValue
    }
}

private struct NativeGoogleSignInTokens: Sendable {
    let idToken: String
    let accessToken: String
}

private enum NativeGoogleSignInError: LocalizedError {
    case missingPresentationContext
    case missingResult
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingPresentationContext:
            return "Google Sign-In could not find an active app window. Try again after toDō finishes opening."
        case .missingResult:
            return "Google Sign-In finished without returning an account."
        case .missingIDToken:
            return "Google Sign-In could not finish. Try again."
        }
    }
}

private enum AuthNonceGenerator {
    static func random(length: Int = 32) throws -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = try (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    throw SecureNonceError.generationFailed(status)
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

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostPresentedViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostPresentedViewController
        }

        return self
    }
}

extension SupabaseAuthStore {
    enum DataMode {
        case local
        case cloudBacked
    }
}

private extension SyncMode {
    var accountStatusLabel: String {
        switch self {
        case .deviceOnly:
            return String(localized: "This Device Only")
        case .iCloud:
            return String(localized: "Sync with iCloud")
        case .syncEverywhere:
            return String(localized: "toDō Sync")
        }
    }

    var dataMode: SupabaseAuthStore.DataMode {
        switch self {
        case .syncEverywhere:
            return .cloudBacked
        case .deviceOnly, .iCloud:
            return .local
        }
    }

    var dataModeTitle: String {
        switch self {
        case .deviceOnly:
            return String(localized: "This Device Only")
        case .iCloud:
            return String(localized: "Sync with iCloud")
        case .syncEverywhere:
            return String(localized: "toDō Sync")
        }
    }

    func dataModeDescription(isAuthenticated: Bool) -> String {
        switch self {
        case .deviceOnly:
            return String(localized: "Your toDōs stay on this device until you choose a sync option.")
        case .iCloud:
            return String(localized: "toDō uses iCloud to keep your Apple devices in step.")
        case .syncEverywhere:
            return isAuthenticated
                ? String(localized: "toDō Sync is keeping your toDōs available across your signed-in devices.")
                : String(format: String(localized: "%@ is selected, but you still need to sign in. Until then, toDōs stay on this device."), title)
        }
    }

}
