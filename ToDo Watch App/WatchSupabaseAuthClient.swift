import Foundation

enum WatchSupabaseConfiguration {
   static var supabaseURL: URL? {
      guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
         return nil
      }
      return URL(string: value)
   }

   static var publishableKey: String? {
      guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !value.isEmpty
      else {
         return nil
      }
      return value
   }
}

struct WatchSupabaseAuthClient {
   private let supabaseURL: URL
   private let publishableKey: String
   private let session: URLSession

   init?(
      bundle: Bundle = .main,
      session: URLSession = .shared
   ) {
      guard let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseURL = URL(string: urlString),
            let publishableKey = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty
      else {
         return nil
      }

      self.supabaseURL = supabaseURL
      self.publishableKey = publishableKey
      self.session = session
   }

   func signInWithApple(idToken: String, nonce: String) async throws -> WatchAuthSession {
      var components = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
      components?.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
      guard let url = components?.url else {
         throw WatchSupabaseAuthError.invalidConfiguration
      }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try Self.encoder.encode(AppleIDTokenRequest(provider: "apple", idToken: idToken, nonce: nonce))

      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw WatchSupabaseAuthError.invalidResponse
      }

      guard (200..<300).contains(httpResponse.statusCode) else {
         let errorResponse = try? Self.decoder.decode(SupabaseErrorResponse.self, from: data)
         throw WatchSupabaseAuthError.server(errorResponse?.message ?? errorResponse?.errorDescription ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
      }

      let authResponse = try Self.decoder.decode(SupabaseAuthResponse.self, from: data)
      guard let userID = UUID(uuidString: authResponse.user.id) else {
         throw WatchSupabaseAuthError.invalidResponse
      }

      return WatchAuthSession(
         accessToken: authResponse.accessToken,
         refreshToken: authResponse.refreshToken,
         expiresAt: authResponse.expiresAtDate,
         userID: userID,
         email: authResponse.user.email,
         provider: "Apple"
      )
   }

   func fetchProfile(accessToken: String, userID: UUID) async throws -> WatchProfileRecord? {
      var components = URLComponents(
         url: supabaseURL.appendingPathComponent("rest/v1/profiles"),
         resolvingAgainstBaseURL: false
      )
      components?.queryItems = [
         URLQueryItem(name: "id", value: "eq.\(userID.uuidString)"),
         URLQueryItem(name: "select", value: "id,username,account_setup_version")
      ]
      guard let url = components?.url else {
         throw WatchSupabaseAuthError.invalidConfiguration
      }

      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Accept")

      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw WatchSupabaseAuthError.invalidResponse
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
         let errorResponse = try? Self.decoder.decode(SupabaseErrorResponse.self, from: data)
         throw WatchSupabaseAuthError.server(
            errorResponse?.message ?? errorResponse?.errorDescription ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
         )
      }

      return try Self.decoder.decode([WatchProfileRecord].self, from: data).first
   }

#if DEBUG
   func signInWithPassword(email: String, password: String) async throws -> WatchAuthSession {
      var components = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
      components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
      guard let url = components?.url else {
         throw WatchSupabaseAuthError.invalidConfiguration
      }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try Self.encoder.encode(PasswordAuthRequest(email: email, password: password))

      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw WatchSupabaseAuthError.invalidResponse
      }

      guard (200..<300).contains(httpResponse.statusCode) else {
         let errorResponse = try? Self.decoder.decode(SupabaseErrorResponse.self, from: data)
         throw WatchSupabaseAuthError.server(errorResponse?.message ?? errorResponse?.errorDescription ?? errorResponse?.msg ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
      }

      let authResponse = try Self.decoder.decode(SupabaseAuthResponse.self, from: data)
      guard let userID = UUID(uuidString: authResponse.user.id) else {
         throw WatchSupabaseAuthError.invalidResponse
      }

      return WatchAuthSession(
         accessToken: authResponse.accessToken,
         refreshToken: authResponse.refreshToken,
         expiresAt: authResponse.expiresAtDate,
         userID: userID,
         email: authResponse.user.email,
         provider: "Simulator"
      )
   }
#endif

   private static let encoder: JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      return encoder
   }()

   private static let decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return decoder
   }()
}

struct WatchProfileRecord: Codable, Sendable {
   let id: UUID
   let username: String?
   let accountSetupVersion: Int?

   var isResolved: Bool {
      guard let username, !username.isEmpty else { return false }
      return (accountSetupVersion ?? 1) >= 2
   }
}

private struct AppleIDTokenRequest: Encodable {
   let provider: String
   let idToken: String
   let nonce: String
}

#if DEBUG
private struct PasswordAuthRequest: Encodable {
   let email: String
   let password: String
}
#endif

private struct SupabaseAuthResponse: Decodable {
   let accessToken: String
   let refreshToken: String
   let expiresAt: Int?
   let expiresIn: Int?
   let user: SupabaseAuthUser

   var expiresAtDate: Date? {
      if let expiresAt {
         return Date(timeIntervalSince1970: TimeInterval(expiresAt))
      }
      if let expiresIn {
         return Date().addingTimeInterval(TimeInterval(expiresIn))
      }
      return nil
   }
}

private struct SupabaseAuthUser: Decodable {
   let id: String
   let email: String?
}

private struct SupabaseErrorResponse: Decodable {
   let message: String?
   let errorDescription: String?
   let msg: String?

   enum CodingKeys: String, CodingKey {
      case message
      case errorDescription = "error_description"
      case msg
   }
}

enum WatchSupabaseAuthError: LocalizedError {
   case invalidConfiguration
   case invalidResponse
   case server(String)

   var errorDescription: String? {
      switch self {
      case .invalidConfiguration:
         return String(localized: "toDō Sync is not configured on this Watch.")
      case .invalidResponse:
         return String(localized: "Supabase returned an invalid auth response.")
      case .server(let message):
         return message
      }
   }
}
