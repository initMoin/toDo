import Combine
import Foundation

@MainActor
final class WatchAuthStore: ObservableObject {
   @Published private(set) var authState: WatchAuthState = .offline
   @Published private(set) var errorMessage: String?

   static let expiredSessionMessage = "Session expired. Sign in again."

   init() {}

   func applyPhoneAuthState(_ phoneAuthState: WatchAuthState?) {
      guard let phoneAuthState else { return }

      if phoneAuthState.isAuthenticated {
         authState = phoneAuthState
         errorMessage = nil
         return
      }

      authState = phoneAuthState
   }

   func signOut() {
      authState = .offline
      errorMessage = nil
   }

   func expireStandaloneSession() {
      authState = .offline
      errorMessage = Self.expiredSessionMessage
   }
}
