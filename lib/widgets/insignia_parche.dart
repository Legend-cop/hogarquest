import 'package:flutter/material.dart';

import 'icons3d.dart';

/// Parche bordado de una insignia.
///
/// Lograda: escudo con relleno dorado, borde de costuras punteadas y
/// destello (se ve como un parche bordado del gabán). Pendiente: silueta
/// gris con costuras apagadas, candado y el progreso actual/meta DENTRO de
/// la medalla (así nunca se sale del recuadro en móvil).
/// Se usa tanto en el Salón de la Fama (Ranking) como en el Perfil, para
/// que el logro se vea igual en ambas vistas.
class InsigniaParche extends StatelessWidget {
  final String icono;
  final String nombre;
  final bool lograda;
  final int? actual;
  final int? meta;
  final double size;

  const InsigniaParche({
    super.key,
    required this.icono,
    required this.nombre,
    required this.lograda,
    this.actual,
    this.meta,
    this.size = 78,
  });

  @override
  Widget build(BuildContext context) {
    final pendiente = !lograda && meta != null && meta! > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _ParchePainter(lograda)),
              ),
              // El icono sube un poco para dejar sitio al chip de progreso.
              Padding(
                padding: EdgeInsets.only(bottom: pendiente ? size * 0.16 : 0),
                child: Opacity(
                  opacity: lograda ? 1 : 0.5,
                  child: insignia3D(icono, size: size * 0.46, animar: false),
                ),
              ),
              if (lograda)
                const Positioned(
                  top: 5,
                  right: 7,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: Color(0xFFFFF7DE),
                  ),
                )
              else if (pendiente)
                // Progreso (candado + 3/10) dentro de la medalla.
                Positioned(
                  bottom: size * 0.07,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 9,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${actual ?? 0}/$meta',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: size * 0.07,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x33000000), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          nombre,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: lograda ? null : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

/// Dibuja el escudo del parche: relleno, contorno y costuras punteadas.
class _ParchePainter extends CustomPainter {
  final bool lograda;
  _ParchePainter(this.lograda);

  /// Escudo con los bordes desplazados [i] px hacia adentro.
  Path _escudo(Size s, double i) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.05 + i * 0.6)
      ..lineTo(w * 0.93 - i, h * 0.17 + i * 0.4)
      ..lineTo(w * 0.93 - i, h * 0.54)
      ..quadraticBezierTo(
        w * 0.93 - i,
        h * 0.85 - i,
        w * 0.5,
        h * 0.96 - i * 0.5,
      )
      ..quadraticBezierTo(
        w * 0.07 + i,
        h * 0.85 - i,
        w * 0.07 + i,
        h * 0.54,
      )
      ..lineTo(w * 0.07 + i, h * 0.17 + i * 0.4)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _escudo(size, 0);

    // Relleno del parche.
    if (lograda) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFD97706)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(Offset.zero & size),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFF3F4F6),
      );
    }

    // Contorno exterior firme (borde del parche).
    canvas.drawPath(
      path,
      Paint()
        ..color = lograda
            ? const Color(0xFF92400E)
            : const Color(0xFFD1D5DB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round,
    );

    // Costuras: borde interior punteado (puntadas de hilo).
    final costura = _escudo(size, size.width * 0.10);
    final hilo = Paint()
      ..color = lograda
          ? const Color(0xFFFFFBEA)
          : const Color(0xFF9CA3AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final metric in costura.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), hilo);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_ParchePainter old) => old.lograda != lograda;
}
