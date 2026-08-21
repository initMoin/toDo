import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, { headers: { accept: "text/html" } }),
    {
      ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
    },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the Home orientation surface without demo tasks", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>toDō Web — Keep what matters in step<\/title>/i);
  assert.match(html, /What matters now\?|Checking your toDō account…|Loading your Home…|Connect Supabase to open Home/);
  assert.match(html, /See all toDōs|Checking your toDō account…|Loading your Home…|Connect Supabase to open Home/);
  assert.match(html, /class="wordmark"/);
  assert.doesNotMatch(html, /What needs doing\?|codex-preview|react-loading-skeleton/i);
});

test("renders ToDosView at the /todos route", async () => {
  const response = await render("/todos");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Connect Supabase to test the Web app|Checking your toDō account…|Loading your toDōs…/);
  assert.match(html, /class="site-header-title">toDō<\/span>/);
});

test("renders the Web-native Account, Stats, Settings, and nested detail routes", async () => {
  const [accountResponse, settingsAccountResponse, statsResponse, settingsResponse, profileResponse, aboutResponse, releasesResponse] = await Promise.all([
    render("/account"),
    render("/account?from=settings"),
    render("/stats"),
    render("/settings"),
    render("/account/profile"),
    render("/settings/about"),
    render("/settings/releases"),
  ]);
  assert.equal(accountResponse.status, 200);
  assert.equal(settingsAccountResponse.status, 200);
  assert.equal(statsResponse.status, 200);
  assert.equal(settingsResponse.status, 200);
  assert.equal(profileResponse.status, 200);
  assert.equal(aboutResponse.status, 200);
  assert.equal(releasesResponse.status, 200);
  assert.match(await accountResponse.text(), /Account|Checking your toDō account…/);
  const settingsAccountHTML = await settingsAccountResponse.text();
  assert.match(settingsAccountHTML, /site-header-account-settings/);
  assert.match(settingsAccountHTML, /href="\/settings"/);
  assert.match(await statsResponse.text(), /Measure what matters|Stats|Loading your Stats…/);
  assert.match(await settingsResponse.text(), /Settings|Checking your toDō account…/);
  assert.match(await profileResponse.text(), /My Profile|Checking your toDō account…/);
  assert.match(await aboutResponse.text(), /about toDō|Checking your toDō account…/);
  assert.match(await releasesResponse.text(), /release history|Checking your toDō account…/);
});

test("renders the browser-native detail route boundary", async () => {
  const response = await render("/todos/example-todo");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Connect Supabase to open this toDō|Loading your toDō…/);
  assert.match(html, /Back to active toDōs|toDōs/);
});

test("renders every Settings submenu route with a Settings back boundary", async () => {
  const submenuPaths = [
    "/settings/membership",
    "/settings/sync",
    "/settings/appearance",
    "/settings/tags",
    "/settings/behavior",
    "/settings/notifications",
    "/settings/tour",
    "/settings/data",
    "/settings/archives",
    "/settings/trash",
  ];
  const responses = await Promise.all(submenuPaths.map((path) => render(path)));

  for (const response of responses) {
    assert.equal(response.status, 200);
    const html = await response.text();
    assert.match(html, /site-header-settings-detail/);
    assert.match(html, /href="\/settings"/);
  }
});

