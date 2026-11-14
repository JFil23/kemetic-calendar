/* ḥꜣw Admin shell worker. Caches interface assets only. */
const CACHE = "haw-admin-shell-v1";
const PRECACHE = ["/", "/index.html", "/manifest.webmanifest"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))),
    ).then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Never cache private activity or auth responses.
  if (
    url.pathname.includes("/rest/v1/") ||
    url.pathname.includes("/auth/v1/") ||
    url.pathname.includes("/functions/v1/") ||
    url.pathname.includes("admin_activity")
  ) {
    return;
  }

  const isNavigation = request.mode === "navigate";
  const isShellAsset =
    isNavigation ||
    url.pathname.startsWith("/assets/") ||
    url.pathname.startsWith("/icons/") ||
    url.pathname === "/manifest.webmanifest" ||
    url.pathname === "/sw.js" ||
    url.pathname.endsWith(".js") ||
    url.pathname.endsWith(".css") ||
    url.pathname.endsWith(".png") ||
    url.pathname.endsWith(".svg") ||
    url.pathname.endsWith(".woff2");

  if (!isShellAsset) return;

  event.respondWith(
    (async () => {
      try {
        const network = await fetch(request);
        if (network.ok && !isNavigation) {
          const cache = await caches.open(CACHE);
          void cache.put(request, network.clone());
        }
        if (isNavigation && network.ok) {
          const cache = await caches.open(CACHE);
          void cache.put("/", network.clone());
          void cache.put("/index.html", network.clone());
        }
        return network;
      } catch {
        const cached = await caches.match(isNavigation ? "/index.html" : request);
        if (cached) return cached;
        if (isNavigation) {
          return new Response(
            "<!doctype html><title>ḥꜣw Admin</title><body style='background:#120f10;color:#ac9f95;font-family:system-ui;padding:2rem'><p>Activity data is unavailable offline.</p></body>",
            { headers: { "content-type": "text/html; charset=utf-8" } },
          );
        }
        return Response.error();
      }
    })(),
  );
});
