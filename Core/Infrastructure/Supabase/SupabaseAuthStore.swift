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
    subsystem: Bundle.main.bundleIdentifier ?? "dev.iamshift.ToDo",
    category: "Auth"
)

enum AuthProviderInProgress: Equatable {
    case apple
    case google
    case authCallback
}

struct SupabaseProfileRecord: Codable, Equatable, Identifiable {
    let id: UUID
    var username: String?
    var displayName: String?
    var givenName: String?
    var familyName: String?
    var avatarURL: String?
    var preferredTimeZone: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case givenName = "given_name"
        case familyName = "family_name"
        case avatarURL = "avatar_url"
        case preferredTimeZone = "preferred_time_zone"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct SupabaseProfileUpsertPayload: Encodable {
    let id: UUID
    let displayName: String?
    let givenName: String?
    let familyName: String?
    let preferredTimeZone: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case givenName = "given_name"
        case familyName = "family_name"
        case preferredTimeZone = "preferred_time_zone"
    }
}

private struct DeviceTokenUpsertPayload: Encodable {
    let userID: UUID
    let platform: String
    let pushProvider: String
    let token: String
    let appBundleID: String?
    let environment: String
    let isActive: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case platform
        case pushProvider = "push_provider"
        case token
        case appBundleID = "app_bundle_id"
        case environment
        case isActive = "is_active"
        case lastSeenAt = "last_seen_at"
    }
}

private struct DeviceTokenDeactivatePayload: Encodable {
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
    @Published var lastErrorMessage: String?

    private lazy var supabase = SupabaseService.shared
    private var authStateTask: Task<Void, Never>?
    private var lastAppliedSyncKey: String?
    private let isPreviewMode: Bool

    private init(isPreviewMode: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
        self.isPreviewMode = isPreviewMode
        if isPreviewMode {
            isStarted = true
        }
    }

    var isAuthenticated: Bool {
        activeSession != nil
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

    var currentUserID: UUID? {
        activeSession?.user.id
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
        guard let currentUserID else { return nil }

        if let storedProvider = storedSignInProvider(for: currentUserID) {
            return storedProvider
        }

        return inferredProviderLabel(for: activeSession?.user)
    }

    var signInMethodLabel: String? {
        guard isAuthenticated else { return nil }
        return accountProviderLabel.map { String(format: String(localized: "Sign In with %@"), $0) }
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
            return effectiveSyncMode == .iCloud ? String(localized: "iCloud ToDo") : String(localized: "Local ToDo")
        }
        if let displayName = profile?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let email = signedInEmail {
            return email
        }
        return String(localized: "Cloud Account")
    }

