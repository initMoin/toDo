# Apple IAP and Supabase Setup

## Confirmed identifiers

| Setting | Value |
| --- | --- |
| Supabase project | `ToDo _prod` |
| Supabase project ref | `kddeevmuyevhgoyvrdlc` |
| iOS bundle ID | `dev.iamshift.toDo` |
| macOS bundle ID for universal purchase | `dev.iamshift.toDo` |
| iOS App Store Apple ID | `6770143925` |
| macOS App Store Apple ID for universal purchase | `6770143925` |

The numeric Apple ID is the number in App Store Connect under **Apps > App
Information > General Information > Apple ID**. It is also the number after `id`
in the public App Store URL. The current iOS URL ends in `id6770143925`.

The native macOS target now uses `dev.iamshift.toDo` for the selected
universal-purchase model. Apple requires the added macOS platform to use the same
bundle ID, Apple ID, and App Store Connect record as iOS. Use `6770143925` for both
App ID values. Do not restore the retired separate Mac identity without a migration
and distribution review.

This applies to the primary native macOS application target. App extensions, widgets,
and other embedded targets must keep their own unique bundle identifiers derived from
the main app identifier; do not assign the main app's bundle identifier to every
target in the Xcode project.

## App Store Connect product setup

Before creating products, the Account Holder must accept the current **Paid Apps
Agreement** and complete required banking and tax information in App Store Connect.
Create the iOS products first; macOS product setup depends on the app-record decision
above.

Under **Apps > toDō > Monetization > Subscriptions**:

1. Create one subscription group named `toDō+`.
2. Add `toDō+ Monthly` with product ID
   `dev.iamshift.todo.plus.monthly`, duration **1 Month**, and US base price **$2.99**.
3. Add `toDō+ Annual` with product ID
   `dev.iamshift.todo.plus.yearly`, duration **1 Year**, and US base price **$24.99**.
4. Put both subscriptions at the same service level because they unlock the same
   capability set.
5. Add localizations, review notes, and a review screenshot for each product.

Configure the approved introductory offers and offer codes from
`Docs/AppStoreOfferConfig.md`:

- Monthly: first week free for eligible new subscribers.
- Annual: first two weeks free for eligible new subscribers.
- Monthly and Annual must remain in the same subscription group. A customer may
  receive only one introductory offer from that group.
- The six community offer codes apply to Monthly and Annual according to the
  configured App Store Connect offer-code rules.
- Lifetime remains a $59.99 non-consumable. Configure the Lifetime offer code
  `shiftalways` at the approved $45.00 price point.

The app must use StoreKit subscription information for eligibility and Apple's
StoreKit redemption sheet for codes. Do not add custom code parsing or let local
copy determine entitlements.

Under **Monetization > In-App Purchases**, create:

| Reference name | Product ID | Type | US price |
| --- | --- | --- | --- |
| toDō+ Lifetime | `dev.iamshift.todo.plus.lifetime` | Non-Consumable | $59.99 |
| Coffee for toDō | `dev.iamshift.todo.appreciation.coffee` | Consumable | $0.99 |
| Lunch for toDō | `dev.iamshift.todo.appreciation.lunch` | Consumable | $4.99 |
| Patron of Dōing | `dev.iamshift.todo.appreciation.patron` | Consumable | $12.99 |
| Founding Supporter | `dev.iamshift.todo.appreciation.founding` | Non-Consumable | $22.99 |

Add localizations, pricing, review notes, and a review screenshot to every product.
Product IDs are permanent after creation, so compare them character-for-character
with the table before saving.

Turn on Family Sharing only for Monthly, Annual, and Lifetime. Do not turn it on for
Founding Supporter merely because it is non-consumable; Founding Supporter recognizes
the purchaser's linked account. Apple does not support Family Sharing for consumables.
Family Sharing cannot be turned off after it is enabled for a product.

Founding Supporter is sold only during the first 14 days after version 3.1 is publicly
released. Record the exact release and removal timestamps in the release checklist.
At the end of the window, remove the product from sale in App Store Connect. The app
hides the purchase row after StoreKit stops returning the product; previously granted
recognition remains restorable.

## In-App Purchase private key

`APPLE_IAP_PRIVATE_KEY` is the complete contents of the `.p8` file downloaded
for the In-App Purchase key whose ID is stored in `APPLE_IAP_KEY_ID`.

Find or generate it in App Store Connect:

1. Open **Users and Access > Integrations > In-App Purchase**.
2. Select the key matching `APPLE_IAP_KEY_ID`.
3. Click **Download Key**.
4. Store the downloaded `SubscriptionKey_<KEY_ID>.p8` file in a password manager
   or secrets vault.

