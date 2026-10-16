import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Anillo de progreso circular estilo Duolingo (lección del día).
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final Color color;

  /// Pista; si es null se usa un gris tenue según el tema activo.
  final Color? trackColor;
  final double strokeWidth;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    this.color = AppColors.verde,
    this.trackColor,
    this.strokeWidth = 10,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final track =
        trackColor ?? (esOscuro(context) ? Colors.white12 : AppColors.linea);
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: track,
              color: color,
            ),
          ),
          child ?? const SizedBox(),
        ],
      ),
    );
  }
}

/// Barra de progreso segmentada estilo Duolingo (10 segmentos).
class SegmentedProgressBar extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final Color color;

  /// Pista; si es null se usa un gris tenue según el tema activo.
  final Color? trackColor;
  final int segments;

  const SegmentedProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.amarillo,
    this.trackColor,
    this.segments = 10,
  });

  @override
  Widget build(BuildContext context) {
    final track =
        trackColor ?? (esOscuro(context) ? Colors.white12 : AppColors.linea);
    return Row(
      children: [
        for (var i = 0; i < segments; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == segments - 1 ? 0 : 3),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: progress >= (i + 1) / segments ? color : track,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
