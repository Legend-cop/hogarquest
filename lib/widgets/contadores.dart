import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Cuenta regresiva viva hasta `hasta`: muestra "quedan HH:MM:SS" (o
/// "Xd HH:MM" si falta más de un día). Tiquea cada segundo y se detiene al
/// llegar a cero. Se usa en la ventana del frenesí y en la lluvia.
class ContadorRegresivo extends StatefulWidget {
  final DateTime hasta;
  final bool compacto;
  final Color? color;
  final Color? fondo;

  const ContadorRegresivo({
    super.key,
    required this.hasta,
    this.compacto = false,
    this.color,
    this.fondo,
  });

  @override
  State<ContadorRegresivo> createState() => _ContadorRegresivoState();
}

class _ContadorRegresivoState extends State<ContadorRegresivo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _texto() {
    final restante = widget.hasta.difference(DateTime.now());
    if (restante.isNegative) return '¡Se acabó!';
    final dias = restante.inDays;
    final horas = restante.inHours % 24;
    final minutos = restante.inMinutes % 60;
    final segundos = restante.inSeconds % 60;
    final h = horas.toString().padLeft(2, '0');
    final m = minutos.toString().padLeft(2, '0');
    final s = segundos.toString().padLeft(2, '0');
    if (dias > 0) return '${dias}d $h:$m';
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.coral;
    final fondo = widget.fondo ?? AppColors.coralFondo;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compacto ? 8 : 10,
        vertical: widget.compacto ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: widget.compacto ? 13 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            _texto(),
            style: TextStyle(
              fontSize: widget.compacto ? 11.5 : 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
