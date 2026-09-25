// Minimal service worker: keeps the app shell available with no signal.
// Supabase requests are never cached; the app handles offline writes itself.
const CACHE = "setlog-__BUILD_ID__";
const SHELL = ["/", "/index.html", "/config.js", "/manifest.webmanifest", "/icons/icon.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // Only handle same-origin files and the pinned Supabase client script.
  const isSameOrigin = url.origin === self.location.origin;
  const isSupabaseLib = url.hostname === "cdn.jsdelivr.net";
  if (!isSameOrigin && !isSupabaseLib) return;

  // Network first, fall back to cache.
  event.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || caches.match("/index.html")))
  );
});

// Rest-timer alerts. They arrive even when the app is closed or the phone is locked.
self.addEventListener("push", (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) {}
  const title = data.title || "Rest over";
  const options = {
    body: data.body || "Time for your next set.",
    tag: "rest-timer",
    renotify: true,
    icon: "/icons/icon-192.png",
    badge: "/icons/icon-192.png",
    data: { url: "/" }
  };
  // Always shown, even with the app open: the notification's sound is the
  // rest alarm, and unlike sound played by a web page it doesn't stop your music.
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const c of wins) {
      if ("focus" in c) return c.focus();
    }
    return self.clients.openWindow("/");
  })());
});
