import Combine
import Foundation

@MainActor
final class WatchAuthStore: ObservableObject {
   @Published private(set) var authState: WatchAuthState = .offline
   @Published private(set) var isSigningIn = false
   @Published private(set) var errorMessage: String?
   @Published private(set) var standaloneSession: WatchAuthSession?

   static let expiredSessionMessage = "Session expired. Sign in again."
   private let authClient = WatchSupabaseAuthClient()
   private let sessionStore = WatchSecureSessionStore()

   init() {}

   func start() {
      guard let session = sessionStore.load() else { return }

      if let expiresAt = session.expiresAt, expiresAt <= Date() {
         expireStandaloneSession()
         return
      }

      applyStandaloneSession(session)
   }

   func applyPhoneAuthState(_ phoneAuthState: WatchAuthState?) {
      guard let phoneAuthState else { return }

      if authState.source == .apple, authState.isAuthenticated {
         return
      }

      if phoneAuthState.isAuthenticated {
         authState = phoneAuthState
         errorMessage = nil
         return
      }

      authState = phoneAuthState
   }

   func signInWithApple(idToken: String, rawNonce: String) async {
      guard let authClient else {
         errorMessage = String(localized: "toDō Sync is not configured on this Watch.")
         return
      }

      isSigningIn = true
      errorMessage = nil
      defer { isSigningIn = false }

      do {
         let session = try await authClient.signInWithApple(idToken: idToken, nonce: rawNonce)
         try sessionStore.save(session)
         applyStandaloneSession(session)
      } catch {
         errorMessage = error.localizedDescription
      }
   }

   func signOut() {
      sessionStore.clear()
      standaloneSession = nil
      authState = .offline
      errorMessage = nil
   }

   func expireStandaloneSession() {
      sessionStore.clear()
      standaloneSession = nil
      authState = .offline
      errorMessage = Self.expiredSessionMessage
   }

   private func applyStandaloneSession(_ session: WatchAuthSession) {
      standaloneSession = session
      authState = WatchAuthState(
         isAuthenticated: true,
         userID: session.userID,
         provider: session.provider,
         email: session.email,
         source: .apple
      )
      errorMessage = nil
   }
}
