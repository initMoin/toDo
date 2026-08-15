# Step 04: App Store Connect and IAP Configuration

## Objective

Configure the universal-purchase app record, toDō+ subscriptions, support
purchases, Family Sharing, billing grace, and
App Store Server Notifications without hardcoded storefront assumptions.

## Identity Check

Confirm before creating or editing products:

| Item | Required value |
| --- | --- |
| Apple app ID | `6770143925` |
| iOS bundle ID | `dev.iamshift.toDo` |
| macOS bundle ID | `dev.iamshift.toDo` |
| Subscription group | `toDō+` |
| Supabase project | `kddeevmuyevhgoyvrdlc` |

The iOS and primary macOS app share the app record and bundle identifier for
Apple universal purchase. Extensions, widgets, and Watch targets retain their own
unique identifiers.

## Commercial Prerequisites

In App Store Connect:

1. Sign in as the Account Holder or an account with sufficient access.
2. Open **Business** or **Agreements, Tax, and Banking**.
3. Confirm the Paid Apps Agreement is active.
4. Confirm banking and tax forms are complete and accepted.
5. Resolve any banner that blocks paid product submission.

Do not continue if paid agreements are pending; products may remain unavailable
even when their IDs are correct.

## Subscription Group and Products

Open **Apps > toDō > Monetization > Subscriptions**.

1. Create or verify one group named `toDō+`.
2. Create or verify `toDō+ Monthly`:
   - Product ID: `dev.iamshift.todo.plus.monthly`
   - Duration: 1 Month
   - US base price: $2.99
3. Create or verify `toDō+ Annual`:
   - Product ID: `dev.iamshift.todo.plus.yearly`
   - Duration: 1 Year
   - US base price: $24.99
4. Place both at the same service level because they unlock the same capability
   set.
5. Add all required localizations, review notes, and review screenshots.

Prices displayed by the app must come from StoreKit. The US values above are
configuration targets, not strings to hardcode in SwiftUI.

## Introductory Offers and Offer Codes

Use `Docs/AppStoreOfferConfig.md` as the only active offer configuration:

- Monthly: first week free for eligible new subscribers.
- Annual: first two weeks free for eligible new subscribers.
- Monthly and Annual share one subscription group, and StoreKit may grant only one
  introductory offer from that group to an Apple Account.
- Configure these six community codes for Monthly and Annual: `iamwithshift`,
  `letsdōthis`, `shiftinside`, `shifttoldme`, `todoshiftly`, and `withshift`.
- Configure the Lifetime code `shiftalways` at the approved $45.00 price point.
  Do not reuse `shifttoldme` for Lifetime.

The app uses Apple's StoreKit redemption sheet and refreshes transactions and
server-backed entitlements after it closes. It must not implement custom code
entry, literal-code validation, or client-side entitlement decisions.

## One-Time and Support Purchases

Open **Monetization > In-App Purchases** and verify:

| Product | Product ID | Type | US price |
| --- | --- | --- | --- |
| toDō+ Lifetime | `dev.iamshift.todo.plus.lifetime` | Non-Consumable | $59.99 |
| Coffee for toDō | `dev.iamshift.todo.appreciation.coffee` | Consumable | $0.99 |
| Lunch for toDō | `dev.iamshift.todo.appreciation.lunch` | Consumable | $4.99 |
| Patron of Dōing | `dev.iamshift.todo.appreciation.patron` | Consumable | $12.99 |
| Founding Supporter | `dev.iamshift.todo.appreciation.founding` | Non-Consumable | $22.99 |

Add product localization, review notes, and screenshots. Confirm `Patron of Dōing`
is cleared for sale and not missing price or localization; otherwise StoreKit may
return it as unavailable.

## Family Sharing

Enable Family Sharing only for:

- Monthly
- Annual
- Lifetime

Do not enable it for Coffee, Lunch, Patron of Dōing, or Founding Supporter. Family
Sharing cannot be disabled after activation for an eligible product, so verify the
product ID before saving.

Founding Supporter is available only during the first 14 days after the public 3.1
release. Record the release and removal timestamps, then remove it from sale in App
Store Connect at the end of the window. Previously purchased recognition remains
restorable.

## Billing Grace Period

Start with Sandbox only:

1. Open subscription billing grace settings.
2. Enable grace for Sandbox.
3. Choose 16 days.
4. Apply to all renewals.
5. Complete the StoreKit sandbox grace tests in Step 05.
6. Only after those tests pass, enable Production and Sandbox according to the
   release decision.

## App Store Server Notifications V2

Set the same Version 2 URL for Sandbox and Production:

```text
https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-app-store-notifications
```

Confirm Version 2 is selected. Then test reachability:

```sh
curl -i --request POST \
  'https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-app-store-notifications' \
  --header 'Content-Type: application/json' \
  --data '{}'
```

Expected: HTTP 400 and `Missing signedPayload`.

Test authenticated linking without a session:

```sh
curl -i --request POST \
  'https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-iap-link' \
  --header 'Content-Type: application/json' \
  --data '{}'
```

Expected: HTTP 401 and `Authentication required`.

## Verify Backend Tables

In Supabase Table Editor or SQL Editor confirm these exist:

- `apple_iap_notification_events`
- `apple_iap_transactions`
- `apple_purchase_account_links`
- `apple_app_transaction_links`
- `account_entitlements`

Do not expose signed payload columns in release evidence.

## Grandfathering Cutoff

Do not estimate the Legacy cutoff. At the actual public 3.1 release instant:

1. Record Apple's release time in UTC.
2. Format it as immutable ISO-8601, such as `2026-08-01T16:00:00Z`.
3. Run `select public.reconcile_legacy_pre_release_accounts('<UTC ISO-8601 cutoff>');` in a controlled production SQL session.
4. Immediately verify one known pre-cutoff account and one post-cutoff account.

Every account with a non-null email created before the cutoff receives `legacy_3_1`
and `founding_supporter`. Do not derive this from a device clock, local preference,
or client-computed claim.

## Pass Criteria

- [ ] Paid agreements, tax, and banking are active.
- [ ] Universal-purchase identity matches the required values.
- [ ] Monthly, Annual, Lifetime, three consumables, and Founding Supporter are complete.
- [ ] Monthly first-week and Annual first-two-week introductory offers are configured.
- [ ] Monthly and Annual are in the same subscription group; one introductory offer
      maximum is confirmed by StoreKit behavior.
- [ ] Six Monthly/Annual community codes and the Lifetime `shiftalways` code are
      configured at the approved App Store price points.
- [ ] No superseded offers remain active.
- [ ] Family Sharing is enabled only for Monthly, Annual, and Lifetime.
- [ ] Founding Supporter's 14-day removal timestamp is recorded.
- [ ] Sandbox grace is configured and Production remains pending until tested.
- [ ] Both V2 notification URLs are correct.
- [ ] Endpoint smoke tests return the expected safe failures.
- [ ] Five IAP backend tables exist.
- [ ] Grandfather cutoff remains unset until the public release instant.
