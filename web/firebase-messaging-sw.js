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

const DAILY_REFLECTION_WIDGET_TAG = 'daily-reflection';
const DAILY_REFLECTION_WIDGET_CACHE = 'kemetic-daily-reflection-widget-v1';
const DAILY_REFLECTION_WIDGET_TEMPLATE_PATH =
  'widgets/daily-reflection.template.json';
const DAILY_REFLECTION_WIDGET_DATA_PATH =
  'widgets/daily-reflection-data.json';
const DAILY_REFLECTION_WIDGET_DAYS_PATH =
  'widgets/daily-reflection-days.json';
const DAILY_REFLECTION_MS_PER_DAY = 24 * 60 * 60 * 1000;
const DAILY_REFLECTION_EPOCH_UTC_MS = Date.UTC(2025, 2, 20);
const DAILY_REFLECTION_MONTH_KEYS = [
  '',
  'thoth',
  'paophi',
  'hathor',
  'kaherka',
  'sefbedet',
  'rekhwer',
  'rekhnedjes',
  'renwet',
  'hnsw',
  'henti',
  'ipt',
  'mswtRa',
  'epagomenal',
];
const DAILY_REFLECTION_MONTH_LABELS = [
  '',
  'Thoth',
  'Phaophi',
  'Athyr',
  'Choiak',
  'Tybi',
  'Mechir',
  'Phamenoth',
  'Pharmuthi',
  'Pachons',
  'Payni',
  'Epiphi',
  'Mesore',
];

function dailyReflectionWidgetDataUrl(widget) {
  return new URL(
    widget?.definition?.data || DAILY_REFLECTION_WIDGET_DATA_PATH,
    self.registration?.scope || self.location.origin + '/',
  ).toString();
}

function dailyReflectionWidgetTemplateUrl(widget) {
  return new URL(
    widget?.definition?.msAcTemplate || DAILY_REFLECTION_WIDGET_TEMPLATE_PATH,
    self.registration?.scope || self.location.origin + '/',
  ).toString();
}

function dailyReflectionWidgetDaysUrl() {
  return scopeAssetUrl(DAILY_REFLECTION_WIDGET_DAYS_PATH);
}

function todayLocalDateKey() {
  const now = new Date();
  return [
    now.getFullYear(),
    String(now.getMonth() + 1).padStart(2, '0'),
    String(now.getDate()).padStart(2, '0'),
  ].join('-');
}

function cleanWidgetString(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed || fallback;
}

function normalizeDailyReflectionWidgetPayload(raw) {
  const payload = raw && typeof raw === 'object' ? raw : {};
  const date = cleanWidgetString(payload.date, todayLocalDateKey());
  const safeDate = /^\d{4}-\d{2}-\d{2}$/.test(date)
    ? date
    : todayLocalDateKey();
  return {
    date: safeDate,
    dateLabel: cleanWidgetString(payload.dateLabel, 'Daily reflection'),
    dayKey: cleanWidgetString(payload.dayKey, ''),
    kYear: Number.isFinite(Number(payload.kYear)) ? Number(payload.kYear) : null,
    question: cleanWidgetString(
      payload.question,
      "Open the planner to refresh today's reflection.",
    ),
    updatedAt: new Date().toISOString(),
  };
}

function buildDailyReflectionPlannerUrl(date) {
  const plannerUrl = new URL('/rhythm/today', self.location.origin);
  plannerUrl.searchParams.set('openDayCard', '1');
  plannerUrl.searchParams.set('source', 'widget');
  plannerUrl.searchParams.set('date', date || todayLocalDateKey());
  return plannerUrl.toString();
}

async function cacheDailyReflectionWidgetPayload(raw) {
  if (!self.caches) return null;
  const payload = normalizeDailyReflectionWidgetPayload(raw);
  const cache = await self.caches.open(DAILY_REFLECTION_WIDGET_CACHE);
  await cache.put(
    scopeAssetUrl(DAILY_REFLECTION_WIDGET_DATA_PATH),
    new Response(JSON.stringify(payload), {
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
    }),
  );
  return payload;
}

