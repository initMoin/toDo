import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import ToDo

@Suite("Profile contract")
struct ProfileContractTests {
    @Test func displayNameValidationNormalizesWhitespace() throws {
        let value = try ToDoProfilePolicy.validatedDisplayName("  Moinuddin\n Ahmad  ")
        #expect(value == "Moinuddin Ahmad")
    }

    @Test func displayNameValidationRejectsEmptyAndOversizedValues() {
        #expect(throws: ToDoProfileValidationError.emptyDisplayName) {
            try ToDoProfilePolicy.validatedDisplayName(" \n ")
        }

        let oversized = String(repeating: "a", count: ToDoProfilePolicy.maximumDisplayNameLength + 1)
        #expect(throws: ToDoProfileValidationError.displayNameTooLong(
            maximum: ToDoProfilePolicy.maximumDisplayNameLength
        )) {
            try ToDoProfilePolicy.validatedDisplayName(oversized)
        }
    }

    @Test func usernameValidationNormalizesHandleAndSupportsDisplayFormat() throws {
        let value = try ToDoProfilePolicy.validatedUsername("  @Shift_Dev  ")
        #expect(value == "shift_dev")
        #expect(ToDoProfilePolicy.displayUsername(value) == "@shift_dev")
    }

    @Test func usernameValidationRejectsUnsafeOrShortHandles() {
        #expect(throws: ToDoProfileValidationError.invalidUsername) {
            try ToDoProfilePolicy.validatedUsername("ab")
        }
        #expect(throws: ToDoProfileValidationError.invalidUsername) {
            try ToDoProfilePolicy.validatedUsername("shift-name")
        }
        #expect(throws: ToDoProfileValidationError.invalidUsername) {
            try ToDoProfilePolicy.validatedUsername("shíft")
        }
    }

    @Test func accountResolutionRequiresCompletedSetup() {
        let id = UUID()
        let profile = SupabaseProfileRecord(
            id: id,
            username: "shift",
            accountSetupVersion: 1,
            displayName: nil,
            givenName: nil,
            familyName: nil,
            avatarURL: nil,
            preferredTimeZone: nil,
            createdAt: nil,
            updatedAt: nil
        )

        #expect(
            ToDoAccountResolutionPolicy.state(
                profile: profile,
                intent: .restoreSession,
                expectedUsername: "shift"
            ) == .migrationRequired(username: "shift")
        )
    }

    @Test func existingUsernameMigrationDoesNotRequireAReplacementUsername() {
        let id = UUID()
        let profile = SupabaseProfileRecord(
            id: id,
            username: "shift",
            accountSetupVersion: 1,
            displayName: nil,
            givenName: nil,
            familyName: nil,
            avatarURL: nil,
            preferredTimeZone: nil,
            createdAt: nil,
            updatedAt: nil
        )

        let resolution = ToDoAccountResolutionPolicy.state(
            profile: profile,
            intent: .signIn,
            expectedUsername: "@SHIFT"
        )

        #expect(resolution == .migrationRequired(username: "shift"))
        if case .migrationRequired(let username) = resolution {
            #expect(username == "shift")
        } else {
            Issue.record("An existing username should enter confirmation, not username creation.")
        }
    }

    @Test func accountResolutionRejectsAProviderForTheWrongRequestedUsername() {
        let id = UUID()
        let profile = SupabaseProfileRecord(
            id: id,
            username: "actual_user",
            accountSetupVersion: 2,
            displayName: nil,
            givenName: nil,
            familyName: nil,
            avatarURL: nil,
            preferredTimeZone: nil,
            createdAt: nil,
            updatedAt: nil
        )

        #expect(
            ToDoAccountResolutionPolicy.state(
                profile: profile,
                intent: .signIn,
                expectedUsername: "requested_user"
            ) == .accountMismatch(
                expectedUsername: "requested_user",
                actualUsername: "actual_user"
            )
        )
    }

    @Test func accountResolutionAcceptsTheCanonicalUUIDAndUsername() {
        let id = UUID()
        let profile = SupabaseProfileRecord(
            id: id,
            username: "shift",
            accountSetupVersion: 2,
            displayName: nil,
            givenName: nil,
            familyName: nil,
            avatarURL: nil,
            preferredTimeZone: nil,
            createdAt: nil,
            updatedAt: nil
        )

        #expect(
            ToDoAccountResolutionPolicy.state(
                profile: profile,
                intent: .signIn,
                expectedUsername: "@SHIFT"
            ) == .resolved(accountID: id, username: "shift")
        )
    }

    @Test func accountResolutionDoesNotInventAUsernameForAProvisionalProfile() {
        let profile = SupabaseProfileRecord(
            id: UUID(),
            username: nil,
            accountSetupVersion: 1,
            displayName: "Provisional",
            givenName: nil,
            familyName: nil,
            avatarURL: nil,
            preferredTimeZone: nil,
            createdAt: nil,
            updatedAt: nil
        )

        #expect(
            ToDoAccountResolutionPolicy.state(
                profile: profile,
                intent: .createAccount,
                expectedUsername: "requested"
            ) == .needsUsername(intent: .createAccount)
        )
    }

    @Test func initialsUseFirstAndLastNamesWithSingleNameFallback() {
        #expect(ToDoProfilePolicy.initials(from: "Moinuddin Ahmad") == "MA")
        #expect(ToDoProfilePolicy.initials(from: "Shift") == "SH")
        #expect(ToDoProfilePolicy.initials(from: "李明") == "李明")
    }

    @Test func avatarURLsRequireHTTPSAndFallBackCleanly() {
        #expect(ToDoProfilePolicy.avatarURL(from: "https://example.com/avatar.png") != nil)
        #expect(ToDoProfilePolicy.avatarURL(from: "http://example.com/avatar.png") == nil)
        #expect(ToDoProfilePolicy.avatarURL(from: "not a url") == nil)
        #expect(ToDoProfilePolicy.avatarURL(from: nil) == nil)
    }

    @Test func profileImagesAcceptPNGAndJPEGInput() throws {
        let pngData = try #require(encodedImageData(uti: UTType.png.identifier))
        let jpegData = try #require(encodedImageData(uti: UTType.jpeg.identifier))

        #expect(ToDoProfileImageStore.supportsImageData(pngData))
        #expect(ToDoProfileImageStore.supportsImageData(jpegData))
        #expect(ToDoProfileImageStore.normalizedJPEGData(from: pngData) != nil)
        #expect(ToDoProfileImageStore.normalizedJPEGData(from: jpegData) != nil)
    }

    @Test func profileDecodesWhenOptionalFieldsAreAbsent() throws {
        let id = UUID()
        let data = try JSONSerialization.data(withJSONObject: ["id": id.uuidString])
        let profile = try JSONDecoder().decode(SupabaseProfileRecord.self, from: data)

        #expect(profile.id == id)
        #expect(profile.accountSetupVersion == nil)
        #expect(profile.displayName == nil)
        #expect(profile.username == nil)
        #expect(profile.avatarURL == nil)
        #expect(profile.preferredTimeZone == nil)
    }

    @Test func collabUserProjectionIgnoresPrivateFieldsFromUnexpectedPayloads() throws {
        let userID = UUID()
        let collabID = UUID()
        let data = try JSONSerialization.data(withJSONObject: [
            "user_id": userID.uuidString,
            "display_name": "Collab User",
            "username": "shift",
            "avatar_url": "https://example.com/avatar.png",
            "role": "user",
            "collab_id": collabID.uuidString,
            "collab_name": "Launch",
            "email": "private@example.com",
            "preferred_time_zone": "America/New_York",
        ])

        let profile = try JSONDecoder().decode(ToDoCollabUserProfile.self, from: data)
        #expect(profile.userID == userID)
        #expect(profile.collabID == collabID)
        #expect(profile.displayName == "Collab User")
        #expect(profile.username == "shift")
        #expect(profile.role == .user)
    }

    @Test func collabUserRPCExposesOnlyCollabScopedIdentityFields() throws {
        let migrationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "supabase/migrations/20260806120000_add_collab_usernames.sql")
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)
        let projection = try #require(sql.range(of: "returns table (").flatMap { start in
            sql.range(of: ")\nlanguage plpgsql", range: start.upperBound..<sql.endIndex).map { end in
                String(sql[start.upperBound..<end.lowerBound])
            }
        })

        #expect(projection.contains("user_id uuid"))
        #expect(projection.contains("username text"))
        #expect(projection.contains("display_name text"))
        #expect(projection.contains("avatar_url text"))
        #expect(projection.contains("role text"))
        #expect(projection.contains("collab_id uuid"))
        #expect(projection.contains("collab_name text"))
        #expect(!projection.contains("email"))
        #expect(!projection.contains("time_zone"))
        #expect(!projection.contains("entitlement"))
        #expect(sql.contains("viewer.user_id = current_account_id"))
        #expect(sql.contains("security definer"))
        #expect(sql.contains("revoke all on function public.collab_user_profiles_for_collab(uuid, integer, integer) from anon"))
        #expect(sql.contains("limit least(greatest(result_limit, 1), 100)"))
        #expect(sql.contains("profiles_username_unique_idx"))
        #expect(sql.contains("lower(btrim(username))"))
    }

    @Test func invitationDeepLinkRPCExposesOnlyRecipientSafeFields() throws {
        let migrationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "supabase/migrations/20260807120000_add_collab_invitation_link_details.sql")
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)
        let returnedColumns = sql
            .components(separatedBy: "returns table (")
            .dropFirst()
            .first?
            .components(separatedBy: ")")
            .first ?? ""

        #expect(sql.contains("returns table ("))
        #expect(sql.contains("invitation_id uuid"))
        #expect(sql.contains("collab_id uuid"))
        #expect(sql.contains("collab_name text"))
        #expect(sql.contains("inviter_display_name text"))
        #expect(sql.contains("inviter_username text"))
        #expect(!returnedColumns.localizedCaseInsensitiveContains("email"))
        #expect(!returnedColumns.localizedCaseInsensitiveContains("preferred_time_zone"))
        #expect(sql.contains("invitation.invitee_user_id = current_account_id"))
        #expect(sql.contains("invitation.invitee_email = current_email"))
        #expect(sql.contains("revoke all on function public.collab_invitation_details(uuid) from anon"))
        #expect(sql.contains("grant execute on function public.collab_invitation_details(uuid) to authenticated"))
    }

    private func encodedImageData(uti: String) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: 1,
                  height: 1,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            uti as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
