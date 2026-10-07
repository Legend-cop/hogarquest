import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Iconos "vivos" pintados a mano con CustomPaint: degradados, bisel,
/// brillo especular, sombra y animación sutil. Sustituyen a los iconos
/// planos de Material para racha (fuego), XP (rayo), medallas y trofeos.

enum MedalTono { oro, plata, bronce, platino, zafiro }

MedalTono medalTonoDe(String liga) {
  switch (liga.toLowerCase()) {
    case 'plata':
      return MedalTono.plata;
    case 'oro':
      return MedalTono.oro;
    case 'platino':
      return MedalTono.platino;
    case 'zafiro':
      return MedalTono.zafiro;
    default:
      return MedalTono.bronce;
  }
}

class _PaletaMetal {
  final Color claro;
  final Color base;
  final Color oscuro;
  const _PaletaMetal(this.claro, this.base, this.oscuro);
}

_PaletaMetal _paleta(MedalTono tono) {
  switch (tono) {
    case MedalTono.oro:
      return const _PaletaMetal(
          Color(0xFFFFF3B8), Color(0xFFFFC800), Color(0xFFC77E00));
    case MedalTono.plata:
      return const _PaletaMetal(
          Color(0xFFFFFFFF), Color(0xFFB0B7C3), Color(0xFF757E8C));
    case MedalTono.bronce:
      return const _PaletaMetal(
          Color(0xFFF2C089), Color(0xFFCD7F32), Color(0xFF8C4E1B));
    case MedalTono.platino:
      return const _PaletaMetal(
          Color(0xFFFFFFFF), Color(0xFFCFEDE8), Color(0xFF6FAFA4));
    case MedalTono.zafiro:
      return const _PaletaMetal(
          Color(0xFF9FC2FF), Color(0xFF2B59C3), Color(0xFF16357E));
  }
}

// ---------------------------------------------------------------------------
// FUEGO (racha)
// ---------------------------------------------------------------------------

class Flame3D extends StatefulWidget {
  final double size;
  final bool animar;
  const Flame3D({super.key, this.size = 32, this.animar = true});

  @override
  State<Flame3D> createState() => _Flame3DState();
}

class _Flame3DState extends State<Flame3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              CustomPaint(painter: _FlamePainter(_c.value)),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final double t;
  _FlamePainter(this.t);

  Path _flama(Rect r, double wob) {
    final cx = r.center.dx;
    final w = r.width;
    final h = r.height;
    final sway = w * 0.06 * wob;
    final tipY = r.top + h * (0.03 - 0.03 * wob);
    final p = Path();
    p.moveTo(cx + sway, tipY);
    p.cubicTo(cx + w * 0.24, r.top + h * 0.20, cx + w * 0.34,
        r.top + h * 0.36, cx + w * 0.33, r.top + h * 0.56);
    p.cubicTo(cx + w * 0.32, r.top + h * 0.82, cx + w * 0.18,
        r.bottom - h * 0.02, cx, r.bottom);
    p.cubicTo(cx - w * 0.18, r.bottom - h * 0.02, cx - w * 0.32,
        r.top + h * 0.82, cx - w * 0.33, r.top + h * 0.56);
    p.cubicTo(cx - w * 0.34, r.top + h * 0.36, cx - w * 0.24,
        r.top + h * 0.20, cx + sway, tipY);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final wob = math.sin(math.pi * t.clamp(0, 1));
    final cx = size.width / 2;

    // Resplandor de fondo.
    final glowRect =
        Rect.fromCircle(center: Offset(cx, size.height * 0.60),
            radius: size.width * 0.62);
    canvas.drawCircle(
      glowRect.center,
      glowRect.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0x66FF9D00), const Color(0x99FF9D00), wob)!,
            const Color(0x00FF9D00),
          ],
        ).createShader(glowRect),
    );

    final p = _flama(r, wob);

    // Sombra proyectada.
    canvas.save();
    canvas.translate(0, size.height * 0.05);
    canvas.drawPath(p, Paint()..color = const Color(0x26000000));
    canvas.restore();

    // Llama exterior con degradado.
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC531), Color(0xFFFF8A1B), Color(0xFFF4511E)],
          stops: [0, 0.5, 1],
        ).createShader(r),
    );

    // Luz en el borde izquierdo (bisel).
    canvas.save();
    canvas.clipPath(p);
    canvas.translate(-size.width * 0.035, 0);
    canvas.drawPath(
      _flama(r, wob),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05
        ..color = const Color(0x66FFFFFF),
    );
    canvas.restore();

    // Llama interior amarilla.
    final ri = Rect.fromLTWH(r.left + size.width * 0.14,
        r.top + size.height * 0.16, size.width * 0.72, size.height * 0.70);
    final pi = _flama(ri, wob * 0.6);
    canvas.drawPath(
      pi,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF7C2), Color(0xFFFFD624)],
        ).createShader(ri),
    );

    // Núcleo blanco caliente.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, size.height * 0.74),
          width: size.width * 0.20,
          height: size.height * 0.26),
      Paint()..color = const Color(0xF2FFFDE7),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// RAYO (XP)
