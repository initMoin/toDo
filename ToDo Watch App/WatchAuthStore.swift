import Combine
import Foundation

@MainActor
final class WatchAuthStore: ObservableObject {
   @Published private(set) var authState: WatchAuthState = .offline
   @Published private(set) var isSigningIn = false
   @Published private(set) var errorMessage: String?
   @Published private(set) var standaloneSession: WatchAuthSession?

   var hasResolvedAccount: Bool {
      authState.isAuthenticated && authState.isAccountResolved
   }

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
      Task { await resolveStandaloneSession(session) }
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
         await resolveStandaloneSession(session)
      } catch {
         errorMessage = error.localizedDescription
      }
   }

#if DEBUG
   func signInWithSimulatorAccount(email: String, password: String) async {
      guard let authClient else {
         errorMessage = String(localized: "toDō Sync is not configured on this Watch.")
         return
      }

      let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedEmail.isEmpty, !password.isEmpty else {
         errorMessage = String(localized: "Enter the simulator test account email and password.")
         return
      }

      isSigningIn = true
      errorMessage = nil
      defer { isSigningIn = false }

      do {
         let session = try await authClient.signInWithPassword(email: trimmedEmail, password: password)
         try sessionStore.save(session)
         applyStandaloneSession(session)
         await resolveStandaloneSession(session)
      } catch {
         errorMessage = error.localizedDescription
      }
   }
#endif

   func signOut() {
      sessionStore.clear()
      standaloneSession = nil
      authState = .offline
      errorMessage = nil
   }

   func deleteAccount() async throws {
      guard let session = standaloneSession else {
         throw WatchAccountDeletionError.notSignedIn
      }

      try await WatchAccountDeletionService.deleteAccount(
         accessToken: session.accessToken
      )
      signOut()
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
         isAccountResolved: false,
         userID: session.userID,
         provider: session.provider,
         email: session.email,
         source: .apple
      )
      errorMessage = String(localized: "Checking your toDō account…")
   }

   private func resolveStandaloneSession(_ session: WatchAuthSession) async {
      guard let authClient else { return }

      do {
         let profile = try await authClient.fetchProfile(
            accessToken: session.accessToken,
            userID: session.userID
         )
         guard let profile else {
            errorMessage = String(localized: "Finish account setup on iPhone, Mac, Android, or Web before Watch sync.")
            return
         }

         authState = WatchAuthState(
            isAuthenticated: true,
            isAccountResolved: profile.isResolved,
            userID: session.userID,
            provider: session.provider,
            email: session.email,
            username: profile.username,
            accountSetupVersion: profile.accountSetupVersion,
            source: .apple
         )
         errorMessage = profile.isResolved
            ? nil
            : String(localized: "Finish account setup on iPhone, Mac, Android, or Web before Watch sync.")
      } catch {
         errorMessage = String(localized: "Your account could not be resolved. Open toDō on another device and finish setup.")
      }
   }
}

enum WatchAccountDeletionError: LocalizedError {
   case notSignedIn

   var errorDescription: String? {
      String(localized: "Sign in before deleting this account.")
   }
}

enum WatchAccountDeletionService {
   static func deleteAccount(accessToken: String) async throws {
      guard let supabaseURL = WatchSupabaseConfiguration.supabaseURL,
            let publishableKey = WatchSupabaseConfiguration.publishableKey
      else {
         throw WatchSupabaseAuthError.invalidConfiguration
      }

      var request = URLRequest(
         url: supabaseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("delete-account")
      )
      request.httpMethod = "POST"
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = Data("{}".utf8)

      let (_, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode) else {
         throw URLError(.badServerResponse)
      }
   }
}