    var accountDetailText: String {
        guard effectiveSyncMode == .syncEverywhere else {
            return effectiveSyncMode.subtitle
        }
        guard isAuthenticated else {
            return String(format: String(localized: "Signed out. ToDos stay on this device until you sign in to %@."), effectiveSyncMode.title)
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
        effectiveSyncMode.dataModeDescription(isAuthenticated: isAuthenticated)
    }

    func start() async {
        guard !isStarted else { return }
        guard !isPreviewMode else {
            isStarted = true
            return
        }
        isStarted = true

        applyActiveSession(supabase.auth.currentSession)
        logAuthConfiguration()

        await supabase.auth.startAutoRefresh()
        startAuthStateListener()
        await applyPreferredSyncModeIfNeeded(userID: currentUserID)

        if let currentUser = activeSession?.user {
            await bootstrapProfile(for: currentUser)
            await syncCurrentDeviceTokenIfPossible()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isStarted else { return }
        guard !isPreviewMode else { return }
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

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        guard !isPreviewMode else { return }
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
            await bootstrapProfile(for: authSession.user, fullName: fullName)
            await syncCurrentDeviceTokenIfPossible()
            await applyPreferredSyncModeIfNeeded(userID: authSession.user.id)
            SyncCoordinator.shared.showTransientFeedback(
                title: "Signed In: Apple",
                message: successMessage(for: authSession.user, providerName: "Apple"),
                style: .success
            )
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

    func signInWithGoogle() async {
        guard !isPreviewMode else { return }
        lastErrorMessage = nil
        authProviderInProgress = .google
        #if DEBUG
        authLog.notice("Google sign-in started with native GoogleSignIn.")
        #endif

        do {
            let rawNonce = AuthNonceGenerator.random()
            let hashedNonce = AuthNonceGenerator.sha256(rawNonce)
            let authSession = try await signInWithNativeGoogle(
                rawNonce: rawNonce,
                hashedNonce: hashedNonce
            )

            applyActiveSession(authSession)
            storeSignInProvider("Google", userID: authSession.user.id)
            authProviderInProgress = nil
            await bootstrapProfile(for: authSession.user)
            await syncCurrentDeviceTokenIfPossible()
            await applyPreferredSyncModeIfNeeded(userID: authSession.user.id)
            SyncCoordinator.shared.showTransientFeedback(
                title: "Signed In: Google",
                message: successMessage(for: authSession.user, providerName: "Google"),
                style: .success
            )
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
        authLog.debug("Incoming auth URL received. scheme=\(url.scheme ?? "none", privacy: .public) host=\(url.host ?? "none", privacy: .public)")
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        await handleAuthCallback(url)
    }

    func handleAuthCallback(_ url: URL) async {
        guard !isPreviewMode else { return }
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
            await bootstrapProfile(for: authSession.user)
            await syncCurrentDeviceTokenIfPossible()
            await applyPreferredSyncModeIfNeeded(userID: authSession.user.id)
            SyncCoordinator.shared.showTransientFeedback(
                title: provider.map { "Signed In: \($0)" } ?? "Signed In",
                message: successMessage(for: authSession.user, providerName: provider),
                style: .success
            )
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
        let previousUserID = currentUserID
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
            lastErrorMessage = nil
            clearStoredSignInProvider()
            await applyPreferredSyncModeIfNeeded(userID: nil)
            SyncCoordinator.shared.showTransientFeedback(
                title: "Signed Out",
                message: "ToDo returned this device to local mode.",
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

    func syncCurrentDeviceTokenIfPossible() async {
        guard !isPreviewMode else { return }
        guard let userID = currentUserID,
              let token = UserDefaults.standard.string(forKey: AppPreferences.Keys.remotePushDeviceToken),
              !token.isEmpty
        else {
            return
        }

        let payload = DeviceTokenUpsertPayload(
            userID: userID,
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
                .upsert(payload, onConflict: "push_provider,token")
                .execute()
           
           AppLog.info("APNs token synced to Supabase", logger: AppLog.auth)
        } catch {
            AppLog.error("Failed to sync APNs token: \(error)", logger: AppLog.auth)

            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshProfile() async {
        guard !isPreviewMode else { return }
        guard let currentUser = activeSession?.user else { return }
        await bootstrapProfile(for: currentUser)
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
            clearStoredSignInProvider()
            return
        }

        session = newSession
        currentUser = newSession.user
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

        #if DEBUG
        authLog.notice("Google sign-in token audience: \(Self.jwtStringClaim("aud", in: tokens.idToken) ?? "unknown", privacy: .public); app bundle: \(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public); iOS client: \(Self.infoPlistString("GIDClientID") ?? "missing", privacy: .public); server client: \(Self.infoPlistString("GIDServerClientID") ?? "missing", privacy: .public)")
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

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery:
            applyActiveSession(session, shouldClearWhenInactive: false)
            await applyPreferredSyncModeIfNeeded(userID: currentUserID)
            if let user = activeSession?.user {
                if storedSignInProvider(for: user.id) == nil,
                   let provider = inferredProviderLabel(for: user) {
                    storeSignInProvider(provider, userID: user.id)
                }
                await bootstrapProfile(for: user)
                await syncCurrentDeviceTokenIfPossible()
            }
        case .signedOut:
            self.session = nil
            currentUser = nil
            profile = nil
            clearStoredSignInProvider()
            await applyPreferredSyncModeIfNeeded(userID: nil)
        default:
            applyActiveSession(session, shouldClearWhenInactive: false)
        }
    }

    private func applyPreferredSyncModeIfNeeded(userID: UUID?) async {
        let syncKey = "\(SyncCoordinator.shared.preferredSyncMode.rawValue)|\(userID?.uuidString ?? "signed-out")"
        guard lastAppliedSyncKey != syncKey else { return }

        lastAppliedSyncKey = syncKey
        await SyncCoordinator.shared.applyPreferredSyncMode(userID: userID)
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
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        let existingProfile = await fetchExistingProfile(for: user.id)
        let payload = SupabaseProfileUpsertPayload(
            id: user.id,
            displayName: resolvedDisplayName(from: user, fullName: fullName) ?? existingProfile?.displayName,
            givenName: resolvedGivenName(from: user, fullName: fullName) ?? existingProfile?.givenName,
            familyName: resolvedFamilyName(from: user, fullName: fullName) ?? existingProfile?.familyName,
            preferredTimeZone: TimeZone.current.identifier
        )

        do {
            let record: SupabaseProfileRecord = try await supabase
                .from("profiles")
                .upsert(payload, onConflict: "id")
                .select()
                .single()
                .execute()
                .value

            profile = record
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func fetchExistingProfile(for userID: UUID) async -> SupabaseProfileRecord? {
        do {
            let records: [SupabaseProfileRecord] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .limit(1)
                .execute()
                .value

            return records.first
        } catch {
            return nil
        }
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

        return "Your ToDo Sync account is now connected.\(providerSuffix)"
    }

    private func authErrorMessage(for error: Error, providerName: String) -> String {
        let rawMessage = String(describing: error)
        let localizedMessage = error.localizedDescription
        let combinedMessage = "\(rawMessage) \(localizedMessage)".lowercased()

        if combinedMessage.contains("provider") && combinedMessage.contains("not enabled") {
            return "Sign In with \(providerName) is not enabled in Supabase Auth yet. Enable the \(providerName) provider in the Supabase dashboard, then try again."
        }

        if combinedMessage.contains("audience") || combinedMessage.contains("aud") || combinedMessage.contains("client_id") || combinedMessage.contains("invalid_client") {
            return "Sign In with \(providerName) was rejected because the provider client ID does not match this app’s current bundle ID (\(Bundle.main.bundleIdentifier ?? "unknown")). Verify the \(providerName) provider settings in Supabase and the provider console."
        }

        if combinedMessage.contains("nonce") {
            return "Sign In with \(providerName) was rejected because the identity token nonce did not match. Try again; if it repeats, the provider nonce settings need review."
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
            return "Google Sign-In could not find an active app window. Try again after ToDo finishes opening."
        case .missingResult:
            return "Google Sign-In finished without returning an account."
        case .missingIDToken:
            return "Google Sign-In did not return the identity token ToDo Sync needs."
        }
    }
}

private enum AuthNonceGenerator {
    static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
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
            return String(localized: "ToDo Sync")
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
            return String(localized: "ToDo Sync")
        }
    }

    func dataModeDescription(isAuthenticated: Bool) -> String {
        switch self {
        case .deviceOnly:
            return String(localized: "ToDo is running without a remote sync engine. Your data stays on this device until you choose a sync option.")
        case .iCloud:
            return String(localized: "ToDo is configured to sync through iCloud for Apple devices. This mode stays inside your private iCloud storage.")
        case .syncEverywhere:
            return isAuthenticated
                ? String(localized: "ToDo is running with ToDo Sync. Data is owner-scoped locally and synchronized through Supabase for cross-platform access.")
                : String(format: String(localized: "%@ is selected, but no account is signed in yet. ToDos stay on this device until you authenticate."), title)
        }
    }

}