test("keeps the documented Web and Supabase boundaries present", async () => {
  const [auth, signIn, data, decisions, migrations, webMigration, webIntegrations, webPush, calendarFeed, layout, routeTransition, home, todos, detail, workspace, settings, submenu, stats, account, about, releaseHistory, legalShell, appFrame, avatar, icon, styles] = await Promise.all([
    readFile(new URL("../features/auth/AuthProvider.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/auth/SignInCard.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/todos/data.ts", import.meta.url), "utf8"),
    readFile(new URL("../docs/WebFoundationDecisions.md", import.meta.url), "utf8"),
    readFile(new URL("../../Shared/Supabase/migrations/20260716190000_add_collab_todos.sql", import.meta.url), "utf8"),
    readFile(new URL("../../Shared/Supabase/migrations/20260814150000_add_web_push_and_calendar_integration.sql", import.meta.url), "utf8"),
    readFile(new URL("../lib/webIntegrations.ts", import.meta.url), "utf8"),
    readFile(new URL("../../Shared/Supabase/functions/todo-web-push/index.ts", import.meta.url), "utf8"),
    readFile(new URL("../../Shared/Supabase/functions/todo-calendar-feed/index.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../components/RouteTransition.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/home/Home.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/todos/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/todos/ToDoDetail.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/todos/ToDoWorkspace.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/settings/Settings.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/settings/SettingsSubmenuView.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/stats/Stats.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/account/AccountView.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/settings/AboutView.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/settings/ReleaseHistoryView.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/legal/LegalShell.tsx", import.meta.url), "utf8"),
    readFile(new URL("../components/AppFrame.tsx", import.meta.url), "utf8"),
    readFile(new URL("../features/account/ProfileAvatar.tsx", import.meta.url), "utf8"),
    readFile(new URL("../components/Icon.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);

  assert.match(auth, /signInWithOAuth/);
  assert.match(auth, /pendingAuthenticationStorageKey/);
  assert.match(auth, /sessionStorage/);
  assert.match(signIn, /apple/);
  assert.match(signIn, /google/);
  assert.match(data, /current_account_entitlements/);
  assert.match(data, /from\("todos"\)/);
  assert.match(data, /from\("nanodos"\)/);
  assert.match(data, /from\("todo_tags"\)/);
  assert.doesNotMatch(auth + signIn + data, /service_role|SUPABASE_SERVICE_ROLE/i);
  assert.match(data, /updateTodoCompletion/);
  assert.match(data, /createTodo/);
  assert.match(data, /loadCollabs/);
  assert.match(data, /createCollab/);
  assert.match(data, /lifecycle_state: "active"/);
  assert.match(home, /NewTodoComposer/);
  assert.doesNotMatch(home, /disabled\s+aria-describedby="capture-note"/);
  assert.match(data, /lifecycle_state: isDone \? "done" : "active"/);
  assert.match(home, /What matters now\?/);
  assert.match(home, /home-completed-summary/);
  assert.match(home, /name="bar-chart"/);
  assert.doesNotMatch(home, /Open all toDōs/);
  assert.match(home, /href="\/todos"/);
  assert.match(todos, /ToDoWorkspace/);
  assert.match(todos, /initialFilter/);
  assert.match(detail, /!isResolved/);
  assert.match(detail, /Complete toDō/);
  assert.match(detail, /Continue to Settings/);
  assert.match(workspace, /todo-complete-button/);
  assert.match(workspace, /todo-utility-tray/);
  assert.match(workspace, /isTodoDueSoon/);
  assert.doesNotMatch(settings, /ProviderMethodsCard|signOut/);
  assert.match(settings, /href="\/account\?from=settings"/);
  assert.doesNotMatch(settings, /coming later|not available yet/);
  assert.match(submenu, /Notification\.requestPermission/);
  assert.match(submenu, /updateTodoLifecycle/);
  assert.match(submenu, /createTag/);
  assert.match(submenu, /todoTheme|data-todo-theme/);
  assert.match(submenu, /Supabase account/);
  assert.match(settings, /href="\/settings\/sync"/);
  assert.doesNotMatch(submenu, /coming later|not available yet|not enabled in this slice/);
  assert.match(account, /ProviderMethodsCard/);
  assert.match(account, /signOut/);
  assert.match(account, /Collabs/);
  assert.doesNotMatch(account, /Where to Save/);
  assert.match(account, /Account Actions/);
  assert.doesNotMatch(account, /support/i);
  assert.match(appFrame, /href="\/account"/);
  assert.doesNotMatch(appFrame, /onSignOut|signOut/);
  assert.doesNotMatch(appFrame, /legal\/(privacy|terms)/);
  assert.match(avatar, /profile-avatar/);
  assert.match(avatar, /avatarURL/);
  assert.doesNotMatch(avatar, /profile-avatar-initials|getInitials/);
  assert.doesNotMatch(home, /Text first|Use New toDō|You can add reminder intent|No due date/);
  assert.match(styles, /brand\/brand-plus-reference\.jpg/);
  assert.match(styles, /background-clip: text/);
  assert.match(styles, /sign-in-provider-reveal/);
  assert.match(styles, /clip-path: inset/);
  assert.match(styles, /flex: 0 0 var\(--profile-avatar-size\)/);
  assert.match(icon, /gear/);
  assert.match(stats, /Measure what matters/);
  assert.match(stats, /Completion rhythm/);
  assert.doesNotMatch(stats, /<p className="eyebrow">Stats<\/p>/);
  assert.doesNotMatch(workspace, /className="workspace-context"/);
  assert.match(about, /shift beneath the view/);
  assert.match(about, /All Release History/);
  assert.match(about, /brand\/shift-logomark\.png/);
  assert.match(about, /arrow-up-right/);
  assert.match(about, /target="_blank"/);
  assert.doesNotMatch(about, /about-link-list|about-section/);
  assert.match(releaseHistory, /3\.0\.1/);
  assert.doesNotMatch(legalShell, /Back to app/);
  assert.match(decisions, /Familiar to a toDō user\. Native to the platform\./);
  assert.match(decisions, /No backend migration is required/);
  assert.match(migrations, /create policy "todos_select_accessible"/);
  assert.match(webMigration, /web_push_subscriptions/);
  assert.match(webMigration, /web_calendar_feeds/);
  assert.match(webMigration, /enqueue_due_web_push_events/);
  assert.match(webIntegrations, /registerWebPushSubscription/);
  assert.match(webIntegrations, /createCalendarFeedURL/);
  assert.match(webPush, /TODO_WEB_PUSH_WEBHOOK_SECRET/);
  assert.match(webPush, /todo_due/);
  assert.match(calendarFeed, /text\/calendar/);
  assert.match(migrations, /create policy "nanodos_select_accessible"/);
  assert.match(layout, /do\.yourtodo\.today/);
  assert.match(layout, /RouteTransition/);
  assert.match(routeTransition, /routeDepth/);
  assert.match(routeTransition, /popstate/);
});
