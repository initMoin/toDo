# Step 10: Personal Product Scope Boundary

## Purpose

Protect the personal productivity product from absorbing unrelated team or
enterprise complexity. This document is a scope boundary, not a plan to build a
second product during 3.1.

## Explicitly Deferred

- Team or enterprise workspaces.
- Seat-based billing.
- Administrative roles beyond Owner and User.
- Organization policy and directory integrations.
- Administrative audit controls.
- Assignment and approval systems designed for teams.
- Enterprise compliance, SSO, SCIM, procurement, or account management.
- Public social profiles, followers, messaging, activity feeds, or productivity
  comparisons.

## Allowed 3.1 Foundations

The following personal-collaboration work may ship in 3.1 without implying a
separate product:

- Personal Collabs.
- Owner and User roles.
- Minimum Collab User profile projection.
- Shared toDōs.
- Free two-accepted-outgoing-User limit.
- Unlimited joining of Collabs owned by others.
- Unlimited personal Collab invitations for toDō+.
- Server authorization and audit-safe transaction handling.

## Terminology

Customer-facing 3.1 language:

- **Collab** for a personal shared list/context.
- **User** for a participating person.
- **Owner** for the person who owns the Collab.

Do not introduce obsolete shared-list terminology. Product and database contracts
use Collab, User, and Owner consistently.

## Revisit Criteria

Revisit a separate product only after:

1. Native 3.1 and web access are stable.
2. Personal Collab usage provides evidence that a separate product is warranted.
3. Roles, billing unit, workspace boundary, and data ownership are defined.
4. The product owner explicitly approves a separate workstream.

## Pass Criteria

- [ ] No separate-product feature blocks 3.1.
- [ ] No team or enterprise billing product is added to the 3.1 App Store configuration.
- [ ] 3.1 UI uses Collab, User, and Owner language.
- [ ] Deferred ideas are tracked without partially shipping unsupported controls.
