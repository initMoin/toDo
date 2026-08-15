# toDō Web

The Web companion for toDō. This package is the `Web/` surface of the toDō
monorepo and keeps the existing Supabase product contract
at its boundary.

The current slice includes the TypeScript/Vinext foundation, browser-native
routing, Apple and Google Supabase OAuth, toDō+ gating, authenticated ToDos,
interactive Settings, Web Push registration, and a private iCalendar feed.

The Web app is an independent Cloudflare Worker with the custom domain
`https://do.yourtodo.today`. Supabase remains the authentication and user-data
backend; Cloudflare serves the Web application and its static assets.

## Local development

Prerequisite: Node.js `>=22.13.0`.

Create `Web/.env.local` with the public Supabase values:

```text
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
VITE_WEB_PUSH_VAPID_PUBLIC_KEY=your-vapid-public-key
```

Never put a Supabase service-role key in this file or any browser bundle.

The production build carries the custom-domain binding in the generated
Cloudflare Wrangler configuration. Do not add a separate DNS record for the
Worker when using Cloudflare Custom Domains; attach `do.yourtodo.today` to the
`todo-web` Worker in Cloudflare Workers & Pages, or deploy the generated
configuration after the Worker project has been created.

Then run:

```bash
npm install
npm run dev
```

Open `http://localhost:3000/`. Without the environment values, the expected
result is an explicit local setup state; the app does not replace Supabase data
with demo tasks.

The Supabase Auth URL configuration must allow `http://localhost:3000/` for
OAuth callbacks during local testing. The signing-in account must have an
active/grace `todo_plus` or `legacy_3_1` entitlement in the existing effective
entitlement view to pass the Web gate.

## Verification

```bash
npm run lint
npm run build
npm test
```

See [`WebFoundationDecisions.md`](docs/WebFoundationDecisions.md) for the
Apple-to-Web interaction decisions and the backend/RLS boundary. See
[`SupabaseWebPushAndCalendar.md`](../Docs/SupabaseWebPushAndCalendar.md) for
the Supabase migration, Edge Function deployment, Web Push secrets, and
calendar-feed setup.
