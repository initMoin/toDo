# toDō Web production setup

This document covers the eventual production setup for
`https://do.yourtodo.today`. The current implementation is the foundation
slice; it is not ready for a public production deployment until the release
checks below pass.

## Supabase values

Configure these public build values in the Web deployment environment:

```text
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Never expose the Supabase service-role key in browser code, build output, or
client environment variables.

## Apple and Google sign-in

In Supabase Auth URL Configuration:

- Site URL: `https://do.yourtodo.today`
- Additional redirect URL: `https://do.yourtodo.today/`
- Keep `http://localhost:3000/` for local testing

Enable Apple and Google in Supabase Auth. In each provider console, use the
exact Supabase callback URL shown by Supabase, normally:

```text
https://<project-ref>.supabase.co/auth/v1/callback
```

The Web client redirects to the current origin after Supabase completes OAuth.
Apple and Google are separate authentication proofs until a resolved account
explicitly connects the second provider. Never merge accounts by username or
email, and never move account data between UUIDs through provider sign-in.

## Entitlement and RLS checks

Web access is gated by `current_account_entitlements`. An account needs an
active or grace `todo_plus`/`legacy_3_1` record with `access_mode = full`.

Before deploying the read path, verify the live project's applied migrations
and authenticated RLS behavior for:

- `todos`
- `nanodos`
- `tags`
- `todo_tags`
- accessible `collabs`

The current Web slice only reads these surfaces. It does not use a server-role
credential and does not write task data.

## Cloudflare Worker and custom domain

Deploy the Web application as its own Cloudflare Worker, independently from
the existing static `yourtodo.today` website. The source build identifies the
Worker as `todo-web` and carries `do.yourtodo.today` as a Cloudflare Custom
Domain. Supabase remains the authentication and user-data backend; it does not
host the Web UI.

In Cloudflare Workers & Pages:

1. Create or select the separate Worker project for `todo-web`.
2. Attach the Custom Domain `do.yourtodo.today` to that Worker.
3. Because the `yourtodo.today` zone is already managed by Cloudflare, let
   Cloudflare create and manage the DNS and certificate for the Custom Domain.
   Do not add a second CNAME pointing at a provider-generated hostname.
4. Build the Web project and deploy the generated Cloudflare configuration.
   Deployment is intentionally a separate approval step from this connection
   work.

After deployment, verify:

- `https://do.yourtodo.today/`
- `https://do.yourtodo.today/legal/privacy`
- `https://do.yourtodo.today/legal/terms`
- `https://do.yourtodo.today/legal/support`

Do not modify or redeploy the existing public site as part of this setup.

## Deferred production work

The following remain after the foundation slice and need their own verification:

- task create/edit/complete/restore/delete with confirmed sync or rollback
- realtime updates, stale reads, reconnects, and concurrent conflict handling
- Collab creation, invitations, membership, and shared-list writes
- Web Push subscription registration and background delivery
- account export and protected account deletion
- updated Privacy Policy, Terms of Service, and support/contact flows

No native Apple or Android change is required for the current foundation.
