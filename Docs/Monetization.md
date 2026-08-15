# toDō Monetization
**Version:** 1.0  
**Status:** Approved  
**Last Updated:** July 2026

---

# Philosophy

The monetization of toDō exists to sustain development without compromising the user's experience.

Every payment should have a clear purpose. Users should never feel pressured into purchasing features through artificial limitations, nor should subscriptions exist solely because recurring billing is common.

toDō should always remain a productivity system for the user.

---

# Vision

The goal is to build a sustainable business around toDō while remaining true to its principles.

The free experience should be complete enough for users to adopt and recommend the application.

Paid offerings should represent additional value rather than removing existing value.

---

# Design Principles

## Respect the User

Users should never feel punished for using the free version.

Avoid artificial restrictions designed solely to encourage purchases.

---

## Payments Should Match Value

Each purchase should correspond to a clear benefit.

- One-time purchases unlock permanent functionality.
- Subscriptions fund ongoing services.
- Support purchases simply support development.

---

## Simplicity

The purchasing experience should be understandable in under one minute.

There should be one premium membership.

Not multiple confusing tiers.

---

## Lifetime Means Lifetime

A Lifetime purchase grants permanent access to toDō+.

Users should never be asked to purchase the same entitlement twice.

---

## Support Is Appreciation

Support purchases never unlock functionality.

They exist purely for users who wish to support continued development.

---

## Reward Loyalty

Early supporters made the continued development of toDō possible.

They should always receive recognition.

---

# Product Structure

```
toDō Free

↓

toDō+

Monthly
Annual
Lifetime

↓

Support
```

---

# Free

The free version should always remain useful.

Included:

- This Device Only
- iCloud Sync
- Unlimited ToDos
- NanoDos
- Notes
- Reminders
- Recurrence
- Tags
- Search
- Widgets
- Live Activities
- App Intents
- Apple Watch support
- Calendar Mirroring
- Core productivity experience

The goal is that users can genuinely adopt toDō without paying.

---

# toDō+

toDō+ is the premium membership.

It unlocks advanced functionality and future services.

Users choose **how** they pay.

Not **what** they receive.

Available as:

- Monthly
- Annual
- Lifetime

All three unlock identical features.

Only the payment method differs.

---

# Version 3.1 toDō+ Value

At launch, toDō+ provides:

- Unlimited outgoing invitations for personal Collabs
- Access to every new toDō+ feature released while the membership is active
- Family Sharing for eligible Apple purchases

Free users may have up to two accepted outgoing Users across the Collabs they own.
Pending, declined, canceled, and expired invitations do not consume those two places.
Users may join unlimited Collabs owned by other people.

Lifetime owners permanently receive toDō+.
Legacy users receive toDō+ plus every future paid capability, with Founding
Supporter recognition included.

---

# Pricing

## Monthly

$2.99 USD

---

## Annual

$24.99 USD

---

## Lifetime

$59.99 USD

---

## Promotional and Introductory Offers

The active App Store configuration is defined in
[`AppStoreOfferConfig.md`](AppStoreOfferConfig.md). StoreKit and Apple's server
transaction data are authoritative; durations, eligibility, renewal, expiration,
revocation, and lifetime access must never be inferred from local copy or a
user-entered code.

- Monthly: first week free for eligible new subscribers; renews at $2.99 USD per
  month.
- Annual: first two weeks free for eligible new subscribers; renews at $24.99 USD
  per year.
- Monthly and Annual share one subscription group. A customer can receive at most
  one introductory offer from that group.
- Offer-code benefits are configured in App Store Connect. The app uses Apple's
  StoreKit redemption sheet and does not parse or validate literal codes itself.
- Lifetime remains a $59.99 USD non-consumable. A configured offer code may provide
  the approved $45.00 price point; both normal purchase and redemption grant the
  same permanent `todo.plus` capability.

The app may explain these approved offers, but it must show a promotional duration
only when StoreKit reports the relevant introductory offer as available to the
current customer.

---

# toDō+ Roadmap

Current and future functionality may include:

- Advanced productivity tools
- Enhanced organization
- Advanced planning
- Premium widgets
- Extended history
- Advanced statistics
- Smart automation
- Future AI functionality
- Future web experience
- Future account-based sync
- Future cross-platform support
- Future collaboration features

As toDō evolves, additional value will be added to toDō+.

---

# Support

Support purchases never unlock features.

They exist for users who simply want to help fund continued development.

---

## Coffee for toDō

Consumable

$0.99 USD

> "Thanks. Here's a coffee."

---

## Lunch for toDō

Consumable

$4.99 USD

> "I've been getting real value from toDō."

---

## Patron of Dōing

Consumable

$12.99 USD

> "I believe in where this project is going."

---

## Founding Supporter

Non-Consumable

$22.99 USD

Available only during the first 14 days following the release of version 3.1.

