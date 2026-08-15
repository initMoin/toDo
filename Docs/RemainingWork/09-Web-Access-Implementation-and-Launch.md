# Step 09: Web Access Implementation and Launch

## Objective

Build and verify the web access included with toDō+ while preserving the free
native personal feature set, server-authoritative entitlements, privacy, sync
correctness, and Collab authorization.

## Product Boundary

### Free native capability remains free

Do not paywall personal toDōs, NanoDos, tags, reminders, recurrence, sorting,
filters, personal sync modes, or the existing native workflow.

### toDō+ adds

- Web access and web sync.
- Unlimited accepted outgoing Users and Collab invitations.
- Unlimited Collab creation/joining according to the approved personal plan.

### When paid access ends

- Existing native and server data remain intact.
- Web becomes read-only for 30 days.
- After 30 days, web access pauses without deleting data.
- Renewing, restoring, Family Sharing, Lifetime, or `legacy_3_1` re-enables access.

## Freeze Contracts Before UI Work

Document and approve:

- Authentication session and refresh behavior.
- Profile response and minimal Collab User projection.
- `current_account_entitlements` response fields and capability mapping.
- Personal and Collab toDō schemas.
- NanoDo, tag, recurrence, reminder, location, and tombstone payloads.
- Pagination, sorting, filtering, and conflict-resolution behavior.
- Error taxonomy: auth, forbidden, validation, conflict, network, server, decoding.

Do not duplicate native business rules in browser-only code. Security-sensitive
limits stay in RLS, RPCs, and server verification.

## Authentication

1. Implement the approved Supabase sign-in methods for web.
2. Use secure session storage appropriate to the selected web architecture.
3. Handle token refresh and expiry.
4. Clear all account-specific caches on sign-out.
5. Verify account switching cannot expose prior data.
6. Ensure redirects are restricted to approved origins.

## Server-Authoritative Entitlements

1. After authentication, query `current_account_entitlements`.
2. Derive web mode only from the server result.
3. Never trust URL parameters, local storage, or client-computed claims.
4. Support Monthly, Annual, Lifetime, Family Sharing, grace, Legacy (`legacy_3_1`), expiration,
   and revocation.
5. Display a recoverable state when entitlement lookup fails; do not guess paid.

## Web Access States

Implement and test:

- **Full access**: read and write.
- **Read-only grace**: data visible, mutations disabled, clear remaining period.
- **Paused**: no operational data view, no deletion, clear renewal/restore guidance.
- **Offline**: cached view only if privacy and correctness permit; no false save state.
- **Server error**: retry with bounded behavior.

## CRUD and Sync Parity

Web must support the approved 3.1 personal and Collab fields:

- title;
- notes;
- due date and optional explicit time behavior;
- reminder intent;
- recurrence;
- tags;
- NanoDos;
- location reminder where browser/platform support is legitimate;
- completion behavior;
- archive/trash lifecycle;
- personal/Collab destination.

Use stable UUID identity and existing `updated_at`/tombstone semantics. Do not create
a second web-only object model.

## Collab Parity

1. List owned and joined Collabs.
2. Create, invite, accept, decline, cancel, and remove according to authorization.
3. Show User profiles through the minimum projection only.
4. Apply free two-accepted-outgoing-User limit on the server.
5. Allow unlimited invitations only when server entitlement says so.
6. Confirm unrelated users cannot enumerate Collabs or profiles.

## Security Verification

Test with a normal browser client, not a service-role key:

- Anonymous access denied.
- Cross-account ID substitution denied.
- Cross-Collab toDō/profile access denied.
- Unauthorized delete denied.
- Invitation-limit bypass denied.
- Email and entitlement internals excluded from Collab User responses.
- Input text and URLs validated and safely rendered.
- Logs contain no tokens, emails, private profiles, or signed transactions.

## Native/Web Integration Matrix

For every field and lifecycle action:

1. Create on web, verify iPhone/iPad/Mac/Watch.
2. Update on native, verify web.
3. Complete/undo on both sides.
4. Archive/restore on both sides.
5. Delete and verify tombstone propagation.
6. Run offline conflict scenarios.
7. Switch accounts on web and native.
8. Change entitlement while web is open and verify mode transition.

## Web Launch Checklist

- [ ] Production domain and TLS configured.
- [ ] Redirect URLs and CORS restricted to approved origins.
- [ ] Privacy Policy and Terms describe web processing.
- [ ] App Store subscription copy accurately describes web access.
- [ ] Full, read-only, paused, offline, and error states implemented.
- [ ] Accessibility and responsive layout tested.
- [ ] Security/RLS test suite passes.
- [ ] Native/web sync and account-switching matrix passes.
- [ ] Monitoring and support recovery procedure documented.

## Pass Criteria

- [ ] Web trusts server entitlements only.
- [ ] Free native features remain unchanged.
- [ ] Full/read-only/paused behavior matches policy.
- [ ] CRUD and Collab parity pass across web and native.
- [ ] RLS blocks anonymous, unrelated, and forged requests.
- [ ] Expiration never deletes user data.
- [ ] Privacy, legal, monitoring, and support paths are ready.
