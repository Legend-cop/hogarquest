# HOGARQUEST

## Sistema Inteligente de Gestión de Tareas del Hogar con Gamificación

**Versión:** 1.0  
**Autor:** Duva Du  
**Fecha:** Agosto 2026

---

# 1. Descripción general

**HogarQuest** es una aplicación multiplataforma (Android y PC) diseñada para administrar las tareas del hogar entre hermanos o miembros de una familia. El sistema permite asignar tareas, otorgar puntos, crear recompensas, visualizar clasificaciones y motivar el cumplimiento mediante elementos de gamificación como niveles, insignias y rachas.

La aplicación tendrá dos tipos de usuarios:

- **Administrador:** crea tareas, aprueba actividades, asigna recompensas y gestiona integrantes.
- **Integrante:** visualiza sus tareas, las completa, gana puntos y canjea recompensas.

---

# 2. Objetivo del proyecto

Desarrollar una aplicación moderna y fácil de usar que fomente la responsabilidad, el trabajo en equipo y la participación en las labores del hogar mediante un sistema de puntos y recompensas.

---

# 3. Objetivos específicos

1. Registrar y administrar integrantes de la familia.
2. Crear y asignar tareas del hogar.
3. Validar el cumplimiento de tareas.
4. Otorgar puntos automáticamente.
5. Gestionar recompensas canjeables.
6. Mostrar clasificaciones semanales y mensuales.
7. Implementar niveles, insignias y rachas.
8. Generar estadísticas de cumplimiento.
9. Permitir funcionamiento móvil y escritorio con la misma información.

---

# 4. Alcance del sistema

Incluye:

- Registro de usuarios familiares.
- Inicio de sesión.
- Gestión de tareas.
- Sistema de puntos.
- Recompensas.
- Clasificación.
- Estadísticas básicas.
- Personalización de perfiles.

No incluye en la versión 1.0:

- Integración con pagos.
- Publicación en Play Store.
- Chat interno.
- Inteligencia artificial.

---

# 5. Usuarios del sistema

## Administrador

- Crear integrantes.
- Editar perfiles.
- Crear tareas.
- Asignar tareas.
- Aprobar o rechazar tareas.
- Crear recompensas.
- Ver reportes y estadísticas.

## Integrante

- Ver tareas pendientes.
- Marcar tareas como realizadas.
- Consultar puntos y nivel.
- Ver ranking.
- Canjear recompensas.
- Editar avatar y tema visual.

---

# 6. Requisitos funcionales

## RF01 – Registro de integrantes

El administrador podrá registrar nuevos integrantes con:

- Nombre
- Foto/avatar
- Edad
- Color o tema favorito

## RF02 – Inicio de sesión

Cada integrante accederá mediante usuario y contraseña o PIN.

## RF03 – Crear tarea

El administrador podrá crear tareas con:

- Título
- Descripción
- Puntos
- Dificultad
- Fecha límite
- Frecuencia

## RF04 – Asignar tarea

Una tarea podrá asignarse a uno o varios integrantes.

## RF05 – Completar tarea

El integrante marcará la tarea como realizada.

## RF06 – Aprobar tarea

El administrador aprobará o rechazará la tarea realizada.

## RF07 – Otorgar puntos

Al aprobar una tarea, el sistema sumará automáticamente los puntos.

## RF08 – Sistema de niveles

Los puntos acumulados determinarán el nivel del integrante.

## RF09 – Recompensas

Los integrantes podrán canjear puntos por recompensas.

## RF10 – Clasificación

El sistema mostrará ranking semanal y mensual.

## RF11 – Insignias

El sistema otorgará insignias por logros específicos.

## RF12 – Estadísticas

El administrador visualizará reportes de cumplimiento.

---

# 7. Requisitos no funcionales

- Interfaz intuitiva.
- Compatible con Android y Windows.
- Tiempo de respuesta menor a 2 segundos.
- Diseño responsivo.
- Almacenamiento seguro de contraseñas.
- Funcionamiento básico sin internet.
- Copia de seguridad local.

---

# 8. Tecnologías seleccionadas

## Frontend móvil

- React Native
- Expo
- React Navigation

## Frontend escritorio

- React + Vite
- Tauri

## Backend

- Node.js
- Express.js
- JWT
- bcrypt

## Base de datos

- SQLite (desarrollo inicial)
- MySQL (producción)

---

# 9. Arquitectura del sistema

```text
Android App (React Native)
          |
          |
      API REST
    Node.js + Express
          |
          |
     Base de datos
   SQLite / MySQL
          |
          |
  App Escritorio (Tauri)
```

---

# 10. Modelo de datos

## Tabla usuarios

| Campo | Tipo |
|---|---|
| id | INT |
| nombre | VARCHAR |
| avatar | VARCHAR |
| edad | INT |
| color_tema | VARCHAR |
| nivel | INT |
| puntos | INT |
| racha | INT |
| password | VARCHAR |

## Tabla tareas

| Campo | Tipo |
|---|---|
| id | INT |
| titulo | VARCHAR |
| descripcion | TEXT |
| puntos | INT |
| dificultad | VARCHAR |
| fecha_limite | DATETIME |
| frecuencia | VARCHAR |
| estado | VARCHAR |

