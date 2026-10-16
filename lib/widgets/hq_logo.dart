import 'package:flutter/material.dart';

/// Logo oficial de HogarQuest (casita con carita) como widget reutilizable.
class HqLogo extends StatelessWidget {
  const HqLogo({super.key, this.size = 40});

  /// Lado del logo en píxeles.
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/hq_logo_1024.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
}
