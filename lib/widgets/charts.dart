import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Número que se anima al cambiar de valor (cuenta ascendente/descendente).
class AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String? suffix;
  final String? prefix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.suffix,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(
          '${prefix ?? ''}${v.round()}${suffix ?? ''}',
          style: style,
        );
      },
    );
  }
}

/// Gráfica de barras animada e interactiva.
///
/// Toca una barra para ver su valor exacto con tooltip.
class BarChart extends StatefulWidget {
  final List<(DateTime, int)> data;
  final Color color;
  final Color trackColor;
  final double barHeight;
  final String Function(DateTime)? labelFor;
  final String Function(int)? valueLabel;

  const BarChart({
    super.key,
    required this.data,
    this.color = AppColors.verde,
    this.trackColor = AppColors.verdeFondo,
    this.barHeight = 90,
    this.labelFor,
    this.valueLabel,
  });

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _seleccionado;

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.data.fold<int>(1, (m, d) => max(m, d.$2));

    // Opción B: ancho fijo por barra + scroll horizontal. Así cada etiqueta
    // tiene espacio suficiente (los números de 2 cifras ya no se parten) y el
    // usuario desliza para ver los 30 días.
    final slot = widget.data.length > 14 ? 30.0 : 44.0;
    final total = widget.data.length * slot;

    Widget barra(int i) => SizedBox(
          width: slot,
          child: GestureDetector(
            onTap: () =>
                setState(() => _seleccionado = _seleccionado == i ? null : i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // tooltip
                SizedBox(
                  height: 24,
                  child: _seleccionado == i
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            widget.valueLabel?.call(widget.data[i].$2) ??
                                '${widget.data[i].$2} pts',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.grisOscuro,
                            ),
                          ),
                        )
                      : null,
                ),
                // barra
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: widget.data[i].$2 / maxVal),
                      duration: Duration(milliseconds: 600 + i * 60),
                      curve: Curves.easeOutBack,
                      builder: (context, v, _) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _barWidth(slot),
                          height: max(4, v * widget.barHeight),
                          decoration: BoxDecoration(
                            color: _seleccionado == i
                                ? widget.color
                                : widget.color.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    Widget etiqueta(int i) => SizedBox(
          width: slot,
          child: Text(
            widget.labelFor?.call(widget.data[i].$1) ??
                widget.data[i].$1.day.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: _seleccionado == i ? FontWeight.w800 : FontWeight.w600,
              color: _seleccionado == i
                  ? AppColors.grisOscuro
                  : AppColors.grisMedio,
            ),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: total,
        child: Column(
          children: [
            SizedBox(
              height: widget.barHeight + 28,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (var i = 0; i < widget.data.length; i++) barra(i)],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [for (var i = 0; i < widget.data.length; i++) etiqueta(i)],
            ),
          ],
        ),
      ),
    );
  }

  double _barWidth(double slot) {
    final ancho = MediaQuery.of(context).size.width;
    return ancho > 700 ? 22 : (slot - 8).clamp(8.0, 22.0);
  }
}

/// Anillo de progreso tipo dona con animación (para porcentajes).
class DonutChart extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final String? centerText;
  final String? centerSub;

  const DonutChart({
    super.key,
    required this.progress,
    this.color = AppColors.verde,
    this.trackColor = AppColors.verdeFondo,
    this.size = 96,
    this.strokeWidth = 12,
    this.centerText,
    this.centerSub,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: strokeWidth,
                  strokeCap: StrokeCap.round,
                  backgroundColor: trackColor,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (centerText != null)
                    Text(
                      centerText!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grisOscuro,
                      ),
                    ),
                  if (centerSub != null)
                    Text(
                      centerSub!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grisMedio,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
