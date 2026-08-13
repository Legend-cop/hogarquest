import 'package:firebase_core/firebase_core.dart';

/// Opciones de Firebase para la plataforma web. Android lee su configuración
/// automáticamente desde `android/app/google-services.json`, así que no se
/// incluyen opciones de Android aquí.
class DefaultFirebaseOptions {
  static FirebaseOptions get web => const FirebaseOptions(
        apiKey: 'AIzaSyBOxAU3xUW9tegHthBO9VxAN-3LHDoM8dI',
        authDomain: 'hogarquest-59324.firebaseapp.com',
        projectId: 'hogarquest-59324',
        storageBucket: 'hogarquest-59324.firebasestorage.app',
        messagingSenderId: '833781012070',
        appId: '1:833781012070:web:0d9a59cd239d01db5fbfa7',
      );
}
