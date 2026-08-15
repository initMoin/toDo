import Combine
import Foundation

extension Notification.Name {
    static let toDoCollaborationMembershipDidChange = Notification.Name(
        "toDo.collaborationMembershipDidChange"
    )
    static let toDoCollaborationInvitationReceived = Notification.Name(
        "toDo.collaborationInvitationReceived"
    )
}

struct ToDoCollab: Decodable, Equatable, Identifiable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let name: String
    let createdAt: String
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ToDoCollabInvitation: Decodable, Equatable, Identifiable, Sendable {
    enum Status: String, Decodable, Sendable {
        case pending
        case accepted
        case declined
        case canceled
        case expired
    }

    let id: UUID
    let collabID: UUID
    let inviterUserID: UUID
    let inviteeEmail: String
    let inviteeUserID: UUID?
    let role: ToDoCollaborationRole
    let status: Status
    let createdAt: String
    let updatedAt: String
    let expiresAt: String
    let respondedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case collabID = "collab_id"
        case inviterUserID = "inviter_user_id"
        case inviteeEmail = "invitee_email"
        case inviteeUserID = "invitee_user_id"
        case role
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
        case respondedAt = "responded_at"
    }
}

struct ToDoCollabInvitationDetails: Decodable, Equatable, Sendable {
    let invitationID: UUID
    let collabID: UUID
    let collabName: String
    let inviterDisplayName: String?
    let inviterUsername: String?
    let status: ToDoCollabInvitation.Status
    let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case invitationID = "invitation_id"
        case collabID = "collab_id"
        case collabName = "collab_name"
        case inviterDisplayName = "inviter_display_name"
        case inviterUsername = "inviter_username"
        case status
        case expiresAt = "expires_at"
    }
}

enum ToDoCollaborationInviteLink {
    private static let invitationQueryName = "invitation"

    private static var scheme: String {
        #if os(macOS)
        return "todo-mac"
        #else
        return "todo"
        #endif
    }

    static func url(for invitationID: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "collab-invite"
        components.queryItems = [
            URLQueryItem(
                name: invitationQueryName,
                value: invitationID.uuidString.lowercased()
            )
        ]
        return components.url
    }

    static func invitationID(from url: URL) -> UUID? {
        #if os(macOS)
        let acceptedSchemes = ["todo-mac", "todo"]
        #else
        let acceptedSchemes = ["todo"]
        #endif
        guard let urlScheme = url.scheme?.lowercased(),
              acceptedSchemes.contains(urlScheme),
              url.host?.lowercased() == "collab-invite" else {
            return nil
        }

        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == invitationQueryName })?
            .value
            .flatMap(UUID.init(uuidString:))
    }
}

nonisolated struct ToDoCollabUserProfile: Decodable, Equatable, Identifiable, Sendable {
    let userID: UUID
    let username: String?
    let displayName: String?
    let avatarURL: String?
    let role: ToDoCollaborationRole
    let collabID: UUID
    let collabName: String

    var id: UUID { userID }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case role
        case collabID = "collab_id"
        case collabName = "collab_name"
    }
}

struct ToDoCollaborationAccess: Decodable, Equatable, Sendable {
    static let signedOut = ToDoCollaborationAccess(
        acceptedOutgoingCount: 0,
        outgoingInvitationLimit: ToDoCapabilities.freeInvitationLimit,
        hasUnlimitedCollaboration: false,
        canSendInvitation: false
    )

    let acceptedOutgoingCount: Int
    let outgoingInvitationLimit: Int?
    let hasUnlimitedCollaboration: Bool
    let canSendInvitation: Bool

    private enum CodingKeys: String, CodingKey {
        case acceptedOutgoingCount = "accepted_outgoing_count"
        case outgoingInvitationLimit = "outgoing_invitation_limit"
        case hasUnlimitedCollaboration = "has_unlimited_collaboration"
        case canSendInvitation = "can_send_invitation"
    }
}

enum ToDoCollaborationPolicy {
    static func normalizedInviteEmail(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count <= 320,
              !normalized.contains(where: { $0.isWhitespace }),
              let at = normalized.firstIndex(of: "@"),
              at != normalized.startIndex,
              at < normalized.index(before: normalized.endIndex),
              normalized[normalized.index(after: at)...].contains(".") else {
            return nil
        }
        return normalized
    }

