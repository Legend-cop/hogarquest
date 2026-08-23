# Plan de fases y mejoras — HogarQuest

Estado de despliegue (al día de hoy):
- Web: https://legend-cop.github.io/hogarquest/
- API (Node + push FCM): https://hogarquest-api-uts.azurewebsites.net
- APK Android: en Releases del repo (workflow "Build APK Release")
- Push FCM: ACTIVO y DURADERO (`FIREBASE_CREDENTIALS_B64` en App Service)
- Sincronización: servidor Node con merge de conflictos por `updated_at` + SSE en vivo
- Nota: el despliegue en Azure App Service (plan B1) resolvió de facto el arranque
  lento de la Fase 4 sin necesidad de UptimeRobot.

---

## FASE 1 — Controles de padre (prioridad)
Objetivo: que tú tengas control y seguridad sin pagar nada.

- **PIN de admin**: al abrir la app como admin pide un PIN (4-6 dígitos) para evitar
  que los niños aprueben tareas o cambien configuración. → ✅ IMPLEMENTADO
  (`lib/screens/pin_gate_screen.dart`, `lib/services/security_service.dart`,
  `app_provider.verificarPin` / `desbloquearAdmin` / `fijarPin`)
- **Botón "Exportar respaldo"**: descarga un archivo JSON de toda la base (usuarios,
  tareas, puntos, historial) para guardarlo en tu drive. → ✅ IMPLEMENTADO
  (`profile_screen.dart` → `app.exportarRespaldo()` → `database_helper.exportarDb()`)
- **Restaurar respaldo** (opcional, en esta fase o la siguiente): cargar ese JSON de
  vuelta. → ✅ IMPLEMENTADO (`profile_screen.dart` → `app.importarRespaldo` →
  `database_helper.importarDb`; usa file_picker para elegir el .json y re-sella los
  registros para que el servidor prefiera la versión restaurada)

Esfuerzo: S (mediano, 1-2 sesiones). Dependencias: ninguna.
> Falta solo el "Restaurar respaldo" para dar Fase 1 por completa.

---

## FASE 2 — Motivación de los niños
Objetivo: que quieran entrar y cumplir tareas.

- **Celebración al aprobar** (confeti/animación) — el código ya existe, solo activarlo.
  → ✅ HECHO (activado en Fase 2 parte 2)
- **Insignias visibles con progreso** (ej. "7 días seguidos", "5 tareas en un día").
  → ✅ HECHO (`lib/models/badge.dart`, `lib/services/gamification_service.dart`)
- **Notificación push al niño cuando se aprueba**: "¡Ganaste 10 puntos!".
  → ✅ HECHO (FCM activo: `notification_service_io/web`, `push_service`, endpoint
  `/api/notify` en el servidor)
- **Tienda de recompensas con fotos y catálogo de premios especiales**.
  → ⚠️ PARCIAL (existen recompensas/catálogos y fotos de perfil; confirmar si la
  tienda muestra fotos de los premios)

Esfuerzo: M. Dependencias: Fase 1 (respaldo sirve de base).

---

## FASE 3 — Más control para padres
Objetivo: visibilidad y organización.

- **Gráfica de 30 días** (hoy solo 7). → ✅ IMPLEMENTADO (dashboard extiende la
  gráfica personal y familiar a 30 días vía `puntosPorDia(dias: 30)` /
  `puntosPorDiaGlobal(dias: 30)`; etiquetas por día del mes)
- **Vista de calendario semanal** de quién tiene qué pendiente. → ✅ YA IMPLEMENTADO
  (pestaña "Semana" en la vista de Tareas del admin: `tasks_screen._AdminSemanaTab`,
  con cada día, tareas asignadas y filtro por integrante)
- **Varios admins / copadres** (hoy solo uno). → ✅ IMPLEMENTADO (el diálogo de
  usuario ahora tiene selector de rol Integrante/Administrador y contraseña; la
  pantalla de gestión lista a todos los usuarios, incluídos los admins, para
  crear/promover copadres)
- **Restaurar respaldo** si no se hizo en Fase 1. → ❌ PENDIENTE (depende Fase 1)

Esfuerzo: M. Dependencias: Fase 1.

---

## FASE 4 — Hosting gratis (sin pagar Always-On)
Objetivo: que la web no tarde 60-90 s al abrir, a costo cero.

- **Mantener despierto gratis**: monitor de uptime gratuito (ej. UptimeRobot) que haga
  ping al endpoint de wake cada 5 min, o aprovechar el keepalive.yml de GitHub Actions
  ya existente. Reduce la espera casi a cero sin costo. → ➖ NO NECESARIO (estamos en
  Azure B1, siempre activo)
- **APK en GitHub Releases** (no dentro del código) para quitar el aviso de
  "archivo >50 MB" y acelerar los push. → ✅ HECHO (workflow `build-apk.yml`)
- **(Opcional) Evaluar un host totalmente gratis que no duerma.** → ➖ N/A (Azure B1)

Esfuerzo: S. Dependencias: ninguna (se puede hacer en cualquier momento).

---

## FASE 5 — Refactor grande a base de datos real (OPCIONAL)
Objetivo: solidez a largo plazo.

- **MongoDB real** (ya lo usas para fotos) en vez del archivo único: historial real,
  mejor concurrencia entre celulares, respaldos automáticos. → ✅ COMPLETO
  (`MONGODB_URI` configurado en Azure; `mongo-status` muestra `mongoReady:true`; la BD
  local se migró sola a Mongo la primera vez que conectó)
- **Login en el servidor (auth server-side)**: la web ya no descarga las contraseñas.
  Mejora de seguridad si la app se usa fuera de casa. → ✅ COMPLETO
  (la web usa `/api/login` para validar credenciales y `/api/db-public` que no
  devuelve passwords/salt; los pushes preservan las contraseñas en el servidor)

Esfuerzo: L (grande, refactor de sincronización). Dependencias: Fases 1-3 estables.

---

## Resumen de estado

| Fase | Ítem | Estado |
|------|------|--------|
| 1 | PIN de admin | ✅ |
| 1 | Exportar respaldo | ✅ |
| 1 | Restaurar respaldo | ✅ |
| 2 | Celebración al aprobar | ✅ |
| 2 | Insignias con progreso | ✅ |
| 2 | Push al niño al aprobar | ✅ |
| 2 | Tienda con fotos/catálogo | ⚠️ |
| 3 | Gráfica 30 días | ✅ |
| 3 | Calendario semanal | ✅ |
| 3 | Varios admins | ✅ |
| 3 | Restaurar respaldo | ❌ |
| 4 | Mantener despierto | ➖ |
| 4 | APK en Releases | ✅ |
| 4 | Host gratis sin dormir | ➖ |
| 5 | MongoDB real | ✅ |
| 5 | Login server-side | ✅ |

✅ hecho · ⚠️ parcial · ❌ pendiente · ➖ no aplica / ya resuelto