async function readCachedDailyReflectionWidgetPayload(dataUrl) {
  if (!self.caches) return null;
  try {
    const cache = await self.caches.open(DAILY_REFLECTION_WIDGET_CACHE);
    const response = await cache.match(dataUrl);
    if (!response) return null;
    const payload = normalizeDailyReflectionWidgetPayload(
      await response.json(),
    );
    return payload.date === todayLocalDateKey() ? payload : null;
  } catch (_) {
    return null;
  }
}

function isDailyReflectionGregorianLeapYear(year) {
  if (year % 4 !== 0) return false;
  if (year % 100 === 0 && year % 400 !== 0) return false;
  return true;
}

function utcEpochDayForDailyReflectionLocalDate(date) {
  const localMidnight = new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
  );
  const utcDateMs = Date.UTC(
    localMidnight.getUTCFullYear(),
    localMidnight.getUTCMonth(),
    localMidnight.getUTCDate(),
  );
  return Math.floor(
    (utcDateMs - DAILY_REFLECTION_EPOCH_UTC_MS) /
      DAILY_REFLECTION_MS_PER_DAY,
  );
}

function dailyReflectionKemeticYearLength(startOffsetDays) {
  const epagomenalStartMs =
    DAILY_REFLECTION_EPOCH_UTC_MS +
    (startOffsetDays + 360) * DAILY_REFLECTION_MS_PER_DAY;
  const gregorianYear = new Date(epagomenalStartMs).getUTCFullYear();
  return isDailyReflectionGregorianLeapYear(gregorianYear) ? 366 : 365;
}

function previousDailyReflectionKemeticYearStart(currentStartOffsetDays) {
  const guess = currentStartOffsetDays - 365;
  const previousLength = dailyReflectionKemeticYearLength(guess);
  return currentStartOffsetDays - previousLength;
}

function kemeticDateForDailyReflection(date = new Date()) {
  let days = utcEpochDayForDailyReflectionLocalDate(date);
  let kYear = 1;
  let kYearStartOffset = 0;

  if (days >= 0) {
    while (true) {
      const length = dailyReflectionKemeticYearLength(kYearStartOffset);
      if (days < length) break;
      days -= length;
      kYear += 1;
      kYearStartOffset += length;
    }
  } else {
    while (days < 0) {
      const previousStart =
        previousDailyReflectionKemeticYearStart(kYearStartOffset);
      const previousLength =
        dailyReflectionKemeticYearLength(previousStart);
      days += previousLength;
      kYear -= 1;
      kYearStartOffset = previousStart;
    }
  }

  if (days < 360) {
    return {
      year: kYear,
      month: Math.floor(days / 30) + 1,
      day: (days % 30) + 1,
      epagomenal: false,
    };
  }

  return {
    year: kYear,
    month: 0,
    day: days - 360 + 1,
    epagomenal: true,
  };
}

function dailyReflectionDecanForDay(kDay) {
  return Math.floor((kDay - 1) / 10) + 1;
}

function dailyReflectionDayKey(kemeticDate) {
  const monthIndex = kemeticDate.epagomenal ? 13 : kemeticDate.month;
  const prefix = DAILY_REFLECTION_MONTH_KEYS[monthIndex];
  if (!prefix) return null;
  return `${prefix}_${kemeticDate.day}_${dailyReflectionDecanForDay(kemeticDate.day)}`;
}

function dailyReflectionDateLabel(kemeticDate) {
  if (kemeticDate.epagomenal) {
    return `Epagomenal ${kemeticDate.day}`;
  }
  const monthLabel = DAILY_REFLECTION_MONTH_LABELS[kemeticDate.month];
  return monthLabel
    ? `${monthLabel} ${kemeticDate.day}`
    : 'Daily reflection';
}

function normalizeDailyReflectionDayTable(raw) {
  if (!raw || typeof raw !== 'object') return null;
  if (raw.schema !== 1 || !raw.days || typeof raw.days !== 'object') {
    return null;
  }
  return raw;
}

