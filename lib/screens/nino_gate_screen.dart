import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/biometria_service.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';

/// Pantalla que pide huella/rostro al niño justo después de restaurar la
/// sesión, si activó el desbloqueo biométrico. La contraseña (logout) es
/// siempre el respaldo.
class NinoGateScreen extends StatefulWidget {
  const NinoGateScreen({super.key});

  @override
  State<NinoGateScreen> createState() => _NinoGateScreenState();
}

class _NinoGateScreenState extends State<NinoGateScreen> {
  bool _bioIntentado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _biometricoInicial());
  }

  Future<void> _biometricoInicial() async {
    if (_bioIntentado) return;
    _bioIntentado = true;
    if (!BiometriaService.activa.value ||
        !BiometriaService.disponible.value) {
      return;
    }
    final ok = await BiometriaService.autenticar();
    if (ok && mounted) {
      context.read<AppProvider>().desbloquearNino();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.usuarioActual;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.grisOscuro
          : AppColors.fondo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DuoCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.verde,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hola, ${user?.nombre ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa tu huella o rostro para entrar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: textoSuaveTema(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DuoButton(
                    label: 'Usar huella o rostro',
                    icon: Icons.fingerprint,
                    onPressed: () async {
                      final ok = await BiometriaService.autenticar();
                      if (ok && context.mounted) {
                        context.read<AppProvider>().desbloquearNino();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => app.logout(),
                    child: const Text('Entrar con contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