// ---------------------------------------------------------------------------

class Bolt3D extends StatefulWidget {
  final double size;
  final bool animar;
  const Bolt3D({super.key, this.size = 32, this.animar = true});

  @override
  State<Bolt3D> createState() => _Bolt3DState();
}

class _Bolt3DState extends State<Bolt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _BoltPainter(_c.value)),
        ),
      ),
    );
  }
}

Path _rayoPath(Size s) {
  final p = Path();
  p.moveTo(s.width * 0.58, 0);
  p.lineTo(s.width * 0.12, s.height * 0.60);
  p.lineTo(s.width * 0.44, s.height * 0.60);
  p.lineTo(s.width * 0.32, s.height);
  p.lineTo(s.width * 0.88, s.height * 0.36);
  p.lineTo(s.width * 0.54, s.height * 0.36);
  p.close();
  return p;
}

class _BoltPainter extends CustomPainter {
  final double t;
  _BoltPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Destello: pulso al final del ciclo.
    final phase = t > 0.86 ? ((t - 0.86) / 0.14) : 0.0;
    final pulse = phase <= 0 ? 0.0 : math.sin(phase * math.pi);

    canvas.save();
    if (pulse > 0) {
      final sc = 1 + 0.14 * pulse;
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(sc, sc);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    // Resplandor.
    final g = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.width * 0.66);
    canvas.drawCircle(
      g.center,
      g.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0x4DFFC800), const Color(0xB3FFC800), pulse)!,
            const Color(0x00FFC800),
          ],
        ).createShader(g),
    );

    final p = _rayoPath(size);

    // Sombra proyectada.
    canvas.save();
    canvas.translate(size.width * 0.05, size.height * 0.06);
    canvas.drawPath(p, Paint()..color = const Color(0x33000000));
    canvas.restore();

    // Cuerpo con degradado dorado.
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFC800), Color(0xFFF59A00)],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );

    // Bisel: luz arriba-izquierda y sombra abajo-derecha dentro del trazo.
    canvas.save();
    canvas.clipPath(p);
    canvas.translate(-size.width * 0.03, -size.height * 0.04);
    canvas.drawPath(
      _rayoPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..color = const Color(0x99FFFFFF),
    );
    canvas.restore();
    canvas.save();
    canvas.clipPath(p);
    canvas.translate(size.width * 0.03, size.height * 0.04);
    canvas.drawPath(
      _rayoPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..color = const Color(0x4D8A4B00),
    );
    canvas.restore();

    // Contorno definido.
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..color = const Color(0x80A86A00),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// MEDALLA (ligas y nivel)
// ---------------------------------------------------------------------------

class Medal3D extends StatefulWidget {
  final double size;
  final MedalTono tono;
  final bool animar;
  const Medal3D({
    super.key,
    this.size = 32,
    this.tono = MedalTono.oro,
    this.animar = true,
  });

  @override
  State<Medal3D> createState() => _Medal3DState();
}

class _Medal3DState extends State<Medal3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _MedalPainter(_c.value, widget.tono),
          ),
        ),
      ),
    );
  }
}

