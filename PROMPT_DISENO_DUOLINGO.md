# PROMPT — Rediseño de HogarQuest al estilo Duolingo

> Copia y pega este prompt completo en tu herramienta de IA preferida
> (ChatGPT, Claude, Midjourney, etc.) para rediseñar la app.

---

## 📌 PROMPT (copia esto)

```
Actúa como un diseñador senior de experiencia de usuario especializado en
gamificación. Necesito rediseñar por completo la presentación visual de una
aplicación móvil llamada "HogarQuest" para que su estética sea lo más
parecida posible a la app de Duolingo.

## DESCRIPCIÓN DE LA APP

HogarQuest es una aplicación multiplataforma (Android, Windows y Web) para
gestionar tareas del hogar entre hermanos o miembros de una familia, con un
sistema completo de gamificación. Los usuarios son:

- ADMINISTRADOR: crea tareas, aprueba actividades, asigna recompensas,
  gestiona integrantes, ve estadísticas.
- INTEGRANTE: ve sus tareas, las completa, gana puntos, sube de nivel,
  mantiene rachas, gana insignias y canjea recompensas.

## PANTALLAS QUE DEBE REDISEÑAR

1. SPLASH — Logo animado al estilo mascota de Duolingo (una mascota casera
   tipo "hogar", puede ser una casita con cara sonriente).
2. LOGIN — Selección de usuario con avatares grandes y redondos, botón
   verde gigante y redondeado.
3. DASHBOARD (Home) — Tarjeta principal tipo "lección del día" con barra de
   progreso circular estilo Duolingo, contador de racha con flama, chips de
   estadísticas (pendientes, por aprobar, racha), lista de "mis tareas".
4. TAREAS — Vista de lista con pestañas (Pendientes / Historial), tarjetas
   con dificultad representada por colores (fácil=verde, media=amarillo,
   difícil=rojo), botón "Completar" grande y redondeado, botón flotante
   "+" gigante.
5. RANKING — Tabla de clasificación estilo "Liga" de Duolingo con
   medallas (oro, plata, bronce) para los 3 primeros, avatares y barras de
   progreso entre posiciones, pestañas Semanal/Mensual.
6. RECOMPENSAS — Tienda con tarjetas de premios, monedas/cristales como
   icono de puntos, botón "Canjear" con costo.
7. PERFIL — Avatar gigante, nivel con barra de progreso, insignias
   desbloqueadas como trofeos, estadísticas de racha, edición de tema.
8. ADMINISTRACIÓN — Panel de aprobación de tareas con botones
   Aprobar/Rechazar, gestión de integrantes y creación de recompensas.

## ESTILO VISUAL REQUERIDO (100% inspirado en Duolingo)

### Paleta de colores
- Verde principal vibrante: #58CC02
- Verde oscuro (bordes/sombras): #58A700
- Amarillo/verde lima (recompensas y XP): #FFD900
- Rojo (errores/rechazos): #FF4B4B
- Azul (vínculos/información): #1CB0F6
- Blanco/crema de fondo: #FFFFFF / #F7F7F7
- Morado (premium/insignias especiales): #CE82FF
- Texto oscuro: #3C3C3C

### Tipografía
- Sans-serif redondeada y amigable (estilo Nunito, Poppins o Baloo 2).
- Títulos en negrita extrabold, mayúsculas para encabezados de sección.
- Texto de botones en negrita, color blanco.

### Componentes
- BOTONES: rectángulos con esquinas MUY redondeadas, color verde plano,
  con sombra sólida oscura debajo (efecto "3D chunky" de Duolingo), sin
  degradados ni elevación suave.
- TARJETAS: fondo blanco, borde grueso gris claro, sombra inferior sólida.
- BARRA DE PROGRESO: segmentada (10 segmentos) o circular con grosor
  grueso, color amarillo/verde.
- ICONOS: redondos, con fondo de color sólido y borde, estilo sticker.
- AVATARES: círculos con borde de color.
- INSIGNIAS: medallas/trofeos con cinta, desbloqueadas en color y
  bloqueadas en gris.
- FLAMA de racha: roja con borde oscuro.
- MICRO-INTERACCIONES: animación de confeti al completar tarea, saltos
  (bounce) al ganar puntos, vibración sutil.

### Principios
- Diseño infantil-familiar: divertido, colorido, sin tecnicismos.
- Jerarquía clara: 1 acción principal por pantalla, botón gigante verde.
- Gamificación siempre visible: XP, racha y nivel en todas las pantallas.
- Espaciado generoso, bordes gruesos, sombras chunky.

## ENTREGABLES

1. Especificación completa del sistema de diseño (paleta, tipografía,
   componentes, tokens).
2. Rediseño de cada pantalla describiendo layout, componentes y
   animaciones pantalla por pantalla.
3. Código de ejemplo (Flutter/Dart con Material 3) del tema global
   (app_theme.dart), los widgets reutilizables (botón estilo Duolingo,
   barra de progreso circular, tarjeta de tarea) y la animación de
   confeti para completar tareas.
4. Guía de migración: cómo sustituir el tema azul actual (#2563EB) por el
   nuevo tema verde Duolingo sin romper la lógica de la app.

## DATOS TÉCNICOS ACTUALES (para referencia)

- Framework: Flutter 3.44.8 (Dart)
- Base de datos: Hive (local, funciona en Android/Windows/Web)
- Estado: Provider (ChangeNotifier)
- Tema actual: Material 3 con colores azul (#2563EB), verde (#16A34A),
  amarillo (#F59E0B), fondo gris (#F3F4F6)
- Niveles existentes: 1=Aprendiz del hogar, 2=Ayudante, 3=Trabajador,
  4=Super estrella, 5=Experto del hogar, y nivel 6+ cada 400 puntos
- Rachas: 3 días=+10 pts, 7 días=+30 pts, 30 días=+50 pts
- Insignias: Maestro de limpieza, Rey de la cocina, Orden perfecto,
  Puntual, Racha de 7 días, Experto del hogar
- Recompensas: elegir película (100), postre favorito (150), hora extra
  de juego (200), salida por helado (300), actividad especial (500)
```

---

## 🎯 USO RÁPIDO

| Quieres | Pega el prompt en |
|---------|-------------------|
| Generar imágenes/mockups | Midjourney, DALL-E, Leonardo |
| Rediseñar el código Flutter | ChatGPT, Claude, Gemini |
| Diseño de UI | Figma + IA (como plugin) |

## 📂 Archivos clave del proyecto actual

| Archivo | Función |
|---------|---------|
| `lib/theme/app_theme.dart` | Tema actual (azul) — este es el principal a cambiar |
| `lib/widgets/level_progress.dart` | Barra de progreso de nivel |
| `lib/widgets/empty_state.dart` | Estado vacío |
| `lib/widgets/section_header.dart` | Encabezados de sección |
| `lib/services/gamification_service.dart` | Lógica de niveles, rachas, insignias |
| `lib/screens/` | Todas las pantallas (8) |
| `lib/db/database_helper.dart` | Base de datos Hive |
