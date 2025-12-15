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

  messaging.onBackgroundMessage(function(payload) {
    const notificationTitle = payload.notification?.title || 'Kemetic Calendar';
    const notificationOptions = {
      body: payload.notification?.body,
      icon: '/icons/Icon-192.png',
      data: payload.data || {},
    };
    self.registration.showNotification(notificationTitle, notificationOptions);
  });
} else {
  console.warn('[firebase-messaging-sw] Missing firebaseConfig; web push disabled.');
}
