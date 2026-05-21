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
            let data = item as? Data else {
         return nil
      }

      return try? JSONDecoder().decode(WatchAuthSession.self, from: data)
   }

   func save(_ session: WatchAuthSession) throws {
      let data = try JSONEncoder().encode(session)
      var query = baseQuery
      let update = [kSecValueData as String: data]
      let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

      if status == errSecItemNotFound {
         query[kSecValueData as String] = data
         let addStatus = SecItemAdd(query as CFDictionary, nil)
         guard addStatus == errSecSuccess else { throw KeychainError.unhandledStatus(addStatus) }
         return
      }

      guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
   }

   func clear() {
      SecItemDelete(baseQuery as CFDictionary)
   }

   private var baseQuery: [String: Any] {
      [
         kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      ]
   }

   enum KeychainError: LocalizedError {
      case unhandledStatus(OSStatus)

      var errorDescription: String? {
         switch self {
         case .unhandledStatus(let status):
            return "Keychain failed with status \(status)."
         }
      }
   }
}
