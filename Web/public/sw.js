self.addEventListener("push", (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch {
    payload = { body: event.data ? event.data.text() : "A toDō needs your attention." };
  }

  const title = payload.title || "toDō";
  const options = {
    body: payload.body || "A toDō needs your attention.",
    icon: "/favicon.svg",
    badge: "/favicon.svg",
    tag: payload.tag || "todo-web",
    data: { url: payload.url || "/" },
    renotify: Boolean(payload.renotify),
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const destination = event.notification.data?.url || "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      const existing = clients.find((client) => "focus" in client);
      if (existing) {
        existing.navigate(destination);
        return existing.focus();
      }
      return self.clients.openWindow(destination);
    }),
  );
});