Apple permits the private key to be downloaded only once. If the download button
is unavailable and the original file cannot be found, revoke that key, generate a
replacement, download it immediately, and update both the Key ID and private key.

The value must include both boundary lines and the content between them:

```text
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

Never add the `.p8` file to the repository, an app bundle, email, chat, logs, or a
support ticket.

The notification endpoint verifies Apple's signed payload using Apple's public root
certificates plus the bundle ID and numeric App Store Apple ID. The issuer ID, key ID,
and private key are not sent by Apple and are not required merely to receive a V2
notification. Keep them configured for authenticated App Store Server API calls such
as test-notification requests, transaction-history reconciliation, and recovery tools.

### Enter the private key in Supabase

Use the Supabase Dashboard so the key does not enter shell history or a checked-in
`.env` file:

1. In Finder, locate `SubscriptionKey_<KEY_ID>.p8`. Confirm `<KEY_ID>` matches the
   value being used for `APPLE_IAP_KEY_ID`.
2. Open the `.p8` file with a plain-text editor. Do not use Pages, Word, or another
   rich-text editor, and do not save or reformat the file.
3. Confirm the first line is exactly `-----BEGIN PRIVATE KEY-----` and the last line
   is exactly `-----END PRIVATE KEY-----`.
4. Select all text in the file and copy it. Include the first line, every encoded
   character, all original line breaks, and the last line.
5. Open the Supabase Dashboard and select project **ToDo _prod**. Confirm the project
   reference is `kddeevmuyevhgoyvrdlc` before entering any secret.
6. Open **Edge Functions > Secrets** and choose **Add secret** or the equivalent
   new-secret control.
7. In the secret **Name** field, enter only `APPLE_IAP_PRIVATE_KEY`.
8. In the secret **Value** field, paste the copied file contents. Do not paste the file
   path. Do not include `APPLE_IAP_PRIVATE_KEY=`. Do not add quotation marks. Do not
   replace the line breaks with the two characters `\\n`, and do not Base64-encode the
   key.
9. Visually check that the Value begins with the `BEGIN` boundary and ends with the
   `END` boundary, with no spaces or quote marks before or after them.
10. Save the secret. Supabase masks stored secret values; that is expected. If there
    is any doubt about what was pasted, replace the secret from the original `.p8`
    file rather than trying to reconstruct the value manually.

The **Name** and **Value** are therefore:

```text
Name:
APPLE_IAP_PRIVATE_KEY

