# toDō 3.1 Remaining Work

This folder converts the remaining external work for toDō 3.1 into an ordered,
auditable release runbook. The native implementation is code-complete; these
documents cover production deployment, external configuration, sandbox and
real-device verification, native commerce, future web access, and the final release
decision.

## How to Use This Runbook

1. Complete the files in numeric order unless a file explicitly says it may run
   in parallel.
2. Do not mark a gate complete because an action was attempted. Mark it complete
   only after every **Pass Criteria** item is satisfied.
3. Save evidence in the release record described in Step 01. Do not save access
   tokens, signed transaction payloads, private keys, user emails, or production
   profile data in screenshots or logs.
4. Record a blocker rather than silently skipping a test. A blocker must name the
   environment, exact step, error, owner, and next action.
5. Never deploy a production database migration or change App Store Connect
   configuration without the product owner's explicit approval.
6. Use **Collab**, **User**, and **Owner** consistently in product and database
   contracts. The canonical tables are `collabs`, `collab_users`, and
   `collab_invitations`.

## Source of Truth

- App checkout: `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo`
- Authoritative backend: `/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase`
- Supabase production project: `kddeevmuyevhgoyvrdlc`
- Apple app ID: `6770143925`
- Primary iOS and macOS bundle ID: `dev.iamshift.toDo`

Do not use the minimal nested `ToDo/ToDo/supabase` directory as a backend
source. Do not move already-public 3.0.1 personal functionality behind toDō+.

## Execution Order

| Step | Gate | Depends On | Completion Result |
| --- | --- | --- | --- |
| 01 | [QA Environment and Evidence](01-QA-Environment-and-Evidence.md) | None | Reproducible test environment and release record |
| 02 | [Production Database Migrations](02-Production-Database-Migrations.md) | 01, explicit approval | Profile and Collab schema safely deployed |
| 02A | [Production Migration Reconciliation](02A-Production-Migration-Reconciliation.md) | 02 | Historical local and remote migration versions reconciled |
| 02B | [Supabase Hardening and Replayable Baseline](02B-Supabase-Hardening-and-Replayable-Baseline.md) | 02A, explicit approval | Webhook credential rotated, bounded maintenance active, baseline strategy verified |
| 03 | [Profile, RLS, and Collab Authorization](03-Profile-RLS-and-Collab-Authorization.md) | 02 | Privacy and collaboration rules proven |
| 04 | [App Store Connect and IAP Configuration](04-App-Store-Connect-and-IAP-Configuration.md) | 01 | Products, offers, notifications, and grace period configured |
| 05 | [StoreKit Sandbox Validation](05-StoreKit-Sandbox-Validation.md) | 04 | Purchases and server entitlements proven |
| 06 | [Siri, App Intents, and Apple Intelligence QA](06-Siri-App-Intents-and-Apple-Intelligence-QA.md) | Candidate build | Structured voice creation proven on device |
| 07 | [Accessibility and Localization QA](07-Accessibility-and-Localization-QA.md) | Candidate build | Supported accessibility and language behavior verified |
| 08 | [Platform Services and Cross-Device QA](08-Platform-Services-and-Cross-Device-QA.md) | 02-07 | Notifications, widgets, Live Activities, sync, and Watch verified |
| 09 | [Web Access Implementation and Launch](09-Web-Access-Implementation-and-Launch.md) | Post-3.1 | Future toDō+ web access and native/web parity |
| 10 | [Personal Product Scope Boundary](10-toDo-Work-Deferred-Scope.md) | None | Personal-product scope remains protected |
| 11 | [Final Release Go/No-Go](11-Final-Release-Go-No-Go.md) | All required gates | Evidence-backed release decision |

## Blocking Versus Non-Blocking Work

Steps 01 through 08 and 11 block the native 3.1 release. Step 09 is intentionally
post-3.1 work for the future toDō+ web experience. Step 10 is a scope-control
document, not an implementation gate.
If a platform cannot be physically tested, record it as an external blocker; do
not convert an untested requirement into a pass.

## Completion Notation

Use this status block at the top of a release record for every step:

```text
Status: Not Started | In Progress | Passed | Failed | Blocked
Owner:
Started:
Completed:
Build:
Environment:
Evidence:
Blockers:
Notes:
```
