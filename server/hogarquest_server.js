const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const config = require('./config.js');

const root = process.env.WEB_ROOT || process.argv[2] || path.join(__dirname, 'web');
const port = parseInt(process.env.PORT || process.argv[3]) || 8080;
const dataFile = process.env.DATA_FILE || process.argv[4] || path.join(__dirname, 'hogarquest_data.json');
const fotosDir = process.env.FOTOS_DIR || path.join(__dirname, 'fotos');
const WRITE_TOKEN = config.writeToken;
const MONGODB_URI = process.env.MONGODB_URI || '';
let mongo = null;
let mongoReady = false;
let MongoMod = null; // módulo 'mongodb' importado dinámicamente
let bucket = null;

// Bucket GridFS para las fotos de perfil. Las fotos viven en MongoDB (no en
// el disco del servidor), porque Render borra el disco local en cada redeploy.
function getBucket() {
  if (bucket) return bucket;
  if (mongoReady && mongo && MongoMod) {
    bucket = new MongoMod.GridFSBucket(mongo.db(), { bucketName: 'fotos' });
  }
  return bucket;
}

if (!fs.existsSync(fotosDir)) fs.mkdirSync(fotosDir, { recursive: true });

const EMPTY = { usuarios: [], tareas: [], asignaciones: [], recompensas: [], canjes: [], insignias: [], castigos: [], retos: [], catalogos: [], meta: [] };
const BOXES = Object.keys(EMPTY);
let db = EMPTY;
if (fs.existsSync(dataFile)) {
  try { db = Object.assign({}, EMPTY, JSON.parse(fs.readFileSync(dataFile, 'utf8'))); } catch (e) {}
}
function saveDb() {
  try { fs.writeFileSync(dataFile, JSON.stringify(db)); } catch (e) { console.log('save err', e); }
  // Persistencia en la nube: espejo en MongoDB si está configurado.
  if (mongoReady && mongo) {
    mongo.db().collection('db').updateOne(
      { _id: 'hogarquest' },
      { $set: { data: JSON.stringify(db), updated_at: Date.now() } },
      { upsert: true }
    ).catch((e) => console.log('mongo save err', e));
  }
}
async function initMongo() {
  if (!MONGODB_URI) return;
  try {
    const mod = await import('mongodb');
    MongoMod = mod;
    mongo = new MongoMod.MongoClient(MONGODB_URI, { serverSelectionTimeoutMS: 8000 });
    await mongo.connect();
    const col = mongo.db().collection('db');
    const doc = await col.findOne({ _id: 'hogarquest' });
    mongoReady = true;
    console.log('DB en la nube (MongoDB) conectada');
    if (doc && doc.data) {
      try {
        const remoto = Object.assign({}, EMPTY, JSON.parse(doc.data));
        db = mergeIncoming(remoto);
        saveDb();
        console.log('Datos restaurados desde la nube (' + remoto.usuarios.length + ' usuarios)');
      } catch (e) { console.log('mongo load parse err', e); }
    } else {
      saveDb(); // primera vez: subir lo que haya local/seed
    }
  } catch (e) {
    console.log('Sin MongoDB, sigo con archivo local:', e.message);
  }
}

// --- FIREBASE (push FCM) -------------------------------------------------
let admin = null;
let lastFirebaseError = null;