Value:
-----BEGIN PRIVATE KEY-----
<the encoded text from SubscriptionKey_<KEY_ID>.p8>
-----END PRIVATE KEY-----
```

Repeat the add-secret process for the remaining Apple settings. Those values are
single-line text and should not include quotation marks:

```text
APPLE_IAP_ISSUER_ID        -> the issuer UUID from App Store Connect
APPLE_IAP_KEY_ID           -> the key ID matching the downloaded .p8 file
APPLE_BUNDLE_ID_IOS        -> dev.iamshift.toDo
APPLE_APP_ID_IOS           -> 6770143925
APPLE_BUNDLE_ID_MACOS      -> dev.iamshift.toDo for universal purchase
APPLE_APP_ID_MACOS         -> 6770143925 for universal purchase
```

After saving, verify that all Apple secret names appear in the Supabase secret list.
Do not expect Supabase to reveal their stored values. Saving or replacing a production
secret makes it available to hosted Edge Functions without putting it in application
source code.

## Supabase production secrets

In the Supabase Dashboard, open project **ToDo _prod**, then open **Edge
Functions > Secrets** and add:

```text
APPLE_IAP_ISSUER_ID=<issuer UUID from App Store Connect>
APPLE_IAP_KEY_ID=<10-character In-App Purchase key ID>
APPLE_IAP_PRIVATE_KEY=<complete multiline .p8 contents>
APPLE_BUNDLE_ID_IOS=dev.iamshift.toDo
APPLE_BUNDLE_ID_MACOS=dev.iamshift.toDo
APPLE_APP_ID_IOS=6770143925
APPLE_APP_ID_MACOS=6770143925
```

Paste `APPLE_IAP_PRIVATE_KEY` directly into the Dashboard secret value so its real
line breaks are preserved. Do not wrap it in quotes. For the selected universal-
purchase setup, the iOS and macOS values intentionally match. Never paste any Apple
secret into a client-side Supabase setting, Xcode build setting, JavaScript bundle,
or public repository.

Do not add a grandfathering secret. Immediately after publishing 3.1, record the
immutable public release instant in UTC and run the controlled SQL function
`public.reconcile_legacy_pre_release_accounts(release_cutoff)`. It checks the
server-side account creation date and email presence, and is idempotent.

Supabase provides `SUPABASE_URL` and a server-only secret to hosted Edge Functions
automatically. Do not create duplicate copies of those values for this integration.

## Backend deployment order

The local backend source is in `/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase`.
Deploy it in this order:

1. Resolve the macOS app-record decision and save the production secrets.
2. Apply migration `20260715090000_add_apple_iap_entitlements.sql` to **ToDo _prod**.
3. Keep `20260715193000_add_apple_app_transaction_grandfathering.sql` as historical
   audit schema only. It is not part of the active eligibility path and must not be
   used to decide Legacy access.
4. Apply the Legacy reconciliation migration
   `20260804143000_reconcile_legacy_access_by_account_cutoff.sql`.
5. Deploy `apple-app-store-notifications`.
6. Deploy `apple-iap-link`.
7. In **Database > Table Editor**, confirm these entitlement tables are present:
   `apple_iap_notification_events`, `apple_iap_transactions`,
   `apple_purchase_account_links`, and `account_entitlements`.
8. In **Edge Functions**, confirm both functions are deployed and inspect their Logs
   tabs after each test.

Do not paste the migration into a different project or deploy these functions before
the migration. The webhook writes to the new tables immediately when Apple calls it.

Uploading the 3.1 app build to App Store Connect is not a prerequisite for these
backend steps. Deploy and verify the backend first, then configure Apple's Sandbox
Server URL. A TestFlight or sandbox-capable app build is needed later for complete
purchase-flow testing.

### Deploy from Terminal

1. Open Terminal and move to the directory that contains the `supabase` folder:

   ```sh
   cd /Users/shift/Development/Mobile/2026/Feb/ToDo
   ```

2. Authenticate the Supabase CLI if this Mac has not already been authenticated:

   ```sh
   supabase login
   ```

   Use a Supabase personal access token when prompted. Do not use the Apple private
   key, database password, publishable key, or service-role key for CLI login.

3. The checkout is already linked locally to production project
   `kddeevmuyevhgoyvrdlc`. Confirm the intended project appears in:

   ```sh
   supabase projects list
   ```

   If a later command reports that the directory is not linked, relink it explicitly:

   ```sh
   supabase link --project-ref kddeevmuyevhgoyvrdlc
   ```

4. Confirm migration `20260715090000` appears in both the local and remote columns:

   ```sh
   supabase migration list
   ```

   If it is not applied remotely, inspect the pending operations before changing
   production:

   ```sh
   supabase db push --dry-run
   ```

   Apply them only after confirming that the IAP migration is the expected pending
   migration:

   ```sh
   supabase db push
   ```

5. Deploy the public Apple webhook:

   ```sh
   supabase functions deploy apple-app-store-notifications --project-ref kddeevmuyevhgoyvrdlc --no-verify-jwt
   ```

6. Deploy the authenticated purchase-linking function:

   ```sh
   supabase functions deploy apple-iap-link --project-ref kddeevmuyevhgoyvrdlc --no-verify-jwt
   ```

   `--no-verify-jwt` is intentional for both functions. Apple cannot supply a Supabase
   JWT to the webhook, which instead verifies Apple's signed JWS payload. The purchase-
   linking function reads the caller's bearer token and validates it with Supabase Auth
   inside the function. The same setting is recorded in `supabase/config.toml`.

   If deployment reports a local bundler or Docker error, retry that same command with
   `--use-api` appended. Do not use `--prune`; this project contains other deployed
   functions that must not be removed.

7. Confirm both names appear in the hosted function list:

   ```sh
   supabase functions list --project-ref kddeevmuyevhgoyvrdlc
   ```

### Smoke-test the deployed endpoints

These tests intentionally send incomplete requests. They prove that the routes are
reachable and reject untrusted input without requiring an App Store build.

1. Test the notification webhook:

   ```sh
   curl -i --request POST 'https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-app-store-notifications' --header 'Content-Type: application/json' --data '{}'
   ```

   Expected result: HTTP `400` with `{"error":"Missing signedPayload"}`. HTTP `401`
   means JWT verification was mistakenly left enabled. HTTP `404` means the function
   was not deployed under the expected project or name.

2. Test the account-linking function without a user session:

   ```sh
   curl -i --request POST 'https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-iap-link' --header 'Content-Type: application/json' --data '{}'
   ```

   Expected result: HTTP `401` with `{"error":"Authentication required"}`. That
   response comes from the function's own authentication guard and is correct.

3. In **Supabase Dashboard > Edge Functions**, open each function. Check both
   **Invocations** and **Logs** and confirm the smoke-test requests arrived. The `400`
   and `401` responses above are expected validation responses, not deployment failures.

4. In **Database > Table Editor**, confirm these tables still exist before connecting
   Apple to the webhook: `apple_iap_notification_events`, `apple_iap_transactions`,
   `apple_purchase_account_links`, and `account_entitlements`. The historical
   `apple_app_transaction_links` table may remain for audit history, but it is not
   queried by the active account-linking or Legacy-reconciliation paths.

### Hosted Node-version warning

Supabase Edge Functions run in Supabase's Deno Edge Runtime, not in the version of
Node installed on the developer's Mac. `apple-iap-link` currently resolves
`@supabase/supabase-js` to `2.110.5`. That package may log a warning that Node.js 20
and below are deprecated because Deno's Node-compatibility layer exposes a compatible
`process.version` value. The warning does not by itself mean the function failed or
that Homebrew Node needs to be changed.

Use the endpoint smoke test and Supabase invocation status as the authority. If
`apple-iap-link` returns HTTP `401` with `{"error":"Authentication required"}` for
the unauthenticated smoke test, the function started and its internal authentication
guard ran successfully. Investigate further only if there is a stack trace, boot
failure, or unexpected `5xx` response in addition to the version warning.

## Planned Edge Function URLs

```text
https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-app-store-notifications
https://kddeevmuyevhgoyvrdlc.supabase.co/functions/v1/apple-iap-link
```

`apple-app-store-notifications` is a public webhook that accepts only Apple-signed
App Store Server Notifications V2 payloads. `apple-iap-link` requires a valid
Supabase user session and binds only a verified purchase transaction to that
account. Legacy access is reconciled separately from the account record and never
from client-supplied acquisition evidence.

Do not configure the URLs in App Store Connect until the database migration and
both functions are deployed and their verification tests pass.

## App Store Server Notifications

After deployment:

1. Open **App Store Connect > Apps > toDō > App Information**.
2. Find **App Store Server Notifications**.
3. Set the Sandbox Server URL to the notification function URL and choose
   **Version 2**.
4. Set the Production Server URL to that same notification function URL and choose
   **Version 2**. Uploading the final 3.1 app build is not required before saving this
   production URL.
5. Request an App Store Server API test notification and verify a successful event
   in Supabase.
6. Run Sandbox subscription, renewal, expiration, refund, revocation, and billing
   grace tests.
7. Run a Mac sandbox purchase after the macOS platform build is available and confirm
   that its notification reaches the same endpoint under this app record.

Both Apple environments intentionally use the production Supabase endpoint. The
**Sandbox** and **Production** labels describe the App Store transaction environment,
not whether the receiving Supabase project is staging or production. Explicitly
configuring both avoids ambiguity: if no Sandbox URL is supplied, Apple sends sandbox
notifications to the Production URL; if only a Sandbox URL is supplied, Apple sends no
production notifications.

The test-notification request is an authenticated App Store Server API call. It uses
the issuer ID, key ID, and `.p8` key; it is not a button that posts an unsigned sample
body to the webhook. A fabricated JSON payload must fail because the function accepts
only Apple-signed JWS data.

## Billing grace period

Enable Billing Grace Period for Sandbox first. Use **16 days**, **All Renewals**,
and **Sandbox Only**. After successful testing, change the environment to
**Production and Sandbox**. This Apple billing grace period is separate from the
30-day read-only web period defined by the toDō product policy.

## Website and App Store metadata

Publish the revised website files before submitting version 3.1, then use:

```text
Privacy Policy URL: https://yourtodo.today/legal/privacy.html
Terms of Use URL: https://yourtodo.today/legal/terms.html
Support URL: https://yourtodo.today/
```

Apple's Support URL must open a webpage with real contact information. The local site
footer now links directly to `support@iamshift.dev`; keep that link present in the
deployed homepage. A dedicated support page is optional, but it would be clearer for
users and can replace the homepage URL later.

In **App Store Connect > App Privacy**, review the answers before submitting 3.1.
Account-backed sync and commerce commonly require declarations for contact
information, user content, user identifiers, purchase history, and diagnostics or
usage data actually collected by the app and its integrated providers. Mark data as
linked to the user and identify the purpose only where that is true in the shipping
implementation; do not copy a generic checklist without checking the SDK behavior.

The legal text is a product-accurate draft, not legal advice. Have qualified counsel
review retention, regional consumer rights, subscription terms, and the operator's
legal identity before publication.

The homepage currently loads Google Analytics. For visitors in regions where prior
consent is required, configure an appropriate consent mechanism so Analytics does not
store or read nonessential identifiers before consent, or remove Analytics. Publishing
the disclosure alone does not replace a consent mechanism where one is legally
required.
