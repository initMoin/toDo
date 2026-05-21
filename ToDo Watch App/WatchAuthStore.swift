import AuthenticationServices
import Combine
import Foundation

@MainActor
final class WatchAuthStore: ObservableObject {
   @Published private(set) var authState: WatchAuthState = .offline
   @Published private(set) var isSigningIn = false
   @Published private(set) var errorMessage: String?

   static let expiredSessionMessage = "Session expired. Sign in again."

   private let client = WatchSupabaseAuthClient()
   private var currentRawNonce: String?

   init() {
      if let session = client?.storedSession() {
         authState = WatchAuthState(
            isAuthenticated: true,
            userID: session.userID,
            provider: session.provider,
            email: session.email,
            source: .apple
         )
      }
   }

   func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
      let rawNonce = WatchAuthNonceGenerator.random()
      currentRawNonce = rawNonce
      request.requestedScopes = [.email, .fullName]
      request.nonce = WatchAuthNonceGenerator.sha256(rawNonce)
   }

   func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
      Task { @MainActor in
         await finishAppleAuthorization(result)
      }
   }

   func applyPhoneAuthState(_ phoneAuthState: WatchAuthState?) {
      guard let phoneAuthState else { return }

      if phoneAuthState.isAuthenticated {
         authState = phoneAuthState
         errorMessage = nil
         return
      }

      if client?.storedSession() == nil {
         authState = phoneAuthState
      }
   }

   func signOut() {
      client?.signOut()
      authState = .offline
      errorMessage = nil
   }

   func standaloneSession() -> WatchAuthSession? {
      client?.storedSession()
   }

   func validStandaloneSession() async throws -> WatchAuthSession? {
      guard let session = try await client?.validStoredSession() else { return nil }
      apply(session)
      return session
   }

   func refreshStandaloneSession() async throws -> WatchAuthSession? {
      guard let session = try await client?.refreshStoredSession() else { return nil }
      apply(session)
      return session
   }

   func expireStandaloneSession() {
      client?.signOut()
      authState = .offline
      errorMessage = Self.expiredSessionMessage
   }

   private func apply(_ session: WatchAuthSession) {
      authState = WatchAuthState(
         isAuthenticated: true,
         userID: session.userID,
         provider: session.provider,
         email: session.email,
         source: .apple
      )
      errorMessage = nil
   }

   private func finishAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
      guard let client else {
         errorMessage = AuthError.missingConfiguration.localizedDescription
         return
      }

      switch result {
      case .success(let authorization):
         guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = credential.identityToken,
               let idToken = String(data: identityToken, encoding: .utf8),
               let rawNonce = currentRawNonce else {
            errorMessage = "Apple did not return a usable identity token."
            return
         }

         isSigningIn = true
         errorMessage = nil
         defer {
            isSigningIn = false
            currentRawNonce = nil
         }

         do {
            let session = try await client.signInWithApple(idToken: idToken, rawNonce: rawNonce)
            apply(session)
         } catch {
            errorMessage = error.localizedDescription
         }
      case .failure(let error):
         currentRawNonce = nil
         if let authorizationError = error as? ASAuthorizationError,
            authorizationError.code == .canceled {
            return
         }
         errorMessage = error.localizedDescription
      }
   }
}
