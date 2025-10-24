// Firebase Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize Firebase
firebase.initializeApp({
  apiKey: 'AIzaSyBhAEQ7wNaBH1nmtRs51WqZPGHfPoRtFQs',
  authDomain: 'nearme-970f3.firebaseapp.com',
  projectId: 'nearme-970f3',
  storageBucket: 'nearme-970f3.firebasestorage.app',
  messagingSenderId: '725875446445',
  appId: '1:725875446445:web:1399519fbff5bf9b0aec24'
});

// Initialize Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'New Message';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
