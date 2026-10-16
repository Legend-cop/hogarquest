import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import 'icons3d.dart';

/// Nivel del integrante: medalla, título, puntos restantes y una barra de
/// progreso hecha con segmentos redondeados que se llenan en cascada.
class LevelProgress extends StatelessWidget {
  final int puntos;
  final int nivel;

  /// Cantidad de trazos del dibujo del progreso.
  final int segmentos;

  const LevelProgress({
    super.key,
    required this.puntos,
    required this.nivel,
    this.segmentos = 14,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = GamificationService.progresoNivel(puntos, nivel);
    final restantes = GamificationService.puntosParaSiguiente(puntos, nivel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Medal3D(size: 28, tono: MedalTono.oro),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIVEL $nivel',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.grisMedio,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    GamificationService.nombreNivel(nivel),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (restantes > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: verdeFondoTema(context),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Faltan $restantes pts',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.verde,
                  ),
                ),
              )
            else
              const Text(
                '¡Máximo! 👑',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.oro,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _BarraSegmentos(progreso: progreso, cantidad: segmentos),
      ],
    );
  }
}

/// Trazo de pequeños rectángulos redondeados que se llenan de izquierda a
/// derecha con un fundido en cascada (el segmento actual se va llenando a
/// medio camino). Degradado verde → amarillo → oro a lo largo del trazo.
class _BarraSegmentos extends StatelessWidget {
  final double progreso;
  final int cantidad;

  const _BarraSegmentos({required this.progreso, required this.cantidad});

  Color _colorDe(int i) {
    final c = cantidad > 1 ? cantidad - 1 : 1;
    final t = (i / c).clamp(0.0, 1.0);
    if (t < 0.5) {
      return Color.lerp(AppColors.verde, AppColors.amarillo, t * 2) ??
          AppColors.verde;
    }
    return Color.lerp(AppColors.amarillo, AppColors.oro, (t - 0.5) * 2) ??
        AppColors.amarillo;
  }

  @override
  Widget build(BuildContext context) {
    final sinAnim = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progreso.clamp(0.0, 1.0)),
      duration: Duration(milliseconds: sinAnim ? 0 : 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Row(
        children: [
          for (var i = 0; i < cantidad; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == cantidad - 1 ? 0 : 3),
                child: _Segmento(
                  llenado: (v * cantidad - i).clamp(0.0, 1.0),
                  color: _colorDe(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un solo trazo del progreso: fondo tenue + relleno de color alineado a la
/// izquierda (se va llenando según el avance animado).
class _Segmento extends StatelessWidget {
  final double llenado;
  final Color color;

  const _Segmento({required this.llenado, required this.color});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 14,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: oscuro ? Colors.white12 : Colors.black12),
            ),
            if (llenado > 0)
              FractionallySizedBox(
                widthFactor: llenado.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }
}
