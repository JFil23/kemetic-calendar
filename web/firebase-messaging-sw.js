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
    body: notification.body || data.body || 'Tap to open in Kemetic.',
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
  const pushData = event.notification?.data || {};

  event.waitUntil((async function() {
    const clientList = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    const candidateClients = clientList
      .filter((client) => client.url.startsWith(self.location.origin))
      .sort((a, b) => {
        const score = (client) => {
          let value = 0;
          if (client.url === targetUrl) value += 4;
          if (client.visibilityState === 'visible') value += 3;
          if (client.focused) value += 5;
          return value;
        };
        return score(b) - score(a);
      });

    for (const client of candidateClients) {
      try {
        if ('focus' in client) {
          await client.focus();
        }
      } catch (_) {
        // Keep going; postMessage may still succeed.
      }

      try {
        client.postMessage({
          type: 'kemetic-push-tap',
          data: pushData,
        });
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
