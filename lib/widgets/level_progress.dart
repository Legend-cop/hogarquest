import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../theme/app_theme.dart';

/// Muestra el nivel del integrante y la barra de progreso al siguiente nivel.
class LevelProgress extends StatelessWidget {
  final int puntos;
  final int nivel;

  const LevelProgress({super.key, required this.puntos, required this.nivel});

  @override
  Widget build(BuildContext context) {
    final progreso = GamificationService.progresoNivel(puntos, nivel);
    final restantes = GamificationService.puntosParaSiguiente(puntos, nivel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.military_tech, size: 20, color: AppColors.amarillo),
            const SizedBox(width: 6),
            Text(
              'Nivel $nivel · ${GamificationService.nombreNivel(nivel)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            if (restantes > 0)
              Text(
                '$restantes pts para subir',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              const Text('¡Nivel máximo alcanzado!',
                  style: TextStyle(fontSize: 12, color: AppColors.verde)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 10,
            backgroundColor: Colors.black12,
            color: AppColors.azul,
          ),
        ),
      ],
    );
  }
}
