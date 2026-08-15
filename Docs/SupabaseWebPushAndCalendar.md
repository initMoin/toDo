# toDō Web Push and Calendar Integration

The canonical database migration is:

```text
supabase/migrations/20260814150000_add_web_push_and_calendar_integration.sql
```

It adds:

- RLS-scoped Web Push subscriptions and a service-only delivery outbox.
- Change-triggered Web Push events for personal and Collab ToDos.
- A guarded `pg_cron` job that enqueues one due reminder per active ToDo and recipient when `pg_cron` is available.
- A private, revocable iCalendar feed token for each account.
- Web-specific notification preferences, kept separate from native reminder preferences.

## Supabase deployment

Generate one VAPID key pair for the production Web Push application. Keep the
private key only in Supabase Edge Function secrets.

```sh
supabase db push
supabase functions deploy todo-web-push --no-verify-jwt
supabase functions deploy todo-calendar-feed --no-verify-jwt
supabase secrets set \
  VAPID_SUBJECT=mailto:support@yourtodo.today \
  VAPID_PUBLIC_KEY=your-vapid-public-key \
  VAPID_PRIVATE_KEY=your-vapid-private-key \
  TODO_WEB_PUSH_WEBHOOK_SECRET=your-random-webhook-secret
```

The migration reads the webhook URL and matching secret from Supabase Vault so
the database trigger does not contain credentials:

```sql
select vault.create_secret(
  'https://<project-ref>.supabase.co/functions/v1/todo-web-push',
  'todo_web_push_webhook_url'
);

select vault.create_secret(
  'your-random-webhook-secret',
  'todo_web_push_webhook_secret'
);
```

If those Vault values are absent, ToDo mutations still succeed but Web Push
delivery is skipped. This is intentional fail-open behavior for the auxiliary
notification path.

## Web environment

`Web/.env.local` may contain the public VAPID key:

```text
VITE_WEB_PUSH_VAPID_PUBLIC_KEY=your-vapid-public-key
```

Never put `VAPID_PRIVATE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, or the webhook
secret in this file or in browser code. Web Push requires HTTPS in production;
`localhost` is permitted for local testing by browsers.

## Calendar behavior

The Web calendar setting creates a private feed URL backed by
`todo-calendar-feed`. The user can copy that URL into Apple Calendar, Google
Calendar, or Outlook. Revoking the setting invalidates the previous URL. The
feed contains active ToDos with due dates and does not require third-party
calendar OAuth credentials.

The feed URL is a bearer secret. It must not be logged, placed in analytics, or
shared publicly.

## Verification

1. Sign in to the Web app over HTTPS.
2. Open `settings → notifications` and allow reminder alerts.
3. Confirm a row appears in `public.web_push_subscriptions`.
4. Change a ToDo from another signed-in client and confirm a row is created in
   `public.web_push_events` and later marked processed.
5. Enable `settings → behavior → calendar`, copy the feed URL, and subscribe
   to it from a calendar client.
6. Create a test ToDo with a due time and confirm the feed contains a `VEVENT`.

If `pg_cron` is unavailable, change-triggered pushes and calendar feeds still
work, but server-side due reminders remain disabled until a scheduled worker is
configured.
