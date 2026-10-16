import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tipos de ícono volumétrico infantil (para navegación y cabeceras).
enum Icono3DTipo {
  casita,
  check,
  bandera,
  estrella,
  regalo,
  persona,
  corazon,
  reloj,
  birrete,
  escoba,
  libro,
  apreton,
  checklist,
  etiqueta,
  esponja,
  trapeo,
  platos,
  lavadora,
  peinadora,
  computadora,
  olla,
  planta,
  basura,
  mochila,
  balon,
  llave;

  /// Resuelve un nombre guardado a su tipo; si no existe, estrella.
  static Icono3DTipo porNombre(String nombre) {
    for (final t in Icono3DTipo.values) {
      if (t.name == nombre) return t;
    }
    return Icono3DTipo.estrella;
  }
}

/// Ícono 3D estático y liviano: cuerpo con gradiente de luz, contorno grueso,
/// brillo especular y sombra proyectada. Pensado para tamaños pequeños
/// (navegación, cabeceras) donde un painter animado sería sobre-ingeniería.
class Icono3D extends StatelessWidget {
  final Icono3DTipo tipo;
  final double size;

  const Icono3D({super.key, required this.tipo, this.size = 40});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _Icono3DPainter(tipo)),
        ),
      );
}

class _Icono3DPainter extends CustomPainter {
  final Icono3DTipo tipo;
  _Icono3DPainter(this.tipo);

  double _s = 1;
  bool _sombra = false;

  static const _ink = Color(0xFF1F2937);

  @override
  void paint(Canvas canvas, Size size) {
    _s = size.width / 100;

    // Sombra proyectada (misma silueta en negro borroso).
    canvas.save();
    canvas.translate(4 * _s, 7 * _s);
    _sombra = true;
    _dibujar(canvas);
    _sombra = false;
    canvas.restore();

    _dibujar(canvas);
  }

