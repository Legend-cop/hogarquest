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

  /// Índice de la barra que representa el día de hoy (se resalta y se etiqueta
  /// como "Hoy"). Si es null, ninguna barra se resalta.
  final int? highlightIndex;

  const BarChart({
    super.key,
    required this.data,
    this.color = AppColors.verde,
    this.trackColor = AppColors.verdeFondo,
    this.barHeight = 90,
    this.labelFor,
    this.valueLabel,
    this.highlightIndex,
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
                                : (i == widget.highlightIndex
                                    ? widget.color.withValues(alpha: 0.9)
                                    : widget.color.withValues(alpha: 0.5)),
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
            i == widget.highlightIndex
                ? 'Hoy'
                : (widget.labelFor?.call(widget.data[i].$1) ??
                    widget.data[i].$1.day.toString()),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: i == widget.highlightIndex
                  ? FontWeight.w900
                  : (_seleccionado == i ? FontWeight.w800 : FontWeight.w600),
              color: i == widget.highlightIndex
                  ? AppColors.verde
                  : (_seleccionado == i
                      ? AppColors.grisOscuro
                      : AppColors.grisMedio),
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

/// Mapa de calor tipo "racha" (estilo GitHub) que muestra la actividad
/// (puntos) día a día durante las últimas [semanas] semanas.
class StreakHeatmap extends StatelessWidget {
  final List<(DateTime, int)> data;
  final int semanas;
  final Color color;
  final bool mostrarLeyenda;
  final bool mostrarDias;

  const StreakHeatmap({
    super.key,
    required this.data,
    this.semanas = 12,
    this.color = AppColors.verde,
    this.mostrarLeyenda = true,
    this.mostrarDias = true,
  });

  static int _nivel(int p) {
    if (p <= 0) return 0;
    if (p < 5) return 1;
    if (p < 15) return 2;
    if (p < 30) return 3;
    return 4;
  }

  Color _colorNivel(int n) {
    if (n == 0) return Colors.grey.withOpacity(0.18);
    return color.withOpacity(0.3 + n * 0.18);
  }

  @override
  Widget build(BuildContext context) {
    final map = <DateTime, int>{};
    for (final d in data) {
      map[DateTime(d.$1.year, d.$1.month, d.$1.day)] = d.$2;
    }

    final hoy = DateTime.now();
    final hoyD = DateTime(hoy.year, hoy.month, hoy.day);
    final inicio = hoyD.subtract(Duration(days: 7 * semanas - 1));
    final desplaz = (inicio.weekday - 1) % 7;
    final start = inicio.subtract(Duration(days: desplaz));

    final columnas = <Widget>[];
    DateTime cur = start;
    while (!cur.isAfter(hoyD)) {
      final celdas = <Widget>[];
      for (int i = 0; i < 7; i++) {
        final fecha = cur.add(Duration(days: i));
        final despues = fecha.isAfter(hoyD);
        final p = map[fecha] ?? 0;
        final n = despues ? -1 : _nivel(p);
        celdas.add(
          Container(
            width: 13,
            height: 13,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: n < 0 ? Colors.transparent : _colorNivel(n),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }
      columnas.add(Column(children: celdas));
      cur = cur.add(const Duration(days: 7));
    }

    final dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarDias)
              Column(
                children: dias
                    .map(
                      (l) => SizedBox(
                        width: 14,
                        height: 16,
                        child: Center(
                          child: Text(
                            l,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.grisMedio,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: columnas),
              ),
            ),
          ],
        ),
        if (mostrarLeyenda) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Menos',
                style: TextStyle(fontSize: 10, color: AppColors.grisMedio),
              ),
              const SizedBox(width: 6),
              for (int n = 0; n <= 4; n++)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: _colorNivel(n),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 6),
              const Text(
                'Más',
                style: TextStyle(fontSize: 10, color: AppColors.grisMedio),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