    static func canSendInvitation(
        acceptedOutgoingCount: Int,
        capabilities: ToDoCapabilities
    ) -> Bool {
        guard let limit = capabilities.outgoingInvitationLimit else { return true }
        return acceptedOutgoingCount < limit
    }
}

struct ToDoCollaborationSnapshot: Equatable, Sendable {
    let collabs: [ToDoCollab]
    let invitations: [ToDoCollabInvitation]
    let access: ToDoCollaborationAccess
}

@MainActor
protocol ToDoCollaborationBackendClient {
    func loadSnapshot(account: ToDoCommerceAccount) async throws -> ToDoCollaborationSnapshot
    func loadCollabUsers(collabID: UUID, account: ToDoCommerceAccount) async throws -> [ToDoCollabUserProfile]
    func loadInvitationDetails(id: UUID, account: ToDoCommerceAccount) async throws -> ToDoCollabInvitationDetails
    func createCollab(name: String, account: ToDoCommerceAccount) async throws -> ToDoCollab
    func sendInvitation(collabID: UUID, email: String, account: ToDoCommerceAccount) async throws
    func acceptInvitation(id: UUID, account: ToDoCommerceAccount) async throws
    func declineInvitation(id: UUID, account: ToDoCommerceAccount) async throws
    func cancelInvitation(id: UUID, account: ToDoCommerceAccount) async throws
    func removeUser(collabID: UUID, userID: UUID, account: ToDoCommerceAccount) async throws
    func deleteCollab(collabID: UUID, account: ToDoCommerceAccount) async throws
    func leaveCollabs(ids: [UUID], account: ToDoCommerceAccount) async throws
}

struct ToDoCollaborationLeaveResult: Equatable, Sendable {
    let leftCollabIDs: Set<UUID>
    let preservedOwnedCollabCount: Int
}

struct LiveToDoCollaborationBackendClient: ToDoCollaborationBackendClient {
    private struct CollabCreateBody: Encodable {
        let ownerUserID: UUID
        let name: String

        private enum CodingKeys: String, CodingKey {
            case ownerUserID = "owner_user_id"
            case name
        }
    }

    private struct InvitationBody: Encodable {
        let targetCollabID: UUID
        let targetEmail: String

        private enum CodingKeys: String, CodingKey {
            case targetCollabID = "target_collab_id"
            case targetEmail = "target_email"
        }
    }

    private struct InvitationIDBody: Encodable {
        let targetInvitationID: UUID

        private enum CodingKeys: String, CodingKey {
            case targetInvitationID = "target_invitation_id"
        }
    }

    private struct RemoveUserBody: Encodable {
        let targetCollabID: UUID
        let targetUserID: UUID

        private enum CodingKeys: String, CodingKey {
            case targetCollabID = "target_collab_id"
            case targetUserID = "target_user_id"
        }
    }

    private struct CollabProfileBody: Encodable {
        let targetCollabID: UUID
        let resultLimit: Int
        let resultOffset: Int

        private enum CodingKeys: String, CodingKey {
            case targetCollabID = "target_collab_id"
            case resultLimit = "result_limit"
            case resultOffset = "result_offset"
        }
    }

    private struct InvitationDetailsBody: Encodable {
        let targetInvitationID: UUID

        private enum CodingKeys: String, CodingKey {
            case targetInvitationID = "target_invitation_id"
        }
    }

    private struct ErrorBody: Decodable {
        let message: String?
        let error: String?
    }

    func loadSnapshot(account: ToDoCommerceAccount) async throws -> ToDoCollaborationSnapshot {
        let collabs: [ToDoCollab] = try await get(
            path: "rest/v1/collabs",
            queryItems: [
                URLQueryItem(name: "select", value: "id,owner_user_id,name,created_at,updated_at"),
                URLQueryItem(name: "order", value: "updated_at.desc"),
            ],
            account: account
        )
        let invitations: [ToDoCollabInvitation] = try await get(
            path: "rest/v1/collab_invitations",
            queryItems: [
                URLQueryItem(
                    name: "select",
                    value: "id,collab_id,inviter_user_id,invitee_email,invitee_user_id,role,status,created_at,updated_at,expires_at,responded_at"
                ),
                URLQueryItem(name: "order", value: "updated_at.desc"),
            ],
            account: account
        )
        let accessRows: [ToDoCollaborationAccess] = try await post(
            path: "rest/v1/rpc/current_collaboration_access",
            body: EmptyBody(),
            account: account
        )
        guard let access = accessRows.first else {
            throw ToDoCollaborationError.invalidServerResponse
        }
        return ToDoCollaborationSnapshot(collabs: collabs, invitations: invitations, access: access)
    }

