import Foundation
import Security

struct WatchSecureSessionStore {
   private let service = "dev.iamshift.toDo.watch.auth"
   private let account = "supabase-session"

   func load() -> WatchAuthSession? {
      var query = baseQuery
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne

      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      guard status == errSecSuccess,
            let data = item as? Data
      else {
         return nil
      }

      return try? JSONDecoder().decode(WatchAuthSession.self, from: data)
   }

   func save(_ session: WatchAuthSession) throws {
      let data = try JSONEncoder().encode(session)
      var query = baseQuery
      query[kSecValueData as String] = data
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

      let status = SecItemAdd(query as CFDictionary, nil)
      if status == errSecDuplicateItem {
         let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
         guard updateStatus == errSecSuccess else {
            throw WatchSecureSessionError.keychain(updateStatus)
         }
         return
      }

      guard status == errSecSuccess else {
         throw WatchSecureSessionError.keychain(status)
      }
   }

   func clear() {
      SecItemDelete(baseQuery as CFDictionary)
   }

   private var baseQuery: [String: Any] {
      [
         kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account
      ]
   }
}

enum WatchSecureSessionError: LocalizedError {
   case keychain(OSStatus)

   var errorDescription: String? {
      switch self {
      case .keychain:
         return String(localized: "Watch sign-in could not be saved. Try again.")
      }
   }
}