After the availability window closes, the purchase will be removed from sale permanently.

### Purpose

Founding Supporter is recognition.

It is not another tip.

It recognizes those who chose to support the beginning of the next chapter of toDō.

Recognition is permanent.

---

# Early Adopter Reward

Every account with an email address that existed before the public release of version 3.1 will automatically receive:

- Lifetime toDō+
- Founding Supporter recognition

This reward is permanent.

No purchase is required.

It exists to recognize the earliest supporters who believed in toDō during its formative years. Eligibility is determined by the server from the account creation date and the fixed 3.1 release cutoff, not from a local preference, device clock, or client-provided claim.

---

# Recognition

Users may receive recognition such as:

- Early Adopter
- Founding Supporter

Recognition is informational only.

It unlocks no additional functionality.

---

# App Store Connect

## Subscription Group

Reference Name

```
toDō+ Membership
```

---

## Monthly Subscription

Reference Name

```
toDō+ Monthly
```

Display Name

```
toDō+
```

Product Identifier

```
dev.iamshift.todo.plus.monthly
```

---

## Annual Subscription

Reference Name

```
toDō+ Annual
```

Display Name

```
toDō+
```

Product Identifier

```
dev.iamshift.todo.plus.yearly
```

---

## Lifetime

Type

```
Non-Consumable
```

Reference Name

```
toDō+ Lifetime
```

Display Name

```
toDō+ Lifetime
```

Product Identifier

```
dev.iamshift.todo.plus.lifetime
```

---

## Support Products

### Coffee for toDō

Consumable

```
dev.iamshift.todo.appreciation.coffee
```

---

### Lunch for toDō

Consumable

```
dev.iamshift.todo.appreciation.lunch
```

---

### Patron of Dōing

Consumable

```
dev.iamshift.todo.appreciation.patron
```

---

### Founding Supporter

Non-Consumable

```
dev.iamshift.todo.appreciation.founding
```

---

# StoreKit Entitlements

```
Free

↓

toDō+

↓

Lifetime

↓

Support
```

### Entitlements

```
todo_plus
```

Granted by:

- Monthly
- Annual
- Lifetime
- Early Adopter Reward

---

```
founding_supporter
```

Granted by:

- Founding Supporter purchase
- Early Adopter Reward

---

# User Interface

The purchase screen should remain intentionally simple.

```
toDō+

Monthly

Annual

Lifetime

──────────────

Support Development

Coffee for toDō

Lunch for toDō

Patron of Dōing

Founding Supporter
```

---

# Migration Strategy

When version 3.1 launches:

1. Existing users continue uninterrupted.
2. Current purchases migrate automatically.
3. Legacy users receive:
   - toDō+ and every current and future paid capability
   - Founding Supporter recognition
4. No existing customer loses functionality.

---

# Technical Notes

Legacy status should be granted once and persisted as a server-owned entitlement.

At release, an operator supplies the immutable public 3.1 release instant to the
server reconciliation function. The function checks the authenticated account's
server-side creation date and non-null email, then grants `legacy_3_1` and
`founding_supporter` idempotently. The client only reads those entitlements.

The existing App Store product identifiers remain unchanged even when customer-facing
names change. Product identifiers cannot be edited after creation in App Store Connect.

The `legacy_3_1` server entitlement records Legacy access. A qualifying account
also receives a `founding_supporter` recognition entitlement. Legacy access is a
durable override for every current and future paid capability; it is not modeled
as a purchased Lifetime product.

Founding Supporter should restore like any other non-consumable purchase.

Lifetime should be treated as a permanent toDō+ entitlement only. It does not
automatically include future paid capabilities that are not part of toDō+.

---

# Future Expansion

Future additions to toDō+ may include:

- Web
- Android
- AI
- Personal collaboration
- Cloud backup
- Cross-platform synchronization
- Advanced automation

These features should naturally expand the value of the membership rather than redefining it.

---

# Core Principle

People should purchase toDō because they love using it.

They should subscribe because they value the services it provides.

They should support it because they believe in its future.

Every decision regarding monetization should reinforce that philosophy.

---

# What This Is Not

toDō will not:

- Restrict the free experience through arbitrary limits.
- Charge subscriptions for features that incur no ongoing cost without clear user value.
- Use advertisements.
- Sell user data.
- Introduce pay-to-win productivity mechanics.
- Gate bug fixes or accessibility improvements behind payment.
- Ask existing users to repurchase functionality they already own.
- Complicate purchasing with unnecessary tiers or confusing feature matrices.
- Never optimize monetization at the expense of trust.

Every future monetization decision should be measured against these principles.

---

# Final Principle

The success of toDō will not be measured by how many purchases it generates.

It will be measured by how many people trust it enough to make it part of their daily lives.

Monetization exists to sustain that relationship, never to replace it.