    func createCollab(name: String, account: ToDoCommerceAccount) async throws -> ToDoCollab {
        let collabs: [ToDoCollab] = try await post(
            path: "rest/v1/collabs",
            queryItems: [URLQueryItem(name: "select", value: "id,owner_user_id,name,created_at,updated_at")],
            body: CollabCreateBody(ownerUserID: account.id, name: name),
            account: account,
            preferRepresentation: true
        )
        guard let collab = collabs.first else {
            throw ToDoCollaborationError.invalidServerResponse
        }
        return collab
    }

    func loadCollabUsers(
        collabID: UUID,
        account: ToDoCommerceAccount
    ) async throws -> [ToDoCollabUserProfile] {
        let pageSize = 100
        let maximumPageCount = 100
        var orderedUserIDs: [UUID] = []
        var profilesByUserID: [UUID: ToDoCollabUserProfile] = [:]

        for pageIndex in 0..<maximumPageCount {
            try Task.checkCancellation()
            let page: [ToDoCollabUserProfile] = try await post(
                path: "rest/v1/rpc/collab_user_profiles_for_collab",
                body: CollabProfileBody(
                    targetCollabID: collabID,
                    resultLimit: pageSize,
                    resultOffset: pageIndex * pageSize
                ),
                account: account
            )
            for profile in page {
                if profilesByUserID[profile.userID] == nil {
                    orderedUserIDs.append(profile.userID)
                }
                profilesByUserID[profile.userID] = profile
            }
            if page.count < pageSize {
                return orderedUserIDs.compactMap { profilesByUserID[$0] }
            }
        }

        throw ToDoCollaborationError.invalidServerResponse
    }

    func loadInvitationDetails(
        id: UUID,
        account: ToDoCommerceAccount
    ) async throws -> ToDoCollabInvitationDetails {
        let details: [ToDoCollabInvitationDetails] = try await post(
            path: "rest/v1/rpc/collab_invitation_details",
            body: InvitationDetailsBody(targetInvitationID: id),
            account: account
        )
        guard let details = details.first else {
            throw ToDoCollaborationError.invalidServerResponse
        }
        return details
    }

    func sendInvitation(collabID: UUID, email: String, account: ToDoCommerceAccount) async throws {
        try await postWithoutResponse(
            path: "rest/v1/rpc/send_collab_invitation",
            body: InvitationBody(targetCollabID: collabID, targetEmail: email),
            account: account
        )
    }

    func acceptInvitation(id: UUID, account: ToDoCommerceAccount) async throws {
        try await postWithoutResponse(
            path: "rest/v1/rpc/accept_collab_invitation",
            body: InvitationIDBody(targetInvitationID: id),
            account: account
        )
    }

    func declineInvitation(id: UUID, account: ToDoCommerceAccount) async throws {
        try await postWithoutResponse(
            path: "rest/v1/rpc/decline_collab_invitation",
            body: InvitationIDBody(targetInvitationID: id),
            account: account
        )
    }

    func cancelInvitation(id: UUID, account: ToDoCommerceAccount) async throws {
        try await postWithoutResponse(
            path: "rest/v1/rpc/cancel_collab_invitation",
            body: InvitationIDBody(targetInvitationID: id),
            account: account
        )
    }

    func removeUser(collabID: UUID, userID: UUID, account: ToDoCommerceAccount) async throws {
        try await postWithoutResponse(
            path: "rest/v1/rpc/remove_collab_user",
            body: RemoveUserBody(targetCollabID: collabID, targetUserID: userID),
            account: account
        )
    }

