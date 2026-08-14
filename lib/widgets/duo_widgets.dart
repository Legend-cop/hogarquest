import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Botón estilo Duolingo: color plano con "borde inferior" grueso oscuro
/// que da el efecto 3D chunky característico.
class DuoButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = enabled ? color : AppColors.linea;
    final bd = enabled ? borderColor : AppColors.grisMedio;

    final mainAxisSize =
        (fullWidth && expanded) ? MainAxisSize.max : MainAxisSize.min;

    final content = Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );

    final radius = BorderRadius.circular(16);

    if (fullWidth) {
      return SizedBox(
        height: 54,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 54,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: bd,
                    borderRadius: radius,
                  ),
                ),
                Container(
                  height: 49,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Container(
            height: 49,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border(bottom: BorderSide(color: bd, width: 5)),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca estilo Duolingo: borde grueso gris claro + sombra inferior.
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
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? (isDark ? AppColors.superficieOscura : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.grisMedio.withValues(alpha: 0.3) : AppColors.linea,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
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
    return Container(
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
    );
  }
}