async function loadDailyReflectionDayTable() {
  const tableUrl = dailyReflectionWidgetDaysUrl();
  const cache = self.caches
    ? await self.caches.open(DAILY_REFLECTION_WIDGET_CACHE)
    : null;

  try {
    const response = await fetch(tableUrl, {
      credentials: 'same-origin',
      cache: 'no-cache',
    });
    if (!response.ok) throw new Error(`day table ${response.status}`);
    const table = normalizeDailyReflectionDayTable(await response.json());
    if (!table) throw new Error('invalid day table');
    await cache?.put(
      tableUrl,
      new Response(JSON.stringify(table), {
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
      }),
    );
    return table;
  } catch (_) {
    try {
      const cached = await cache?.match(tableUrl);
      return cached
        ? normalizeDailyReflectionDayTable(await cached.json())
        : null;
    } catch (_) {
      return null;
    }
  }
}

async function buildDailyReflectionPayloadFromDayTable() {
  const table = await loadDailyReflectionDayTable();
  if (!table) return null;

  const kemeticDate = kemeticDateForDailyReflection();
  const dayKey = dailyReflectionDayKey(kemeticDate);
  const question = cleanWidgetString(table.days?.[dayKey]?.question, '');
  if (!dayKey || !question) return null;

  return normalizeDailyReflectionWidgetPayload({
    date: todayLocalDateKey(),
    dateLabel: dailyReflectionDateLabel(kemeticDate),
    dayKey,
    kYear: kemeticDate.year,
    question,
  });
}

function fallbackDailyReflectionWidgetPayload() {
  return {
    date: todayLocalDateKey(),
    dateLabel: 'Daily reflection',
    dayKey: '',
    kYear: null,
    question: "Open the planner to refresh today's reflection.",
    updatedAt: new Date().toISOString(),
  };
}

async function loadDailyReflectionWidgetTemplate(templateUrl) {
  const cache = self.caches
    ? await self.caches.open(DAILY_REFLECTION_WIDGET_CACHE)
    : null;
  try {
    const response = await fetch(templateUrl, {
      credentials: 'same-origin',
      cache: 'no-cache',
    });
    if (!response.ok) throw new Error(`template ${response.status}`);
    const template = await response.text();
    await cache?.put(
      templateUrl,
      new Response(template, {
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
      }),
    );
    return template;
  } catch (_) {
    const cached = await cache?.match(templateUrl);
    if (cached) return cached.text();
    return JSON.stringify({
      type: 'AdaptiveCard',
      version: '1.5',
      body: [
        {
          type: 'TextBlock',
          text: "Open the planner to refresh today's reflection.",
          wrap: true,
        },
      ],
      actions: [
        {
          type: 'Action.Execute',
          title: 'Open planner',
          verb: 'open-planner',
        },
      ],
    });
  }
}

async function loadDailyReflectionWidgetData(dataUrl) {
  const computed = await buildDailyReflectionPayloadFromDayTable();
  if (computed) {
    await cacheDailyReflectionWidgetPayload(computed);
    return JSON.stringify(computed);
  }

  const cached = await readCachedDailyReflectionWidgetPayload(dataUrl);
  if (cached) return JSON.stringify(cached);

  try {
    const response = await fetch(dataUrl, {
      credentials: 'same-origin',
      cache: 'no-cache',
    });
    if (response.ok) {
      return JSON.stringify(
        normalizeDailyReflectionWidgetPayload(await response.json()),
      );
    }
  } catch (_) {
    // Fall through to a deterministic same-origin fallback.
  }

  return JSON.stringify(fallbackDailyReflectionWidgetPayload());
}

async function refreshDailyReflectionWidget(widget) {
  if (!self.widgets?.updateByTag || !widget?.definition) return;
  const templateUrl = dailyReflectionWidgetTemplateUrl(widget);
  const dataUrl = dailyReflectionWidgetDataUrl(widget);
  const [template, data] = await Promise.all([
    loadDailyReflectionWidgetTemplate(templateUrl),
    loadDailyReflectionWidgetData(dataUrl),
  ]);
  await self.widgets.updateByTag(widget.definition.tag, { template, data });
}