    func deleteCollab(collabID: UUID, account: ToDoCommerceAccount) async throws {
        try await deleteWithoutResponse(
            path: "rest/v1/collabs",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(collabID.uuidString)"),
            ],
            account: account
        )
    }

    func leaveCollabs(ids: [UUID], account: ToDoCommerceAccount) async throws {
        let stableIDs = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
        guard !stableIDs.isEmpty else { return }

        try await deleteWithoutResponse(
            path: "rest/v1/collab_users",
            queryItems: [
                URLQueryItem(
                    name: "collab_id",
                    value: "in.(\(stableIDs.map(\.uuidString).joined(separator: ",")))"
                ),
                URLQueryItem(name: "user_id", value: "eq.\(account.id.uuidString)"),
                URLQueryItem(name: "role", value: "eq.user"),
            ],
            account: account
        )
    }

    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        account: ToDoCommerceAccount
    ) async throws -> Response {
        var components = URLComponents(
            url: SupabaseConfig.supabaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: authorizedRequest(url: url, account: account))
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Body,
        account: ToDoCommerceAccount,
        preferRepresentation: Bool = false
    ) async throws -> Response {
        var components = URLComponents(
            url: SupabaseConfig.supabaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = authorizedRequest(url: url, account: account)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func postWithoutResponse<Body: Encodable>(
        path: String,
        body: Body,
        account: ToDoCommerceAccount
    ) async throws {
        let url = SupabaseConfig.supabaseURL.appending(path: path)
        var request = authorizedRequest(url: url, account: account)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func deleteWithoutResponse(
        path: String,
        queryItems: [URLQueryItem],
        account: ToDoCommerceAccount
    ) async throws {
        var components = URLComponents(
            url: SupabaseConfig.supabaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = authorizedRequest(url: url, account: account)
        request.httpMethod = "DELETE"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func authorizedRequest(url: URL, account: ToDoCommerceAccount) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            let message = body?.message
                ?? body?.error
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw ToDoCollaborationError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

private struct EmptyBody: Encodable {}

enum ToDoCollaborationError: LocalizedError, Equatable {
    case signInRequired
    case notAuthorized
    case invitationLimitReached(limit: Int)
    case invalidInviteEmail
    case invalidServerResponse
    case requestFailed(statusCode: Int, message: String)

    var isMissingBackendSchema: Bool {
        guard case .requestFailed(let statusCode, let message) = self else { return false }
        let normalizedMessage = message.lowercased()
        return statusCode == 404
            && normalizedMessage.contains("schema cache")
            && (
                normalizedMessage.contains("public.collabs")
                    || normalizedMessage.contains("public.collab_invitations")
                    || normalizedMessage.contains("current_collaboration_access")
                    || normalizedMessage.contains("collab_invitation_details")
            )
    }

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            String(localized: "Sign in to use Collabs.")
        case .notAuthorized:
            String(localized: "Only the Collab owner can remove it.")
        case .invitationLimitReached(let limit):
            String(format: String(localized: "Free accounts can invite up to %lld users. Remove one or choose toDō+ to invite someone else."), limit)
        case .invalidInviteEmail:
            String(localized: "Enter a valid email address for the person you want to invite.")
        case .invalidServerResponse:
            String(localized: "Collabs could not be refreshed. Please try again.")
        case .requestFailed(_, let message):
            message
        }
    }
}

@MainActor
final class ToDoCollaborationService: ObservableObject {
    static let shared = ToDoCollaborationService()
    static let preview = ToDoCollaborationService(backendClient: nil)

    @Published private(set) var collabs: [ToDoCollab] = []
    @Published private(set) var invitations: [ToDoCollabInvitation] = []
    @Published private(set) var access = ToDoCollaborationAccess.signedOut
    @Published private(set) var profilesByCollabID: [UUID: [ToDoCollabUserProfile]] = [:]
    @Published private(set) var loadingProfileCollabIDs: Set<UUID> = []
    @Published private(set) var profileErrorsByCollabID: [UUID: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedSnapshot = false
    @Published private(set) var isBackendAvailable = true
    @Published private(set) var pendingInvitationID: UUID?
    @Published var errorMessage: String?

    private let backendClient: (any ToDoCollaborationBackendClient)?
    private var account: ToDoCommerceAccount?
    private var accountRevision = 0

    init(backendClient: (any ToDoCollaborationBackendClient)? = LiveToDoCollaborationBackendClient()) {
        self.backendClient = backendClient
    }

    var incomingInvitations: [ToDoCollabInvitation] {
        guard let accountID = account?.id else { return [] }
        return invitations.filter { invitation in
            invitation.status == .pending && invitation.inviterUserID != accountID
        }
    }

    var outgoingInvitations: [ToDoCollabInvitation] {
        guard let accountID = account?.id else { return [] }
        return invitations.filter { $0.inviterUserID == accountID }
    }

    func canSendInvitation(capabilities: ToDoCapabilities) -> Bool {
        guard account != nil else { return false }
        return access.canSendInvitation && ToDoCollaborationPolicy.canSendInvitation(
            acceptedOutgoingCount: access.acceptedOutgoingCount,
            capabilities: capabilities
        )
    }

    func updateAccount(_ account: ToDoCommerceAccount?) async {
        accountRevision += 1
        let revision = accountRevision
        let previousAccountID = self.account?.id
        // Preserve a deep link received while signed out so the newly signed-in
        // recipient can review it. Never carry an invitation across sign-out or
        // from one authenticated account to another.
        if account == nil || (previousAccountID != nil && previousAccountID != account?.id) {
            pendingInvitationID = nil
        }
        self.account = account
        collabs = []
        invitations = []
        access = .signedOut
        profilesByCollabID = [:]
        loadingProfileCollabIDs = []
        profileErrorsByCollabID = [:]
        isLoading = false
        hasLoadedSnapshot = false
        errorMessage = nil
        isBackendAvailable = true

        guard account != nil else { return }
        await refresh(revision: revision)
    }

    func refresh() async {
        await refresh(revision: accountRevision)
    }

    @discardableResult
    func receiveInvitationURL(_ url: URL) -> Bool {
        guard let invitationID = ToDoCollaborationInviteLink.invitationID(from: url) else {
            return false
        }
        pendingInvitationID = invitationID
        NotificationCenter.default.post(
            name: .toDoCollaborationInvitationReceived,
            object: invitationID
        )
        return true
    }

    func clearPendingInvitation() {
        pendingInvitationID = nil
    }

    func loadInvitationDetails(id: UUID) async throws -> ToDoCollabInvitationDetails {
        let (backendClient, account) = try authenticatedContext()
        return try await backendClient.loadInvitationDetails(id: id, account: account)
    }

    func profiles(for collabID: UUID) -> [ToDoCollabUserProfile] {
        profilesByCollabID[collabID] ?? []
    }

    func loadCollabUsers(collabID: UUID, force: Bool = false) async {
        guard force || profilesByCollabID[collabID] == nil else { return }
        guard !loadingProfileCollabIDs.contains(collabID) else { return }

        let revision = accountRevision
        guard let backendClient, let account else {
            profileErrorsByCollabID[collabID] = ToDoCollaborationError.signInRequired.localizedDescription
            return
        }

        loadingProfileCollabIDs.insert(collabID)
        profileErrorsByCollabID[collabID] = nil
        defer {
            if revision == accountRevision {
                loadingProfileCollabIDs.remove(collabID)
            }
        }

        do {
            let profiles = try await backendClient.loadCollabUsers(
                collabID: collabID,
                account: account
            )
            guard revision == accountRevision, self.account?.id == account.id else { return }
            profilesByCollabID[collabID] = profiles
            profileErrorsByCollabID[collabID] = nil
        } catch {
            guard revision == accountRevision else { return }
            profileErrorsByCollabID[collabID] = error.localizedDescription
            AppLog.error("Collab user profile refresh failed: \(error)", logger: AppLog.app)
        }
    }

    func createCollab(name: String) async throws -> ToDoCollab {
        let (backendClient, account) = try authenticatedContext()
        let collab = try await backendClient.createCollab(name: name.trimmingCharacters(in: .whitespacesAndNewlines), account: account)
        await refresh()
        return collab
    }

    func sendInvitation(
        collabID: UUID,
        email: String,
        capabilities: ToDoCapabilities
    ) async throws -> ToDoCollabInvitation {
        let (backendClient, account) = try authenticatedContext()
        guard let normalizedEmail = ToDoCollaborationPolicy.normalizedInviteEmail(email) else {
            throw ToDoCollaborationError.invalidInviteEmail
        }
        guard canSendInvitation(capabilities: capabilities) else {
            throw ToDoCollaborationError.invitationLimitReached(
                limit: capabilities.outgoingInvitationLimit ?? ToDoCapabilities.freeInvitationLimit
            )
        }
        try await backendClient.sendInvitation(collabID: collabID, email: normalizedEmail, account: account)
        await refresh()
        guard let invitation = invitations.first(where: {
            $0.collabID == collabID
                && $0.inviterUserID == account.id
                && $0.inviteeEmail == normalizedEmail
                && $0.status == .pending
        }) else {
            throw ToDoCollaborationError.invalidServerResponse
        }
        return invitation
    }

    func acceptInvitation(id: UUID) async throws {
        let (backendClient, account) = try authenticatedContext()
        try await backendClient.acceptInvitation(id: id, account: account)
        await refresh()
        notifyMembershipChange()
    }

    func declineInvitation(id: UUID) async throws {
        let (backendClient, account) = try authenticatedContext()
        try await backendClient.declineInvitation(id: id, account: account)
        await refresh()
        notifyMembershipChange()
    }

    func cancelInvitation(id: UUID) async throws {
        let (backendClient, account) = try authenticatedContext()
        try await backendClient.cancelInvitation(id: id, account: account)
        await refresh()
        notifyMembershipChange()
    }

    func removeUser(collabID: UUID, userID: UUID) async throws {
        let (backendClient, account) = try authenticatedContext()
        try await backendClient.removeUser(collabID: collabID, userID: userID, account: account)
        await refresh()
        await loadCollabUsers(collabID: collabID, force: true)
        notifyMembershipChange()
    }

    func deleteCollab(id: UUID) async throws {
        let (backendClient, account) = try authenticatedContext()
        guard collabs.first(where: { $0.id == id })?.ownerUserID == account.id else {
            throw ToDoCollaborationError.notAuthorized
        }

        try await backendClient.deleteCollab(collabID: id, account: account)
        await refresh()
        notifyMembershipChange()
    }

    func leaveSharedCollabs() async throws -> ToDoCollaborationLeaveResult {
        let (backendClient, account) = try authenticatedContext()
        let ownedCollabCount = collabs.count { $0.ownerUserID == account.id }
        let collabIDsToLeave = Set(
            collabs.lazy
                .filter { $0.ownerUserID != account.id }
                .map(\.id)
        )

        guard !collabIDsToLeave.isEmpty else {
            return ToDoCollaborationLeaveResult(
                leftCollabIDs: [],
                preservedOwnedCollabCount: ownedCollabCount
            )
        }

        try await backendClient.leaveCollabs(
            ids: Array(collabIDsToLeave),
            account: account
        )
        await refresh()
        notifyMembershipChange()
        return ToDoCollaborationLeaveResult(
            leftCollabIDs: collabIDsToLeave,
            preservedOwnedCollabCount: ownedCollabCount
        )
    }

    private func notifyMembershipChange() {
        NotificationCenter.default.post(
            name: .toDoCollaborationMembershipDidChange,
            object: account?.id
        )
    }

    private func refresh(revision: Int) async {
        guard let backendClient, let account else { return }
        guard !isLoading else { return }
        isLoading = true
        defer {
            if revision == accountRevision { isLoading = false }
        }

        do {
            let snapshot = try await backendClient.loadSnapshot(account: account)
            guard revision == accountRevision, self.account?.id == account.id else { return }
            collabs = snapshot.collabs
            invitations = snapshot.invitations
            access = snapshot.access
            let visibleCollabIDs = Set(snapshot.collabs.map(\.id))
            profilesByCollabID = profilesByCollabID.filter { visibleCollabIDs.contains($0.key) }
            profileErrorsByCollabID = profileErrorsByCollabID.filter { visibleCollabIDs.contains($0.key) }
            errorMessage = nil
            isBackendAvailable = true
            hasLoadedSnapshot = true
        } catch {
            guard revision == accountRevision else { return }
            hasLoadedSnapshot = true
            if let collaborationError = error as? ToDoCollaborationError,
               collaborationError.isMissingBackendSchema {
                collabs = []
                invitations = []
                access = .signedOut
                isBackendAvailable = false
                errorMessage = nil
                AppLog.info("Collab backend is awaiting its database migration.", logger: AppLog.app)
                return
            }
            errorMessage = error.localizedDescription
            AppLog.error("Collaboration refresh failed: \(error)", logger: AppLog.app)
        }
    }

    private func authenticatedContext() throws -> (any ToDoCollaborationBackendClient, ToDoCommerceAccount) {
        guard let backendClient, let account else {
            throw ToDoCollaborationError.signInRequired
        }
        return (backendClient, account)
    }
}
