# Step 11: Final Release Go/No-Go

## Objective

Make an evidence-backed release decision, run final validation and analysis, submit
the correct universal-purchase build, configure the immutable grandfathering cutoff,
and monitor launch without concealing unresolved blockers.

## Required Gate Status

Before declaring **Go**, confirm:

- Step 01: Passed.
- Step 02: Passed.
- Step 03: Passed.
- Step 04: Passed.
- Step 05: Passed.
- Step 06: Passed, or an explicitly approved scope change removes the feature.
- Step 07: Passed.
- Step 08: Passed, with any unavailable physical-hardware test explicitly accepted.
- Step 09: Deferred; web access is a post-3.1 implementation phase and does not
  block the native release.
- Step 10: Scope acknowledged.

Any security, privacy, purchase, account-isolation, data-loss, crash, duplicate
notification, or broken onboarding defect is a **No-Go**.

## Final Source Validation

From the app checkout:

```sh
cd /Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo
Scripts/validate_release_readiness.sh
```

Expected:

```text
Release readiness validation passed.
```

If validation fails, fix the source or catalog problem. Do not weaken the script
merely to obtain a pass.

## Build and Test Requirements

1. Build affected iOS/iPadOS, macOS, watchOS, and extension schemes in Debug.
2. Build them in Release.
3. Run all focused unit, contract, integration, UI, and regression tests.
4. Run Xcode static analysis on affected targets.
5. Treat new compiler, Swift concurrency, localization, and analyzer warnings as
   defects.
6. Confirm deployment-target availability for every API.
7. Confirm no archive, build product, secret, private log, or test credential is
   bundled or included in the source submission.

## Archive Validation

1. Select the production app scheme.
2. Select a generic distribution destination.
3. Archive with the intended Release configuration.
4. In Organizer, run Validate App.
5. Inspect signing, entitlements, embedded extensions, bundle identifiers, version,
   and build number.
6. Confirm the macOS platform remains part of the universal-purchase app record.
7. Resolve all errors and materially relevant warnings before upload.

## App Store Connect Submission

1. Upload the validated archive.
2. Wait for processing to complete.
3. Attach the correct build to the 3.1 version.
4. Attach every subscription and IAP requiring review.
5. Confirm localized metadata, screenshots, Privacy Policy, Terms, support URL, and
   review notes.
6. Give App Review exact instructions for account, Collab, StoreKit, restoration,
   Apple Intelligence, notifications, and any hardware-dependent flow. Do not
   describe deferred web access as an available 3.1 feature.
7. Verify export compliance and privacy disclosures.
8. Submit for review.

## Set the Grandfathering Cutoff

At the actual public 3.1 release instant:

1. Record the immutable release time in UTC.
2. Run the controlled SQL function `public.reconcile_legacy_pre_release_accounts` with that ISO-8601 value.
3. Do not use local midnight, approval time, upload time, or an estimated date.
4. Immediately test one known pre-cutoff and one post-cutoff acquisition.
5. Preserve the release record proving the chosen instant without exposing secrets.

## Launch Strategy

Use phased release if approved. During rollout monitor:

- Crash and hang rate by platform.
- Authentication failures.
- Sync failures and tombstone resurrection.
- APNs rejection reasons and duplicate notifications.
- Widget and Live Activity regressions.
- StoreKit product-load and purchase failures.
- Server notification processing and dead-letter/retry state.
- Entitlement-link failures and account-switch leakage.
- Profile/Collab authorization denials and suspicious enumeration attempts.
- Web errors, read-only transitions, and RLS denials.

Define who may pause the rollout and how to contact them before release.

## Rollback and Forward-Fix Policy

- Client regression: pause phased release and prepare a corrected build.
- Backend regression: disable only the smallest affected feature if a safe server
  control exists; otherwise deploy a reviewed forward fix.
- Security/privacy issue: stop rollout immediately and contain exposure.
- Never delete customer data to resolve entitlement, sync, or billing state.
- Never rewrite an applied migration; add a corrective migration.

## Final Decision Record

```text
Decision: GO | NO-GO | CONDITIONAL GO
Decision time in UTC:
Candidate version/build:
Decision owner:
Passed gates:
Accepted external blockers:
Known non-blocking issues:
Monitoring owner:
Rollback owner:
Grandfather cutoff status:
App Store Connect submission status:
```

## Pass Criteria

- [ ] Every required gate has passed or has explicit written acceptance.
- [ ] Release readiness validation passes.
- [ ] Debug/Release builds, tests, and static analysis pass without new warnings.
- [ ] Archive validates and contains the intended platforms/extensions.
- [ ] App Store products and review metadata are attached.
- [ ] Grandfathering cutoff procedure is assigned and ready.
- [ ] Monitoring and rollback ownership are explicit.
- [ ] Final decision is recorded before release.
