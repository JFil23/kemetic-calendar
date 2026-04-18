// Dedicated Web Push service worker for Kemetic Calendar PWA.
// Standard browser Web Push only; no Firebase web runtime is required.

function resolveTargetUrl(payload) {
  const raw =
    payload?.data?.link ||
    payload?.data?.url ||
    payload?.fcmOptions?.link ||
    '/';
  try {
    return new URL(raw, self.location.origin).toString();
  } catch (_) {
    return new URL('/', self.location.origin).toString();
  }
}

function scopeAssetUrl(path) {
  return new URL(
    path,
    self.registration?.scope || self.location.origin + '/',
  ).toString();
}

function normalizeKemeticWebPushPayload(payload) {
  if (!payload || payload.source !== 'kemetic-webpush') {
    return null;
  }
  const notification = payload.notification || {};
  const data = payload.data || {};
  return {
    title: notification.title || data.title || 'Kemetic Calendar',
    body: notification.body || data.body || '',
    tag: data.kind || data.type || 'kemetic-calendar',
    url: resolveTargetUrl({ data }),
    data,
  };
}

self.addEventListener('install', function() {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function(event) {
  let payload = null;
  try {
    payload = event.data ? event.data.json() : null;
  } catch (_) {
    payload = null;
  }

  const normalized = normalizeKemeticWebPushPayload(payload);
  if (!normalized) {
    return;
  }

  event.waitUntil(
    self.registration.showNotification(normalized.title, {
      body: normalized.body,
      icon: scopeAssetUrl('icons/Icon-192.png'),
      badge: scopeAssetUrl('icons/Icon-maskable-192.png'),
      tag: normalized.tag,
      data: {
        ...normalized.data,
        url: normalized.url,
      },
    }),
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const targetUrl =
    event.notification?.data?.url ||
    new URL('/', self.location.origin).toString();

  event.waitUntil((async function() {
    const clientList = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    for (const client of clientList) {
      const sameOrigin = client.url.startsWith(self.location.origin);
      if (!sameOrigin) continue;

      try {
        if ('focus' in client) {
          await client.focus();
        }
        if ('navigate' in client && client.url !== targetUrl) {
          await client.navigate(targetUrl);
        }
        return;
      } catch (_) {
        // Keep searching or fall back to openWindow below.
      }
    }

    if (self.clients.openWindow) {
      await self.clients.openWindow(targetUrl);
    }
  })());
});
