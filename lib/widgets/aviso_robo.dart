import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/aviso_robo.dart';
import '../services/haptics_service.dart';
import '../theme/app_theme.dart';

/// Diálogo animado "¡Te robaron!" que se muestra al abrir la app cuando
/// alguien robó una tarea vencida o un slot de reto del usuario. Escala con
/// rebote y temblor; la víctima ve quién robó y cuántos puntos ganó.
Future<void> mostrarAvisoRobo(
  BuildContext context,
  List<AvisoRobo> avisos,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => DialogAvisoRobo(avisos: avisos),
  );
}

class DialogAvisoRobo extends StatefulWidget {
  final List<AvisoRobo> avisos;

  const DialogAvisoRobo({super.key, required this.avisos});

  @override
  State<DialogAvisoRobo> createState() => _DialogAvisoRoboState();
}

class _DialogAvisoRoboState extends State<DialogAvisoRobo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    HapticsService.ligero();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surface = esOscuro ? AppColors.superficieOscura : Colors.white;
    final avisos = widget.avisos;
    final principal = avisos.first;
    final extras = avisos.length - 1;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Escala con rebote suave al entrar.
        final escala = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
        // Temblor que se amortigua rápido.
        final temblor = math.sin(t * math.pi * 6) * 8 * (1 - t);
        return Transform.translate(
          offset: Offset(temblor, 0),
          child: Transform.scale(
            scale: 0.7 + 0.3 * escala,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Dialog(
                backgroundColor: surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💸', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Text(
                        '¡Te robaron!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: esOscuro ? Colors.white : AppColors.grisOscuro,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${principal.ladron} robó '
                        '${principal.esReto ? 'tu reto' : 'la tarea'} '
                        '«${principal.titulo}» y ganó '
                        '${principal.puntos} puntos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: esOscuro ? Colors.white70 : AppColors.grisOscuro,
                        ),
                      ),
                      if (extras > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '…y te robaron $extras cosa${extras == 1 ? '' : 's'} más.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: esOscuro
                                ? Colors.white54
                                : AppColors.grisMedio,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.rojo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            '¡Entendido!',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
