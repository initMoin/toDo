# toDō Web foundation decisions

This document records the decisions for the first Web implementation slice. The product and UX source of truth is [`toDo_on_Web_Product_Design_Engineering_Spec.md`](/Users/shift/Downloads/toDo_on_Web_Product_Design_Engineering_Spec.md), with the Apple application used as the established behavior and terminology reference. The standard is: **Familiar to a toDō user. Native to the platform.**

## Product translation

The Web keeps the Apple mental model: Home orientation, a focused list of active toDōs, compact metadata, a clear completion control, and a detail view that exposes notes, due information, tags, and NanoDos. The Web does not imitate SwiftUI sheets, swipe gestures, Dynamic Island surfaces, or other Apple-only controls.

| Apple behavior | Web equivalent | Current status |
| --- | --- | --- |
| Tap a row to open its detail surface | Semantic link to `/todos/:id`, with browser Back/Forward support | Included as the route boundary |
| Leading/trailing swipe actions | Explicit row/detail actions with accessible labels | Included through browser-native controls |
| Long press/context menu | Browser-native pointer/keyboard actions where useful | Not required for the current Web contract |
| Sheet presentation | Responsive detail route; side-by-side detail is a later desktop enhancement | Included as a route boundary |
| NavigationStack | App Router routes and ordinary browser history | Included |
| Guided first capture | Browser route continuation from capture → detail → Settings, with a resumable local step | Included for first capture |
| Utility tray | Search, filter, ordering, grouping, and reset controls in a compact semantic tray | Included |
| Stats reflection | `/stats` route with current workload metrics | Included |
| Account/settings access | Apple-shaped `/account` surface for identity, sign-in methods, Collabs, and account actions; `/settings` owns sync and app preferences | Included |
| Apple-only widgets, Live Activities, Watch surfaces | No Web analogue in this slice | Excluded |

## Framework and structure

The existing Vinext/React/TypeScript project is retained because it already produces the Cloudflare-compatible Sites output and keeps the eventual `web/` package boundary small. The product code is being split into feature and service modules rather than continuing the previous monolithic demo page.

The shared visual source of truth is [`toDo-Brand-UI-UX-Principles.md`](../../Docs/toDo-Brand-UI-UX-Principles.md). Web adopts its semantic color roles, typography roles, spacing and shape guidance, accessibility requirements, and native-platform translation rules. The initial Web theme implementation is classic light/dark in that order; additional named Apple themes remain a later shared-token decision.

The first structure is:

- `app/`: route entry points and document metadata
- `components/`: reusable shell and state primitives
- `features/home/`: home orientation surface
- `features/auth/`: session state and sign-in UI
- `features/todos/`: ToDo data loading, list presentation, and detail presentation
- `lib/`: browser-safe Supabase client and shared data types

The route contract is `/` for Home, `/todos` for the operational ToDosView, `/todos/:id` for browser-native detail navigation, `/stats` for reflection, `/account` for the Apple-shaped account flow, and `/settings` for app preferences. Home uses the document's “What matters now?” hierarchy and first-capture flow. Full editing, lifecycle controls, Tags, NanoDos, basic Collabs, Web Push registration controls, and private calendar-feed controls are now implemented. Full Collab membership administration remains deferred.

## Brand and typography boundary

The approved Cal Sans, Cal Sans UI, Jura, Bebas Neue, and Aleo assets are packaged in `public/fonts/` and exposed through semantic CSS variables: `--font-brand`, `--font-view-title`, `--font-ui`, `--font-display`, and `--font-user-entry`. Cal Sans is reserved for the wordmark. Home questions and ordinary UI use Jura; deliberate top-level view titles use Cal Sans UI; Bebas Neue is reserved for section labels, prominent button moments, and metrics; Aleo is used for user-authored titles and notes. The Web client uses the classic semantic colors in light mode and their documented dark-mode roles under the user's system color preference.

No component library is introduced. Tokens and visual primitives are local CSS, derived from the Apple app's `AppColor` system and observed ToDo list/detail hierarchy.

## Authentication and entitlement boundary