Path _estrella(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.46;
    final ang = -math.pi / 2 + i * math.pi / 5;
    final o =
        Offset(c.dx + rad * math.cos(ang), c.dy + rad * math.sin(ang));
    if (i == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  p.close();
  return p;
}

class _MedalPainter extends CustomPainter {
  final double t;
  final MedalTono tono;
  _MedalPainter(this.t, this.tono);

  @override
  void paint(Canvas canvas, Size size) {
    final pal = _paleta(tono);
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final centro = Offset(cx, h * 0.60);
    final radio = w * 0.34;

    // Cinta trasera.
    final cintaIzq = Path()
      ..moveTo(w * 0.28, 0)
      ..lineTo(w * 0.47, 0)
      ..lineTo(w * 0.53, h * 0.40)
      ..lineTo(w * 0.33, h * 0.47)
      ..close();
    final cintaDer = Path()
      ..moveTo(w * 0.53, 0)
      ..lineTo(w * 0.72, 0)
      ..lineTo(w * 0.67, h * 0.47)
      ..lineTo(w * 0.47, h * 0.40)
      ..close();
    canvas.drawPath(
      cintaIzq,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE5484D), Color(0xFFA3151B)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      cintaDer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4DA3FF), Color(0xFF1466B8)],
        ).createShader(Offset.zero & size),
    );

    // Sombra bajo la medalla.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.96),
          width: radio * 1.7,
          height: radio * 0.34),
      Paint()..color = const Color(0x33000000),
    );

    // Aro metálico (barrido de luz).
    final disco = Rect.fromCircle(center: centro, radius: radio);
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..shader = SweepGradient(
          transform: const GradientRotation(-math.pi / 2),
          colors: [pal.claro, pal.base, pal.oscuro, pal.base, pal.claro],
        ).createShader(disco),
    );

    // Centro con gradiente radial.
    final centroR = Rect.fromCircle(center: centro, radius: radio * 0.80);
    canvas.drawCircle(
      centro,
      radio * 0.80,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.95,
          colors: [pal.claro, pal.base, pal.oscuro],
          stops: const [0, 0.55, 1],
        ).createShader(centroR),
    );

    // Estrella grabada: sombra oscura + luz clara.
    canvas.save();
    canvas.translate(w * 0.012, h * 0.014);
    canvas.drawPath(_estrella(centro, radio * 0.50),
        Paint()..color = Color((pal.oscuro.toARGB32() & 0x00FFFFFF) | 0x99000000));
    canvas.restore();
    canvas.save();
    canvas.translate(-w * 0.012, -h * 0.010);
    canvas.drawPath(_estrella(centro, radio * 0.50),
        Paint()..color = Color((pal.claro.toARGB32() & 0x00FFFFFF) | 0xCC000000));
    canvas.restore();
    canvas.drawPath(
        _estrella(centro, radio * 0.50),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pal.claro, pal.base],
          ).createShader(disco));

    // Brillo especular arriba-izquierda.
    canvas.save();
    canvas.clipPath(Path()..addOval(disco));
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(-0.6);
    canvas.translate(-centro.dx, -centro.dy);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(centro.dx - radio * 0.42,
              centro.dy - radio * 0.55),
          width: radio * 1.1,
          height: radio * 0.5),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCenter(
            center: Offset(centro.dx - radio * 0.42,
                centro.dy - radio * 0.55),
            width: radio * 1.1,
            height: radio * 0.5)),
    );
    canvas.restore();

    // Brillo barrido (solo durante su fase del ciclo).
    if (t > 0.06 && t < 0.56) {
      final k = (t - 0.06) / 0.50;
      final x = -w * 0.7 + k * w * 2.1;
      canvas.save();
      canvas.clipPath(Path()..addOval(disco));
      canvas.translate(cx + x, h * 0.60);
      canvas.rotate(-0.55);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: w * 0.16, height: h * 2.0),
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0xB3FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(
              Rect.fromCenter(center: Offset.zero, width: w * 0.16, height: h)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.t != t || old.tono != tono;
}

// ---------------------------------------------------------------------------
// TROFEO (insignias y logros)
// ---------------------------------------------------------------------------

class Trophy3D extends StatefulWidget {
  final double size;
  final bool animar;
  const Trophy3D({super.key, this.size = 32, this.animar = true});

  @override
  State<Trophy3D> createState() => _Trophy3DState();
}

class _Trophy3DState extends State<Trophy3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              CustomPaint(painter: _TrophyPainter(_c.value)),
        ),
      ),
    );
  }
}

Path _copaPath(Size s) {
  final p = Path();
  p.moveTo(s.width * 0.26, s.height * 0.14);
  p.lineTo(s.width * 0.74, s.height * 0.14);
  p.lineTo(s.width * 0.70, s.height * 0.46);
  p.quadraticBezierTo(s.width * 0.50, s.height * 0.70,
      s.width * 0.30, s.height * 0.46);
  p.close();
  return p;
}

