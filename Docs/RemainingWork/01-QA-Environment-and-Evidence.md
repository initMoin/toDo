# Step 01: QA Environment and Evidence

## Objective

Create a repeatable QA environment before changing production state. This gate
prevents account contamination, undocumented configuration changes, ambiguous
results, and accidental disclosure of private data.

## Required Equipment and Accounts

### Apple hardware

- One current iPhone capable of Apple Intelligence and ActivityKit testing.
- One iPad signed into a test Apple Account.
- One Apple Watch paired with the test iPhone.
- One Mac capable of running the native macOS app and menu-bar surface.
- Chargers and a stable Wi-Fi network for all devices.

Use additional narrow iPhones, small Watches, or alternate Macs when available,
but do not replace the required matrix with simulators. Simulator results are
useful for layout checks; they do not prove push delivery, Siri routing, Apple
Intelligence availability, StoreKit account behavior, or physical Watch behavior.

### Test accounts

Prepare these accounts before testing:

1. **Supabase Owner A**: owns test Collabs and sends invitations.
2. **Supabase User B**: accepts invitations and edits shared toDōs.
3. **Supabase User C**: tests the second free accepted outgoing User.
4. **Supabase Stranger D**: has no shared Collab with Owner A and tests privacy.
5. **App Store Sandbox Monthly account**: has never used a toDō+ introductory offer.
6. **App Store Sandbox Annual account**: independent purchase history.
7. **App Store Sandbox Lifetime account**: tests non-consumable ownership.
8. **App Store Sandbox Family account**: purchaser plus eligible family member.
9. **App Store Sandbox state-transition account**: billing retry, grace, refund,
   revocation, and expiration testing.

Do not reuse one Sandbox Apple Account for every scenario. StoreKit purchase
history and introductory-offer eligibility persist and will invalidate later
tests.

## Record the Candidate Build

Create a release record outside the source tree or in the approved release
tracking system. Record:

- Marketing version and build number.
- Xcode version and beta number, if applicable.
- Commit or source snapshot identifier used for the build. If this local checkout
  is not Git-initialized, record the archive creation timestamp and a checksum of
  the archive or source package instead.
- OS version and device model for every test device.
- Supabase project ref.
- StoreKit environment: Xcode, Sandbox, TestFlight, or Production.
- Device language, region, appearance, and accessibility settings.

## Evidence Rules

Capture enough evidence to reproduce failures without exposing secrets.

### Safe evidence

- Screen recording of a UI flow.
- Screenshot with test-only names.
- Console excerpts with tokens and personal information removed.
- APNs response status, reason, environment, and redacted token identifier.
- SQL result containing synthetic test IDs and no email addresses.
- App Store Connect status screenshot with financial and account details hidden.

### Never capture or share

- Supabase access, refresh, service-role, or publishable tokens.
- Apple `.p8` contents, signing certificates, or provisioning credentials.
- Full signed StoreKit JWS payloads.
- Real customer email addresses or private profile fields.
- Complete push tokens.
- Database passwords.

## Reset Procedure Before Each Scenario

1. Write down the account and device assigned to the scenario.
2. Confirm the app is signed out of any prior Supabase account.
3. Confirm StoreKit Sandbox is using the intended Apple Account.
4. Remove prior synthetic records that could affect counts, but never delete real
   user data as part of a test reset.
5. Launch the app and wait for initial sync to finish.
6. Confirm the displayed account, membership, and sync mode.
7. Record the test start time in UTC so server logs can be correlated.
8. Run exactly one scenario before changing accounts.

## Failure Report Template

```text
Title:
Gate and scenario:
Expected:
Observed:
Device and OS:
App version/build:
Account role:
Sync mode:
StoreKit environment:
Exact reproduction steps:
First relevant timestamp in UTC:
Console or server evidence:
Screenshot/screen recording:
Reproducibility: Always | Intermittent | Once
Recovery attempted:
```

## Pass Criteria

- [ ] Every required device and account has an assigned purpose.
- [ ] Candidate build identity is recorded.
- [ ] Evidence storage and redaction rules are understood.
- [ ] Reset and failure-report procedures have been rehearsed once.
- [ ] No production secret is present in the release record.
