# Step 05: StoreKit Sandbox Validation

## Objective

Verify StoreKit transactions, explicit restoration, server linking, server-backed
entitlements, Family Sharing, consumables, lifecycle changes, and
account isolation using Sandbox or TestFlight on real devices.

## Rules

- Use a separate Sandbox Apple Account for scenarios whose purchase histories
  conflict.
- Use the signed-in Supabase bearer token only when the app links a verified Apple
  transaction. Never submit client-computed entitlement claims.
- Do not inspect or copy complete signed transaction JWS values.
- Query effective capabilities through `current_account_entitlements` or the
  approved server contract, not a local preference.
- Confirm sign-out clears account-backed capability state before the next account
  signs in.

## Baseline

1. Install the candidate build through TestFlight or the approved Sandbox path.
2. Sign in with the scenario's Sandbox Apple Account.
3. Sign in to the intended Supabase test account.
4. Open Membership and wait for StoreKit products to load.
5. Verify localized product prices and durations.
6. Confirm no prior Supabase account's membership appears.
7. Record the starting entitlement rows without signed payload data.

## Scenario A: Monthly

1. Purchase Monthly with a fresh eligible Sandbox account.
2. Confirm Apple's purchase sheet shows the localized product and standard price.
3. Complete the purchase.
4. Verify the app receives a verified transaction.
5. Verify the transaction is linked to the signed-in Supabase account.
6. Verify effective entitlement becomes active Monthly.
7. Confirm unlimited personal Collab capability becomes available.
8. Relaunch the app and verify persistence from StoreKit and server reconciliation.

## Scenario B: Annual

Repeat Scenario A with the Annual product and a separate account. Confirm the
one-year duration and standard price.

## Scenario B1: Introductory Offer Eligibility

1. Use a fresh eligible Sandbox Apple Account and confirm Monthly displays its
   first-week introductory offer when StoreKit reports it as eligible.
2. Complete or redeem the Monthly offer, then inspect Annual with the same Apple
   Account.
3. Confirm the account is not promised a second introductory offer from the shared
   subscription group. StoreKit, not the app's copy, determines the result.
4. Repeat with a separate eligible account for Annual and confirm the first-two-week
   offer is displayed and applied when StoreKit makes it available.

## Scenario B2: Offer Codes

1. Use Apple's StoreKit redemption sheet from Membership; do not use a custom code
   entry field.
2. Redeem one configured Monthly or Annual community code with a Sandbox account.
3. Close the sheet and confirm the app synchronizes transactions, refreshes verified
   entitlements, and updates Membership without a relaunch.
4. Redeem the Lifetime code `shiftalways` with a separate eligible account and
   confirm the permanent Lifetime entitlement is linked to the signed-in account.
5. Confirm the app never logs or stores the literal code and never grants access
   from local code matching.

## Scenario C: Lifetime

1. Purchase Lifetime.
2. Verify permanent paid capability without a renewal date.
3. Reinstall or use a second eligible Apple device.
4. Use explicit Restore Purchases.
5. Confirm Lifetime is restored and relinked to the same Supabase account.

## Scenario D: Consumable Appreciation

For Coffee, Lunch, and Patron of Dōing:

1. Purchase each once.
2. Purchase at least one a second time.
3. Confirm every purchase completes independently.
4. Confirm none unlocks toDō+ capability.
5. Confirm Restore Purchases does not recreate consumable recognition.
6. Confirm product availability and localized price, especially Patron of Dōing.

## Scenario E: Founding Supporter

1. Purchase Founding Supporter once.
2. Verify recognition appears only for the linked owner account.
3. Confirm it does not unlock toDō+ capabilities.
4. Reinstall and use Restore Purchases.
5. Confirm recognition restores.
6. Confirm a second purchase is prevented because it is non-consumable.
7. Confirm Collab Users do not see the badge without an explicit public preference.

## Scenario F: Explicit Restoration

1. Use an Apple Account with an existing Monthly, Annual, Lifetime, or Founding
   transaction.
