const http = require('http');
const fs = require('fs');
const path = require('path');
const config = require('./config.js');

const root = process.env.WEB_ROOT || process.argv[2] || path.join(__dirname, 'web');
const port = parseInt(process.env.PORT || process.argv[3]) || 8080;
const dataFile = process.env.DATA_FILE || process.argv[4] || path.join(__dirname, 'hogarquest_data.json');
const fotosDir = path.join(__dirname, 'fotos');
const WRITE_TOKEN = config.writeToken;
const MONGODB_URI = process.env.MONGODB_URI || '';
let mongo = null;
let mongoReady = false;

if (!fs.existsSync(fotosDir)) fs.mkdirSync(fotosDir, { recursive: true });

const EMPTY = { usuarios: [], tareas: [], asignaciones: [], recompensas: [], canjes: [], insignias: [], castigos: [], retos: [], meta: [] };
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
    const { MongoClient } = await import('mongodb');
    mongo = new MongoClient(MONGODB_URI, { serverSelectionTimeoutMS: 8000 });
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
        const ext = (req.headers['content-type'] || '').includes('png') ? 'png' : 'jpg';
        const name = Date.now() + '-' + Math.random().toString(36).slice(2, 8) + '.' + ext;
        fs.writeFileSync(path.join(fotosDir, name), Buffer.concat(chunks));
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ ok: true, url: '/fotos/' + name }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: String(e) }));
      }
    });
    return;
  }

  // Fotos de perfil guardadas junto al servidor.
  if (url.startsWith('/fotos/')) {
    const f = path.join(fotosDir, path.basename(url));
    fs.readFile(f, (err, data) => {
      if (err) { res.writeHead(404); res.end('Not found'); return; }
      res.writeHead(200, { 'Content-Type': 'image/jpeg' });
      res.end(data);
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

initMongo().finally(() => {
  server.listen(port, '0.0.0.0', () => console.log('HogarQuest server on 0.0.0.0:' + port + ' (db=' + dataFile + ')'));
});
