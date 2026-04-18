// Firebase Messaging service worker for Kemetic Calendar PWA.
// Fill in firebaseConfig with your Firebase Web creds and set a VAPID key.
// You can also provide a firebase-config.js that sets `self.firebaseConfig`
// and `self.firebaseVapidKey` before this script loads.

try {
  importScripts('firebase-config.js'); // optional override file
} catch (_) {
  // ignore if not present
}

// Use compat layer (v10+) for better Safari/iOS PWA support
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

self.firebaseConfig = self.firebaseConfig || {
  apiKey: 'AIzaSyDxi7_OQx76JaPgjBTEF-Rfv2-1EZh0GeY',
  authDomain: 'kemet-ead9d.firebaseapp.com',
  projectId: 'kemet-ead9d',
  storageBucket: 'kemet-ead9d.firebasestorage.app',
  messagingSenderId: '867956659884',
  appId: '1:867956659884:web:08c4b8b604332669727109',
};

const vapidKey =
  self.firebaseVapidKey ||
  'BCL_DxiCA9I2kweZh33mnnNv2-41OLh1FZbO8lX-JjdVSHs7XS9e8gxZldJRYWVRh0WxhffmH37gMM7-qjPQgMY';

if (self.firebaseConfig && self.firebaseConfig.apiKey && self.firebaseConfig.messagingSenderId) {
  firebase.initializeApp(self.firebaseConfig);
  const messaging = firebase.messaging();

  if (vapidKey && vapidKey !== 'REPLACE_ME_VAPID_KEY') {
    messaging.usePublicVapidKey(vapidKey);
  } else {
    console.warn('[firebase-messaging-sw] Missing VAPID key; web push will fail.');
  }

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

  messaging.onBackgroundMessage(function(payload) {
    const notificationTitle =
      payload.notification?.title ||
      payload.data?.title ||
      'Kemetic Calendar';
    const targetUrl = resolveTargetUrl(payload);
    const notificationOptions = {
      body: payload.notification?.body || payload.data?.body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-maskable-192.png',
      tag: payload.data?.kind || payload.data?.type || 'kemetic-calendar',
      data: {
        ...(payload.data || {}),
        url: targetUrl,
      },
    };
    self.registration.showNotification(notificationTitle, notificationOptions);
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
} else {
  console.warn('[firebase-messaging-sw] Missing firebaseConfig; web push disabled.');
}
