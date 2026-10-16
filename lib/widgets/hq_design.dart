import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'icono3d.dart';
import 'playful_motion.dart';

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
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.grisMedio.withValues(alpha: 0.3)
              : AppColors.linea,
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
    // Fondo pastel en claro y fondo profundo en oscuro: la tinta sigue el
    // tema (grisOscuro en claro, blanco en oscuro) para no perderse.
    final tinta = textoTema(context);
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tinta,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
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
    final target = value.clamp(0, 1).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: Duration(milliseconds: hqReduceMotion(context) ? 0 : 800),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: animatedValue,
          minHeight: 12,
          color: color,
          backgroundColor: isDark ? Colors.white12 : AppColors.fondo,
        ),
      ),
    );
  }
}

/// Segmento pastilla idéntico al de la referencia: contenedor verde claro
/// con radio 16, pestaña activa en píldora blanca con icono + etiqueta.
class PillSegment extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<({IconData icon, String label})> items;
  const PillSegment({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.verde.withValues(alpha: 0.15)
            : AppColors.verdeFondo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: index == i
                        ? (isDark
                              ? AppColors.superficieOscura
                              : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].icon, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        items[i].label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Encabezado de pantalla estilo referencia: eyebrow verde 11 + título 28.
class ReferenciaTitulo extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Widget> actions;

  /// Ícono 3D infantil opcional junto al título.
  final Icono3DTipo? icono;

  const ReferenciaTitulo(
    this.eyebrow,
    this.title, {
    super.key,
    this.actions = const [],
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.verde,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textoTema(context),
          ),
        ),
      ],
    );
    final conIcono = icono == null
        ? column
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icono3D(tipo: icono!, size: 38),
              const SizedBox(width: 10),
              Expanded(child: column),
            ],
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: actions.isEmpty
          ? conIcono
          : Row(
              children: [Expanded(child: conIcono), ...actions],
            ),
    );
  }
}

/// Pestañas segmentadas estilo diseño de referencia (SegmentedButton M3).
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegmentTabs(this.labels, this.index, this.onChanged, {super.key});

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
    'facil' => verdeFondoTema(context),
    'media' => amarilloFondoTema(context),
    'dificil' => rojoFondoTema(context),
    _ => azulFondoTema(context),
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

/// Botón "Cancelar" unificado para diálogos: fondo suave, borde redondeado,
/// icono ✕ y rebote al presionar. Sustituye a los TextButton planos.
/// Botón "Cancelar" con el mismo lenguaje visual que [DuoButton]: radio 16,
/// sombra dura inferior, texto en mayúsculas w900 y rebote al presionar.
class CancelarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool fullWidth;

  const CancelarButton({
    super.key,
    this.onPressed,
    this.label = 'Cancelar',
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tinta = textoTema(context);
    final bg = dark ? AppColors.superficieOscura : const Color(0xFFF1F5F9);
    final sombra = dark ? Colors.white24 : AppColors.linea;
    return Semantics(
      button: true,
      child: BouncyTap(
        onTap: onPressed,
        child: Container(
          width: fullWidth ? double.infinity : null,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: sombra, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_rounded, size: 18, color: tinta),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acciones de diálogo apiladas en vertical y a lo ancho: la acción
/// principal arriba y Cancelar debajo, ambas ocupando todo el ancho.
class DialogActions extends StatelessWidget {
  final Widget primary;
  final VoidCallback? onCancel;
  final String cancelLabel;

  const DialogActions({
    super.key,
    required this.primary,
    this.onCancel,
    this.cancelLabel = 'Cancelar',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: 10),
          CancelarButton(onPressed: onCancel, label: cancelLabel),
        ],
      ),
    );
  }
}
