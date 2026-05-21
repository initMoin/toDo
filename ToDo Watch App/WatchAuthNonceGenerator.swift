import CryptoKit
import Foundation
import Security

enum WatchAuthNonceGenerator {
   private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

   static func random(length: Int = 32) -> String {
      precondition(length > 0)
      var result = ""
      var remainingLength = length

      while remainingLength > 0 {
         var random: UInt8 = 0
         let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
         guard status == errSecSuccess else {
            fatalError("Unable to generate a secure nonce.")
         }

         if random < charset.count {
            result.append(charset[Int(random)])
            remainingLength -= 1
         }
      }

      return result
   }

   static func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      return hashedData.map { String(format: "%02x", $0) }.joined()
   }
}
