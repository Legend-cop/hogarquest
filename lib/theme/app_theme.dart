import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta exacta del proyecto original de HogarQuest (zip):
/// verde Duolingo #58CC02, pastéis y neutros del diseño de referencia.
class AppColors {
  // Marca principal (zip: primary)
  static const verde = Color(0xFF58CC02);
  static const verdeOscuro = Color(0xFF43A702);
  static const verdeFondo = Color(0xFFD7FFB8);
  // Acentos (zip: info / warning / danger / secondary)
  static const azul = Color(0xFF1CB0F6);
  static const amarillo = Color(0xFFFFC800);
  static const amarilloOscuro = Color(0xFF3C3C3C);
  static const amarilloFondo = Color(0xFFFFF4C2);
  static const rojo = Color(0xFFFF4B4B);
  static const rojoFondo = Color(0xFFFFE1E1);
  static const azulFondo = Color(0xFFDDF4FF);
  static const morado = Color(0xFFCE82FF);
  static const moradoClaro = Color(0xFFF6E7FF);
  // Fondos y bordes (zip: ink / muted / surface / borde E5E5E5)
  static const grisOscuro = Color(0xFF3C3C3C);
  static const grisMedio = Color(0xFF777777);
  static const linea = Color(0xFFE5E5E5);
  static const fondo = Color(0xFFF7F7F7);
  static const superficieOscura = Color(0xFF1E293B);
  // Metales de ligas (colores exactos de `leagues` en el zip)
  static const oro = Color(0xFFFFC800);
  static const plata = Color(0xFFB0B7C3);
  static const bronce = Color(0xFFCD7F32);
}

/// Color de texto principal según el tema activo (blanco en oscuro).
/// Usar en Textos para que nunca queden invisibles en modo oscuro.
Color textoTema(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.white
    : AppColors.grisOscuro;

/// Color de texto secundario/tenue según el tema (blanco 70% en oscuro).
/// Sustituye a `AppColors.grisMedio` en textos e iconos: el gris medio
/// sobre fondo oscuro queda ilegible.
Color textoSuaveTema(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.white70
    : AppColors.grisMedio;

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
    // Color de texto principal según el modo (evita texto invisible en dark).
    final texto = isDark ? Colors.white : AppColors.grisOscuro;
    final suave = isDark ? Colors.white70 : AppColors.grisMedio;
    // Base de tipografía Nunito (mismo look que el diseño aprobado).
    final google = GoogleFonts.nunitoTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: google.bodyMedium?.fontFamily,
      scaffoldBackgroundColor: isDark ? AppColors.grisOscuro : Colors.white,
      textTheme: google.copyWith(
        headlineMedium: google.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: texto,
          fontSize: 26,
        ),
        titleLarge: google.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: texto,
          fontSize: 20,
        ),
        titleMedium: google.titleMedium?.copyWith(color: texto),
        bodyLarge: google.bodyLarge?.copyWith(color: texto),
        bodyMedium: google.bodyMedium?.copyWith(color: texto, fontSize: 15),
        bodySmall: google.bodySmall?.copyWith(color: suave),
        labelLarge: google.labelLarge?.copyWith(color: texto),
        labelMedium: google.labelMedium?.copyWith(color: suave),
        labelSmall: google.labelSmall?.copyWith(color: suave),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isDark ? AppColors.grisOscuro : Colors.white,
        foregroundColor: texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: texto,
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
            color: isDark
                ? AppColors.grisMedio.withValues(alpha: 0.3)
                : AppColors.linea,
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
        labelStyle: TextStyle(color: suave, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: suave, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.linea,
          disabledForegroundColor: AppColors.grisMedio,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
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
        indicatorColor: isDark
            ? AppColors.verde.withValues(alpha: 0.25)
            : AppColors.verdeFondo,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.verde : AppColors.verdeOscuro)
                : (isDark ? Colors.white70 : AppColors.grisMedio),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.verde : AppColors.verdeOscuro)
                : (isDark ? Colors.white70 : AppColors.grisMedio),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide.none,
        ),
        backgroundColor: isDark
            ? AppColors.verde.withValues(alpha: 0.2)
            : AppColors.verdeFondo,
        labelStyle: TextStyle(
          color: isDark ? AppColors.verde : AppColors.verdeOscuro,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white24 : AppColors.linea,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? AppColors.verde : AppColors.verdeOscuro,
        unselectedLabelColor: suave,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        indicatorColor: AppColors.verde,
        dividerColor: isDark ? Colors.white24 : AppColors.linea,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.superficieOscura : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: texto,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Fondo oscuro SIEMPRE (en claro evita el inverseSurface ilegible
        // que combinaba fondo oscuro con texto gris).
        backgroundColor:
            isDark ? AppColors.superficieOscura : AppColors.grisOscuro,
        contentTextStyle: const TextStyle(color: Colors.white),
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
