import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Título de página estilo diseño de referencia: 26 w900 + subtítulo tenue,
/// con espacio inferior de 16. `actions` (iconos) va a la derecha.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              color: textoSuaveTema(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: actions.isEmpty
          ? column
          : Row(
              children: [
                Expanded(child: column),
                ...actions,
              ],
            ),
    );
  }
}

/// Tarjeta plana estilo diseño de referencia: fondo sólido (por defecto
/// blanco), radio 18, borde 2 px gris claro y margen inferior 12.
class CardBox extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  const CardBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.superficieOscura : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.grisMedio.withValues(alpha: 0.3)
              : const Color(0xFFE5E5E5),
          width: 2,
        ),
      ),
      child: child,
    );
  }
}

/// Métrica compacta con fondo pastel, icono 3D animado (o el de Material
/// como respaldo), valor 22 w900 y etiqueta 12 w700 centrada.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Widget? iconoWidget;
  const MetricCard(
    this.label,
    this.value,
    this.icon,
    this.bg, {
    super.key,
    this.iconoWidget,
  });

  @override
  Widget build(BuildContext context) {
    // El fondo es pastel (claro) en ambos modos: el texto siempre oscuro.
    const tinta = AppColors.grisOscuro;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconoWidget ?? Icon(icon, color: tinta),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tinta,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tinta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso redondeada (radio 99, alto 12).
class ProgressLine extends StatelessWidget {
  final double value;
  final Color color;
  const ProgressLine(this.value, {super.key, this.color = AppColors.verde});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 12,
        color: color,
        backgroundColor: isDark ? Colors.white12 : AppColors.fondo,
      ),
    );
  }
}

/// Pestañas segmentadas estilo diseño de referencia (SegmentedButton M3).
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegmentTabs(
    this.labels,
    this.index,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var i = 0; i < labels.length; i++)
              ButtonSegment(value: i, label: Text(labels[i])),
          ],
          selected: {index},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      );
}

/// Chip de dificultad estilo referencia: fondo pastel (verde/amarillo/rosa)
/// y etiqueta en formato normal, tamaño de chip por defecto.
Widget difChip(BuildContext context, String dificultad) {
  final bg = switch (dificultad) {
    'facil' => AppColors.verdeFondo,
    'media' => AppColors.amarilloFondo,
    'dificil' => AppColors.rojoFondo,
    _ => AppColors.azulFondo,
  };
  final label = dificultad == 'facil'
      ? 'FÁCIL'
      : dificultad == 'media'
          ? 'MEDIA'
          : 'DIFÍCIL';
  return Chip(
    label: Text(label),
    backgroundColor: bg,
    labelStyle: TextStyle(
      color: textoTema(context),
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );
}