2. Install cleanly and sign in to the correct Supabase account.
3. Tap Restore Purchases.
4. Confirm `AppStore.sync()` prompts only as Apple requires.
5. Confirm verified current entitlements are read afterward.
6. Confirm the signed transaction links to the authenticated Supabase account.
7. Verify server capabilities match the restored products.

## Scenario G: Family Sharing

1. Purchase an eligible product as the family organizer or purchaser.
2. On the family member's device, use their Apple Account.
3. Sign in to the family member's own Supabase account.
4. Confirm StoreKit reports family-shared ownership.
5. Confirm the family member receives paid capability.
6. Confirm appreciation products and Founding Supporter are not family-shared.
7. Remove or disable sharing in the Sandbox test state and verify capability updates
   without deleting user data.

## Scenario H: Billing Retry and Grace

1. Use the App Store Connect Sandbox account controls to enable interrupted
   purchases or billing-retry behavior.
2. Let an auto-renewable subscription enter billing retry.
3. Confirm the server notification is stored idempotently.
4. Confirm a grace-period entitlement remains active during the configured period.
5. Resolve billing and confirm active status resumes without duplicate entitlement.
6. Let a separate test expire beyond grace and confirm paid capability ends while
   data remains intact.

## Scenario I: Refund and Revocation

1. Trigger a Sandbox refund or revocation through Apple's available test controls.
2. Confirm the V2 notification reaches Supabase.
3. Verify transaction state is updated rather than duplicated.
4. Confirm effective entitlement is removed when appropriate.
5. Confirm personal and shared data are preserved.
6. Confirm restoring does not revive a revoked transaction incorrectly.

## Scenario J: Account Switching

1. Sign in to Supabase Account A with an active paid entitlement.
2. Verify paid capability.
3. Sign out.
4. Before Account B loads, verify Account A's profile and server entitlement are
   cleared from visible state.
5. Sign in to Account B, which has no linked purchase.
6. Confirm Account B remains free even though the device Apple Account owns a
   transaction linked to Account A.
7. Attempt to link the same original transaction to an unrelated account. The
   server must reject it or route it through the audited recovery path.

## Scenario K: Purchase Before Supabase Sign-In

1. Start signed out of Supabase.
2. Purchase or restore an eligible product.
3. Sign in to the intended Supabase account.
4. Confirm the app sends Apple's signed transaction to `apple-iap-link`.
5. Confirm the server verifies and binds it once.
6. Relaunch and verify server-backed capability.

## Scenario L: Grandfathering

After the actual cutoff is configured:

1. Record one test account created before the release cutoff and one created after it.
2. Run the server reconciliation function with the recorded cutoff.
3. Confirm the pre-cutoff account receives Legacy access and Founding Supporter recognition.
4. Confirm the post-cutoff account receives neither entitlement unless it separately qualifies.
5. Confirm the decision cannot be changed by device clock, reinstall, local
   preference, or edited account metadata.

## Server Evidence

For each scenario, record only:

- product ID;
- environment;
- original transaction identifier in redacted form;
- ownership type;
- entitlement kind and effective dates;
- revocation/grace status;
- linked synthetic Supabase user UUID;
- notification type and idempotency result.

## Pass Criteria

- [ ] Monthly, Annual, and Lifetime purchase and restore correctly.
- [ ] Monthly first-week and Annual first-two-week introductory offers are shown
      only when StoreKit reports the current account eligible.
- [ ] Offer-code redemption uses Apple's system sheet and refreshes entitlements
      after it closes; no literal code is parsed by the app.
- [ ] Family Sharing works only for approved products.
- [ ] Consumables are repeatable, non-restorable, and non-functional.
- [ ] Founding Supporter is one-time, restorable, and non-functional.
- [ ] Billing retry, grace, expiration, refund, and revocation reconcile correctly.
- [ ] Account switching prevents entitlement leakage.
- [ ] Purchase-before-sign-in links securely.
- [ ] Grandfathering uses the server-side account cutoff reconciliation function.
- [ ] No billing transition deletes user data.
