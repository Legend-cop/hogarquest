import 'dart:math';

import 'package:flutter/material.dart';

/// Explosión de confeti estilo celebración Duolingo.
///
/// Se inserta como OverlayEntry en la raíz de la app y se elimina
/// solo después de la animación. Sin dependencias externas.
class ConfettiBurst extends StatefulWidget {
  final int piezas;
  final Duration duracion;

  const ConfettiBurst({
    super.key,
    this.piezas = 60,
    this.duracion = const Duration(milliseconds: 1700),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Pieza> _piezas;
  final _random = Random();

  static const _colores = [
    Color(0xFF58CC02),
    Color(0xFFFFD900),
    Color(0xFF1CB0F6),
    Color(0xFFCE82FF),
    Color(0xFFFF4B4B),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duracion)
      ..forward();
    _piezas = List.generate(widget.piezas, (_) => _Pieza(_random));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final alto = MediaQuery.of(context).size.height;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            children: [
              for (final p in _piezas)
                Positioned(
                  left: p.x * ancho,
                  top: (t * alto * 0.95) - p.alturaInicial,
                  child: Transform.rotate(
                    angle: p.rotacion * t * p.velocidadRotacion,
                    child: Opacity(
                      opacity: t < 0.85 ? 1 : (1 - (t - 0.85) / 0.15),
                      child: Container(
                        width: p.tamano,
                        height: p.tamano,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(p.rounded ? p.tamano / 2 : 2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Invoca una explosión de confeti sobre la raíz de la app.
void lanzarConfeti(BuildContext context) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (_) => ConfettiBurst(
      key: ValueKey(DateTime.now().microsecondsSinceEpoch),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1900), () {
    if (entry.mounted) entry.remove();
  });
}

class _Pieza {
  final double x;
  final double alturaInicial;
  final double rotacion;
  final double velocidadRotacion;
  final double tamano;
  final Color color;
  final bool rounded;

  _Pieza(Random random)
      : x = random.nextDouble(),
        alturaInicial = 40 + random.nextDouble() * 200,
        rotacion = random.nextDouble() * 6,
        velocidadRotacion = 2 + random.nextDouble() * 6,
        tamano = 6 + random.nextDouble() * 8,
        color = _ConfettiBurstState._colores[
            random.nextInt(_ConfettiBurstState._colores.length)],
        rounded = random.nextBool();
}