## Tabla asignaciones

| Campo | Tipo |
|---|---|
| id | INT |
| usuario_id | INT |
| tarea_id | INT |
| completada | BOOLEAN |
| aprobada | BOOLEAN |
| fecha_completada | DATETIME |

## Tabla recompensas

| Campo | Tipo |
|---|---|
| id | INT |
| nombre | VARCHAR |
| descripcion | TEXT |
| costo_puntos | INT |

## Tabla canjes

| Campo | Tipo |
|---|---|
| id | INT |
| usuario_id | INT |
| recompensa_id | INT |
| fecha | DATETIME |

## Tabla insignias

| Campo | Tipo |
|---|---|
| id | INT |
| nombre | VARCHAR |
| descripcion | TEXT |

## Tabla usuario_insignias

| Campo | Tipo |
|---|---|
| usuario_id | INT |
| insignia_id | INT |

---

# 11. Estructura de carpetas

```text
hogarquest/
│
├── mobile/
│   ├── src/
│   │   ├── screens/
│   │   ├── components/
│   │   ├── services/
│   │   ├── context/
│   │   └── assets/
│
├── desktop/
│   ├── src/
│   └── tauri/
│
├── backend/
│   ├── src/
│   │   ├── routes/
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── middleware/
│   │   └── config/
│   └── package.json/
│
└── database/
    └── schema.sql
```

---

# 12. Pantallas del sistema

## Móvil

1. Splash
2. Login
3. Dashboard
4. Tareas
5. Ranking
6. Recompensas
7. Perfil
8. Estadísticas

## Escritorio

1. Login
2. Panel administrador
3. Gestión de tareas
4. Gestión de usuarios
5. Recompensas
6. Reportes

---

# 13. Diseño visual recomendado

## Paleta de colores

- Azul: #2563EB
- Verde: #16A34A
- Amarillo: #F59E0B
- Gris oscuro: #111827

## Estilo

- Tarjetas redondeadas.
- Iconografía moderna.
- Barra de progreso.
- Modo oscuro.
- Animaciones suaves.

---

# 14. Sistema de gamificación

## Niveles

| Nivel | Puntos |
|---|---|
| 1 | 0–99 |
| 2 | 100–249 |
| 3 | 250–499 |
| 4 | 500–799 |
| 5 | 800–1199 |

## Insignias

- Maestro de limpieza
- Rey de la cocina
- Orden perfecto
- Puntual
- Racha de 7 días
- Experto del hogar

## Rachas

- 3 días: +10 puntos
- 7 días: +30 puntos
- 30 días: insignia especial

---

# 15. Ejemplo de recompensas

| Recompensa | Costo |
|---|---|
| Elegir película | 100 |
| Postre favorito | 150 |
| Hora extra de juego | 200 |
| Salida por helado | 300 |
| Actividad especial | 500 |

---

# 16. API principal

## Autenticación

- POST /api/auth/login

## Usuarios

- GET /api/users
- POST /api/users
- PUT /api/users/:id

## Tareas

- GET /api/tasks
- POST /api/tasks
- PUT /api/tasks/:id
- DELETE /api/tasks/:id

## Asignaciones

- POST /api/assignments
- PUT /api/assignments/:id/complete
- PUT /api/assignments/:id/approve

## Recompensas

- GET /api/rewards
- POST /api/rewards

## Ranking

- GET /api/ranking/weekly
- GET /api/ranking/monthly

---

# 17. Cronograma de desarrollo

## Semana 1

- Diseño UI
- Base de datos
- Backend inicial

## Semana 2

- Autenticación
- Gestión de usuarios

## Semana 3

- CRUD de tareas
- Asignaciones

## Semana 4

- Puntos
- Ranking
- Recompensas

## Semana 5

- Insignias
- Rachas
- Estadísticas

## Semana 6

- Versión escritorio
- Pruebas finales

---

# 18. Pruebas

- Inicio de sesión correcto.
- Creación de tareas.
- Asignación de tareas.
- Aprobación y rechazo.
- Cálculo de puntos.
- Canje de recompensas.
- Actualización de ranking.
- Persistencia de datos.

---

# 19. Riesgos

| Riesgo | Mitigación |
|---|---|
| Desmotivación | Recompensas atractivas |
| Eliminación accidental | Confirmaciones y backups |
| Manipulación de puntos | Solo administrador modifica |
| Falta de uso | Notificaciones y retos |

---

# 20. Mejoras futuras

- Notificaciones push.
- Evidencia fotográfica.
- Sincronización en la nube.
- Integración con WhatsApp.
- Asistente por voz.
- Calendario familiar.
- Múltiples familias.
- Publicación en tiendas oficiales.

---

# 21. Conclusión

HogarQuest será una aplicación multiplataforma enfocada en la organización del hogar y la motivación familiar. El proyecto combina administración de tareas con gamificación, ofreciendo una experiencia moderna, educativa y útil para la vida diaria. Además, representa un excelente proyecto académico y de portafolio para formación en desarrollo de software.
