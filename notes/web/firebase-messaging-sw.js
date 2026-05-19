importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Firebase config matching firebase_options.dart (web)
firebase.initializeApp({
  apiKey: "AIzaSyA4JtmDvOFuD441spoBIOEKjNUabzq-Y48",
  authDomain: "notes-37320.firebaseapp.com",
  projectId: "notes-37320",
  storageBucket: "notes-37320.firebasestorage.app",
  messagingSenderId: "1052727763580",
  appId: "1:1052727763580:web:8db656505cdfb6ff7c1ff9",
  measurementId: "G-ZSJ8G839MZ",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || "New Note";
  const notificationOptions = {
    body: payload.notification?.body || "Check your app",
    icon: "/favicon.png",
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
