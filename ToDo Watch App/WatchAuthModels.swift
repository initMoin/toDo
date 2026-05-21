import Foundation

extension WatchAuthState {
   var title: String {
      guard isAuthenticated else { return "Not Signed In" }

      switch source {
      case .iPhone:
         if let provider {
            return "Using iPhone: \(provider)"
         }
         return "Using iPhone Account"
      case .apple:
         return "Signed In: Apple"
      case .offline:
         return "Offline"
      }
   }

   var detail: String {
      if let email, !email.isEmpty {
         return email
      }

      switch source {
      case .iPhone:
         return "Synced from paired iPhone."
      case .apple:
         return "Account ready. Direct Watch sync comes next."
      case .offline:
         return "Capture still works when your iPhone is nearby."
      }
   }
}

struct WatchAuthSession: Codable, Equatable {
   let accessToken: String
   let refreshToken: String
   let expiresAt: Date?
   let userID: UUID
   let email: String?
   let provider: String
}
