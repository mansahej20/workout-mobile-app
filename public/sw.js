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
