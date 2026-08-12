import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Anillo de progreso circular estilo Duolingo (lección del día).
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    this.color = AppColors.verde,
    this.trackColor = AppColors.linea,
    this.strokeWidth = 10,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: trackColor,
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
  final Color trackColor;
  final int segments;

  const SegmentedProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.amarillo,
    this.trackColor = AppColors.linea,
    this.segments = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < segments; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == segments - 1 ? 0 : 3),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: progress >= (i + 1) / segments
                      ? color
                      : trackColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
