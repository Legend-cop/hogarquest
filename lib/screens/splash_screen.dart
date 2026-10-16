import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/playful_motion.dart';
import '../widgets/hq_logo.dart';

/// Splash con animación de entrada (logo que "bota" + fade del texto).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _escala = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.elasticOut,
  );

  late final Animation<double> _aparece = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azul,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.azul, AppColors.verde],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Positioned(
                        left: -34,
                        top: 4,
                        child: Twinkle(color: AppColors.amarillo, size: 24),
                      ),
                      const Positioned(
                        right: -40,
                        bottom: 8,
                        child: Twinkle(
                          color: Colors.white,
                          size: 18,
                          delayMs: 380,
                        ),
                      ),
                      ScaleTransition(
                        scale: _escala,
                        child: RotationTransition(
                          turns: Tween<double>(begin: -0.035, end: 0).animate(
                            CurvedAnimation(
                              parent: _ctrl,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const HqLogo(size: 96),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _aparece,
                    child: const Text(
                      'HogarQuest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _aparece,
                    child: const Text(
                      'Tareas del hogar con recompensas',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _aparece,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const SizedBox(
                        width: 58,
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
