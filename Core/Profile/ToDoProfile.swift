import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ToDoProfileImageScope: String, CaseIterable, Sendable {
    case thisDevice
    case appleDevices
    case allDevices
}

nonisolated enum ToDoProfileImageStore {
    enum StorageError: Error {
        case iCloudUnavailable
    }

    static let didChangeNotification = Notification.Name("toDo.profileImageDidChange")

    private static let directoryName = "Profile Images"
    private static let fileName = "avatar.jpg"
    private static let offsetKeyPrefix = "toDo.profileImageOffset."
    private static let revisionKeyPrefix = "toDo.profileImageRevision."
    private static let scopeKeyPrefix = "toDo.profileImageScope."

    /// PhotosPicker and file imports can provide PNG, JPEG, HEIF, and other
    /// ImageIO-backed raster data. Keep the stored representation consistent,
    /// but validate the source as an image before normalizing it.
    static func supportsImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source) as String?,
              let type = UTType(typeIdentifier) else {
            return false
        }

        return type.conforms(to: .image)
    }

    static func normalizedJPEGData(from data: Data) -> Data? {
        guard supportsImageData(data),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Downsample at the ImageIO boundary. HEIC images from Photos can be
        // very large; decoding the original on the main UI path is both
        // memory-heavy and more likely to fail on macOS.
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
        ]
        let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        guard let image else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func save(_ data: Data, for userID: UUID, scope: ToDoProfileImageScope) throws {
        guard scope != .appleDevices || isICloudAvailable else {
            throw StorageError.iCloudUnavailable
        }

        // Keep a device-local copy for immediate rendering. iCloud coordination
        // can lag behind the save, and a local cache prevents the rest of the
        // current app session from falling back to initials.
        try saveToDirectory(data, for: userID, scope: .thisDevice)
        guard scope != .thisDevice else { return }
        try saveToDirectory(data, for: userID, scope: scope)
    }

    private static func saveToDirectory(
        _ data: Data,
        for userID: UUID,
        scope: ToDoProfileImageScope
    ) throws {
        let directory = try directoryURL(scope: scope)
            .appendingPathComponent(userID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(fileName), options: [.atomic])
    }

    static func load(for userID: UUID) -> Data? {
        // The device-local copy is the immediate source of truth after a save.
        // Fall back to iCloud only when this device has no local copy yet.
        for scope in [ToDoProfileImageScope.thisDevice, .appleDevices] {
            guard let url = try? directoryURL(scope: scope)
                .appendingPathComponent(userID.uuidString, isDirectory: true)
                .appendingPathComponent(fileName),
                FileManager.default.fileExists(atPath: url.path),
                let data = try? Data(contentsOf: url) else {
                continue
            }
            return data
        }
        return nil
    }

    /// Returns whether a device-local or iCloud-backed copy exists without
    /// decoding the image. This keeps profile settings useful for images saved
    /// by an older build before the scope preference was persisted.
    static func hasStoredImage(for userID: UUID) -> Bool {
        [ToDoProfileImageScope.thisDevice, .appleDevices].contains { scope in
            guard let url = try? directoryURL(scope: scope)
                .appendingPathComponent(userID.uuidString, isDirectory: true)
                .appendingPathComponent(fileName) else {
                return false
            }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
            && FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.dev.iamshift.toDo") != nil
    }

    static func loadOffset(for userID: UUID) -> CGSize {
        let values = UserDefaults.standard.array(forKey: offsetKeyPrefix + userID.uuidString) as? [Double]
        guard let values, values.count == 2 else { return .zero }
        return CGSize(width: values[0], height: values[1])
    }

    static func saveOffset(_ offset: CGSize, for userID: UUID) {
        UserDefaults.standard.set([Double(offset.width), Double(offset.height)], forKey: offsetKeyPrefix + userID.uuidString)
    }

    /// Avatar editors store their position in a 250-point canvas. Scale that
    /// position for each rendered avatar and clamp old values to the editor's
    /// supported range so the image cannot disappear from the circle.
    static func displayOffset(_ sourceOffset: CGSize, for size: CGFloat) -> CGSize {
        let scale = max(size, 0) / 250
        let limit = 88 * scale
        return CGSize(
            width: min(max(sourceOffset.width * scale, -limit), limit),
            height: min(max(sourceOffset.height * scale, -limit), limit)
        )
    }

    static func scope(for userID: UUID, remoteAvatarURL: String? = nil) -> ToDoProfileImageScope? {
        let scopeKey = scopeKeyPrefix + userID.uuidString
        let rawValue = UserDefaults.standard.string(forKey: scopeKey)
            ?? NSUbiquitousKeyValueStore.default.string(forKey: scopeKey)
        if let rawValue,
           let scope = ToDoProfileImageScope(rawValue: rawValue) {
            return scope
        }

        // A remote avatar is the server-backed representation used by the
        // all-devices option. This fallback also gives existing accounts a
        // useful answer before they next save their scope preference.
        if remoteAvatarURL != nil {
            return .allDevices
        }
        return nil
    }

    static func saveScope(_ scope: ToDoProfileImageScope, for userID: UUID) {
        let scopeKey = scopeKeyPrefix + userID.uuidString
        UserDefaults.standard.set(scope.rawValue, forKey: scopeKey)
        NSUbiquitousKeyValueStore.default.set(scope.rawValue, forKey: scopeKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    static func clearScope(for userID: UUID) {
        let scopeKey = scopeKeyPrefix + userID.uuidString
        UserDefaults.standard.removeObject(forKey: scopeKey)
        NSUbiquitousKeyValueStore.default.removeObject(forKey: scopeKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    static func clear(for userID: UUID) {
        for scope in [ToDoProfileImageScope.thisDevice, .appleDevices] {
            guard let directory = try? directoryURL(scope: scope)
                .appendingPathComponent(userID.uuidString, isDirectory: true) else {
                continue
            }
            try? FileManager.default.removeItem(at: directory)
        }

        UserDefaults.standard.removeObject(forKey: offsetKeyPrefix + userID.uuidString)
        UserDefaults.standard.removeObject(forKey: revisionKeyPrefix + userID.uuidString)
        clearScope(for: userID)
        NotificationCenter.default.post(name: didChangeNotification, object: userID)
    }

    /// Persists a user-scoped revision and notifies all in-process avatar surfaces.
    @discardableResult
    static func bumpRevision(for userID: UUID) -> Int {
        let key = revisionKeyPrefix + userID.uuidString
        let revision = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(revision, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: userID)
        return revision
    }

    private static func directoryURL(scope: ToDoProfileImageScope) throws -> URL {
        if scope == .appleDevices,
           let ubiquityURL = FileManager.default.url(
               forUbiquityContainerIdentifier: "iCloud.dev.iamshift.toDo"
           ) {
            return ubiquityURL.appendingPathComponent(directoryName, isDirectory: true)
        }

        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent(directoryName, isDirectory: true)
    }
}

/// The validated, platform-independent payload used by the iOS and Mac
/// profile-image upload paths. Network clients still own their Supabase
/// requests, but image normalization and storage identity must not diverge.
nonisolated struct ToDoProfileImagePreparation: Sendable {
    enum PreparationError: Error {
        case unreadableImage
        case tooLarge
        case iCloudUnavailable
    }

    static let maximumByteCount = 5 * 1024 * 1024

    let data: Data
    let userID: UUID
    let scope: ToDoProfileImageScope
    let remotePath: String

    static func prepare(
        sourceData: Data,
        userID: UUID,
        scope: ToDoProfileImageScope
    ) throws -> Self {
        guard let data = ToDoProfileImageStore.normalizedJPEGData(from: sourceData) else {
            throw PreparationError.unreadableImage
        }
        guard data.count <= maximumByteCount else {
            throw PreparationError.tooLarge
        }
        guard scope != .appleDevices || ToDoProfileImageStore.isICloudAvailable else {
            throw PreparationError.iCloudUnavailable
        }

        return Self(
            data: data,
            userID: userID,
            scope: scope,
            remotePath: "\(userID.uuidString.lowercased())/avatar.jpg"
        )
    }
}

nonisolated struct SupabaseProfileRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var username: String?
    var accountSetupVersion: Int?
    var displayName: String?
    var givenName: String?
    var familyName: String?
    var avatarURL: String?
    var preferredTimeZone: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case accountSetupVersion = "account_setup_version"
        case displayName = "display_name"
        case givenName = "given_name"
        case familyName = "family_name"
        case avatarURL = "avatar_url"
        case preferredTimeZone = "preferred_time_zone"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// The provider proves account ownership; this intent tells the account
/// resolver what username the user meant to reach before that proof arrives.
nonisolated enum ToDoAccountAuthenticationIntent: String, Equatable, Sendable {
    case createAccount
    case signIn
    case restoreSession
}

nonisolated enum ToDoAccountResolutionState: Equatable, Sendable {
    case signedOut
    case authenticating(intent: ToDoAccountAuthenticationIntent, expectedUsername: String?)
    case resolving(intent: ToDoAccountAuthenticationIntent, expectedUsername: String?)
    case needsUsername(intent: ToDoAccountAuthenticationIntent)
    case migrationRequired(username: String?)
    case accountMismatch(expectedUsername: String, actualUsername: String)
    case resolved(accountID: UUID, username: String)
}

nonisolated enum ToDoAccountResolutionPolicy {
    static let completedSetupVersion = 2

    static func state(
        profile: SupabaseProfileRecord,
        intent: ToDoAccountAuthenticationIntent,
        expectedUsername: String?
    ) -> ToDoAccountResolutionState {
        guard let username = profile.username,
              let normalizedUsername = try? ToDoProfilePolicy.validatedUsername(username) else {
            return .needsUsername(intent: intent)
        }

        if let expectedUsername,
           let normalizedExpected = try? ToDoProfilePolicy.validatedUsername(expectedUsername),
           normalizedExpected != normalizedUsername,
           intent == .signIn || intent == .createAccount {
            return .accountMismatch(
                expectedUsername: normalizedExpected,
                actualUsername: normalizedUsername
            )
        }

        guard (profile.accountSetupVersion ?? 1) >= completedSetupVersion else {
            return .migrationRequired(username: normalizedUsername)
        }

        return .resolved(accountID: profile.id, username: normalizedUsername)
    }
}

nonisolated struct ToDoProfileBootstrapPayload: Encodable, Sendable {
    let id: UUID
    let displayName: String?
    let givenName: String?
    let familyName: String?
    let preferredTimeZone: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case givenName = "given_name"
        case familyName = "family_name"
        case preferredTimeZone = "preferred_time_zone"
    }
}

nonisolated struct ToDoProfileDisplayNamePayload: Encodable, Sendable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

nonisolated struct ToDoProfileAvatarPayload: Encodable, Sendable {
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}

nonisolated enum ToDoProfileStoreError: Error, Sendable {
    case missingProfile
}

nonisolated enum ToDoProfileValidationError: LocalizedError, Equatable, Sendable {
    case emptyDisplayName
    case displayNameTooLong(maximum: Int)
    case invalidUsername
    case usernameTooLong(maximum: Int)

    var errorDescription: String? {
        switch self {
        case .emptyDisplayName:
            String(localized: "Enter a display name.")
        case .displayNameTooLong(let maximum):
            String(
                format: String(localized: "Keep your display name to %lld characters or fewer."),
                maximum
            )
        case .invalidUsername:
            String(localized: "Use a username with letters, numbers, periods, or underscores.")
        case .usernameTooLong(let maximum):
            String(
                format: String(localized: "Keep your username to %lld characters or fewer."),
                maximum
            )
        }
    }
}

nonisolated enum ToDoProfilePolicy {
    static let maximumDisplayNameLength = 60
    static let maximumUsernameLength = 30

    static func validatedDisplayName(_ value: String) throws -> String {
        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !normalized.isEmpty else {
            throw ToDoProfileValidationError.emptyDisplayName
        }
        guard normalized.count <= maximumDisplayNameLength else {
            throw ToDoProfileValidationError.displayNameTooLong(
                maximum: maximumDisplayNameLength
            )
        }
        return normalized
    }

    static func resolvedDisplayName(
        profile: SupabaseProfileRecord?,
        email: String?
    ) -> String {
        if let displayName = normalizedNonempty(profile?.displayName) {
            return displayName
        }

        let fullName = [profile?.givenName, profile?.familyName]
            .compactMap(normalizedNonempty)
            .joined(separator: " ")
        if !fullName.isEmpty {
            return fullName
        }

        if let emailName = normalizedNonempty(email?.split(separator: "@").first.map(String.init)) {
            return emailName
        }
        return String(localized: "toDō User")
    }

    static func validatedUsername(_ value: String) throws -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^@", with: "", options: .regularExpression)
            .lowercased()

        guard normalized.count >= 3,
              normalized.count <= maximumUsernameLength,
              normalized.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 48...57, 97...122, 46, 95:
                      true
                  default:
                      false
                  }
              }),
              !normalized.hasPrefix("."),
              !normalized.hasSuffix(".") else {
            if normalized.count > maximumUsernameLength {
                throw ToDoProfileValidationError.usernameTooLong(maximum: maximumUsernameLength)
            }
            throw ToDoProfileValidationError.invalidUsername
        }
        return normalized
    }

    static func displayUsername(_ username: String?) -> String? {
        guard let username = username?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty else { return nil }
        return username.hasPrefix("@") ? username : "@\(username)"
    }

    static func initials(
        profile: SupabaseProfileRecord?,
        email: String?
    ) -> String {
        initials(from: resolvedDisplayName(profile: profile, email: email))
    }

    static func initials(from displayName: String) -> String {
        let components = displayName
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard let first = components.first else { return "?" }
        if let last = components.dropFirst().last,
           let firstCharacter = first.first,
           let lastCharacter = last.first {
            return String([firstCharacter, lastCharacter]).uppercased()
        }

        let characters = Array(first.prefix(2))
        return characters.isEmpty ? "?" : String(characters).uppercased()
    }

    static func avatarURL(from value: String?) -> URL? {
        guard let value = normalizedNonempty(value),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    private static func normalizedNonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
