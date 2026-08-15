# Correct App Store Offer Configuration

Replace any previous implementation notes that describe a free first month, a discounted first annual year, or another unapproved offer structure.

## toDō+ Monthly

```text
Standard price
$2.99 per month

Introductory offer
First week free

Offer-code benefit
First 3 days free
```

Active community codes:

```text
iamwithshift
letsdōthis
shiftinside
shifttoldme
todoshiftly
withshift
```

The subscription automatically renews at the standard monthly price after the applicable promotional and introductory periods unless the user cancels.

Eligible customers may receive both the offer-code benefit and the introductory offer, subject to Apple’s StoreKit eligibility rules.

## toDō+ Annual

```text
Standard price
$24.99 per year

Introductory offer
First 2 weeks free

Offer-code benefit
First week free
```

Active community codes:

```text
iamwithshift
letsdōthis
shiftinside
shifttoldme
todoshiftly
withshift
```

The subscription automatically renews at the standard annual price after the applicable promotional and introductory periods unless the user cancels.

Eligible customers may receive both the offer-code benefit and the introductory offer, subject to Apple’s StoreKit eligibility rules.

## Introductory-Offer Eligibility

Monthly and Annual belong to the same subscription group.

A customer may receive only one introductory offer from that subscription group. Do not imply that a customer can redeem the Monthly introductory offer and later receive the Annual introductory offer.

Use StoreKit subscription information as the source of truth for introductory-offer eligibility.

## toDō+ Lifetime

```text
Product type
Non-consumable

Standard price
$59.99

Introductory offer
None

Offer-code price
$45.00, subject to the configured App Store price point
```

Lifetime does not support subscription introductory offers because it is not an auto-renewable subscription.

Lifetime may use Apple’s In-App Purchase offer-code system.

The Lifetime custom code should be:

```text
shiftalways
```

Do not use `shifttoldme` for Lifetime while that code is active on another offer within the same app.

Lifetime purchases and discounted Lifetime offer-code redemptions grant the same permanent `todo.plus` entitlement.

## Implementation Rules

Do not hard-code promotional durations or prices as entitlement logic.

The app may display approved promotional messaging, but StoreKit transaction data remains authoritative for:

- Offer eligibility
- Promotional period dates
- Introductory period dates
- Renewal status
- Expiration
- Revocation
- Lifetime ownership

After Apple’s offer-code redemption interface closes:

1. Synchronize StoreKit transactions.
2. Refresh verified current entitlements.
3. Refresh subscription status.
4. Update the membership interface.
5. Do not attempt to determine which literal code the customer entered.

Do not build a custom code-entry or validation system.