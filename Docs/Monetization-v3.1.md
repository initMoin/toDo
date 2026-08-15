# Superseded: toDō 3.1 Monetization and Entitlement Specification

> This document is retained for implementation history only. The approved source of
> truth is [`Monetization.md`](Monetization.md). Where the documents differ,
> `Monetization.md` controls.

## Product Boundary

toDō 3.1 keeps every personal capability publicly available in 3.0.1 free. Existing Apple, iCloud, and toDō Sync behavior must not depend on a paid entitlement. Paid access adds web access and expanded personal collaboration; it does not remove or meter the existing personal workflow.

Personal products:

- `toDō`: free personal app
- `toDō+ Monthly`: auto-renewable subscription
- `toDō+ Yearly`: auto-renewable subscription
- `toDō+ Lifetime`: non-consumable purchase

Business product `toDō Work` is deferred until workspaces, administration, roles, and seat management are mature. Version 3.1 presents only Owner and User roles in personal Collabs.

## Product Identifiers

These identifiers are immutable after they are created in App Store Connect:

| Product | Identifier | Type |
| --- | --- | --- |
| toDō+ Monthly | `dev.iamshift.todo.plus.monthly` | Auto-renewable subscription |
| toDō+ Yearly | `dev.iamshift.todo.plus.yearly` | Auto-renewable subscription |
| toDō+ Lifetime | `dev.iamshift.todo.plus.lifetime` | Non-consumable |
| Coffee for toDō | `dev.iamshift.todo.appreciation.coffee` | Consumable |
| Lunch for toDō | `dev.iamshift.todo.appreciation.lunch` | Consumable |
| Patron of Doing | `dev.iamshift.todo.appreciation.patron` | Consumable |
| Founding Supporter | `dev.iamshift.todo.appreciation.founding` | Non-consumable |

All displayed prices must come from StoreKit so storefront currency and tax presentation remain correct.

## Pricing and Introductory Access

Standard United States pricing:

- Monthly: $2.99 per month
- Yearly: $19.99 per year
- Lifetime: $69.99 once

Launch offers:

- Monthly: 1 week free, then $0.99 per month for three months, then $2.99 per month
- Yearly: 14 days free, then $12.99 for the first year, then $19.99 per year
- `shifttoldme`: monthly launch offer code
- `intention`: yearly launch offer code
- Launch-code redemption closes 90 days after the public 3.1 release

The free trials are introductory offers. The discounted periods are subscription offer-code offers configured to run after the introductory trial available to a new subscriber.

For product copy and the Terms of Use, **new subscriber** means an Apple Account
that has not previously redeemed an introductory offer in the `toDō+` subscription
group. Apple determines this status from the customer's App Store purchase history;
toDō does not determine or override it. The Terms of Use published at
`https://yourtodo.today/legal/terms.html` must include this definition before the
3.1 release is submitted for review.

## Appreciation

- Coffee for toDō: $0.99, repeatable
- Lunch for toDō: $6.99, repeatable
- Patron of Doing: $14.99, repeatable
- Founding Supporter: $24.99, one-time and restorable

Appreciation purchases do not unlock product functionality. Founding Supporter permanently records an acknowledgment on the account and may show an optional account badge.

## Capabilities

Free users:

- Keep all 3.0.1 personal features and sync modes
- May have two accepted outgoing collaboration invitations at a time
- May join unlimited shared lists

toDō+ subscribers and Lifetime owners:

- Receive web access and web sync
- May create and join unlimited shared lists
- May send unlimited collaboration invitations
- Receive Apple Family Sharing access when shared by the purchaser

Declined, canceled, and expired invitations do not consume free invitation slots. Removing a user frees a slot.

The native app disables its invitation action when the server reports two accepted
outgoing users. That is a UX guard, not the security boundary. Invitation
acceptance is serialized and rechecked by the database so concurrent acceptances,
older clients, and direct API requests cannot exceed the free limit. Pending
invitations remain valid until accepted, declined, canceled, or expired; if a free
owner is already at the limit when another person accepts, acceptance is refused
without discarding the invitation.

Personal shared lists are represented as Collabs. Version 3.1 Collabs support only
Owner and User roles. Administrative roles, seats, organization policy, and
workspace management remain reserved for toDō Work.

## Expiration and Downgrade

- Never delete local or server data because an entitlement expires.
- Existing Collabs and users continue working.
- A downgraded owner above the free limit cannot create another shared list or send another invitation.
- Web becomes read-only for 30 days after paid access ends, then pauses without deleting data.
- Renewing or restoring immediately re-enables paid capabilities.
- Enable App Store billing grace period to avoid interruption during temporary billing failures.

## Grandfathering

This historical AppTransaction design was replaced. The approved model grants
`legacy_3_1` and `founding_supporter` to accounts with a non-null email created before
the public 3.1 release cutoff. The server reconciliation function owns that decision;
the client reads the resulting entitlements. Legacy access includes every current and
future paid capability, while Lifetime remains limited to toDō+.

## Purchase Restoration and Account Linking

Apple clients read `Transaction.currentEntitlements` on launch and listen for transaction updates. The Restore Purchases command calls `AppStore.sync()` only after explicit user action.

When a signed-in user purchases a product, pass their toDō account UUID as StoreKit's `appAccountToken`. For purchases made before sign-in or shared through Family Sharing, send the verified StoreKit JWS transaction to a protected server endpoint after sign-in. The server must:

1. Authenticate the Supabase user.
2. Verify the Apple-signed transaction and bundle identifier.
3. Confirm product, environment, revocation, ownership, and expiration state.
4. Bind the original transaction to one toDō account without trusting client-provided entitlement fields.
5. Process App Store Server Notifications V2 for renewals, refunds, revocations, billing retry, grace period, and Family Sharing changes.
6. Expose only the resulting account capability state to Apple clients and the web app.

One Apple original transaction must not be attachable to unrelated toDō accounts. Customer support needs an audited recovery path for incorrect account linking.

## Required Validation

- New monthly and yearly purchase flows
- Both introductory trials and both launch offer codes
- Monthly, yearly, and Lifetime restoration
- Family Sharing purchaser and family-member transactions
- Renewal, expiration, billing retry, grace period, refund, and revocation
- Purchase before sign-in followed by account linking
- Sign-out and sign-in to a different account
- Free invitation limit and downgrade behavior
- Founding Supporter restoration; repeatable appreciation purchases remain non-restorable
- Web read-only grace and reactivation after renewal