class _TrophyPainter extends CustomPainter {
  final double t;
  _TrophyPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sombra en el suelo.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.965),
          width: w * 0.52,
          height: h * 0.10),
      Paint()..color = const Color(0x33000000),
    );

    // Asas (trazo grueso dorado oscuro).
    final asa = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE0A800);
    final a1 = Path()
      ..moveTo(w * 0.29, h * 0.20)
      ..cubicTo(w * 0.06, h * 0.20, w * 0.06, h * 0.44, w * 0.31, h * 0.44);
    final a2 = Path()
      ..moveTo(w * 0.71, h * 0.20)
      ..cubicTo(w * 0.94, h * 0.20, w * 0.94, h * 0.44, w * 0.69, h * 0.44);
    canvas.drawPath(a1, asa);
    canvas.drawPath(a2, asa);

    // Base y tallo.
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.62, w * 0.28, h * 0.16),
        Radius.circular(w * 0.03),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.26, h * 0.76, w * 0.48, h * 0.16),
        Radius.circular(w * 0.04),
      ));
    canvas.drawPath(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD75E), Color(0xFFD08C00), Color(0xFF9C6600)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    // Copa.
    final copa = _copaPath(size);
    canvas.drawPath(
      copa,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0A0), Color(0xFFFFC800), Color(0xFFE08A00)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    // Borde superior (aro).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.11, w * 0.52, h * 0.09),
        Radius.circular(w * 0.045),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF7CF), Color(0xFFE8A100)],
        ).createShader(Rect.fromLTWH(w * 0.24, h * 0.11, w * 0.52, h * 0.09)),
    );

    // Luz lateral en la copa (bisel).
    canvas.save();
    canvas.clipPath(copa);
    canvas.translate(-w * 0.03, -h * 0.03);
    canvas.drawPath(
      _copaPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08
        ..color = const Color(0x80FFFFFF),
    );
    canvas.restore();

    // Estrella grabada en la copa.
    final ce = Offset(w * 0.5, h * 0.36);
    canvas.drawPath(_estrella(ce, w * 0.13),
        Paint()..color = const Color(0x667A4E00));
    canvas.save();
    canvas.translate(0, -h * 0.02);
    canvas.drawPath(_estrella(ce, w * 0.13),
        Paint()..color = const Color(0xB3FFF3B0));
    canvas.restore();

    // Brillo barrido sobre la copa.
    if (t > 0.10 && t < 0.60) {
      final k = (t - 0.10) / 0.50;
      final x = -w * 0.7 + k * w * 2.1;
      canvas.save();
      canvas.clipPath(copa);
      canvas.translate(w * 0.5 + x, h * 0.4);
      canvas.rotate(-0.55);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w * 0.16, height: h * 1.4),
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0x99FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(Rect.fromCenter(
              center: Offset.zero, width: w * 0.16, height: h)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TrophyPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// GENÉRICO: anima cualquier pintor con RepaintBoundary (iconos de objeto)
// ---------------------------------------------------------------------------

class _Anim3D extends StatefulWidget {
  final double size;
  final bool animar;
  final Duration duracion;
  final bool inverso;
  final CustomPainter Function(double t) pintar;
  const _Anim3D({
    required this.size,
    required this.animar,
    required this.duracion,
    required this.inverso,
    required this.pintar,
  });

  @override
  State<_Anim3D> createState() => _Anim3DState();
}

class _Anim3DState extends State<_Anim3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duracion,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat(reverse: widget.inverso);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: widget.pintar(_c.value)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INTEGRANTES (dos personas)
// ---------------------------------------------------------------------------

class People3D extends StatelessWidget {
  final double size;
  final bool animar;
  const People3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: true,
        duracion: const Duration(milliseconds: 2200),
        pintar: (t) => _PeoplePainter(t),
      );
}

class _PeoplePainter extends CustomPainter {
  final double t;
  _PeoplePainter(this.t);

  void _persona(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double r,
    required Path cuerpo,
    required Color claro,
    required Color base,
    required Color oscuro,
    required double dy,
  }) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(0, dy);

    canvas.drawPath(
      cuerpo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [claro, base, oscuro],
          stops: const [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(cuerpo);
    canvas.translate(-w * 0.03, -h * 0.03);
    canvas.drawPath(
      cuerpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.10
        ..color = const Color(0x66FFFFFF),
    );
    canvas.restore();
    canvas.save();
    canvas.clipPath(cuerpo);
    canvas.translate(w * 0.03, h * 0.03);
    canvas.drawPath(
      cuerpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.10
        ..color = const Color(0x40000000),
    );
    canvas.restore();

    final hc = Offset(w * cx, h * cy);
    final hr = w * r;
    final disco = Rect.fromCircle(center: hc, radius: hr);
    canvas.drawCircle(
      hc,
      hr,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.40),
          radius: 0.95,
          colors: [claro, base, oscuro],
          stops: const [0, 0.55, 1],
        ).createShader(disco),
    );
    canvas.drawCircle(
      hc,
      hr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..color = const Color(0x40000000),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hc.dx - hr * 0.34, hc.dy - hr * 0.40),
        width: hr * 0.50,
        height: hr * 0.34,
      ),
      Paint()..color = const Color(0xB3FFFFFF),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bob = math.sin(math.pi * t.clamp(0, 1));

    final g = Rect.fromCircle(
        center: Offset(w * 0.5, h * 0.58), radius: w * 0.62);
    canvas.drawCircle(
      g.center,
      g.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0x4D1CB0F6), const Color(0x801CB0F6), bob)!,
            const Color(0x001CB0F6),
          ],
        ).createShader(g),
    );

    _persona(
      canvas,
      size,
      cx: 0.66,
      cy: 0.34,
      r: 0.135,
      cuerpo: Path()
        ..moveTo(w * 0.47, h * 0.94)
        ..cubicTo(w * 0.52, h * 0.34, w * 0.80, h * 0.34, w * 0.85, h * 0.94)
        ..close(),
      claro: const Color(0xFFD6EFFD),
      base: const Color(0xFF7EC4EC),
      oscuro: const Color(0xFF4E9CC9),
      dy: 0,
    );

    _persona(
      canvas,
      size,
      cx: 0.40,
      cy: 0.38,
      r: 0.165,
      cuerpo: Path()
        ..moveTo(w * 0.09, h * 0.97)
        ..cubicTo(w * 0.23, h * 0.40, w * 0.57, h * 0.40, w * 0.71, h * 0.97)
        ..close(),
      claro: const Color(0xFF9BEAFF),
      base: const Color(0xFF22B3F4),
      oscuro: const Color(0xFF0B78B5),
      dy: -0.03 * h * bob,
    );
  }

  @override
  bool shouldRepaint(_PeoplePainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// TABLERO COMPARTIDO (tareas y aprobaciones)
// ---------------------------------------------------------------------------

void _tablero(Canvas canvas, Size size, Color c1, Color c2) {
  final w = size.width;
  final h = size.height;
  final rtab = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.13, h * 0.14, w * 0.74, h * 0.80),
    Radius.circular(w * 0.08),
  );

  canvas.save();
  canvas.translate(w * 0.03, h * 0.05);
  canvas.drawRRect(rtab, Paint()..color = const Color(0x33000000));
  canvas.restore();

  canvas.drawRRect(
    rtab,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFE7ECF3), Color(0xFFD3DAE4)],
        stops: [0, 0.55, 1],
      ).createShader(Offset.zero & size),
  );
  canvas.drawRRect(
    rtab,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..color = const Color(0xFF94A3B8),
  );
  canvas.save();
  canvas.clipRRect(rtab);
  canvas.translate(-w * 0.03, -h * 0.03);
  canvas.drawRRect(
    rtab,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..color = const Color(0x66FFFFFF),
  );
  canvas.restore();

  final clip = RRect.fromRectAndRadius(
    Rect.fromLTWH(w * 0.31, h * 0.04, w * 0.38, h * 0.17),
    Radius.circular(w * 0.05),
  );
  canvas.drawRRect(
    clip,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c1, c2],
      ).createShader(Offset.zero & size),
  );
  canvas.drawRRect(
    clip,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = const Color(0x80000000),
  );
  canvas.save();
  canvas.clipRRect(clip);
  canvas.translate(-w * 0.02, -h * 0.02);
  canvas.drawRRect(
    clip,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..color = const Color(0xB3FFFFFF),
  );
  canvas.restore();
}

