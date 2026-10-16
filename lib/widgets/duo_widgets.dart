import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'playful_motion.dart';

/// Botón estilo Duolingo con respuesta elástica y profundidad al tocar.
class DuoButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color borderColor;
  final bool loading;
  final bool expanded;
  final bool fullWidth;

  const DuoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.verde,
    this.borderColor = AppColors.verdeOscuro,
    this.loading = false,
    this.expanded = true,
    this.fullWidth = true,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.loading;
    final bg = enabled
        ? widget.color
        : (isDark ? Colors.white10 : AppColors.linea);
    final fg = enabled || widget.loading
        ? Colors.white
        : textoSuaveTema(context);
    final mainAxisSize = (widget.fullWidth && widget.expanded)
        ? MainAxisSize.max
        : MainAxisSize.min;
    final content = Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 3, color: fg),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, color: fg, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
    final radius = BorderRadius.circular(16);

    Widget button(double height, EdgeInsetsGeometry padding) => Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        child: AnimatedScale(
          scale: hqReduceMotion(context) || !_pressed ? 1 : 0.94,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            height: height,
            padding: padding,
            alignment: Alignment.center,
            transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              boxShadow: enabled && !_pressed
                  ? [
                      BoxShadow(
                        color: widget.borderColor,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: content,
          ),
        ),
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(height: 48, child: button(44, EdgeInsets.zero));
    }
    return SizedBox(
      height: 44,
      child: button(40, const EdgeInsets.symmetric(horizontal: 24)),
    );
  }
}

/// Tarjeta blanca estilo Duolingo: borde grueso gris claro.
class DuoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const DuoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PlayfulEntrance(
      delayMs: 80,
      child: Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color:
                color ?? (isDark ? AppColors.superficieOscura : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.grisMedio.withValues(alpha: 0.3)
                  : AppColors.linea,
              width: 2,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Icono redondo estilo sticker de Duolingo.
class DuoIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const DuoIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return PlayfulEntrance(
      delayMs: 120,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}