// Parsea JSON tolerando saltos de línea reales: como whitespace son válidos,
// y dentro de strings (p.ej. private_key) se escapan a \n.
function parseCred(creds) {
  const s = String(creds || '').trim();
  try { return JSON.parse(s); } catch (_) {}
  try {
    const fixed = s.replace(/"(?:\\.|[^"\\])*"/g, (m) => m.replace(/\n/g, '\\n'));
    return JSON.parse(fixed);
  } catch (_) { return null; }
}
async function _leerCredencialFirebase() {
  const fuentes = [];
  if (process.env.FIREBASE_CREDENTIALS_FILE) {
    fuentes.push(() => { try { return fs.readFileSync(process.env.FIREBASE_CREDENTIALS_FILE, 'utf8'); } catch (_) { return null; } });
  }
  if (process.env.FIREBASE_CREDENTIALS) fuentes.push(() => process.env.FIREBASE_CREDENTIALS);
  if (process.env.FIREBASE_CREDENTIALS_B64) fuentes.push(() => process.env.FIREBASE_CREDENTIALS_B64);
  fuentes.push(() => { try { return fs.readFileSync(path.join(__dirname, 'firebase-credentials.json'), 'utf8'); } catch (_) { return null; } });
  if (mongoReady && mongo) {
    try {
      const doc = await mongo.db().collection('config').findOne({ _id: 'firebaseCreds' });
      if (doc && doc.json) fuentes.push(() => doc.json);
    } catch (_) {}
  }
  for (const f of fuentes) {
    const c = f();
    if (!c) continue;
    let obj = parseCred(c);
    if (!obj) {
      try { obj = parseCred(Buffer.from(c.trim(), 'base64').toString('utf8')); } catch (_) {}
    }
    // Solo aceptamos una credencial completa de cuenta de servicio.
    if (obj && obj.project_id && obj.private_key && obj.client_email) return obj;
  }
  return null;
}
async function initFirebase() {
  if (admin) return; // ya inicializado
  const obj = await _leerCredencialFirebase();
  if (!obj) {
    console.log('Sin FIREBASE_CREDENTIALS valido: push FCM desactivado');
    return;
  }
  try {
    admin = require('firebase-admin');
    admin.initializeApp({ credential: admin.credential.cert(obj) });
    console.log('Firebase Admin inicializado (push listo)');
  } catch (e) {
    lastFirebaseError = e && e.message;
    console.log('Firebase init err:', lastFirebaseError);
  }
}

// Almacén de tokens FCM por usuario (Mongo si está disponible, si no memoria).
const _memTokens = new Map(); // userId -> Set(token)
async function guardarToken(userId, token) {
  if (mongoReady && mongo) {
    await mongo.db().collection('deviceTokens').updateOne(
      { userId, token },
      { $set: { userId, token, updated_at: Date.now() } },
      { upsert: true }
    );
    return;
  }
  if (!_memTokens.has(userId)) _memTokens.set(userId, new Set());
  _memTokens.get(userId).add(token);
}
async function quitarToken(userId, token) {
  if (mongoReady && mongo) {
    await mongo.db().collection('deviceTokens').deleteOne({ userId, token });
    return;
  }
  _memTokens.get(userId)?.delete(token);
}
async function tokensDe(userId) {
  if (mongoReady && mongo) {
    const docs = await mongo.db().collection('deviceTokens').find({ userId }).toArray();
    return docs.map((d) => d.token);
  }
  return Array.from(_memTokens.get(userId) || []);
}
async function enviarPush(userId, title, body, data) {
  if (!admin) return { ok: false, reason: 'no-admin' };
  const tokens = await tokensDe(userId);
  if (tokens.length === 0) return { ok: false, reason: 'no-tokens' };
  try {
    const resp = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: data || {},
    });
    if (resp.failureCount > 0) {
      const invalidos = [];
      resp.responses.forEach((r, i) => {
        if (!r.success) {
          const err = r.error && r.error.code;
          if (err === 'messaging/registration-token-not-registered' ||
              err === 'messaging/invalid-registration-token') {
            invalidos.push(tokens[i]);
          }
        }
      });
      for (const t of invalidos) await quitarToken(userId, t);
    }
    return { ok: true, sent: resp.successCount, failed: resp.failureCount };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

// --- RECORDATORIOS DIARIOS (push desde el server) -------------------------
// Cada usuario configura una hora local (minutos del día) y su offset UTC.
// El server envía el push cuando en su hora local coinciden esos minutos.
const _recordatorios = new Map(); // userId -> { minutos, offset, localDate }
async function guardarRecordatorio(userId, minutos, offset) {
  _recordatorios.set(userId, { minutos: Number(minutos), offset: Number(offset || 0), localDate: null });
  if (mongoReady && mongo) {
    await mongo.db().collection('reminders').updateOne(
      { _id: userId },
      { $set: { minutos: Number(minutos), offset: Number(offset || 0) } },
      { upsert: true }
    ).catch(() => {});
  }
}
async function quitarRecordatorio(userId) {
  _recordatorios.delete(userId);
  if (mongoReady && mongo) {
    await mongo.db().collection('reminders').deleteOne({ _id: userId }).catch(() => {});
  }
}
async function cargarRecordatorios() {
  if (!mongoReady || !mongo) return;
  try {
    const docs = await mongo.db().collection('reminders').find({}).toArray();
    for (const d of docs) {
      _recordatorios.set(d._id, { minutos: Number(d.minutos), offset: Number(d.offset || 0), localDate: null });
    }
    console.log('Recordatorios diarios cargados (' + _recordatorios.size + ')');
  } catch (_) {}
}

