import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta "arcoíris pastel por sección" de HogarQuest.
/// Cada sección tiene su color saturado (texto/iconos/botones) y su fondo
/// pastel (tarjetas, chips y banners):
/// - Inicio/Tareas/marca: verde #10B981 → #E8F8F0
/// - Retos: coral #FF7A66 → #FFF1EC
/// - Ranking: morado #8B7CF6 → #F1EEFF
/// - Premios: dorado #F59E0B / pastel #FBBF24 → #FFF7DE
/// - Perfil: rosa #F472B6 → #FFEEF7
/// - Errores/destructivo: rojo #E5484D → #FFE4E6
class AppColors {
  // Sección Inicio/Tareas/marca.
  static const verde = Color(0xFF10B981);
  static const verdeOscuro = Color(0xFF059669);
  static const verdeFondo = Color(0xFFE8F8F0);
  static const verdeProfundo = Color(0xFF064E3B);

  // Sección Retos.
  static const coral = Color(0xFFFF7A66);
  static const coralOscuro = Color(0xFFE85D44);
  static const coralFondo = Color(0xFFFFF1EC);

  // Sección Ranking.
  static const morado = Color(0xFF8B7CF6);
  static const moradoClaro = Color(0xFFF1EEFF);

  // Sección Premios (dorado = acento; pastel = fondo de sección).
  static const amarillo = Color(0xFFF59E0B);
  static const amarilloOscuro = Color(0xFFD97706);
  static const amarilloPastel = Color(0xFFFBBF24);
  static const amarilloFondo = Color(0xFFFFF7DE);

  // Sección Perfil.
  static const rosa = Color(0xFFF472B6);
  static const rosaFondo = Color(0xFFFFEEF7);

  // Errores y acciones destructivas.
  static const rojo = Color(0xFFE5484D);
  static const rojoOscuro = Color(0xFFB91C1C);
  static const rojoFondo = Color(0xFFFFE4E6);

  // Auxiliares.
  static const azul = Color(0xFF0EA5E9);
  static const azulOscuro = Color(0xFF0284C7);
  static const azulFondo = Color(0xFFE0F2FE);
  static const grisOscuro = Color(0xFF1F2937);
  static const grisMedio = Color(0xFF6B7280);
  static const linea = Color(0xFFE5E7EB);
  static const fondo = Color(0xFFFCFBF7);
  static const superficie = Color(0xFFFFFFFF);
  static const superficieOscura = Color(0xFF1E293B);
  static const fondoOscuro = Color(0xFF0F172A);
  static const oro = amarillo;
  static const plata = Color(0xFFCBD5E1);
  static const bronce = Color(0xFFCD7F32);

  // Variantes profundas de los fondos pastel para modo oscuro: el texto
  // blanco del tema sigue legible y los colores saturados de sección
  // también. Nunca se usan los fondos claros sobre fondo oscuro.
  static const verdeFondoOscuro = Color(0xFF0B3D2E);
  static const coralFondoOscuro = Color(0xFF4C241B);
  static const moradoClaroOscuro = Color(0xFF2E2A56);
  static const amarilloFondoOscuro = Color(0xFF44340F);
  static const rosaFondoOscuro = Color(0xFF4A1F3B);
  static const rojoFondoOscuro = Color(0xFF4C1D24);
  static const azulFondoOscuro = Color(0xFF0B3B52);
}

/// ¿El tema activo es oscuro?
bool esOscuro(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Color de texto principal según el tema activo (blanco en oscuro).
Color textoTema(BuildContext context) =>
    esOscuro(context) ? Colors.white : AppColors.grisOscuro;

/// Color de texto secundario/tenue según el tema (blanco 70% en oscuro).
Color textoSuaveTema(BuildContext context) =>
    esOscuro(context) ? Colors.white70 : AppColors.grisMedio;

/// Fondo de superficie (tarjetas blancas) según el tema.
Color superficieTema(BuildContext context) =>
    esOscuro(context) ? AppColors.superficieOscura : Colors.white;

// Fondos pastel de sección resueltos según el tema (variantes profundas
// en oscuro para que el texto blanco siga legible).
Color verdeFondoTema(BuildContext context) =>
    esOscuro(context) ? AppColors.verdeFondoOscuro : AppColors.verdeFondo;

Color coralFondoTema(BuildContext context) =>
    esOscuro(context) ? AppColors.coralFondoOscuro : AppColors.coralFondo;

Color moradoClaroTema(BuildContext context) =>
    esOscuro(context) ? AppColors.moradoClaroOscuro : AppColors.moradoClaro;

Color amarilloFondoTema(BuildContext context) =>
    esOscuro(context) ? AppColors.amarilloFondoOscuro : AppColors.amarilloFondo;

Color rosaFondoTema(BuildContext context) =>
    esOscuro(context) ? AppColors.rosaFondoOscuro : AppColors.rosaFondo;

Color rojoFondoTema(BuildContext context) =>
    esOscuro(context) ? AppColors.rojoFondoOscuro : AppColors.rojoFondo;

Color azulFondoTema(BuildContext context) =>
    esOscuro(context) ? AppColors.azulFondoOscuro : AppColors.azulFondo;

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.verde,
      primary: AppColors.verde,
      secondary: AppColors.azul,
      tertiary: AppColors.amarilloPastel,
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
      tertiary: AppColors.amarilloPastel,
      surface: AppColors.superficieOscura,
      error: AppColors.rojo,
    );
    return _base(Brightness.dark, scheme);
  }

  static ThemeData _base(Brightness brightness, ColorScheme scheme) {
    final isDark = brightness == Brightness.dark;
    final texto = isDark ? Colors.white : AppColors.grisOscuro;
    final suave = isDark ? Colors.white70 : AppColors.grisMedio;
    // Nunito de verdad: se aplica a TODO el TextTheme de la app.
    final nunito = GoogleFonts.nunitoTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: texto, displayColor: texto);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.fondoOscuro : AppColors.fondo,
      textTheme: nunito,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isDark ? AppColors.fondoOscuro : AppColors.fondo,
        foregroundColor: texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          color: texto,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.superficieOscura : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? AppColors.grisMedio.withValues(alpha: 0.3)
                : AppColors.linea,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.superficieOscura : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.linea),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.linea),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.verde, width: 2),
        ),
        labelStyle: TextStyle(color: suave, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: suave, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.linea,
          disabledForegroundColor: AppColors.grisMedio,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.verde,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.superficieOscura : Colors.white,
        height: 64,
        indicatorColor: isDark
            ? AppColors.verde.withValues(alpha: 0.22)
            : AppColors.verde.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? AppColors.verde
                : (isDark ? Colors.white70 : AppColors.grisMedio),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.verde
                : (isDark ? Colors.white70 : AppColors.grisMedio),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide.none,
        ),
        backgroundColor: isDark
            ? AppColors.verde.withValues(alpha: 0.2)
            : AppColors.verdeFondo,
        labelStyle: TextStyle(
          color: isDark ? AppColors.verde : AppColors.verdeOscuro,
          fontWeight: FontWeight.w800,
          fontSize: 11,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.nunito(
          color: texto,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.superficieOscura
            : AppColors.grisOscuro,
        contentTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
