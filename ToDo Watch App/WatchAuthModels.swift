import Foundation

extension WatchAuthState {
   var title: String {
      guard isAuthenticated else { return String(localized: "Not Signed In") }

      guard isAccountResolved else {
         return String(localized: "Finish Account Setup")
      }

      switch source {
      case .iPhone:
         if let provider {
            return String(format: String(localized: "Using iPhone: %@"), provider)
         }
         return String(localized: "Using iPhone Account")
      case .apple:
         return String(localized: "Signed In: Apple")
      case .offline:
         return String(localized: "Offline")
      }
   }

   var detail: String {
      if isAuthenticated, !isAccountResolved {
         return String(localized: "Finish setup on iPhone, Mac, Android, or Web before Watch sync.")
      }

      if let email, !email.isEmpty {
         return email
      }

      switch source {
      case .iPhone:
         return String(localized: "Synced from paired iPhone.")
      case .apple:
         return String(localized: "Account ready. Direct Watch sync comes next.")
      case .offline:
         return String(localized: "Capture still works when your iPhone is nearby.")
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
