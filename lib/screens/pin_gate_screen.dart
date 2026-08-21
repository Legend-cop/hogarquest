import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';

/// Pantalla que pide el PIN al administrador justo después de iniciar sesión.
class PinGateScreen extends StatefulWidget {
  const PinGateScreen({super.key});

  @override
  State<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends State<PinGateScreen> {
  final _pin = TextEditingController();
  bool _error = false;
  bool _enviando = false;

  Future<void> _verificar() async {
    final app = context.read<AppProvider>();
    final texto = _pin.text.trim();
    if (texto.isEmpty) return;
    setState(() => _enviando = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    if (app.verificarPin(texto)) {
      app.desbloquearAdmin();
    } else {
      setState(() {
        _error = true;
        _enviando = false;
        _pin.clear();
      });
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
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
                      color: AppColors.amarillo,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.lock_outline,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Acceso de administrador',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grisOscuro,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hola ${user?.nombre ?? ''}, ingresa tu PIN para '
                    'entrar al panel de administración.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.grisMedio,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    onSubmitted: (_) => _verificar(),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      errorText: _error ? 'PIN incorrecto' : null,
                    ),
                  ),
                  if (_error) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.rojo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'PIN incorrecto. Inténtalo de nuevo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.rojo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  DuoButton(
                    label: _enviando ? 'Verificando…' : 'Desbloquear',
                    icon: Icons.lock_open,
                    loading: _enviando,
                    onPressed: _enviando ? null : _verificar,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => app.logout(),
                    child: const Text('Salir'),
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
