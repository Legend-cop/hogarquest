importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging.js');

// Configuración de la web app de Firebase (debe coincidir con firebase_options.dart).
const firebaseConfig = {
  apiKey: 'AIzaSyBOxAU3xUW9tegHthBO9VxAN-3LHDoM8dI',
  authDomain: 'hogarquest-59324.firebaseapp.com',
  projectId: 'hogarquest-59324',
  storageBucket: 'hogarquest-59324.firebasestorage.app',
  messagingSenderId: '833781012070',
  appId: '1:833781012070:web:0d9a59cd239d01db5fbfa7'
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// En web, los mensajes en segundo plano se muestran automáticamente si traen
// la sección "notification". Aquí solo registramos el manejo por si acaso.
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw] mensaje en segundo plano:', payload);
});