// ---------------------------------------------------------------------------
// TAREAS (tablero con palomita viva)
// ---------------------------------------------------------------------------

class ClipboardCheck3D extends StatelessWidget {
  final double size;
  final bool animar;
  const ClipboardCheck3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: true,
        duracion: const Duration(milliseconds: 2400),
        pintar: (t) => _ClipboardCheckPainter(t),
      );
}

class _ClipboardCheckPainter extends CustomPainter {
  final double t;
  _ClipboardCheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pulse = math.sin(math.pi * t.clamp(0, 1));
    final centro = Offset(w * 0.50, h * 0.64);

    _tablero(canvas, size, const Color(0xFF5AD1FF), const Color(0xFF0E86C7));

    final gl = Rect.fromCircle(center: centro, radius: w * 0.44);
    canvas.drawCircle(
      gl.center,
      gl.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0x3358CC02), const Color(0x6658CC02), pulse)!,
            const Color(0x0058CC02),
          ],
        ).createShader(gl),
    );

    final check = Path()
      ..moveTo(w * 0.30, h * 0.63)
      ..lineTo(w * 0.44, h * 0.77)
      ..lineTo(w * 0.73, h * 0.40);
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    final sc = 1 + 0.08 * pulse;
    canvas.scale(sc, sc);
    canvas.translate(-centro.dx, -centro.dy);

    canvas.save();
    canvas.translate(w * 0.012, h * 0.016);
    canvas.drawPath(check, trazo..color = const Color(0xFF3E8600));
    canvas.restore();
    canvas.save();
    canvas.translate(-w * 0.012, -h * 0.014);
    canvas.drawPath(check, trazo..color = const Color(0xB3B9F56A));
    canvas.restore();
    canvas.drawPath(check, trazo..color = const Color(0xFF58CC02));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClipboardCheckPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// APROBACIONES (tablero con reloj y segundero vivo)
// ---------------------------------------------------------------------------

class ClipboardClock3D extends StatelessWidget {
  final double size;
  final bool animar;
  const ClipboardClock3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: false,
        duracion: const Duration(milliseconds: 6000),
        pintar: (t) => _ClipboardClockPainter(t),
      );
}

class _ClipboardClockPainter extends CustomPainter {
  final double t;
  _ClipboardClockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centro = Offset(w * 0.51, h * 0.64);
    final r = w * 0.24;

    _tablero(canvas, size, const Color(0xFFFFD93B), const Color(0xFFE8A100));

    canvas.drawCircle(
      centro + Offset(w * 0.015, h * 0.025),
      r,
      Paint()..color = const Color(0x33000000),
    );

