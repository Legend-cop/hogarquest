# Desplegar HogarQuest en la nube (gratis)

Con esto la app del celular y la web funcionan en cualquier parte, **sin que la PC esté encendida**.

## Opción A: Render (recomendado, más fácil)

1. Ve a https://render.com y crea una cuenta gratuita.
2. Botón **"New +" → "Web Service"**.
3. Conecta tu cuenta de GitHub y sube la carpeta `HogarQuest` a un repositorio (o usa "Public Git repository" si ya está en línea).
4. Configura el Web Service:
   - **Root Directory**: `server`
   - **Build Command**: (vacío)
   - **Start Command**: `npm start`
   - **Instance Type**: Free
5. Da **"Create Web Service"**. Espera 3-5 minutos a que haga deploy.
6. Cuando esté listo tendrás una URL tipo `https://hogarquest-server.onrender.com`.

> Importante: antes del deploy, copia la carpeta `build/web` **dentro de `server/`** (llámala `web`), porque el servidor sirve la web compilada. Puedes generar el build con `flutter build web`.

## Opción B: Railway

1. Ve a https://railway.app y crea una cuenta.
2. **"New Project" → "Deploy from GitHub repo"** (sube `HogarQuest`).
3. Ajusta:
   - **Root Directory**: `server`
   - **Start Command**: `npm start`
   - Mismo paso: copia `build/web` a `server/web`.
4. Railway detecta `package.json` y arranca solo.

## Configurar la app para apuntar a la nube

En `lib/db/server_config.dart` cambia `baseUrl` por la URL de tu servicio en la nube:

```dart
static const String baseUrl = 'https://hogarquest-server.onrender.com';
```

Recompila la app: `flutter build apk` (celular) y `flutter build web`.

## Persistencia de datos

- En Render/Railway **el disco se resetea** en cada redeploy. Para que los datos duren, configura una variable de entorno `DATA_FILE` apuntando a un volumen persistente (ver docs de cada plataforma), o simplemente descarga `hogarquest_data.json` como respaldo regular.
- El token de escritura vive en `server/config.js` y debe coincidir con `ServerConfig.writeToken`.

## Datos iniciales

La primera vez, el servidor sirve `hogarquest_data.json` tal cual. Si quieres empezar limpio, borra el archivo antes del primer deploy o sube uno nuevo desde cualquier cliente con la app (el botón de sincronizar lo reemplaza).