The browser uses only `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
The Web account flow is username-first, but the username is a public locator,
not proof of ownership. A private email address is verified with a short-lived
code during account setup or recovery. A passkey is the preferred returning
sign-in, a password is an optional fallback, and Apple/Google are optional
backup identities that must be explicitly connected to the same canonical
Supabase account UUID.

The Web client never links identities by matching usernames, email addresses,
or provider metadata, and never transfers data between UUIDs. Provider linking
starts from an authenticated account and must verify that the canonical UUID
does not change. TOTP is the preferred additional factor; SMS is an optional
fallback. Email codes verify the private email or support recovery, but are not
treated as the strongest MFA factor. The UI uses the required public username
rather than a full name.

### Browser credential and state storage

- Supabase owns passwords, verified-email state, provider identities, passkeys,
  and MFA factors server-side. Passwords, passkey private keys, TOTP secrets,
  and SMS secrets never enter browser application storage.
- Supabase's browser client may persist the authenticated session so a user can
  return without repeating sign-in. Sign-out must clear that session.
- Username, email-setup intent, and the current verification-step state may be
  held briefly in memory or `sessionStorage`; they must be cleared after
  success, cancellation, sign-out, timeout, or account switch.
- Email OTPs must remain in transient input state only and must never be saved
  to `localStorage`, IndexedDB, analytics, URLs, logs, or query strings.
- Passkeys are created and stored by the browser/operating-system authenticator
  (including Apple Passwords or Google Password Manager). Web does not store or
  export the private key.
- The Web client stores only factor/provider status for presentation. Secret
  material and verification decisions remain in Supabase Auth.

The Web reads `current_account_entitlements`, not the underlying commerce table, and treats an active/grace `todo_plus` or `legacy_3_1` entitlement as full access. Expired/revoked read-only access is not enough for this gated app. Entitlement state is a capability check, not a visual-only gate.

When Supabase is not configured locally, the app shows a setup state. It does not silently substitute demo tasks for a signed-in user's data.

## Data access and RLS

Authenticated reads and the first safe task mutations use the existing tables and policies:

- `todos`: accessible personal and Collab toDōs
- `nanodos`: NanoDos attached to accessible toDōs
- `tags` and `todo_tags`: accessible tag metadata and relationships

The Web client can create and edit accessible personal or Collab toDōs, update completion/lifecycle state, maintain Tags and NanoDos, create basic Collabs, and perform the account data controls exposed in Settings. These operations are server-confirmed through the existing authenticated policies; no service-role credential is introduced in browser code. The production-equivalent RLS matrix remains a release gate.

The current migration chain enables RLS and grants authenticated select access through policies that call the existing access functions. The Web client therefore performs ordinary Supabase reads with the user's session and never uses a service-role key or a server-side credential in browser code.

The Web Push and calendar integration migration is part of the current backend contract. Before public release, verify the live project's applied migration state and the corresponding RLS, Edge Function, webhook, and token behavior. Full Collab membership administration and conflict-resolution semantics are outside the frozen Web 3.1 contract and require a separate product/backend decision before they affect Apple or Android.

## Rendering and hydration

The authenticated surface is client-owned because the Supabase session and browser OAuth callback are client state. Server-rendered output is limited to stable shell text and metadata. Dates are formatted only after data is loaded in the browser with an explicit locale/time-zone policy; no current date or locale-dependent value is rendered as a server/client comparison point.

## Sync posture

The current Web uses confirmed remote retrieval and confirmed mutations with explicit loading, empty, error, unauthenticated, entitlement, and configuration states. The UI labels the current state as `Synced` after confirmed retrieval/mutation; it does not claim realtime delivery. Web Push registration and calendar-feed controls exist, but production delivery and feed compatibility still need verification. The client does not claim offline-first behavior or automatic conflict resolution. Successful lifecycle mutations trigger a fresh remote snapshot, and active views refetch on browser focus, reconnect, page restore, visibility return, and access-token refresh. Detail saves surface a partial-save state rather than silently presenting an optimistic success.

## Cross-platform impact

This work does not modify the Apple or Android applications, their terminology, local stores, or auth flows. It consumes their existing Supabase contract. The public `yourtodo.today` website is also not modified or redeployed.