    final disco = Rect.fromCircle(center: centro, radius: r);
    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5AD1FF), Color(0xFF1CB0F6), Color(0xFF0B74AD)],
          stops: [0, 0.5, 1],
        ).createShader(disco),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(disco));
    canvas.translate(-w * 0.012, -h * 0.014);
    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..color = const Color(0x66FFFFFF),
    );
    canvas.restore();

    final rf = r * 0.78;
    final cara = Rect.fromCircle(center: centro, radius: rf);
    canvas.drawCircle(
      centro,
      rf,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.30, -0.35),
          radius: 1.0,
          colors: [const Color(0xFFFFFFFF), const Color(0xFFEAF5FC)],
        ).createShader(cara),
    );

    for (var i = 0; i < 12; i++) {
      final ang = -math.pi / 2 + i * math.pi / 6;
      final p = centro + Offset(math.cos(ang), math.sin(ang)) * rf * 0.84;
      final grande = i % 3 == 0;
      canvas.drawCircle(
        p,
        w * (grande ? 0.022 : 0.013),
        Paint()..color = const Color(0xFF9AA7B5),
      );
    }

    canvas.drawLine(
      centro,
      centro + const Offset(-0.55, -0.83) * rf * 0.50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.050
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4A5568),
    );
    canvas.drawLine(
      centro,
      centro + const Offset(0.66, -0.75) * rf * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.036
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4A5568),
    );

    final ang = t * 2 * math.pi - math.pi / 2;
    final dir = Offset(math.cos(ang), math.sin(ang));
    canvas.drawLine(
      centro - dir * rf * 0.18,
      centro + dir * rf * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.024
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF4B4B),
    );

    canvas.drawCircle(
        centro, w * 0.026, Paint()..color = const Color(0xFF3C3C3C));
    canvas.drawCircle(
        centro, w * 0.011, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_ClipboardClockPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// LIMPIEZA (escoba con barrido)
// ---------------------------------------------------------------------------

class Broom3D extends StatelessWidget {
  final double size;
  final bool animar;
  const Broom3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: true,
        duracion: const Duration(milliseconds: 2600),
        pintar: (t) => _BroomPainter(t),
      );
}

class _BroomPainter extends CustomPainter {
  final double t;
  _BroomPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.38, h * 0.965),
          width: w * 0.54,
          height: h * 0.09),
      Paint()..color = const Color(0x33000000),
    );

    final ang = math.sin(math.pi * t.clamp(0, 1)) * 0.16;
    final piv = Offset(w * 0.70, h * 0.10);
    canvas.save();
    canvas.translate(piv.dx, piv.dy);
    canvas.rotate(ang);
    canvas.translate(-piv.dx, -piv.dy);

    final palo = Path()
      ..moveTo(w * 0.70, h * 0.10)
      ..lineTo(w * 0.43, h * 0.56);
    canvas.drawPath(
      palo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.10
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFFD09040), Color(0xFF8A4B14)],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.translate(-w * 0.016, -h * 0.013);
    canvas.drawPath(
      palo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.030
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x59FFDCA8),
    );
    canvas.restore();

    final p1 = Offset(w * 0.36, h * 0.52);
    final p2 = Offset(w * 0.50, h * 0.60);
    final p3 = Offset(w * 0.44, h * 0.95);
    final p4 = Offset(w * 0.10, h * 0.86);
    final cabeza = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(
      cabeza,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE24F), Color(0xFFFFC800), Color(0xFFD98A00)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    final cerdas = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.020
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x808A4B14);
    for (final k in const [0.30, 0.55, 0.80]) {
      canvas.drawLine(
        Offset(p1.dx + (p2.dx - p1.dx) * k, p1.dy + (p2.dy - p1.dy) * k),
        Offset(p4.dx + (p3.dx - p4.dx) * k, p4.dy + (p3.dy - p4.dy) * k),
        cerdas,
      );
    }

    canvas.save();
    canvas.clipPath(cabeza);
    canvas.translate(-w * 0.025, -h * 0.025);
    canvas.drawPath(
      cabeza,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08
        ..color = const Color(0x66FFFFFF),
    );
    canvas.restore();

    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A4B14),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BroomPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// COCINA (hamburguesa con rebote)
// ---------------------------------------------------------------------------

class Meal3D extends StatelessWidget {
  final double size;
  final bool animar;
  const Meal3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: true,
        duracion: const Duration(milliseconds: 2400),
        pintar: (t) => _MealPainter(t),
      );
}

