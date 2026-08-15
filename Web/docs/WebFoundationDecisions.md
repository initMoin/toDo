# toDō Web foundation decisions

This document records the decisions for the first Web implementation slice. The product and UX source of truth is [`toDo_on_Web_Product_Design_Engineering_Spec.md`](/Users/shift/Downloads/toDo_on_Web_Product_Design_Engineering_Spec.md), with the Apple application used as the established behavior and terminology reference. The standard is: **Familiar to a toDō user. Native to the platform.**

## Product translation

The Web keeps the Apple mental model: Home orientation, a focused list of active toDōs, compact metadata, a clear completion control, and a detail view that exposes notes, due information, tags, and NanoDos. The Web does not imitate SwiftUI sheets, swipe gestures, Dynamic Island surfaces, or other Apple-only controls.

| Apple behavior | Web equivalent | First-slice status |
| --- | --- | --- |
| Tap a row to open its detail surface | Semantic link to `/todos/:id`, with browser Back/Forward support | Included as the route boundary |
| Leading/trailing swipe actions | Explicit row actions and an accessible action menu | Deferred until broader lifecycle mutations |
| Long press/context menu | Native pointer/keyboard menu or labeled action menu | Deferred until task mutations begin |
| Sheet presentation | Responsive detail route; side-by-side detail is a later desktop enhancement | Included as a route boundary |
| NavigationStack | App Router routes and ordinary browser history | Included |
| Guided first capture | Browser route continuation from capture → detail → Settings, with a resumable local step | Included for first capture |
| Utility tray | Search, filter, ordering, grouping, and reset controls in a compact semantic tray | Included |
| Stats reflection | Read-only `/stats` route with current workload metrics | Included as a first read-only slice |
| Account/settings access | Apple-shaped `/account` surface for identity, sign-in methods, Collabs, sync choice, and account actions; `/settings` remains the app-preferences surface | Included |
| Apple-only widgets, Live Activities, Watch surfaces | No Web analogue in this slice | Excluded |

## Framework and structure

The existing Vinext/React/TypeScript project is retained because it already produces a Cloudflare-compatible Worker bundle and keeps the `Web/` package boundary small. The product code is being split into feature and service modules rather than continuing the previous monolithic demo page.

The shared visual source of truth is [`toDo-Brand-UI-UX-Principles.md`](../../Docs/toDo-Brand-UI-UX-Principles.md). Web adopts its semantic color roles, typography roles, spacing and shape guidance, accessibility requirements, and native-platform translation rules. The initial Web theme implementation is classic light/dark in that order; additional named Apple themes remain a later shared-token decision.

The first structure is:

- `app/`: route entry points and document metadata
- `components/`: reusable shell and state primitives
- `features/home/`: home orientation surface
- `features/auth/`: session state and sign-in UI
- `features/todos/`: ToDo data loading, list presentation, and detail presentation
- `lib/`: browser-safe Supabase client and shared data types

The route contract is `/` for Home, `/todos` for the operational ToDosView, `/todos/:id` for browser-native detail navigation, `/stats` for read-only reflection, `/account` for the Apple-shaped account flow, and `/settings` for app preferences. Home uses the document's “What matters now?” hierarchy and first-capture flow; full editing, notifications, and Collab member/invitation management remain later slices.

## Brand and typography boundary

The approved Cal Sans, Cal Sans UI, Jura, Bebas Neue, and Aleo assets are packaged in `public/fonts/` and exposed through semantic CSS variables: `--font-brand`, `--font-view-title`, `--font-ui`, `--font-display`, and `--font-user-entry`. Cal Sans is reserved for the wordmark. Home questions and ordinary UI use Jura; deliberate top-level view titles use Cal Sans UI; Bebas Neue is reserved for section labels, prominent button moments, and metrics; Aleo is used for user-authored titles and notes. The Web client uses the classic semantic colors in light mode and their documented dark-mode roles under the user's system color preference.

No component library is introduced. Tokens and visual primitives are local CSS, derived from the Apple app's `AppColor` system and observed ToDo list/detail hierarchy.

## Authentication and entitlement boundary

The browser uses only `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Apple and Google are started with Supabase OAuth and return to the current Web origin. They remain separate authentication proofs until a resolved account explicitly connects the second provider; the Web client never links identities by username or email and never transfers data between UUIDs. The UI uses the required public username rather than a full name.

The Web reads `current_account_entitlements`, not the underlying commerce table, and treats an active/grace `todo_plus` or `legacy_3_1` entitlement as full access. Expired/revoked read-only access is not enough for this gated app. Entitlement state is a capability check, not a visual-only gate.

When Supabase is not configured locally, the app shows a setup state. It does not silently substitute demo tasks for a signed-in user's data.

## Data access and RLS

Authenticated reads and the first safe task mutations use the existing tables and policies:

- `todos`: accessible personal and Collab toDōs
- `nanodos`: NanoDos attached to accessible toDōs
- `tags` and `todo_tags`: accessible tag metadata and relationships

The Web client can create a personal active toDō and can complete/reopen an accessible toDō. These operations are server-confirmed through the existing `todos_insert_accessible` and `todos_update_accessible` policies; no service-role credential or new backend contract is introduced.

The current migration chain enables RLS and grants authenticated select access through policies that call the existing access functions. The Web client therefore performs ordinary Supabase reads with the user's session and never uses a service-role key or a server-side credential in browser code.

No backend migration is required for the current create/complete slice. Before adding full editing, archive/trash, bulk actions, or conflict resolution, we must test the live project's applied migration state and confirm the corresponding policies and conflict behavior. That later work may require a backend contract discussion before it affects Apple or Android.

## Rendering and hydration

The authenticated surface is client-owned because the Supabase session and browser OAuth callback are client state. Server-rendered output is limited to stable shell text and metadata. Dates are formatted only after data is loaded in the browser with an explicit locale/time-zone policy; no current date or locale-dependent value is rendered as a server/client comparison point.

## Sync posture for the first slice

The current slice uses confirmed remote retrieval plus confirmed create/complete mutations with explicit loading, empty, error, unauthenticated, entitlement, and configuration states. The UI labels the current state as `Synced` after confirmed retrieval/mutation; it does not claim realtime delivery. It does not claim offline-first behavior, optimistic mutation success, browser push delivery, or realtime conflict resolution. Those will be added only with tests for rollback, stale data, concurrent edits, reconnect, and deletion/completion conflicts.

## Cross-platform impact

This work does not modify the Apple or Android applications, their terminology, local stores, or auth flows. It consumes their existing Supabase contract. The public `yourtodo.today` website is also not modified or redeployed.