async function refreshDailyReflectionWidgetByTag(tag) {
  if (!self.widgets?.getByTag) return;
  const widget = await self.widgets.getByTag(tag);
  if (widget) await refreshDailyReflectionWidget(widget);
}

async function registerDailyReflectionPeriodicSync(widget) {
  if (!self.registration?.periodicSync || !widget?.definition) return;
  const updateSeconds = Number(widget.definition.update);
  if (!Number.isFinite(updateSeconds) || updateSeconds <= 0) return;
  const tags = await self.registration.periodicSync.getTags();
  if (tags.includes(widget.definition.tag)) return;
  await self.registration.periodicSync.register(widget.definition.tag, {
    minInterval: updateSeconds * 1000,
  });
}

async function unregisterDailyReflectionPeriodicSync(widget) {
  if (!self.registration?.periodicSync || !widget?.definition) return;
  const tags = await self.registration.periodicSync.getTags();
  if (
    tags.includes(widget.definition.tag) &&
    Array.isArray(widget.instances) &&
    widget.instances.length <= 1
  ) {
    await self.registration.periodicSync.unregister(widget.definition.tag);
  }
}

async function openOrFocusDailyReflectionPlanner(widget) {
  const cached = await readCachedDailyReflectionWidgetPayload(
    dailyReflectionWidgetDataUrl(widget),
  );
  const targetUrl = buildDailyReflectionPlannerUrl(
    cached?.date || todayLocalDateKey(),
  );
  const clientList = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });

  const candidateClients = clientList
    .filter((client) => {
      try {
        return new URL(client.url).origin === self.location.origin;
      } catch (_) {
        return false;
      }
    })
    .sort((a, b) => {
      const score = (client) => {
        let value = 0;
        if (client.visibilityState === 'visible') value += 3;
        if (client.focused) value += 5;
        return value;
      };
      return score(b) - score(a);
    });

  for (const client of candidateClients) {
    try {
      const navigated = await client.navigate(targetUrl);
      if (navigated && 'focus' in navigated) {
        return await navigated.focus();
      }
    } catch (_) {
      // Keep searching or fall back to openWindow below.
    }
  }

  if (self.clients.openWindow) {
    return self.clients.openWindow(targetUrl);
  }
  return undefined;
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
  event.waitUntil((async function() {
    await self.clients.claim();
    await refreshDailyReflectionWidgetByTag(DAILY_REFLECTION_WIDGET_TAG);
  })());
});

self.addEventListener('message', function(event) {
  const data = event.data || {};
  if (data.type !== 'kemetic-daily-reflection-widget-data') return;

  const task = (async function() {
    await cacheDailyReflectionWidgetPayload(data.payload);
    await refreshDailyReflectionWidgetByTag(DAILY_REFLECTION_WIDGET_TAG);
  })();

  if (event.waitUntil) {
    event.waitUntil(task);
  }
});

self.addEventListener('widgetinstall', function(event) {
  if (event.widget?.definition?.tag !== DAILY_REFLECTION_WIDGET_TAG) return;
  event.waitUntil((async function() {
    await registerDailyReflectionPeriodicSync(event.widget);
    await refreshDailyReflectionWidget(event.widget);
  })());
});

self.addEventListener('widgetresume', function(event) {
  if (event.widget?.definition?.tag !== DAILY_REFLECTION_WIDGET_TAG) return;
  event.waitUntil(refreshDailyReflectionWidget(event.widget));
});

self.addEventListener('widgetuninstall', function(event) {
  if (event.widget?.definition?.tag !== DAILY_REFLECTION_WIDGET_TAG) return;
  event.waitUntil(unregisterDailyReflectionPeriodicSync(event.widget));
});

self.addEventListener('widgetclick', function(event) {
  if (event.action !== 'open-planner') return;
  event.waitUntil(openOrFocusDailyReflectionPlanner(event.widget));
});

self.addEventListener('periodicsync', function(event) {
  if (event.tag !== DAILY_REFLECTION_WIDGET_TAG) return;
  event.waitUntil(refreshDailyReflectionWidgetByTag(event.tag));
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