class _MealPainter extends CustomPainter {
  final double t;
  _MealPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bob = math.sin(math.pi * t.clamp(0, 1));

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.965),
          width: w * 0.62,
          height: h * 0.09),
      Paint()..color = const Color(0x40000000),
    );

    canvas.save();
    canvas.translate(0, -0.03 * h * bob);

    final panSup = Path()
      ..moveTo(w * 0.08, h * 0.46)
      ..quadraticBezierTo(w * 0.08, h * 0.06, w * 0.50, h * 0.06)
      ..quadraticBezierTo(w * 0.92, h * 0.06, w * 0.92, h * 0.46)
      ..close();
    canvas.drawPath(
      panSup,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFEDBE), Color(0xFFFFC85A), Color(0xFFEE9E2E)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(panSup);
    canvas.translate(-w * 0.02, -h * 0.03);
    canvas.drawPath(
      panSup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08
        ..color = const Color(0x66FFFFFF),
    );
    canvas.restore();

    final semillas = [
      (Offset(w * 0.33, h * 0.30), -0.5),
      (Offset(w * 0.50, h * 0.19), 0.0),
      (Offset(w * 0.67, h * 0.31), 0.5),
    ];
    for (final s in semillas) {
      canvas.save();
      canvas.translate(s.$1.dx, s.$1.dy);
      canvas.rotate(s.$2);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: w * 0.05, height: h * 0.026),
        Paint()..color = const Color(0xFFF7F0D4),
      );
      canvas.restore();
    }

    final lechuga = Path()
      ..moveTo(w * 0.06, h * 0.44)
      ..lineTo(w * 0.94, h * 0.44)
      ..lineTo(w * 0.94, h * 0.54);
    var x = 0.94;
    while (x > 0.075) {
      x = math.max(x - 0.147, 0.06);
      lechuga.quadraticBezierTo(w * (x + 0.0735), h * 0.67, w * x, h * 0.54);
    }
    lechuga.close();
    canvas.drawPath(
      lechuga,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9BE84B), Color(0xFF4C9A0F)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.61, w * 0.80, h * 0.18),
        Radius.circular(w * 0.07),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFA9601F), Color(0xFF7A3D0E), Color(0xFF5C2E08)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    final queso = Path()
      ..moveTo(w * 0.09, h * 0.55)
      ..lineTo(w * 0.91, h * 0.55)
      ..lineTo(w * 0.91, h * 0.63)
      ..lineTo(w * 0.62, h * 0.63)
      ..quadraticBezierTo(w * 0.60, h * 0.73, w * 0.52, h * 0.72)
      ..quadraticBezierTo(w * 0.46, h * 0.71, w * 0.46, h * 0.63)
      ..lineTo(w * 0.09, h * 0.63)
      ..close();
    canvas.drawPath(
      queso,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFDF6E), Color(0xFFFFB300)],
        ).createShader(Offset.zero & size),
    );

    final panInf = Path()
      ..moveTo(w * 0.10, h * 0.76)
      ..lineTo(w * 0.90, h * 0.76)
      ..lineTo(w * 0.90, h * 0.86)
      ..quadraticBezierTo(w * 0.90, h * 0.95, w * 0.78, h * 0.95)
      ..lineTo(w * 0.22, h * 0.95)
      ..quadraticBezierTo(w * 0.10, h * 0.95, w * 0.10, h * 0.86)
      ..close();
    canvas.drawPath(
      panInf,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF5B154), Color(0xFFD9852B)],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(panInf);
    canvas.translate(-w * 0.02, -h * 0.02);
    canvas.drawPath(
      panInf,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..color = const Color(0x4DFFFFFF),
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MealPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// ORDEN (caja isométrica con balanceo)
// ---------------------------------------------------------------------------

class Box3D extends StatelessWidget {
  final double size;
  final bool animar;
  const Box3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: true,
        duracion: const Duration(milliseconds: 2400),
        pintar: (t) => _BoxPainter(t),
      );
}

class _BoxPainter extends CustomPainter {
  final double t;
  _BoxPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bob = math.sin(math.pi * t.clamp(0, 1));

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.975),
          width: w * 0.56,
          height: h * 0.08),
      Paint()..color = const Color(0x40000000),
    );

    canvas.save();
    canvas.translate(0, -0.03 * h * bob);

    final top = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.92, h * 0.30)
      ..lineTo(w * 0.50, h * 0.54)
      ..lineTo(w * 0.08, h * 0.30)
      ..close();
    final izq = Path()
      ..moveTo(w * 0.08, h * 0.30)
      ..lineTo(w * 0.50, h * 0.54)
      ..lineTo(w * 0.50, h * 0.95)
      ..lineTo(w * 0.08, h * 0.71)
      ..close();
    final der = Path()
      ..moveTo(w * 0.50, h * 0.54)
      ..lineTo(w * 0.92, h * 0.30)
      ..lineTo(w * 0.92, h * 0.71)
      ..lineTo(w * 0.50, h * 0.95)
      ..close();

    canvas.drawPath(
      der,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB87E3A), Color(0xFF8A5A20)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      izq,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8AC63), Color(0xFFC07E32)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9D7A4), Color(0xFFE5A961)],
        ).createShader(Offset.zero & size),
    );

    final canto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..color = const Color(0x66805018);
    canvas.drawPath(top, canto);
    canvas.drawPath(izq, canto);
    canvas.drawPath(der, canto);
    canvas.drawLine(
      Offset(w * 0.50, h * 0.06),
      Offset(w * 0.50, h * 0.54),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016
        ..color = const Color(0x66805018),
    );

    if (t > 0.15 && t < 0.55) {
      final k = (t - 0.15) / 0.40;
      final xx = -w * 0.7 + k * w * 2.1;
      canvas.save();
      canvas.clipPath(top);
      canvas.translate(w * 0.5 + xx, h * 0.30);
      canvas.rotate(-0.55);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w * 0.16, height: h * 1.4),
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0x80FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(Rect.fromCenter(
              center: Offset.zero, width: w * 0.16, height: h)),
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// HORARIO (reloj de despertador con segundero vivo)
// ---------------------------------------------------------------------------

