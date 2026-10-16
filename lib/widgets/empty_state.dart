import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'mascots.dart';

/// Placeholder amigable para listas vacías. Puede mostrar una mascota
/// infantil en lugar del ícono del sistema.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;

  /// Si se indica, se muestra esta mascota (interactiva) en vez del ícono.
  final MascotType? mascota;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.hint,
    this.mascota,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mascota != null)
              MascotWidget(mascota: mascota!, size: 116, flotante: true)
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: verdeFondoTema(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: AppColors.verdeOscuro),
              ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color:
                    Theme.of(context).textTheme.titleLarge?.color ??
                    AppColors.grisOscuro,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      Theme.of(context).textTheme.bodySmall?.color ??
                      AppColors.grisMedio,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
