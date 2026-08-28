import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/theme_controller.dart';
import 'screens/admin_usuarios_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/pin_gate_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';

/// Llave global para poder mostrar diálogos de error sin un BuildContext a mano.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Captura errores de construcción/layout y los muestra en pantalla.
  FlutterError.onError = (details) {
    _reportarError(details.exceptionAsString(), details.stack);
  };
  // Captura errores asíncronos no manejados.
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    _reportarError(error.toString(), stack);
    return true;
  };
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.web : null,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.instance.inicializar();
  } catch (e) {
    // Sin config de Firebase (aún) la app funciona con notificaciones locales.
  }
  runApp(const HogarQuestApp());
}

/// Muestra un diálogo con el error para que el usuario pueda leerlo o copiarlo.
void _reportarError(String mensaje, StackTrace? stack) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  final texto = '$mensaje\n\n${stack ?? ''}';
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bug_report, color: Colors.red),
          SizedBox(width: 8),
          Text('Error detectado'),
        ],
      ),
      content: SingleChildScrollView(
        child: SelectableText(texto, style: const TextStyle(fontSize: 12)),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: texto)),
          child: const Text('Copiar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class HogarQuestApp extends StatelessWidget {
  const HogarQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeController()..cargar()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return MaterialApp(
      title: 'HogarQuest',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.mode,
      home: const _Root(),
      routes: {
        '/admin/usuarios': (_) => const AdminUsuariosScreen(),
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.huboErrorInicializacion && app.usuarioActual == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'No se pudo inicializar la base de datos.\n\n${app.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => app.init(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (app.cargando) return const SplashScreen();
    final u = app.usuarioActual;
    if (u == null) return const LoginScreen();
    if (u.esAdmin && u.pin.isNotEmpty && !app.adminDesbloqueado) {
      return const PinGateScreen();
    }
    return HomeShell();
  }
}
