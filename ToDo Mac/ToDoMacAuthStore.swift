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
    subsystem: Bundle.main.bundleIdentifier ?? "dev.iamshift.toDo.mac",
    category: "MacAuth"
)

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
    @Published var lastErrorMessage: String?

    private lazy var supabase = SupabaseService.shared
    private var authStateTask: Task<Void, Never>?
    private var appleAuthorizationCoordinator: MacAppleAuthorizationCoordinator?
    private var lastAppliedSyncKey: String?

    private init() {}

    var isAuthenticated: Bool {
        activeSession != nil
    }

    var isAuthenticating: Bool {
        providerInProgress != nil
    }

    var currentUserID: UUID? {
        activeSession?.user.id
    }

    var signedInEmail: String? {
        activeSession?.user.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var accountDisplayName: String {
        signedInEmail ?? String(localized: "Signed In")
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

        guard SupabaseConfig.isConfigured else {
            let message = SupabaseConfig.configurationIssue ?? String(localized: "toDō Sync is not configured for this build.")
            lastErrorMessage = message
            macAuthLog.error("\(message, privacy: .public)")
            await applyPreferredSyncModeIfNeeded(userID: nil, force: true)
            return
        }

        applyActiveSession(supabase.auth.currentSession)
        await supabase.auth.startAutoRefresh()
        startAuthStateListener()
        await applyPreferredSyncModeIfNeeded(userID: currentUserID, force: true)
    }

    func signInWithApple() async {
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
            await applyPreferredSyncModeIfNeeded(userID: authSession.user.id, force: true)
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Signed In: Apple"),
                message: successMessage(for: authSession.user, providerName: "Apple"),
                style: .success
            )
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

    func signInWithGoogle() async {
        await signInWithOAuth(provider: .google, label: "Google", progress: .google)
    }

    func handleIncomingURL(_ url: URL) async {
        guard SupabaseConfig.isConfigured else { return }
        guard url.scheme?.caseInsensitiveCompare(SupabaseConfig.callbackScheme) == .orderedSame else { return }
        providerInProgress = .callback
        await finishAuthCallback(url)
    }

    func signOut() async {
        guard SupabaseConfig.isConfigured else {
            clearLocalSession()
            await applyPreferredSyncModeIfNeeded(userID: nil)
            return
        }

        do {
            try await supabase.auth.signOut()
            clearLocalSession()
            await applyPreferredSyncModeIfNeeded(userID: nil)
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Signed Out"),
                message: String(localized: "toDō now keeps what matters on this Mac."),
                style: .warning
            )
        } catch {
            lastErrorMessage = error.localizedDescription
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sign Out Failed"),
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    private func signInWithOAuth(provider: Provider, label: String, progress: ProviderInProgress) async {
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
        lastErrorMessage = nil

        do {
            let authSession = try await supabase.auth.signInWithOAuth(
                provider: provider,
                redirectTo: SupabaseConfig.redirectURL,
                configure: { session in
                    session.prefersEphemeralWebBrowserSession = false
                }
            )
            applyActiveSession(authSession)
            providerInProgress = nil
            await applyPreferredSyncModeIfNeeded(userID: authSession.user.id, force: true)
            SyncCoordinator.shared.showTransientFeedback(
                title: String(format: String(localized: "Signed In: %@"), label),
                message: successMessage(for: authSession.user, providerName: label),
                style: .success
            )
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

    private func finishAuthCallback(_ url: URL) async {
        do {
            let authSession = try await supabase.auth.session(from: url)
            applyActiveSession(authSession)
            providerInProgress = nil
            await applyPreferredSyncModeIfNeeded(userID: authSession.user.id, force: true)
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Signed In"),
                message: successMessage(for: authSession.user, providerName: providerLabel),
                style: .success
            )
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

        session = newSession
        currentUser = newSession.user
    }

    private func clearLocalSession() {
        session = nil
        currentUser = nil
        lastErrorMessage = nil
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
            await applyPreferredSyncModeIfNeeded(userID: currentUserID)
        case .signedOut:
            clearLocalSession()
            await applyPreferredSyncModeIfNeeded(userID: nil)
        default:
            applyActiveSession(session, shouldClearWhenInactive: false)
        }
    }

    private func applyPreferredSyncModeIfNeeded(userID: UUID?, force: Bool = false) async {
        let syncKey = "\(SyncCoordinator.shared.preferredSyncMode.rawValue)|\(userID?.uuidString ?? "signed-out")"
        guard force || lastAppliedSyncKey != syncKey || SyncCoordinator.shared.preferredSyncMode == .syncEverywhere else { return }
        await SyncCoordinator.shared.applyPreferredSyncMode(userID: userID)
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