  Paint _relleno(Color color) {
    if (_sombra) {
      return Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * _s);
    }
    final claro = Color.lerp(color, Colors.white, 0.34)!;
    final oscuro = Color.lerp(color, const Color(0xFF000000), 0.24)!;
    return Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [claro, color, oscuro],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, 100 * _s, 100 * _s));
  }

  Paint _contorno([double ancho = 5]) {
    if (_sombra) {
      return Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ancho * _s
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * _s);
    }
    return Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = ancho * _s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
  }

  /// Brillo especular arriba-izquierda (no se dibuja en modo sombra).
  void _brillo(Canvas canvas, Rect rect) {
    if (_sombra) return;
    canvas.drawOval(
      rect,
      Paint()..color = const Color(0x59FFFFFF),
    );
  }

  void _dibujar(Canvas canvas) {
    switch (tipo) {
      case Icono3DTipo.casita:
        _casita(canvas);
      case Icono3DTipo.check:
        _check(canvas);
      case Icono3DTipo.bandera:
        _bandera(canvas);
      case Icono3DTipo.estrella:
        _estrella(canvas);
      case Icono3DTipo.regalo:
        _regalo(canvas);
      case Icono3DTipo.persona:
        _persona(canvas);
      case Icono3DTipo.corazon:
        _corazon(canvas);
      case Icono3DTipo.reloj:
        _reloj(canvas);
      case Icono3DTipo.birrete:
        _birrete(canvas);
      case Icono3DTipo.escoba:
        _escoba(canvas);
      case Icono3DTipo.libro:
        _libro(canvas);
      case Icono3DTipo.apreton:
        _apreton(canvas);
      case Icono3DTipo.checklist:
        _checklist(canvas);
      case Icono3DTipo.etiqueta:
        _etiqueta(canvas);
      case Icono3DTipo.esponja:
        _esponja(canvas);
      case Icono3DTipo.trapeo:
        _trapeo(canvas);
      case Icono3DTipo.platos:
        _platos(canvas);
      case Icono3DTipo.lavadora:
        _lavadora(canvas);
      case Icono3DTipo.peinadora:
        _peinadora(canvas);
      case Icono3DTipo.computadora:
        _computadora(canvas);
      case Icono3DTipo.olla:
        _olla(canvas);
      case Icono3DTipo.planta:
        _planta(canvas);
      case Icono3DTipo.basura:
        _basura(canvas);
      case Icono3DTipo.mochila:
        _mochila(canvas);
      case Icono3DTipo.balon:
        _balon(canvas);
      case Icono3DTipo.llave:
        _llave(canvas);
    }
  }

  void _casita(Canvas canvas) {
    final techo = Path()
      ..moveTo(50 * _s, 8 * _s)
      ..lineTo(95 * _s, 50 * _s)
      ..lineTo(5 * _s, 50 * _s)
      ..close();
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(20 * _s, 46 * _s, 60 * _s, 46 * _s),
      Radius.circular(9 * _s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFFFFFFFF)));
    canvas.drawPath(techo, _relleno(const Color(0xFFFF7A66)));
    canvas.drawPath(techo, _contorno());
    canvas.drawRRect(cuerpo, _contorno());
    final puerta = RRect.fromRectAndRadius(
      Rect.fromLTWH(41 * _s, 64 * _s, 18 * _s, 28 * _s),
      Radius.circular(7 * _s),
    );
    canvas.drawRRect(puerta, _relleno(const Color(0xFF10B981)));
    canvas.drawRRect(puerta, _contorno(4));
    _brillo(
      canvas,
      Rect.fromLTWH(20 * _s, 18 * _s, 26 * _s, 14 * _s),
    );
  }

  void _check(Canvas canvas) {
    final c = Offset(50 * _s, 50 * _s);
    canvas.drawCircle(c, 44 * _s, _relleno(const Color(0xFF10B981)));
    canvas.drawCircle(c, 44 * _s, _contorno());
    final paloma = Path()
      ..moveTo(28 * _s, 52 * _s)
      ..lineTo(44 * _s, 68 * _s)
      ..lineTo(73 * _s, 32 * _s);
    canvas.drawPath(
      paloma,
      _sombra
          ? _relleno(Colors.white)
          : (Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11 * _s
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round),
    );
    _brillo(
      canvas,
      Rect.fromLTWH(22 * _s, 16 * _s, 30 * _s, 15 * _s),
    );
  }

  void _bandera(Canvas canvas) {
    final asta = Path()
      ..moveTo(26 * _s, 8 * _s)
      ..lineTo(26 * _s, 88 * _s);
    canvas.drawPath(
      asta,
      _relleno(const Color(0xFF64748B)),
    );
    if (!_sombra) {
      canvas.drawPath(
        asta,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * _s
          ..strokeCap = StrokeCap.round,
      );
    }
    final bandera = Path()
      ..moveTo(30 * _s, 12 * _s)
      ..lineTo(88 * _s, 20 * _s)
      ..lineTo(72 * _s, 33 * _s)
      ..lineTo(88 * _s, 46 * _s)
      ..lineTo(30 * _s, 54 * _s)
      ..close();
    canvas.drawPath(bandera, _relleno(const Color(0xFFFF7A66)));
    canvas.drawPath(bandera, _contorno());
    canvas.drawOval(
      Rect.fromCenter(center: Offset(26 * _s, 90 * _s), width: 34 * _s, height: 12 * _s),
      _relleno(const Color(0xFF64748B)),
    );
    if (!_sombra) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(26 * _s, 90 * _s), width: 34 * _s, height: 12 * _s),
        _contorno(4),
      );
    }
    _brillo(
      canvas,
      Rect.fromLTWH(36 * _s, 18 * _s, 22 * _s, 10 * _s),
    );
  }

  void _estrella(Canvas canvas) {
    final pts = <Offset>[];
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 46 * _s : 20 * _s;
      final a = -math.pi / 2 + i * math.pi / 5;
      pts.add(
        Offset(50 * _s + math.cos(a) * r, 52 * _s + math.sin(a) * r),
      );
    }
    final path = Path()..addPolygon(pts, true);
    canvas.drawPath(path, _relleno(const Color(0xFFFBBF24)));
    canvas.drawPath(path, _contorno());
    _brillo(
      canvas,
      Rect.fromLTWH(30 * _s, 22 * _s, 22 * _s, 12 * _s),
    );
  }

  void _regalo(Canvas canvas) {
    final caja = RRect.fromRectAndRadius(
      Rect.fromLTWH(14 * _s, 46 * _s, 72 * _s, 42 * _s),
      Radius.circular(8 * _s),
    );
    final tapa = RRect.fromRectAndRadius(
      Rect.fromLTWH(8 * _s, 30 * _s, 84 * _s, 20 * _s),
      Radius.circular(7 * _s),
    );
    canvas.drawRRect(caja, _relleno(const Color(0xFFFBBF24)));
    canvas.drawRRect(tapa, _relleno(const Color(0xFFF59E0B)));
    // Cinta vertical.
    canvas.drawRect(
      Rect.fromLTWH(42 * _s, 30 * _s, 16 * _s, 58 * _s),
      _relleno(const Color(0xFFF472B6)),
    );
    canvas.drawRRect(caja, _contorno());
    canvas.drawRRect(tapa, _contorno());
    if (!_sombra) {
      canvas.drawRect(
        Rect.fromLTWH(42 * _s, 30 * _s, 16 * _s, 58 * _s),
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * _s,
      );
      // Lazo: dos aros.
      for (final dx in const [-12.0, 12.0]) {
        canvas.drawCircle(
          Offset((50 + dx) * _s, 24 * _s),
          11 * _s,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7 * _s,
        );
        canvas.drawCircle(
          Offset((50 + dx) * _s, 24 * _s),
          11 * _s,
          _relleno(const Color(0xFFF472B6)),
        );
        canvas.drawCircle(
          Offset((50 + dx) * _s, 24 * _s),
          11 * _s,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * _s,
        );
      }
    }
    _brillo(
      canvas,
      Rect.fromLTWH(20 * _s, 52 * _s, 24 * _s, 12 * _s),
    );
  }

  void _persona(Canvas canvas) {
    final cabeza = Offset(50 * _s, 30 * _s);
    final torso = RRect.fromRectAndRadius(
      Rect.fromLTWH(18 * _s, 56 * _s, 64 * _s, 38 * _s),
      Radius.circular(19 * _s),
    );
    canvas.drawRRect(torso, _relleno(const Color(0xFF60A5FA)));
    canvas.drawCircle(cabeza, 21 * _s, _relleno(const Color(0xFF60A5FA)));
    canvas.drawRRect(torso, _contorno());
    canvas.drawCircle(cabeza, 21 * _s, _contorno());
    _brillo(
      canvas,
      Rect.fromCenter(
          center: cabeza + Offset(-6 * _s, -7 * _s),
          width: 14 * _s,
          height: 9 * _s),
    );
  }

  void _corazon(Canvas canvas) {
    final path = Path()
      ..moveTo(50 * _s, 88 * _s)
      ..cubicTo(8 * _s, 60 * _s, 14 * _s, 20 * _s, 50 * _s, 38 * _s)
      ..cubicTo(86 * _s, 20 * _s, 92 * _s, 60 * _s, 50 * _s, 88 * _s)
      ..close();
    canvas.drawPath(path, _relleno(const Color(0xFFF472B6)));
    canvas.drawPath(path, _contorno());
    _brillo(
      canvas,
      Rect.fromLTWH(24 * _s, 26 * _s, 22 * _s, 13 * _s),
    );
  }

  void _reloj(Canvas canvas) {
    final c = Offset(50 * _s, 54 * _s);
    final corona = RRect.fromRectAndRadius(
      Rect.fromLTWH(42 * _s, 4 * _s, 16 * _s, 14 * _s),
      Radius.circular(4 * _s),
    );
    canvas.drawRRect(corona, _relleno(const Color(0xFF2563EB)));
    canvas.drawCircle(c, 40 * _s, _relleno(const Color(0xFF60A5FA)));
    canvas.drawCircle(c, 40 * _s, _contorno());
    canvas.drawRRect(corona, _contorno(4));
    if (!_sombra) {
      final manos = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx, c.dy - 22 * _s)
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + 15 * _s, c.dy + 7 * _s);
      canvas.drawPath(
        manos,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * _s
          ..strokeCap = StrokeCap.round,
      );
    }
    _brillo(
      canvas,
      Rect.fromLTWH(26 * _s, 26 * _s, 24 * _s, 13 * _s),
    );
  }

  void _birrete(Canvas canvas) {
    final banda = Path()
      ..moveTo(26 * _s, 40 * _s)
      ..lineTo(74 * _s, 40 * _s)
      ..lineTo(68 * _s, 70 * _s)
      ..lineTo(58 * _s, 78 * _s)
      ..lineTo(42 * _s, 78 * _s)
      ..lineTo(32 * _s, 70 * _s)
      ..close();
    canvas.drawPath(banda, _relleno(const Color(0xFF60A5FA)));
    canvas.drawPath(banda, _contorno());
    final placa = Path()
      ..moveTo(50 * _s, 12 * _s)
      ..lineTo(94 * _s, 34 * _s)
      ..lineTo(50 * _s, 56 * _s)
      ..lineTo(6 * _s, 34 * _s)
      ..close();
    canvas.drawPath(placa, _relleno(const Color(0xFF3B82F6)));
    canvas.drawPath(placa, _contorno());
    if (!_sombra) {
      final cordon = Path()
        ..moveTo(50 * _s, 20 * _s)
        ..lineTo(76 * _s, 34 * _s)
        ..quadraticBezierTo(86 * _s, 44 * _s, 80 * _s, 64 * _s);
      canvas.drawPath(
        cordon,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * _s
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(80 * _s, 68 * _s),
        7 * _s,
        _relleno(const Color(0xFFFBBF24)),
      );
      canvas.drawCircle(Offset(80 * _s, 68 * _s), 7 * _s, _contorno(4));
    }
    _brillo(canvas, Rect.fromLTWH(24 * _s, 24 * _s, 22 * _s, 10 * _s));
  }

  void _escoba(Canvas canvas) {
    final mango = Path()
      ..moveTo(72 * _s, 8 * _s)
      ..lineTo(85 * _s, 17 * _s)
      ..lineTo(46 * _s, 58 * _s)
      ..lineTo(33 * _s, 49 * _s)
      ..close();
    canvas.drawPath(mango, _relleno(const Color(0xFFB45309)));
    canvas.drawPath(mango, _contorno(4));
    final cerdas = Path()
      ..moveTo(30 * _s, 44 * _s)
      ..lineTo(50 * _s, 64 * _s)
      ..lineTo(30 * _s, 92 * _s)
      ..lineTo(6 * _s, 70 * _s)
      ..close();
    canvas.drawPath(cerdas, _relleno(const Color(0xFFFBBF24)));
    canvas.drawPath(cerdas, _contorno());
    if (!_sombra) {
      for (final l in const [
        [42.0, 58.0, 34.0, 84.0],
        [34.0, 52.0, 18.0, 74.0],
        [46.0, 66.0, 40.0, 88.0],
      ]) {
        canvas.drawLine(
          Offset(l[0] * _s, l[1] * _s),
          Offset(l[2] * _s, l[3] * _s),
          Paint()
            ..color = const Color(0xFFB45309)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _brillo(canvas, Rect.fromLTWH(14 * _s, 52 * _s, 20 * _s, 12 * _s));
  }

  void _libro(Canvas canvas) {
    final portada = RRect.fromRectAndRadius(
      Rect.fromLTWH(8 * _s, 22 * _s, 84 * _s, 62 * _s),
      Radius.circular(9 * _s),
    );
    canvas.drawRRect(portada, _relleno(const Color(0xFF8B7CF6)));
    canvas.drawRRect(portada, _contorno());
    final izq = Path()
      ..moveTo(50 * _s, 32 * _s)
      ..lineTo(16 * _s, 30 * _s)
      ..lineTo(16 * _s, 74 * _s)
      ..lineTo(50 * _s, 78 * _s)
      ..close();
    final der = Path()
      ..moveTo(50 * _s, 32 * _s)
      ..lineTo(84 * _s, 30 * _s)
      ..lineTo(84 * _s, 74 * _s)
      ..lineTo(50 * _s, 78 * _s)
      ..close();
    canvas.drawPath(izq, _relleno(const Color(0xFFFFFFFF)));
    canvas.drawPath(der, _relleno(const Color(0xFFF8F7FF)));
    canvas.drawPath(izq, _contorno(4));
    canvas.drawPath(der, _contorno(4));
    if (!_sombra) {
      for (final y in const [44.0, 56.0, 68.0]) {
        canvas.drawLine(
          Offset(23 * _s, y * _s),
          Offset(43 * _s, y * _s),
          Paint()
            ..color = const Color(0xFFC4B5FD)
            ..strokeWidth = 4 * _s
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(57 * _s, y * _s),
          Offset(77 * _s, y * _s),
          Paint()
            ..color = const Color(0xFFC4B5FD)
            ..strokeWidth = 4 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(
        Offset(50 * _s, 32 * _s),
        Offset(50 * _s, 78 * _s),
        Paint()
          ..color = _ink
          ..strokeWidth = 5 * _s
          ..strokeCap = StrokeCap.round,
      );
    }
    _brillo(canvas, Rect.fromLTWH(14 * _s, 28 * _s, 24 * _s, 12 * _s));
  }

  void _apreton(Canvas canvas) {
    final brazoIzq = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * _s, 34 * _s, 46 * _s, 30 * _s),
      Radius.circular(15 * _s),
    );
    final brazoDer = RRect.fromRectAndRadius(
      Rect.fromLTWH(50 * _s, 38 * _s, 46 * _s, 30 * _s),
      Radius.circular(15 * _s),
    );
    final enlace = RRect.fromRectAndRadius(
      Rect.fromLTWH(34 * _s, 28 * _s, 32 * _s, 42 * _s),
      Radius.circular(14 * _s),
    );
    canvas.drawRRect(brazoIzq, _relleno(const Color(0xFF60A5FA)));
    canvas.drawRRect(brazoDer, _relleno(const Color(0xFF10B981)));
    canvas.drawRRect(enlace, _relleno(const Color(0xFF3B82F6)));
    canvas.drawRRect(brazoIzq, _contorno());
    canvas.drawRRect(brazoDer, _contorno());
    canvas.drawRRect(enlace, _contorno());
    _brillo(canvas, Rect.fromLTWH(10 * _s, 40 * _s, 20 * _s, 10 * _s));
  }

  void _checklist(Canvas canvas) {
    final tablero = RRect.fromRectAndRadius(
      Rect.fromLTWH(16 * _s, 18 * _s, 68 * _s, 74 * _s),
      Radius.circular(10 * _s),
    );
    canvas.drawRRect(tablero, _relleno(const Color(0xFFFFFFFF)));
    canvas.drawRRect(tablero, _contorno());
    final clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(38 * _s, 7 * _s, 24 * _s, 18 * _s),
      Radius.circular(6 * _s),
    );
    canvas.drawRRect(clip, _relleno(const Color(0xFF60A5FA)));
    canvas.drawRRect(clip, _contorno(4));
    if (!_sombra) {
      final caja = RRect.fromRectAndRadius(
        Rect.fromLTWH(26 * _s, 38 * _s, 16 * _s, 16 * _s),
        Radius.circular(4 * _s),
      );
      canvas.drawRRect(caja, _relleno(const Color(0xFF10B981)));
      canvas.drawRRect(caja, _contorno(4));
      final paloma = Path()
        ..moveTo(29 * _s, 46 * _s)
        ..lineTo(35 * _s, 52 * _s)
        ..lineTo(43 * _s, 40 * _s);
      canvas.drawPath(
        paloma,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * _s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (final y in const [46.0, 70.0]) {
        canvas.drawLine(
          Offset((y == 46.0 ? 50.0 : 26.0) * _s, y * _s),
          Offset(74 * _s, y * _s),
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 5 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _brillo(canvas, Rect.fromLTWH(22 * _s, 26 * _s, 24 * _s, 12 * _s));
  }

  void _etiqueta(Canvas canvas) {
    final path = Path()
      ..moveTo(8 * _s, 50 * _s)
      ..lineTo(40 * _s, 16 * _s)
      ..lineTo(90 * _s, 16 * _s)
      ..lineTo(90 * _s, 84 * _s)
      ..lineTo(40 * _s, 84 * _s)
      ..close();
    canvas.drawPath(path, _relleno(const Color(0xFFF472B6)));
    canvas.drawPath(path, _contorno());
    canvas.drawCircle(
      Offset(56 * _s, 50 * _s),
      9 * _s,
      _relleno(const Color(0xFFFFFFFF)),
    );
    canvas.drawCircle(Offset(56 * _s, 50 * _s), 9 * _s, _contorno(4));
    _brillo(canvas, Rect.fromLTWH(48 * _s, 24 * _s, 26 * _s, 12 * _s));
  }

  void _esponja(Canvas canvas) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(10 * _s, 24 * _s, 80 * _s, 56 * _s),
      Radius.circular(18 * _s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFFFBBF24)));
    final topo = RRect.fromRectAndRadius(
      Rect.fromLTWH(10 * _s, 24 * _s, 80 * _s, 20 * _s),
      Radius.circular(18 * _s),
    );
    canvas.drawRRect(topo, _relleno(const Color(0xFF10B981)));
    canvas.drawRRect(cuerpo, _contorno());
    if (!_sombra) {
      for (final o in const [
        [30.0, 56.0, 6.0],
        [52.0, 64.0, 5.0],
        [70.0, 54.0, 6.0],
        [40.0, 70.0, 4.0],
      ]) {
        canvas.drawCircle(
          Offset(o[0] * _s, o[1] * _s),
          o[2] * _s,
          Paint()..color = const Color(0xFFB45309).withValues(alpha: 0.45),
        );
      }
    }
    _brillo(canvas, Rect.fromLTWH(20 * _s, 30 * _s, 22 * _s, 10 * _s));
  }

  void _trapeo(Canvas canvas) {
    final mango = Path()
      ..moveTo(70 * _s, 10 * _s)
      ..lineTo(82 * _s, 20 * _s)
      ..lineTo(44 * _s, 58 * _s)
      ..lineTo(32 * _s, 48 * _s)
      ..close();
    canvas.drawPath(mango, _relleno(const Color(0xFF64748B)));
    canvas.drawPath(mango, _contorno(4));
    final cabeza = RRect.fromRectAndRadius(
      Rect.fromLTWH(14 * _s, 52 * _s, 44 * _s, 36 * _s),
      Radius.circular(16 * _s),
    );
    canvas.drawRRect(cabeza, _relleno(const Color(0xFF60A5FA)));
    canvas.drawRRect(cabeza, _contorno());
    if (!_sombra) {
      for (final x in const [24.0, 36.0, 48.0]) {
        canvas.drawLine(
          Offset(x * _s, 60 * _s),
          Offset((x - 2) * _s, 82 * _s),
          Paint()
            ..color = const Color(0xFF1E3A8A)
            ..strokeWidth = 4 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _brillo(canvas, Rect.fromLTWH(20 * _s, 56 * _s, 18 * _s, 10 * _s));
  }

  void _platos(Canvas canvas) {
    final plato = RRect.fromRectAndRadius(
      Rect.fromLTWH(8 * _s, 58 * _s, 84 * _s, 22 * _s),
      Radius.circular(11 * _s),
    );
    canvas.drawRRect(plato, _relleno(const Color(0xFF60A5FA)));
    canvas.drawRRect(plato, _contorno());
    final plato2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(16 * _s, 42 * _s, 68 * _s, 20 * _s),
      Radius.circular(10 * _s),
    );
    canvas.drawRRect(plato2, _relleno(const Color(0xFFFFFFFF)));
    canvas.drawRRect(plato2, _contorno());
    final cuenco = Path()
      ..moveTo(30 * _s, 18 * _s)
      ..lineTo(70 * _s, 18 * _s)
      ..quadraticBezierTo(70 * _s, 40 * _s, 50 * _s, 40 * _s)
      ..quadraticBezierTo(30 * _s, 40 * _s, 30 * _s, 18 * _s)
      ..close();
    canvas.drawPath(cuenco, _relleno(const Color(0xFFF8F7FF)));
    canvas.drawPath(cuenco, _contorno());
    _brillo(canvas, Rect.fromLTWH(34 * _s, 22 * _s, 18 * _s, 8 * _s));
  }

  void _lavadora(Canvas canvas) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(16 * _s, 10 * _s, 68 * _s, 80 * _s),
      Radius.circular(12 * _s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF60A5FA)));
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(16 * _s, 10 * _s, 68 * _s, 18 * _s),
      Radius.circular(12 * _s),
    );
    canvas.drawRRect(panel, _relleno(const Color(0xFF2563EB)));
    canvas.drawCircle(
      Offset(50 * _s, 60 * _s),
      22 * _s,
      _relleno(const Color(0xFFE0F2FE)),
    );
    canvas.drawRRect(cuerpo, _contorno());
    canvas.drawRRect(panel, _contorno(4));
    canvas.drawCircle(Offset(50 * _s, 60 * _s), 22 * _s, _contorno());
    if (!_sombra) {
      canvas.drawCircle(
        Offset(50 * _s, 60 * _s),
        12 * _s,
        _relleno(const Color(0xFF38BDF8)),
      );
    }
    _brillo(canvas, Rect.fromLTWH(22 * _s, 14 * _s, 16 * _s, 8 * _s));
  }

  void _peinadora(Canvas canvas) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(20 * _s, 24 * _s, 60 * _s, 34 * _s),
      Radius.circular(17 * _s),
    );
    final boquilla = RRect.fromRectAndRadius(
      Rect.fromLTWH(76 * _s, 30 * _s, 14 * _s, 22 * _s),
      Radius.circular(6 * _s),
    );
    final mango = Path()
      ..moveTo(30 * _s, 54 * _s)
      ..lineTo(46 * _s, 54 * _s)
      ..lineTo(40 * _s, 88 * _s)
      ..lineTo(22 * _s, 88 * _s)
      ..close();
    canvas.drawPath(mango, _relleno(const Color(0xFFBE185D)));
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFFF472B6)));
    canvas.drawRRect(boquilla, _relleno(const Color(0xFFDB2777)));
    canvas.drawPath(mango, _contorno());
    canvas.drawRRect(cuerpo, _contorno());
    canvas.drawRRect(boquilla, _contorno(4));
    _brillo(canvas, Rect.fromLTWH(28 * _s, 30 * _s, 22 * _s, 10 * _s));
  }

  void _computadora(Canvas canvas) {
    final pantalla = RRect.fromRectAndRadius(
      Rect.fromLTWH(14 * _s, 20 * _s, 72 * _s, 48 * _s),
      Radius.circular(8 * _s),
    );
    canvas.drawRRect(pantalla, _relleno(const Color(0xFF334155)));
    final contenido = RRect.fromRectAndRadius(
      Rect.fromLTWH(20 * _s, 26 * _s, 60 * _s, 36 * _s),
      Radius.circular(4 * _s),
    );
    canvas.drawRRect(contenido, _relleno(const Color(0xFF38BDF8)));
    canvas.drawRRect(pantalla, _contorno());
    canvas.drawRRect(contenido, _contorno(3));
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(6 * _s, 68 * _s, 88 * _s, 14 * _s),
      Radius.circular(7 * _s),
    );
    canvas.drawRRect(base, _relleno(const Color(0xFF64748B)));
    canvas.drawRRect(base, _contorno());
    if (!_sombra) {
      final pad = RRect.fromRectAndRadius(
        Rect.fromLTWH(38 * _s, 72 * _s, 24 * _s, 6 * _s),
        Radius.circular(3 * _s),
      );
      canvas.drawRRect(pad, _relleno(const Color(0xFF1E293B)));
    }
    _brillo(canvas, Rect.fromLTWH(24 * _s, 30 * _s, 20 * _s, 10 * _s));
  }

  void _olla(Canvas canvas) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(18 * _s, 40 * _s, 64 * _s, 46 * _s),
      Radius.circular(10 * _s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF64748B)));
    for (final x in const [6.0, 78.0]) {
      final asa = RRect.fromRectAndRadius(
        Rect.fromLTWH(x * _s, 52 * _s, 16 * _s, 16 * _s),
        Radius.circular(8 * _s),
      );
      canvas.drawRRect(asa, _relleno(const Color(0xFF475569)));
      canvas.drawRRect(asa, _contorno(4));
    }
    final tapa = RRect.fromRectAndRadius(
      Rect.fromLTWH(14 * _s, 30 * _s, 72 * _s, 14 * _s),
      Radius.circular(7 * _s),
    );
    canvas.drawRRect(tapa, _relleno(const Color(0xFF94A3B8)));
    canvas.drawRRect(cuerpo, _contorno());
    canvas.drawRRect(tapa, _contorno());
    canvas.drawCircle(
      Offset(50 * _s, 26 * _s),
      6 * _s,
      _relleno(const Color(0xFF334155)),
    );
    if (!_sombra) {
      for (final x in const [38.0, 50.0, 62.0]) {
        final vapor = Path()
          ..moveTo(x * _s, 22 * _s)
          ..quadraticBezierTo((x + 5) * _s, 14 * _s, x * _s, 8 * _s);
        canvas.drawPath(
          vapor,
          Paint()
            ..color = const Color(0xFFCBD5E1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _brillo(canvas, Rect.fromLTWH(24 * _s, 46 * _s, 18 * _s, 10 * _s));
  }

  void _planta(Canvas canvas) {
    final maceta = Path()
      ..moveTo(26 * _s, 60 * _s)
      ..lineTo(74 * _s, 60 * _s)
      ..lineTo(66 * _s, 92 * _s)
      ..lineTo(34 * _s, 92 * _s)
      ..close();
    canvas.drawPath(maceta, _relleno(const Color(0xFFD97706)));
    final borde = RRect.fromRectAndRadius(
      Rect.fromLTWH(22 * _s, 52 * _s, 56 * _s, 12 * _s),
      Radius.circular(5 * _s),
    );
    canvas.drawPath(maceta, _contorno());
    canvas.drawRRect(borde, _relleno(const Color(0xFFB45309)));
    canvas.drawRRect(borde, _contorno(4));
    if (!_sombra) {
      final tallo = Path()
        ..moveTo(50 * _s, 54 * _s)
        ..lineTo(50 * _s, 24 * _s);
      canvas.drawPath(
        tallo,
        Paint()
          ..color = const Color(0xFF15803D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * _s
          ..strokeCap = StrokeCap.round,
      );
      final hojaIzq = Path()
        ..moveTo(50 * _s, 34 * _s)
        ..quadraticBezierTo(24 * _s, 20 * _s, 22 * _s, 36 * _s)
        ..quadraticBezierTo(34 * _s, 46 * _s, 50 * _s, 34 * _s)
        ..close();
      final hojaDer = Path()
        ..moveTo(50 * _s, 28 * _s)
        ..quadraticBezierTo(76 * _s, 14 * _s, 78 * _s, 30 * _s)
        ..quadraticBezierTo(66 * _s, 40 * _s, 50 * _s, 28 * _s)
        ..close();
      canvas.drawPath(hojaIzq, _relleno(const Color(0xFF22C55E)));
      canvas.drawPath(hojaDer, _relleno(const Color(0xFF16A34A)));
      canvas.drawPath(hojaIzq, _contorno(4));
      canvas.drawPath(hojaDer, _contorno(4));
    }
    _brillo(canvas, Rect.fromLTWH(30 * _s, 64 * _s, 16 * _s, 10 * _s));
  }

  void _basura(Canvas canvas) {
    final cuerpo = Path()
      ..moveTo(24 * _s, 30 * _s)
      ..lineTo(76 * _s, 30 * _s)
      ..lineTo(70 * _s, 90 * _s)
      ..lineTo(30 * _s, 90 * _s)
      ..close();
    canvas.drawPath(cuerpo, _relleno(const Color(0xFF64748B)));
    final tapa = RRect.fromRectAndRadius(
      Rect.fromLTWH(16 * _s, 18 * _s, 68 * _s, 12 * _s),
      Radius.circular(6 * _s),
    );
    final manija = RRect.fromRectAndRadius(
      Rect.fromLTWH(40 * _s, 9 * _s, 20 * _s, 11 * _s),
      Radius.circular(5 * _s),
    );
    canvas.drawPath(cuerpo, _contorno());
    canvas.drawRRect(tapa, _relleno(const Color(0xFF475569)));
    canvas.drawRRect(manija, _relleno(const Color(0xFF334155)));
    canvas.drawRRect(tapa, _contorno());
    canvas.drawRRect(manija, _contorno(4));
    if (!_sombra) {
      for (final x in const [40.0, 50.0, 60.0]) {
        canvas.drawLine(
          Offset(x * _s, 42 * _s),
          Offset(x * _s, 78 * _s),
          Paint()
            ..color = const Color(0xFF334155)
            ..strokeWidth = 4 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _brillo(canvas, Rect.fromLTWH(30 * _s, 36 * _s, 16 * _s, 10 * _s));
  }

  void _mochila(Canvas canvas) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(18 * _s, 26 * _s, 64 * _s, 64 * _s),
      Radius.circular(18 * _s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF10B981)));
    final tapeta = RRect.fromRectAndRadius(
      Rect.fromLTWH(18 * _s, 26 * _s, 64 * _s, 28 * _s),
      Radius.circular(18 * _s),
    );
    final bolsillo = RRect.fromRectAndRadius(
      Rect.fromLTWH(32 * _s, 60 * _s, 36 * _s, 22 * _s),
      Radius.circular(8 * _s),
    );
    canvas.drawRRect(cuerpo, _contorno());
    canvas.drawRRect(tapeta, _relleno(const Color(0xFF059669)));
    canvas.drawRRect(bolsillo, _relleno(const Color(0xFF34D399)));
    canvas.drawRRect(tapeta, _contorno(4));
    canvas.drawRRect(bolsillo, _contorno(4));
    if (!_sombra) {
      final correa = Path()
        ..moveTo(40 * _s, 26 * _s)
        ..quadraticBezierTo(50 * _s, 10 * _s, 60 * _s, 26 * _s);
      canvas.drawPath(
        correa,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * _s
          ..strokeCap = StrokeCap.round,
      );
    }
    _brillo(canvas, Rect.fromLTWH(26 * _s, 32 * _s, 18 * _s, 10 * _s));
  }

  void _balon(Canvas canvas) {
    final c = Offset(50 * _s, 50 * _s);
    canvas.drawCircle(c, 42 * _s, _relleno(const Color(0xFFFFFFFF)));
    canvas.drawCircle(c, 42 * _s, _contorno());
    if (!_sombra) {
      final pent = Path();
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        final p = Offset(
          c.dx + 15 * _s * math.cos(ang),
          c.dy + 15 * _s * math.sin(ang),
        );
        if (i == 0) {
          pent.moveTo(p.dx, p.dy);
        } else {
          pent.lineTo(p.dx, p.dy);
        }
      }
      pent.close();
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        canvas.drawLine(
          Offset(
            c.dx + 15 * _s * math.cos(ang),
            c.dy + 15 * _s * math.sin(ang),
          ),
          Offset(
            c.dx + 40 * _s * math.cos(ang),
            c.dy + 40 * _s * math.sin(ang),
          ),
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * _s
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawPath(pent, _relleno(const Color(0xFF1F2937)));
      canvas.drawPath(pent, _contorno(3));
    }
    _brillo(canvas, Rect.fromLTWH(22 * _s, 22 * _s, 22 * _s, 12 * _s));
  }

  void _llave(Canvas canvas) {
    canvas.drawCircle(
      Offset(32 * _s, 32 * _s),
      20 * _s,
      _relleno(const Color(0xFFFBBF24)),
    );
    final shaft = Path()
      ..moveTo(44 * _s, 44 * _s)
      ..lineTo(82 * _s, 82 * _s)
      ..lineTo(74 * _s, 90 * _s)
      ..lineTo(36 * _s, 52 * _s)
      ..close();
    final diente = Path()
      ..moveTo(66 * _s, 70 * _s)
      ..lineTo(80 * _s, 62 * _s)
      ..lineTo(86 * _s, 70 * _s)
      ..lineTo(72 * _s, 78 * _s)
      ..close();
    canvas.drawCircle(Offset(32 * _s, 32 * _s), 20 * _s, _contorno());
    canvas.drawPath(shaft, _relleno(const Color(0xFFF59E0B)));
    canvas.drawPath(shaft, _contorno());
    canvas.drawPath(diente, _relleno(const Color(0xFFD97706)));
    canvas.drawPath(diente, _contorno(4));
    canvas.drawCircle(
      Offset(32 * _s, 32 * _s),
      8 * _s,
      _relleno(const Color(0xFFFFFFFF)),
    );
    canvas.drawCircle(Offset(32 * _s, 32 * _s), 8 * _s, _contorno(3));
    _brillo(canvas, Rect.fromLTWH(20 * _s, 20 * _s, 16 * _s, 10 * _s));
  }

  @override
  bool shouldRepaint(covariant _Icono3DPainter oldDelegate) =>
      oldDelegate.tipo != tipo;
}
