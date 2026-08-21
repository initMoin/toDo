# toDō

toDō is a focused task-management product built around clarity, structure,
and daily momentum. This repository is the product monorepo for the native
Apple clients, Android client, Web client, and shared Supabase backend.

The guiding standard is:

> Familiar to a toDō user. Native to the platform.

The Apple implementation remains the primary reference for product behavior,
terminology, information hierarchy, and interaction intent. Android and Web
adapt those behaviors to their platforms without turning toDō into a generic
dashboard or copying Apple-only controls literally.

## Repository structure

```text
Apple/                                          Apple iPhone/iPad/Mac/watchOS code
Apple/toDo.xcodeproj                           Apple Xcode project and targets
Google/ToDo_onGoogle/                          Kotlin / Jetpack Compose app
Web/                                             React / TypeScript Web app
Shared/Supabase/                               migrations, RLS, Edge Functions
Docs/                                            product, brand, QA, and operations
```

Each client now has an explicit platform boundary. Apple remains the primary
product reference, while Google and Web implement the same product semantics in
platform-native ways. Shared backend infrastructure lives under `Shared/`.

The public marketing site at [yourtodo.today](https://yourtodo.today) remains
a separate project and repository: [initMoin/yourToDo.today](https://github.com/initMoin/yourToDo.today).
It is not deployed or modified by the Web product build.

## Platform surfaces

### Apple

The root Xcode project contains the iPhone, iPad, Mac, Apple Watch, widgets,
App Intents, StoreKit, notifications, calendar, and Supabase synchronization
surfaces. Apple is the established product reference for the other clients.

Open `Apple/toDo.xcodeproj` in Xcode, or inspect the available targets and schemes:

```bash
xcodebuild -list -project Apple/toDo.xcodeproj
```

### Android

`Google/ToDo_onGoogle/` is a native Kotlin and Jetpack Compose application. It uses a
Room-backed local source of truth, a durable sync outbox, Supabase transport,
Realtime invalidation, and adaptive phone/tablet layouts.

Open `Google/ToDo_onGoogle/` in Android Studio and use its checked-in Gradle wrapper.
Local Supabase and Google/Firebase configuration is documented in
[`Google/ToDo_onGoogle/Docs/SyncProviderSetup.md`](Google/ToDo_onGoogle/Docs/SyncProviderSetup.md).
Those machine-local files are ignored and must not be committed.

```bash
cd Google/ToDo_onGoogle
./gradlew test
```

### Web

`Web/` is the gated toDō+ Web surface at
[`https://do.yourtodo.today`](https://do.yourtodo.today). Cloudflare Workers
serves the Web application; Supabase remains responsible for authentication,
entitlements, RLS-protected data, Web Push persistence, calendar-feed
generation, and related Edge Functions.

Local setup:

```bash
cd Web
npm install
npm run dev
```

Create `Web/.env.local` with browser-safe values only:

```text
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
VITE_WEB_PUSH_VAPID_PUBLIC_KEY=your-vapid-public-key
```

Never use a Supabase service-role key in Web environment variables or browser
code. Without these values, the correct local result is an explicit setup
state—not demo data.

The Web foundation currently includes Apple and Google OAuth, separate account
identity handling, toDō+ entitlement gating, authenticated ToDo retrieval,
Collabs/shared-list reads, browser-native routes, responsive Apple-shaped UI,
settings subviews, Web Push registration, and a private iCalendar feed.

The current Web slice does not claim offline-first behavior, realtime conflict
resolution, or complete task and Collab lifecycle coverage. Those require their
own sync, RLS, rollback, and cross-platform verification work.

## Shared Supabase backend

The `Shared/Supabase/` directory is the shared backend contract for Apple, Android, and
Web. It contains:

- ordered schema and RLS migrations;
- Collabs, usernames, entitlements, account deletion, and profile storage;
- notification and sync infrastructure;
- Web Push and private calendar-feed migrations;
- Edge Functions for push, calendar, account, and Apple commerce workflows;
- database contract tests and sanitized schema snapshots.

Apply migrations to a Supabase project only after reviewing the migration order
and comparing it with the project’s applied migration history. The browser and
mobile clients use publishable credentials with RLS; privileged credentials
belong only in protected server or Edge Function configuration.

## Verification

Web:

```bash
cd Web
npm run lint
npm test
```

Android:

```bash
cd Google/ToDo_onGoogle
./gradlew test
```

Apple build verification can use a generic simulator destination without code
signing:

```bash
xcodebuild \
  -project Apple/toDo.xcodeproj \
  -scheme ToDo \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/todo-apple-deriveddata \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Cloudflare deployment shape

The Web project is deployed independently from the public marketing site:

- Cloudflare Worker name: `todo-web`;
- Cloudflare Workers & Pages project root: `Web`;
- build command: `npm run build`;
- generated deployment configuration: `Web/dist/server/wrangler.json`;
- custom domain: `do.yourtodo.today`;
- application backend: the existing Supabase project.

Use a Cloudflare Custom Domain for `do.yourtodo.today`; do not add a second
provider-hostname CNAME. Cloudflare should manage the DNS record and TLS
certificate for the custom domain. The complete setup, Supabase redirect URLs,
secrets, Workers Builds configuration, and post-deployment checks are in
[`Docs/WebProductionSetup.md`](Docs/WebProductionSetup.md).

## Product and design references

- [Brand, UI, and UX principles](Docs/toDo-Brand-UI-UX-Principles.md)
- [Web foundation decisions](Web/docs/WebFoundationDecisions.md)
- [Web local development](Docs/WebLocalDevelopment.md)
- [Web production setup](Docs/WebProductionSetup.md)
- [Supabase Web Push and calendar integration](Docs/SupabaseWebPushAndCalendar.md)
- [Android branding implementation](Google/ToDo_onGoogle/Docs/Android-Branding-Implementation.md)
- [Android sync provider setup](Google/ToDo_onGoogle/Docs/SyncProviderSetup.md)

## Security and repository hygiene

The root `.gitignore` excludes Xcode and Gradle output, Node and Deno
dependencies, local environment files, Firebase configuration, Supabase
runtime state, and exported IPAs. Review `git status --ignored` before every
commit. Do not force-push `main`, commit local provider configuration, or
deploy a backend migration without confirming its production impact.

## License and contribution

See [`LICENSE.md`](LICENSE.md), [`SECURITY.md`](SECURITY.md),
[`CONTRIBUTING.md`](CONTRIBUTING.md), and the GitHub issue and pull-request
templates for project-specific guidance.
