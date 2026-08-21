//
//  ToDo_Watch_AppTests.swift
//  ToDo Watch AppTests
//
//  Created by Moinuddin Ahmad on 5/13/26.
//

import Foundation
import Testing
@testable import ToDo_Watch

struct ToDo_Watch_AppTests {

    @Test func usernamePolicyMatchesAccountLocatorRules() {
        #expect(WatchUsernamePolicy.normalized(" @Shift ") == "shift")
        #expect(WatchUsernamePolicy.normalized("moin.shift_3") == "moin.shift_3")
        #expect(WatchUsernamePolicy.normalized("ab") == nil)
        #expect(WatchUsernamePolicy.normalized(".shift") == nil)
        #expect(WatchUsernamePolicy.normalized("shift-") == nil)
    }

    @MainActor
    @Test func unsignedChoiceRejectsMirroredAccountState() throws {
        let suiteName = "WatchAuthStoreTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = WatchAuthStore(userDefaults: userDefaults)
        store.continueWithoutSigningIn()
        store.applyPhoneAuthState(
            ToDo_Watch.WatchAuthState(
                isAuthenticated: true,
                isAccountResolved: true,
                userID: UUID(),
                provider: "apple",
                email: nil,
                username: "shift",
                accountSetupVersion: 1,
                source: .iPhone
            )
        )

        #expect(store.prefersUnsignedSession)
        #expect(!store.authState.isAuthenticated)
        #expect(store.authState.userID == nil)
    }

}
