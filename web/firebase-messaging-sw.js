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

function firstNonEmptyString(...values) {
  for (const value of values) {
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed) {
        return trimmed;
      }
    } else if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value);
    }
  }
  return null;
}

function scopeAssetUrl(path) {
  return new URL(
    path,
    self.registration?.scope || self.location.origin + '/',
  ).toString();
}

function buildNotificationTag(notification, data) {
  return (
    firstNonEmptyString(
      data?.notification_tag,
      data?.delivery_key,
      data?.scheduled_id && `scheduled:${data.scheduled_id}`,
      data?.reminder_id && `reminder:${data.reminder_id}`,
      data?.client_event_id &&
        `event:${data.client_event_id}:${firstNonEmptyString(data?.notification_type, data?.kind, data?.type) || 'notification'}`,
      data?.kind,
      data?.type,
    ) || 'kemetic-calendar'
  );
}

function buildNotificationDeliveryKey(notification, data) {
  const explicit = firstNonEmptyString(
    data?.delivery_key,
    data?.scheduled_id && `scheduled:${data.scheduled_id}`,
    data?.reminder_id && `reminder:${data.reminder_id}`,
    data?.client_event_id &&
      `event:${data.client_event_id}:${firstNonEmptyString(data?.notification_type, data?.scheduled_at, data?.kind, data?.type) || 'notification'}`,
  );
  return explicit || null;
}

function normalizeKemeticWebPushPayload(payload) {
  if (!payload || payload.source !== 'kemetic-webpush') {
    return null;
  }
  const notification = payload.notification || {};
  const data = payload.data || {};
  const deliveryKey = buildNotificationDeliveryKey(notification, data);
  return {
    title: notification.title || data.title || 'Kemetic Calendar',
    body: notification.body || data.body || 'Tap to open in Kemetic.',
    tag: buildNotificationTag(notification, data),
    deliveryKey,
    url: resolveTargetUrl({ data }),
    data,
  };
}

const PUSH_DEDUPE_CACHE = 'kemetic-push-dedupe-v1';
const PUSH_DEDUPE_TTL_MS = 12 * 60 * 60 * 1000;

function dedupeRequestUrl(key) {
  return `https://local.push-dedupe.invalid/${encodeURIComponent(key)}`;
}

async function wasDuplicateDisplay(deliveryKey) {
  if (!deliveryKey || !self.caches) {
    return false;
  }
  try {
    const cache = await self.caches.open(PUSH_DEDUPE_CACHE);
    const request = new Request(dedupeRequestUrl(deliveryKey));
    const cached = await cache.match(request);
    if (!cached) {
      return false;
    }

    const seenAt = Number(await cached.text());
    if (!Number.isFinite(seenAt)) {
      await cache.delete(request);
      return false;
    }

    if (Date.now() - seenAt > PUSH_DEDUPE_TTL_MS) {
      await cache.delete(request);
      return false;
    }

    return true;
  } catch (_) {
    return false;
  }
}

async function rememberDisplayedNotification(deliveryKey) {
  if (!deliveryKey || !self.caches) {
    return;
  }
  try {
    const cache = await self.caches.open(PUSH_DEDUPE_CACHE);
    const request = new Request(dedupeRequestUrl(deliveryKey));
    await cache.put(
      request,
      new Response(String(Date.now()), {
        headers: { 'Cache-Control': 'no-store' },
      }),
    );
  } catch (_) {
    // Best effort only.
  }
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

  event.waitUntil((async function() {
    if (await wasDuplicateDisplay(normalized.deliveryKey)) {
      return;
    }

    await rememberDisplayedNotification(normalized.deliveryKey);
    await self.registration.showNotification(normalized.title, {
      body: normalized.body,
      icon: scopeAssetUrl('icons/Icon-192.png'),
      badge: scopeAssetUrl('icons/Icon-maskable-192.png'),
      tag: normalized.tag,
      renotify: false,
      data: {
        ...normalized.data,
        delivery_key: normalized.deliveryKey,
        url: normalized.url,
      },
    });
  })());
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