class Clock3D extends StatelessWidget {
  final double size;
  final bool animar;
  const Clock3D({super.key, this.size = 32, this.animar = true});

  @override
  Widget build(BuildContext context) => _Anim3D(
        size: size,
        animar: animar,
        inverso: false,
        duracion: const Duration(milliseconds: 6000),
        pintar: (t) => _ClockPainter(t),
      );
}

class _ClockPainter extends CustomPainter {
  final double t;
  _ClockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.57;
    final radio = w * 0.33;

    final g = Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.62);
    canvas.drawCircle(
      g.center,
      g.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x4D1CB0F6), const Color(0x001CB0F6)],
        ).createShader(g),
    );

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.95),
          width: radio * 1.8,
          height: radio * 0.30),
      Paint()..color = const Color(0x33000000),
    );

    final campana = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE27A), Color(0xFFE8A100)],
      ).createShader(Offset.zero & size);
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.020
      ..color = const Color(0xFFB8721F);
    for (final o in [Offset(w * 0.18, h * 0.17), Offset(w * 0.82, h * 0.17)]) {
      canvas.drawCircle(o, w * 0.13, campana);
      canvas.drawCircle(o, w * 0.13, borde);
    }

    final pata = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0B74AD);
    canvas.drawLine(
        Offset(w * 0.30, h * 0.84), Offset(w * 0.21, h * 0.95), pata);
    canvas.drawLine(
        Offset(w * 0.70, h * 0.84), Offset(w * 0.79, h * 0.95), pata);

    final disco = Rect.fromCircle(center: Offset(cx, cy), radius: radio);
    canvas.drawCircle(
      Offset(cx, cy),
      radio,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.40),
          radius: 1.0,
          colors: [
            const Color(0xFF7ADCFF),
            const Color(0xFF1CB0F6),
            const Color(0xFF0B74AD),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(disco),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(disco));
    canvas.translate(-w * 0.02, -h * 0.025);
    canvas.drawCircle(
      Offset(cx, cy),
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..color = const Color(0x66FFFFFF),
    );
    canvas.restore();

    final rf = radio * 0.78;
    final cara = Rect.fromCircle(center: Offset(cx, cy), radius: rf);
    canvas.drawCircle(
      Offset(cx, cy),
      rf,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.30, -0.35),
          radius: 1.0,
          colors: [const Color(0xFFFFFFFF), const Color(0xFFEAF5FC)],
        ).createShader(cara),
    );

    for (var i = 0; i < 12; i++) {
      final ang = -math.pi / 2 + i * math.pi / 6;
      final p =
          Offset(cx, cy) + Offset(math.cos(ang), math.sin(ang)) * rf * 0.84;
      final grande = i % 3 == 0;
      canvas.drawCircle(
        p,
        w * (grande ? 0.022 : 0.013),
        Paint()..color = const Color(0xFF9AA7B5),
      );
    }

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx, cy) + const Offset(-0.55, -0.83) * rf * 0.50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4A5568),
    );
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx, cy) + const Offset(0.66, -0.75) * rf * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.038
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4A5568),
    );

    final ang = t * 2 * math.pi - math.pi / 2;
    final dir = Offset(math.cos(ang), math.sin(ang));
    canvas.drawLine(
      Offset(cx, cy) - dir * rf * 0.18,
      Offset(cx, cy) + dir * rf * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.024
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF4B4B),
    );

    canvas.drawCircle(
        Offset(cx, cy), w * 0.026, Paint()..color = const Color(0xFF3C3C3C));
    canvas.drawCircle(
        Offset(cx, cy), w * 0.011, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// MAPA UNIFICADO: icono 3D de una insignia por su nombre de icono Material.
// ---------------------------------------------------------------------------

Widget insignia3D(String icono, {double size = 28, bool animar = true}) {
  switch (icono) {
    case 'cleaning_services':
      return Broom3D(size: size, animar: animar);
    case 'restaurant':
      return Meal3D(size: size, animar: animar);
    case 'inventory_2':
      return Box3D(size: size, animar: animar);
    case 'schedule':
      return Clock3D(size: size, animar: animar);
    case 'local_fire_department':
      return Flame3D(size: size, animar: animar);
    case 'flash_on':
      return Bolt3D(size: size, animar: animar);
    case 'emoji_events':
    default:
      return Trophy3D(size: size, animar: animar);
  }
}
