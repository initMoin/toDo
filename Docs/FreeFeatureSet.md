# Free Feature Set Contract

ToDo's current personal productivity feature set is permanently treated as free. toDō+ may add expanded personal collaboration, web access, and other advanced personal features, but it must not remove or paywall the individual workflow that already exists.

## Free Personal Scope

- Individual ToDos and NanoDos
- Tags
- Basic and complex reminders
- Recurring reminders
- Sorting, grouping, and filtering
- Saved personal views when implemented for personal use
- Personal calendar and planning views when implemented for personal use
- This Device Only storage
- Sync with iCloud for Apple devices when available
- ToDo Sync for personal account sync when available
- Creation of personal shared lists
- Up to two accepted outgoing users across owned Collabs
- Unlimited membership in shared lists owned by other people

## toDō+ Expansion Boundary

toDō+ may add recurring services and operating modes beyond the existing personal feature set:

- Web access and web sync
- Unlimited accepted outgoing users and Collab invitations
- Premium widgets, extended history, and advanced statistics
- Smart automation and future AI functionality
- Future cross-platform access and account-backed services

Version 3.1 presents only Owner and User roles in personal Collabs. The deployed
backend stores the role as `user`. No team, enterprise, workspace-administration,
or seat-billing product is part of the personal app's current scope.

## Engineering Rule

Current personal features should not depend on future monetization checks. If a future capability system is added, personal capabilities must default to enabled and should be covered by tests.
