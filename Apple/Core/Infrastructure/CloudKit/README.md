# CloudKit Foundation

`ToDo` is configured to use the private CloudKit database for Apple-device replication of the local SwiftData store.

Container identifier:
- `iCloud.dev.iamshift.toDo`

Required Apple-side setup:
- enable the iCloud capability for the app identifier
- create the CloudKit container above in Apple Developer
- associate that container with the app identifier and provisioning profiles
- keep the app's SwiftData schema compatible with CloudKit requirements

Architectural note:
- Supabase remains the cross-platform backend
- CloudKit is the Apple-platform private sync layer for the local store
- local SwiftData is the shared persistence layer mirrored to both backends
