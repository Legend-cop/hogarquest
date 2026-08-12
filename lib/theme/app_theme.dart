import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Paleta estilo Duolingo para HogarQuest.
class AppColors {
  static const verde = Color(0xFF58CC02);
  static const verdeOscuro = Color(0xFF46A302);
  static const verdeFondo = Color(0xFFE5FFCC);
  static const azul = Color(0xFF1CB0F6);
  static const amarillo = Color(0xFFFFD900);
  static const rojo = Color(0xFFFF4B4B);
  static const morado = Color(0xFFCE82FF);
  static const moradoClaro = Color(0xFFF4E7FF);
  static const grisOscuro = Color(0xFF3C3C3C);
  static const grisMedio = Color(0xFF777777);
  static const linea = Color(0xFFE5E5E5);
  static const fondo = Color(0xFFF7F7F7);
  static const superficieOscura = Color(0xFF1F1F1F);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.verde,
      primary: AppColors.verde,
      secondary: AppColors.azul,
      tertiary: AppColors.amarillo,
      surface: Colors.white,
      error: AppColors.rojo,
    );
    return _base(Brightness.light, scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.verde,
      brightness: Brightness.dark,
      primary: AppColors.verde,
      secondary: AppColors.azul,
      tertiary: AppColors.amarillo,
      surface: AppColors.superficieOscura,
      error: AppColors.rojo,
    );
    return _base(Brightness.dark, scheme);
  }

  static ThemeData _base(Brightness brightness, ColorScheme scheme) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.grisOscuro : AppColors.fondo,
      textTheme: ThemeData.light().textTheme.copyWith(
            headlineMedium: const TextStyle(
              fontFamily: 'sans-serif',
              fontWeight: FontWeight.w800,
              color: AppColors.grisOscuro,
              fontSize: 26,
            ),
            titleLarge: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.grisOscuro,
              fontSize: 20,
            ),
            bodyMedium: const TextStyle(
              color: AppColors.grisOscuro,
              fontSize: 15,
            ),
          ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isDark ? AppColors.grisOscuro : Colors.white,
        foregroundColor: AppColors.grisOscuro,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: AppColors.grisOscuro,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.superficieOscura : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.grisMedio.withValues(alpha: 0.3) : AppColors.linea,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.superficieOscura : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.linea, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.linea, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.verde, width: 3),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : AppColors.grisMedio,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.linea,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.verdeOscuro, width: 2),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.verdeOscuro, width: 2),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.azul,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.grisOscuro : Colors.white,
        indicatorColor: AppColors.verdeFondo,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? AppColors.verdeOscuro
                : AppColors.grisMedio,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.verdeOscuro
                : AppColors.grisMedio,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide.none,
        ),
        backgroundColor: AppColors.verdeFondo,
        labelStyle: const TextStyle(
          color: AppColors.verdeOscuro,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.linea,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.verdeOscuro,
        unselectedLabelColor: AppColors.grisMedio,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        indicatorColor: AppColors.verde,
        dividerColor: AppColors.linea,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.superficieOscura : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: AppColors.grisOscuro,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