function _contarAsignaciones(userId, esAdmin) {
  const asig = Array.isArray(db.asignaciones) ? db.asignaciones : [];
  if (esAdmin) {
    return asig.filter((a) => a.completada === 1 && a.aprobada !== 1).length;
  }
  return asig.filter((a) => a.usuario_id === userId && a.completada !== 1 && a.castigada !== 1).length;
}

function iniciarRecordatorios() {
  setInterval(() => {
    if (!admin || _recordatorios.size === 0) return;
    const ahora = Date.now();
    for (const [userId, cfg] of _recordatorios) {
      const local = new Date(ahora + (cfg.offset || 0) * 60000);
      const minutoDelDia = local.getHours() * 60 + local.getMinutes();
      if (minutoDelDia !== cfg.minutos) continue;
      const hoy = local.getFullYear() + '-' + (local.getMonth() + 1) + '-' + local.getDate();
      if (cfg.localDate === hoy) continue;
      cfg.localDate = hoy;
      const u = (Array.isArray(db.usuarios) ? db.usuarios : []).find((x) => x.id === userId);
      const esAdmin = !!(u && u.rol === 'admin');
      const n = _contarAsignaciones(userId, esAdmin);
      if (n === 0) continue;
      if (esAdmin) {
        enviarPush(userId, 'HogarQuest: tareas por revisar',
          'Tienes ' + n + ' tarea' + (n === 1 ? '' : 's') + ' completada' + (n === 1 ? '' : 's') + ' por aprobar.');
      } else {
        enviarPush(userId, 'HogarQuest: tus tareas de hoy',
          'Tienes ' + n + ' tarea' + (n === 1 ? '' : 's') + ' pendiente' + (n === 1 ? '' : 's') + '. ¡Complétalas para ganar puntos!');
      }
    }
  }, 60000);
}

// --- MERGE DE CONFLICTOS -------------------------------------------------
// Cada dispositivo guarda la base completa y la envía. En vez de reemplazar
// todo (que borraría los cambios de otro celular), se fusiona registro por
// registro: gana el que tenga `updated_at` más reciente. Para los borrados se
// usan "tombstones" (marca de borrado con su hora), así no reaparecen.
function idKey(rec, byK) {
  if (!rec) return 'nil';
  if (byK) return 'k:' + (rec.k != null ? rec.k : '');
  const id = rec.id;
  return 'id:' + (id == null ? '__noid__' : id);
}
function ts(rec) { return (rec && rec.updated_at) || 0; }

function mergeBox(listaA, listaB, byK) {
  const res = new Map();
  for (const r of (listaA || [])) res.set(idKey(r, byK), r);
  for (const r of (listaB || [])) {
    const k = idKey(r, byK);
    const old = res.get(k);
    if (!old || ts(r) > ts(old)) res.set(k, r);
  }
  return Array.from(res.values());
}

function mergeIncoming(inc) {
  const out = Object.assign({}, EMPTY);
  for (const box of BOXES) {
    out[box] = mergeBox(db[box] || [], (inc && inc[box]) || [], box === 'meta');
  }

  // Unir tombstones de ambos lados (el más reciente por registro gana).
  const del = new Map();
  const todos = (Array.isArray(db.deleted) ? db.deleted : [])
    .concat(Array.isArray(inc.deleted) ? inc.deleted : []);
  for (const d of todos) {
    if (!d || d.box == null || d.k == null) continue;
    const key = d.box + '|' + d.k;
    const old = del.get(key);
    if (!old || ts(d) > ts(old)) del.set(key, d);
  }
  out.deleted = Array.from(del.values());

  // Aplicar tombstones: un registro borrado con marca más reciente que su
  // `updated_at` no debe resucitar.
  for (const box of BOXES) {
    const byK = box === 'meta';
    out[box] = out[box].filter((r) => {
      const d = del.get(box + '|' + idKey(r, byK));
      return !(d && ts(d) > ts(r));
    });
  }
  return out;
}

