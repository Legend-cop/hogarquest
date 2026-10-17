import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/biometria_service.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/hq_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_enviando) return;
    if (_usuario.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe usuario y contraseña.')),
      );
      return;
    }
    setState(() => _enviando = true);
    final app = context.read<AppProvider>();
    try {
      final ok = await app.login(_usuario.text.trim(), _password.text);
      if (mounted && !ok) {
        setState(() => _enviando = false);
      }
      // Recordatorio biométrico tras el primer login de un niño.
      if (mounted && ok) {
        final u = app.usuarioActual;
        if (u != null && !u.esAdmin) {
          final sin = await BiometriaService.sinPreferencia(u.id!);
          if (sin && BiometriaService.disponible.value && mounted) {
            final activar = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('¿Usar tu huella?'),
                content: const Text(
                  'Puedes entrar la próxima vez con tu huella o rostro, '
                  'sin escribir la contraseña. Siempre podrás usar la '
                  'contraseña como respaldo.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No, gracias'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sí, activar'),
                  ),
                ],
              ),
            );
            if (activar == true) {
              await BiometriaService.setActivaPara(u.id!, true);
              // Evita que el gate se muestre en esta misma sesión.
              if (mounted) context.read<AppProvider>().desbloquearNino();
            } else if (activar == false) {
              // Se marca como respondido para no volver a preguntar.
              await BiometriaService.setActivaPara(u.id!, false);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error al iniciar sesión: $e');
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al iniciar sesión: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF1E3314), AppColors.grisOscuro]
                : const [Color(0xFFE5FFCC), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.verde.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const HqLogo(size: 88),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'HogarQuest',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.verde : AppColors.verdeOscuro,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '¡Aprende, coopera y gana premios!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textoSuaveTema(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 36),
                    DuoCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _usuario,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _password,
                            obscureText: _ocultar,
                            onSubmitted: (_) => _ingresar(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultar
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () =>
                                    setState(() => _ocultar = !_ocultar),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (app.error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.rojo.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.rojo.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.rojo,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      app.error!,
                                      style: const TextStyle(
                                        color: AppColors.rojo,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          DuoButton(
                            label: _enviando ? 'Ingresando…' : 'Entrar',
                            icon: _enviando ? null : Icons.rocket_launch,
                            loading: _enviando,
                            onPressed: _enviando ? null : _ingresar,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿Olvidaste tu contraseña? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: textoSuaveTema(context),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Si eres el administrador, restablécela desde "Gestionar integrantes".',
                                  ),
                                ),
                              ),
                          child: const Text('Pide ayuda'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
