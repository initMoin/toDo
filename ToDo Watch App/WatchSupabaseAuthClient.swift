import Foundation

struct WatchSupabaseAuthClient {
   private let supabaseURL: URL
   private let publishableKey: String
   private let sessionStore = WatchSecureSessionStore()

   init?() {
      guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty else {
         return nil
      }

      self.supabaseURL = url
      self.publishableKey = publishableKey
   }

   func signInWithApple(idToken: String, rawNonce: String) async throws -> WatchAuthSession {
      let endpoint = supabaseURL
         .appending(path: "auth/v1/token")
         .appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")])
      var request = URLRequest(url: endpoint)
      request.httpMethod = "POST"
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(IDTokenRequest(provider: "apple", idToken: idToken, nonce: rawNonce))

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw AuthError.invalidResponse
      }

      guard (200..<300).contains(httpResponse.statusCode) else {
         throw AuthError.rejected(errorMessage(from: data) ?? "Supabase rejected Apple sign-in.")
      }

      let tokenResponse = try JSONDecoder.supabaseAuth.decode(TokenResponse.self, from: data)
      let session = WatchAuthSession(
         accessToken: tokenResponse.accessToken,
         refreshToken: tokenResponse.refreshToken,
         expiresAt: tokenResponse.resolvedExpiresAt,
         userID: tokenResponse.user.id,
         email: tokenResponse.user.email,
         provider: "Apple"
      )
      try sessionStore.save(session)
      return session
   }

   func validStoredSession(refreshLeeway: TimeInterval = 5 * 60) async throws -> WatchAuthSession? {
      guard let session = storedSession() else { return nil }

      guard let expiresAt = session.expiresAt,
            expiresAt.timeIntervalSinceNow <= refreshLeeway else {
         return session
      }

      return try await refresh(session)
   }

   func refreshStoredSession() async throws -> WatchAuthSession? {
      guard let session = storedSession() else { return nil }
      return try await refresh(session)
   }

   func storedSession() -> WatchAuthSession? {
      sessionStore.load()
   }

   func signOut() {
      sessionStore.clear()
   }

   private func refresh(_ session: WatchAuthSession) async throws -> WatchAuthSession {
      let endpoint = supabaseURL
         .appending(path: "auth/v1/token")
         .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])
      var request = URLRequest(url: endpoint)
      request.httpMethod = "POST"
      request.setValue(publishableKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(RefreshTokenRequest(refreshToken: session.refreshToken))

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
         throw AuthError.invalidResponse
      }

      guard (200..<300).contains(httpResponse.statusCode) else {
         throw AuthError.rejected(errorMessage(from: data) ?? "Supabase rejected session refresh.")
      }

      let tokenResponse = try JSONDecoder.supabaseAuth.decode(TokenResponse.self, from: data)
      let refreshedSession = WatchAuthSession(
         accessToken: tokenResponse.accessToken,
         refreshToken: tokenResponse.refreshToken,
         expiresAt: tokenResponse.resolvedExpiresAt,
         userID: tokenResponse.user.id,
         email: tokenResponse.user.email ?? session.email,
         provider: session.provider
      )
      try sessionStore.save(refreshedSession)
      return refreshedSession
   }

   private func errorMessage(from data: Data) -> String? {
      if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
         return errorResponse.errorDescription ?? errorResponse.message ?? errorResponse.error
      }
      return String(data: data, encoding: .utf8)
   }
}

private struct IDTokenRequest: Encodable {
   let provider: String
   let idToken: String
   let nonce: String

   enum CodingKeys: String, CodingKey {
      case provider
      case idToken = "id_token"
      case nonce
   }
}

private struct RefreshTokenRequest: Encodable {
   let refreshToken: String

   enum CodingKeys: String, CodingKey {
      case refreshToken = "refresh_token"
   }
}

private struct TokenResponse: Decodable {
   let accessToken: String
   let refreshToken: String
   let expiresIn: TimeInterval?
   let expiresAt: TimeInterval?
   let user: AuthUser

   var resolvedExpiresAt: Date? {
      if let expiresAt {
         return Date(timeIntervalSince1970: expiresAt)
      }
      if let expiresIn {
         return Date(timeIntervalSinceNow: expiresIn)
      }
      return nil
   }
}

private struct AuthUser: Decodable {
   let id: UUID
   let email: String?
}

private struct ErrorResponse: Decodable {
   let error: String?
   let message: String?
   let errorDescription: String?
}

private extension JSONDecoder {
   static var supabaseAuth: JSONDecoder {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return decoder
   }
}

enum AuthError: LocalizedError {
   case invalidResponse
   case rejected(String)
   case missingConfiguration

   var errorDescription: String? {
      switch self {
      case .invalidResponse:
         return "Supabase returned an invalid auth response."
      case .rejected(let message):
         return message
      case .missingConfiguration:
         return "toDō Sync is not configured on this Watch app."
      }
   }
}

private extension URL {
   func appending(queryItems: [URLQueryItem]) -> URL {
      guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
      components.queryItems = (components.queryItems ?? []) + queryItems
      return components.url ?? self
   }
}