const clients = new Set();
function broadcast() {
  const msg = 'data: change\n\n';
  for (const res of clients) { try { res.write(msg); } catch (e) {} }
}

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];

  // CORS: permite que la web (GitHub Pages) y las apps llamen a la API
  // desde un origen distinto al del servidor.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-write-token, authorization');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, up: true }));
    return;
  }

  if (url === '/api/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('retry: 2000\n\n');
    clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }

  if (url === '/api/upload' && req.method === 'POST') {
    if (req.headers['x-write-token'] !== WRITE_TOKEN) {
      res.writeHead(403, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: 'Token de escritura inválido' }));
      return;
    }
    let chunks = [];
    let size = 0;
    req.on('data', (c) => {
      chunks.push(c);
      size += c.length;
      if (size > 8 * 1024 * 1024) req.destroy(); // máx 8 MB
    });
    req.on('end', () => {
      try {
        const mime = req.headers['content-type'] || 'image/jpeg';
        const ext = mime.includes('png') ? 'png' : 'jpg';
        const name = Date.now() + '-' + Math.random().toString(36).slice(2, 8) + '.' + ext;
        const buf = Buffer.concat(chunks);
        const b = getBucket();
        if (b) {
          // Con MongoDB: la foto se guarda en GridFS, dura a través de los
          // redespliegues de Render (el disco local es efímero).
          const up = b.openUploadStream(name, { contentType: mime });
          up.on('error', (e) => {
            try {
              res.writeHead(400, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ ok: false, error: String(e) }));
            } catch (_) {}
          });
          up.on('finish', () => {
            const idHex = up.id.toHexString();
            res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
            res.end(JSON.stringify({ ok: true, url: '/fotos/' + idHex }));
          });
          up.end(buf);
          return;
        }
        fs.writeFileSync(path.join(fotosDir, name), buf);
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true, url: '/fotos/' + name }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  // Fotos de perfil: se sirven desde GridFS (MongoDB) si está disponible,
  // con respaldo en el archivo local cuando no hay conexión a Mongo.
  if (url.startsWith('/fotos/')) {
    const name = path.basename(url).toLowerCase();
    const b = getBucket();
    const esObjectId = /^[0-9a-f]{24}$/.test(name);
    if (b && esObjectId) {
      (async () => {
        try {
          const files = await b.find({ _id: MongoMod.ObjectId.createFromHexString(name) }).toArray();
          if (files.length === 0) {
            res.writeHead(404); res.end('Not found'); return;
          }
          const dl = b.openDownloadStream(files[0]._id);
          res.writeHead(200, { 'Content-Type': files[0].contentType || 'image/jpeg' });
          dl.on('error', () => { try { res.destroy(); } catch (_) {} });
          dl.pipe(res);
        } catch (e) {
          res.writeHead(500, { 'Content-Type': 'text/plain' });
          res.end('error');
        }
      })();
      return;
    }
    const f = path.join(fotosDir, name);
    fs.readFile(f, (err, data) => {
      if (err) { res.writeHead(404); res.end('Not found'); return; }
      res.writeHead(200, { 'Content-Type': 'image/jpeg' });
      res.end(data);
    });
    return;
  }

  if (url === '/api/login' && req.method === 'POST') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      try {
        const { usuario, password } = JSON.parse(body);
        const nombre = String(usuario || '').trim().toLowerCase();
        const u = (db.usuarios || []).find(
          (x) => x && x.nombre && x.nombre.toLowerCase() === nombre);
        if (!u) {
          res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
          res.end(JSON.stringify({ ok: false, error: 'Credenciales inválidas' }));
          return;
        }
        const hash = crypto.createHash('sha256')
          .update((u.salt || '') + '::' + (password || ''))
          .digest('hex');
        if (hash !== u.password) {
          res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
          res.end(JSON.stringify({ ok: false, error: 'Credenciales inválidas' }));
          return;
        }
        const limpio = Object.assign({}, u);
        delete limpio.password;
        delete limpio.salt;
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true, user: limpio }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  if (url === '/api/db' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify(db));
    return;
  }

  if (url === '/api/db' && req.method === 'POST') {
    if (req.headers['x-write-token'] !== WRITE_TOKEN) {
      res.writeHead(403, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: 'Token de escritura inválido' }));
      return;
    }
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      try {
        db = mergeIncoming(JSON.parse(body));
        saveDb();
        broadcast();
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  if (url === '/api/set-firebase-creds' && req.method === 'POST') {
    if (req.headers['x-write-token'] !== WRITE_TOKEN) {
      res.writeHead(403, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: 'Token de escritura inválido' }));
      return;
    }
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', async () => {
      try {
        const obj = JSON.parse(body);
        if (!obj.project_id || !obj.private_key || !obj.client_email) {
          res.writeHead(400, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
          res.end(JSON.stringify({ ok: false, error: 'El JSON no parece una cuenta de servicio de Firebase (falta project_id/private_key/client_email)' }));
          return;
        }
        if (mongoReady && mongo) {
          await mongo.db().collection('config').updateOne(
            { _id: 'firebaseCreds' },
            { $set: { json: body, updated_at: Date.now() } },
            { upsert: true }
          );
        }
        // Respaldo en archivo local (activa el proceso actual sin depender de Mongo).
        try { fs.writeFileSync(path.join(__dirname, 'firebase-credentials.json'), body); } catch (_) {}
        // Activar de inmediato sin reiniciar.
        if (!admin) await initFirebase();
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true, activo: !!admin }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  if (url === '/api/firebase-status' && req.method === 'GET') {
    (async () => {
      let tieneMongo = false;
      let credOk = false;
      let motivo = null;
      let prefix = null;
      if (mongoReady && mongo) {
        try {
          const doc = await mongo.db().collection('config').findOne({ _id: 'firebaseCreds' });
          if (doc && doc.json) {
            tieneMongo = true;
            const s = String(doc.json).trim();
            prefix = JSON.stringify(s.slice(0, 30));
            try {
              const o = parseCred(s);
              if (o && o.project_id && o.private_key && o.client_email) credOk = true;
              else motivo = 'JSON parseable pero sin project_id/private_key/client_email';
            } catch (e) { motivo = 'JSON invalido: ' + (e && e.message ? e.message.slice(0, 120) : String(e)); }
          }
        } catch (e) { motivo = 'read error: ' + e.message; }
      }
      let tieneLocal = false;
      try { tieneLocal = !!fs.readFileSync(path.join(__dirname, 'firebase-credentials.json'), 'utf8'); } catch (_) {}
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({
        admin: !!admin,
        mongoReady,
        tieneCredencialMongo: tieneMongo,
        credencialOk: credOk,
        motivo,
        prefix,
        tieneCredencialLocal: tieneLocal,
        tieneEnvB64: !!process.env.FIREBASE_CREDENTIALS_B64,
        ultimoError: lastFirebaseError,
      }));
    })();
    return;
  }

  if (url === '/api/register-token' && req.method === 'POST') {
    if (req.headers['x-write-token'] !== WRITE_TOKEN) {
      res.writeHead(403, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: 'Token de escritura inválido' }));
      return;
    }
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', async () => {
      try {
        const { userId, token, remove } = JSON.parse(body);
        if (remove) await quitarToken(userId, token);
        else await guardarToken(userId, token);
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  if (url === '/api/notify' && req.method === 'POST') {
    if (req.headers['x-write-token'] !== WRITE_TOKEN) {
      res.writeHead(403, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: 'Token de escritura inválido' }));
      return;
    }
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', async () => {
      try {
        const { userId, title, body: texto, data } = JSON.parse(body);
        const r = await enviarPush(userId, title, texto, data);
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify(r));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  if (url === '/api/reminder' && req.method === 'POST') {
    if (req.headers['x-write-token'] !== WRITE_TOKEN) {
      res.writeHead(403, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: 'Token de escritura inválido' }));
      return;
    }
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', async () => {
      try {
        const { userId, minutos, offset, remove } = JSON.parse(body);
        if (remove) await quitarRecordatorio(userId);
        else await guardarRecordatorio(userId, minutos, offset);
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  let f = path.join(root, url === '/' ? 'index.html' : url);
  if (!fs.existsSync(f)) f = path.join(root, 'index.html');
  const ext = path.extname(f);
  const ct = {
    '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
    '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml',
    '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf',
    '.apk': 'application/vnd.android.package-archive',
  }[ext] || 'text/plain';
  const isApk = ext.toLowerCase() === '.apk';
  fs.readFile(f, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    const headers = { 'Content-Type': ct };
    if (isApk) headers['Content-Disposition'] = 'attachment; filename="hogarquest.apk"';
    res.writeHead(200, headers);
    res.end(data);
  });
});

// Firebase necesita Mongo conectado (lee la credencial de ahí), así que
// esperamos a initMongo antes de initFirebase. Los recordatorios diarios
// también se cargan desde Mongo.
initMongo().then(async () => {
  await cargarRecordatorios();
  await initFirebase();
  iniciarRecordatorios();
}).catch((e) => console.log('init err:', e && e.message)).finally(() => {
  server.listen(port, '0.0.0.0', () => console.log('HogarQuest server on 0.0.0.0:' + port + ' (db=' + dataFile + ')'));
  // Reintentar Firebase si Mongo conectó tarde.
  let reintentos = 0;
  const reintentar = setInterval(() => {
    if (admin) { clearInterval(reintentar); return; }
    if (reintentos++ > 5) { clearInterval(reintentar); return; }
    initFirebase();
  }, 4000);
});
