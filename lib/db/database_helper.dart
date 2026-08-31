import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment.dart';
import '../models/badge.dart';
import '../models/castigo.dart';
import '../models/redemption.dart';
import '../models/reto.dart';
import '../models/reward.dart';
import '../models/tarea_catalogo.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/security_service.dart';
import 'sync_client.dart';

/// Base de datos compartida vía el servidor Node (REST + SSE).
/// Todos los clientes conectados ven los cambios de los demás al instante.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _boxUsuarios = 'usuarios';
  static const _boxTareas = 'tareas';
  static const _boxAsignaciones = 'asignaciones';
  static const _boxRecompensas = 'recompensas';
  static const _boxCanjes = 'canjes';
  static const _boxInsignias = 'insignias';
  static const _boxCastigos = 'castigos';
  static const _boxRetos = 'retos';
  static const _boxCatalogos = 'catalogos';
  static const _boxMeta = 'meta';

  final SyncClient _client = SyncClient();
  final Map<String, _Box> _boxes = {};
  bool _cargado = false;
  Timer? _debounce;

  /// Verdadero cuando el servidor no responde y se están usando datos locales.
  bool _sinConexion = false;
  bool get sinConexion => _sinConexion;

  /// Reintenta la sincronización cada cierto tiempo mientras se está sin
  /// conexión, para recuperar automáticamente cuando el servidor vuelve o el
  /// dispositivo recupera internet (sin esperar a reiniciar la app).
  Timer? _reconnectTimer;

  /// Poll periódico del servidor (incluso con conexión activa). El SSE puede
  /// caerse en móviles (app en segundo plano, cambio de red, Doze) y, al no
  /// haber otro mecanismo de arrastre, las solicitudes de los niños (tareas por
  /// aprobar, canjes) dejaban de llegar al padre. Este poll las trae en ~20 s
  /// aunque el SSE esté caído.
  Timer? _pollTimer;

  /// Caché local: última copia completa de la base de datos. Permite que la
  /// app funcione (y muestre datos correctos) aunque el servidor esté apagado.
  static const _cacheKey = 'hq_db_cache_v1';

  /// Marcas de borrado ("tombstones"): {box, k, updated_at}. Evitan que un
  /// registro eliminado en un teléfono reaparezca al sincronizar el otro.
  final List<Map> _tombstones = [];

  /// Sella un registro con la hora actual para el merge "último que escribe".
  void _sellar(Map m) {
    m['updated_at'] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Clave estable de un registro para comparar versiones entre dispositivos.
  String _idKey(Map m, String boxName) {
    if (boxName == _boxMeta) return 'k:${m['k'] ?? ''}';
    return 'id:${m['id'] ?? '__noid__'}';
  }

  /// Registra la marca de borrado de un registro que se va a eliminar.
  void _tombstone(String boxName, Map m) {
    _tombstones.removeWhere((t) =>
        t['box'] == boxName && t['k'] == _idKey(m, boxName));
    _tombstones.add({
      'box': boxName,
      'k': _idKey(m, boxName),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Se invoca cuando otro cliente cambió datos en el servidor.
  VoidCallback? onRemoteChange;
  bool _cargandoDesdeServidor = false;

  _Box _box(String name) => _boxes.putIfAbsent(name, () => _Box());

  Future<void> init() async {
    await _cargarCache(); // muestra datos al instante aunque el servidor tarde
    // Si quedaron cambios sin sincronizar de la última sesión, se suben antes
    // de recargar, para que no se pierdan al sobreescribir con lo remoto.
    if (_cargado) await _subirLocal();
    await _cargarDesdeServidor();
    _migrarContrasenas();
    await _seedIfEmpty();
    await _seedPerfilesSemana();
    await _seedCatalogo();
    _migrarContrasenas();
    _migrarCategoriasTareas();
    _persistir();
    _client.listen(() async {
      await _cargarDesdeServidor();
      onRemoteChange?.call();
    }, onReconnect: () async {
      // El servidor volvió: primero subimos los cambios hechos sin conexión
      // y luego recargamos para tomar lo que haya cambiado desde otros lados.
      await _subirLocal();
      await _cargarDesdeServidor();
      onRemoteChange?.call();
    });

    // Poll de respaldo aunque haya conexión (ver nota en _pollTimer).
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await _cargarDesdeServidor();
      onRemoteChange?.call();
    });
  }

  /// Empuja el estado local al servidor (esperando a que termine).
  Future<void> _subirLocal() async {
    final db = _exportar();
    await _guardarCache();
    await _client.pushDb(db);
  }

  // --- PUSH (Firebase Cloud Messaging) ------------------------------------

  /// Registra el token FCM de este dispositivo para un usuario en el servidor.
  Future<void> registrarFcmToken(int userId, String token) =>
      _client.registrarFcmToken(userId, token);

  /// Quita el token FCM del usuario (al cerrar sesión).
  Future<void> borrarFcmToken(int userId, String token) =>
      _client.borrarFcmToken(userId, token);

  /// Pide al servidor que envíe un push real al dispositivo del usuario.
  Future<void> enviarPush(int userId, String titulo, String cuerpo,
      [Map<String, String>? data]) =>
      _client.enviarPushFcm(userId, titulo, cuerpo, data);

  Future<void> enviarRecordatorioConfig(int userId, int minutos, int offset) =>
      _client.enviarRecordatorioConfig(userId, minutos, offset);

  Future<void> _cargarDesdeServidor() async {
    if (_cargandoDesdeServidor) return;
    _cargandoDesdeServidor = true;
    try {
      final data = await _client.fetchDb();
      if (data == null || data.isEmpty) {
        // Servidor sin conexión: usamos la última copia guardada en caché.
        _sinConexion = true;
        if (!_cargado) await _cargarCache();
        _iniciarReintentoConexion();
        return;
      }
      _sinConexion = false;
      _detenerReintentoConexion();
      // Se fusiona registro por registro (el más reciente gana) en vez de
      // reemplazar todo: así un cambio local que aún no se ha subido no se
      // pierde al llegar datos remotos de otro dispositivo.
      final victoriaLocal = _mezclar(data);
      _cargado = true;
      await _guardarCache();
      if (victoriaLocal) {
        // Hay cambios locales más nuevos que el servidor no conoce: subirlos.
        await _client.pushDb(_exportar());
      }
    } finally {
      _cargandoDesdeServidor = false;
    }
  }

  void _iniciarReintentoConexion() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_sinConexion) {
        _detenerReintentoConexion();
        return;
      }
      await _subirLocal();
      final sinConexionAntes = _sinConexion;
      await _cargarDesdeServidor();
      // Solo notificamos si el servidor volvió (cambio real de estado), para
      // no disparar recargas pesadas en bucle mientras seguimos sin conexión.
      if (sinConexionAntes && !_sinConexion) onRemoteChange?.call();
    });
  }

  void _detenerReintentoConexion() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Combina los datos remotos con los locales igual que el servidor: por
  /// cada registro gana el de `updated_at` más reciente (LWW) y los
  /// tombstones de ambos lados se unen. Devuelve true si algún registro
  /// local ganó (el servidor no lo tenía), para que el llamador lo suba.
  bool _mezclar(Map data) {
    var victoriaLocal = false;

    // Unir tombstones de ambos lados (el más reciente por registro gana).
    final tombstones = <String, Map>{
      for (final t in _tombstones) '${t['box']}|${t['k']}': t,
    };
    final borradas = data['deleted'];
    if (borradas is List) {
      for (final t in borradas) {
        if (t is! Map) continue;
        final clave = '${t['box']}|${t['k']}';
        final previo = tombstones[clave];
        if (previo == null ||
            (t['updated_at'] as int? ?? 0) >
                (previo['updated_at'] as int? ?? 0)) {
          tombstones[clave] = Map<String, dynamic>.from(t);
        }
      }
    }
    _tombstones
      ..clear()
      ..addAll(tombstones.values);

    for (final entry in data.entries) {
      if (entry.key == 'deleted') continue;
      final boxName = entry.key;
      final box = _box(boxName);
      final lista = entry.value;
      if (lista is! List) continue;

      final locales = <String, Map>{
        for (final m in box.items) _idKey(m, boxName): m,
      };
      final remotos = <String, Map>{};
      for (final e in lista) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        remotos[_idKey(m, boxName)] = m;
      }

      // Resolver cada registro: gana el de updated_at más reciente.
      final resueltos = <Map>[];
      for (final entrada in remotos.entries) {
        final remoto = entrada.value;
        final local = locales[entrada.key];
        if (local != null &&
            (local['updated_at'] as int? ?? 0) >
                (remoto['updated_at'] as int? ?? 0)) {
          resueltos.add(local);
          victoriaLocal = true;
        } else {
          // La foto local es un caché del dispositivo; el servidor no la conoce
          // (es una ruta de archivo local). Si el registro remoto gana,
          // preservamos la foto_local local para que la imagen no desaparezca
          // ni parpadee al sincronizar.
    final ganador = Map<String, dynamic>.from(remoto);
    if (boxName == _boxUsuarios) {
      final flLocal = local?['foto_local'];
      if (flLocal != null && '$flLocal'.isNotEmpty) {
        ganador['foto_local'] = flLocal;
      }
    }
    if (boxName == _boxTareas) {
      final estado = ganador['estado'];
      if (estado == null || '$estado'.trim().isEmpty) {
        ganador['estado'] = 'activa';
      }
      if (ganador['created_at'] == null && local?['created_at'] != null) {
        ganador['created_at'] = local!['created_at'];
      }
    }
    resueltos.add(ganador);
        }
      }
      // Los registros locales que el servidor no tiene se conservan.
      for (final loc in locales.values) {
        if (!remotos.containsKey(_idKey(loc, boxName))) {
          resueltos.add(loc);
          victoriaLocal = true;
        }
      }

      // Aplicar tombstones: un borrado (local o remoto) elimina el registro
      // de forma definitiva. Sin esto, un servidor que no aplica los
      // tombstones (o que re-sella el registro al recibir el push) hace que la
      // tarea "reviva" al sincronizar y el usuario la vea de nuevo al reabrir
      // la app. Un borrado explícito siempre gana sobre el registro.
      final vivos = resueltos.where((r) {
        final id = _idKey(r, boxName);
        final clave = '$boxName|$id';
        final d = tombstones[clave];
        if (d == null) return true;
        final tsTomb = d['updated_at'] as int? ?? 0;
        // created_at es estable: el servidor no lo re-firma. Si la tarea se
        // creó DESPUÉS del borrado, es una nueva con id reusado y se muestra.
        // Si se creó ANTES, era la tarea original que fue borrada y se oculta.
        final tsCreado = r['created_at'] as int? ?? 0;
        return tsCreado > tsTomb;
      }).toList();

      box.items
        ..clear()
        ..addAll(vivos);
    }
    return victoriaLocal;
  }

  /// Guarda la copia actual completa de la base en el dispositivo.
  Future<void> _guardarCache() async {
    try {
      final db = _exportar();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(db));
    } catch (_) {}
  }

  /// Recupera la última copia guardada (para uso sin conexión).
  Future<void> _cargarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      _aplicar(data);
      _cargado = true;
    } catch (_) {}
  }

  /// Rellena las cajas y tombstones a partir de un mapa completo de la base.
  void _aplicar(Map data) {
    _boxes.clear();
    _tombstones.clear();
    final borradas = data['deleted'];
    if (borradas is List) {
      for (final t in borradas) {
        if (t is Map) _tombstones.add(Map<String, dynamic>.from(t));
      }
    }
    for (final entry in data.entries) {
      if (entry.key == 'deleted') continue;
      final box = _box(entry.key);
      final lista = entry.value;
      if (lista is List) {
        for (final e in lista) {
          if (e is Map) box.items.add(Map<String, dynamic>.from(e));
        }
      }
    }
  }

  /// Serializa todas las cajas + tombstones para guardar/persistir.
  Map<String, dynamic> _exportar() {
    final db = <String, dynamic>{};
    for (final entry in _boxes.entries) {
      db[entry.key] = entry.value.items;
    }
    if (_tombstones.isNotEmpty) db['deleted'] = _tombstones;
    return db;
  }

  /// Convierte contraseñas en texto plano a hash SHA-256 con salt.
  void _migrarContrasenas() {
    final box = _box(_boxUsuarios);
    var cambio = false;
    for (final m in box.items) {
      if (m != null && SecurityService.requiereMigracion(m)) {
        final salt = SecurityService.generarSalt();
        m['salt'] = salt;
        m['password'] = SecurityService.hashPassword(m['password'] as String, salt);
        _sellar(m);
        cambio = true;
      }
    }
    if (cambio) _marcar();
  }

  /// Reglas de heurística para reasignar la categoría de una tarea a partir de
  /// palabras clave en su título. El orden define prioridad (la primera
  /// coincidencia gana).
  static const Map<String, List<String>> _reglasCategoria =
      <String, List<String>>{
    'Escuela': <String>[
      'escuela', 'colegio', 'estudiar', 'estudio', 'leer', 'libro', 'examen',
      'clase', 'mate', 'matem', 'español', 'espanol', 'inglés', 'ingles',
      'lengua', 'ciencia', 'historia', 'cuaderno', 'deberes', 'lectura',
      'repasar', 'investigar', 'tarea escolar',
    ],
    'Limpieza': <String>[
      'limpiar', 'limpieza', 'barrer', 'trapear', 'lavar', 'ordenar',
      'recoger', 'aspirar', 'planchar', 'tender', 'platos', 'baño', 'aseo',
      'basura', 'sacudir', 'pulir', 'organizar',
    ],
    'Ejercicio': <String>[
      'ejercicio', 'correr', 'trotar', 'deporte', 'gimnas', 'caminar',
      'yoga', 'bicicleta', 'saltar', 'entrenar', 'flexion', 'sentadilla',
      'estiramiento', 'calentar',
    ],
    'Hogar': <String>[
      'hogar', 'mercado', 'super', 'cocinar', 'preparar comida', 'cuidar',
      'mascota', 'perro', 'jardín', 'jardin', 'regar', 'planta', 'recado',
      'mandado', 'auto',
    ],
    'Salud': <String>[
      'salud', 'dormir', 'cepillar', 'diente', 'bañar', 'bañarse', 'medicina',
      'pastilla', 'tomar agua', 'beber agua', 'fruta', 'verdura', 'vegetal',
      'despertar', 'levantarse', 'higiene', 'ducha', 'descansar', 'sano',
    ],
  };

  /// Reasigna la categoría de las tareas que se guardaron como 'General' por un
  /// bug anterior (la categoría no se persistía). Usa [_categoriaPorTitulo].
  /// Se ejecuta una sola vez por dispositivo (bandera en la caja 'meta').
  void _migrarCategoriasTareas() {
    final meta = _box(_boxMeta);
    final yaMigrado =
        meta.items.any((m) => m != null && m['k'] == 'migracion_categorias_v1');
    if (yaMigrado) return;

    final box = _box(_boxTareas);
    var cambio = false;
    for (final m in box.items) {
      if (m == null) continue;
      final cat = m['categoria'] as String? ?? 'General';
      if (cat != 'General') continue;
      final titulo = (m['titulo'] as String?) ?? '';
      final nueva = _categoriaPorTitulo(titulo);
      if (nueva == 'General') continue;
      m['categoria'] = nueva;
      _sellar(m);
      cambio = true;
    }

    meta.items.add(<String, Object?>{
      'k': 'migracion_categorias_v1',
      'version': 1,
      'aplicado': DateTime.now().toIso8601String(),
    });
    cambio = true; // siempre persiste la bandera, aunque no hubiera tareas
    if (cambio) _marcar();
  }

  String _categoriaPorTitulo(String titulo) {
    final t = titulo.toLowerCase();
    for (final entry in _reglasCategoria.entries) {
      for (final p in entry.value) {
        if (t.contains(p)) return entry.key;
      }
    }
    return 'General';
  }

  void _marcar() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _persistir);
  }

  void _persistir() {
    final db = _exportar();
    // Guardamos localmente siempre (aunque el push falle sin conexión).
    unawaited(_guardarCache());
    _client.pushDb(db);
  }

  Future<void> _seedIfEmpty() async {
    final usuarios = _box(_boxUsuarios);
    if (usuarios.isEmpty) {
      await _addConId(usuarios, _userToMap(User(
        id: 0,
        nombre: 'Admin',
        avatar: '👑',
        edad: 0,
        colorTema: 'azul',
        nivel: 1,
        puntos: 0,
        racha: 0,
        password: 'admin123',
        rol: 'admin',
      )));
      await _addConId(usuarios, _userToMap(User(
        id: 1,
        nombre: 'Integrante Demo',
        avatar: '😀',
        edad: 12,
        colorTema: 'verde',
        nivel: 1,
        puntos: 0,
        racha: 0,
        password: '1234',
        rol: 'integrante',
      )));
    }

    final recompensas = _box(_boxRecompensas);
    if (recompensas.isEmpty) {
      await _addConId(recompensas, _rewardToMap(Reward(nombre: 'Elegir película', descripcion: 'Elige la película de la noche en familia.', costoPuntos: 100)));
      await _addConId(recompensas, _rewardToMap(Reward(nombre: 'Postre favorito', descripcion: 'Elige el postre del fin de semana.', costoPuntos: 150)));
      await _addConId(recompensas, _rewardToMap(Reward(nombre: 'Hora extra de juego', descripcion: 'Una hora extra de juego o pantallas.', costoPuntos: 200)));
      await _addConId(recompensas, _rewardToMap(Reward(nombre: 'Salida por helado', descripcion: 'Salida por helado a tu gusto.', costoPuntos: 300)));
      await _addConId(recompensas, _rewardToMap(Reward(nombre: 'Actividad especial', descripcion: 'Elige una actividad especial para la familia.', costoPuntos: 500)));
    }

    final insignias = _box(_boxInsignias);
    final catalogoInsignias = [
      Badge(id: 1, nombre: 'Maestro de limpieza', descripcion: 'Completaste 10 tareas de limpieza.', icono: 'cleaning_services'),
      Badge(id: 2, nombre: 'Rey de la cocina', descripcion: 'Completaste 10 tareas de cocina.', icono: 'restaurant'),
      Badge(id: 3, nombre: 'Orden perfecto', descripcion: 'Completaste 10 tareas de orden.', icono: 'inventory_2'),
      Badge(id: 4, nombre: 'Puntual', descripcion: 'Completaste 5 tareas antes de la fecha límite.', icono: 'schedule'),
      Badge(id: 5, nombre: 'Racha de 7 días', descripcion: 'Mantuviste una racha de 7 días.', icono: 'local_fire_department'),
      Badge(id: 6, nombre: 'Experto del hogar', descripcion: 'Alcanzaste el nivel 5.', icono: 'emoji_events'),
      Badge(id: 7, nombre: '5 tareas en un día', descripcion: 'Completaste 5 tareas en un solo día.', icono: 'flash_on'),
    ];
    for (final b in catalogoInsignias) {
      final existe =
          insignias.items.where((m) => m['id'] == b.id).isNotEmpty;
      if (!existe) await _addConId(insignias, _badgeToMap(b));
    }
  }

  /// Catálogo por defecto de tareas con sus puntos. Solo se siembra si la caja
  /// está vacía, para que las ediciones del admin se respeten.
  Future<void> _seedCatalogo() async {
    final box = _box(_boxCatalogos);
    if (box.items.isNotEmpty) return;
    const defs = <(String, int)>[
      ('Orar', 10),
      ('Leer la Biblia', 10),
      ('Ir a la iglesia', 15),
      ('Cocinar', 8),
      ('Lavar baño', 7),
      ('Lavar ropa', 6),
      ('Trapear', 5),
      ('Organizar patio', 5),
      ('Organizar nevera', 5),
      ('Lavar loza', 4),
      ('Arreglar multimueble', 3),
      ('Arreglar peinadora', 3),
      ('Barrer', 2),
      ('Doblar ropa', 2),
      ('Ordenar cuarto', 1),
    ];
    for (final (titulo, puntos) in defs) {
      await _addConId(
          box, _catalogoToMap(TareaCatalogo(titulo: titulo, puntos: puntos)));
    }
    _marcar();
  }

  Future<void> _seedPerfilesSemana() async {
    final usuarios = _box(_boxUsuarios);
    final tareas = _box(_boxTareas);
    final asignaciones = _box(_boxAsignaciones);
    final meta = _box(_boxMeta);

    // La semana se regenera sola: al cambiar la versión del horario o al
    // empezar una semana nueva (domingo). Solo se crean tareas desde HOY en
    // adelante, así un reinicio a mitad de semana no genera tareas ya
    // vencidas (y por lo tanto no castiga al instante). La semana va de
    // domingo a sábado (domingo = primer día).
    const versionSeed = 6;
    final hoy = DateTime.now();
    final inicioSemana = hoy.subtract(Duration(days: hoy.weekday % 7));
    final claveSemana =
        '${inicioSemana.year}-${inicioSemana.month}-${inicioSemana.day}';
    final semilla = meta.get('seed_horario');

    // Regeneración NO destructiva:
    //  * La limpieza solo ocurre cuando la semana guardada es ANTERIOR a la
    //    actual (empezó un domingo nuevo), y borra únicamente asignaciones
    //    PENDIENTES de semanas pasadas (las completadas quedan como historial).
    //  * Nunca borra asignaciones de la semana actual ni las completadas/
    //    aprobadas, ni tareas (algunas las crea el admin). Así un reinicio a
    //    mitad de semana o un celular con datos viejos NO puede borrar el
    //    trabajo ya hecho.
    //  * Si el marcador falta o la versión cambió pero es la misma semana,
    //    solo se actualiza el marcador y se crea lo que falte (crear es
    //    idempotente: no duplica).
    final inicio =
        DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);

    bool esSemanaAnterior(String? s) {
      if (s is! String) return false;
      final p = s.split('-');
      if (p.length != 3) return false;
      final a = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (a == null || m == null || d == null) return false;
      return DateTime(a, m, d).isBefore(inicio);
    }

    final semanaGuardada = semilla is Map ? semilla['semana'] : null;
    if (esSemanaAnterior(semanaGuardada)) {
      for (var i = asignaciones.items.length - 1; i >= 0; i--) {
        final a = asignaciones.items[i];
        final fa = DateTime.tryParse(a['fecha_asignada'] ?? '');
        final completada = a['completada'] == 1 || a['aprobada'] == 1;
        if (fa != null && fa.isBefore(inicio) && !completada) {
          _tombstone(_boxAsignaciones, a);
          asignaciones.items.removeAt(i);
        }
      }
    }

    // Marcador con hora: así se propaga entre dispositivos (LWW) y la
    // regeneración de otros teléfonos se vuelve inofensiva.
    final registro = {'version': versionSeed, 'semana': claveSemana};
    _sellar(registro);
    meta.put('seed_horario', registro);

    const dias = [
      'domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado',
    ];
    // 0 = domingo … 6 = sábado. Los días anteriores a hoy no se crean.
    final desdeHoy = hoy.weekday % 7;

    int? idUsuario(String nombre) {
      for (final m in usuarios.items) {
        if (m['nombre'] == nombre) return m['id'] as int?;
      }
      return null;
    }

    int? idTarea(String titulo, String dia) {
      for (final m in tareas.items) {
        if (m['titulo'] == titulo && m['dia'] == dia) return m['id'] as int?;
      }
      return null;
    }

    bool tieneAsignacion(int usuarioId, int tareaId) {
      for (final m in asignaciones.items) {
        if (m['usuario_id'] == usuarioId && m['tarea_id'] == tareaId) {
          return true;
        }
      }
      return false;
    }

    Future<int> crearUsuario(String nombre, String avatar) async {
      final id = idUsuario(nombre);
      if (id != null) return id;
      String colorLibre() {
        final usados = <String>{
          for (final m in usuarios.items)
            if (User.claveColor(m['color_tema'] as String?) != null)
              User.claveColor(m['color_tema'] as String?)!,
        };
        for (final n in User.nombresPaleta) {
          if (!usados.contains(n)) return n;
        }
        return User.nombresPaleta.first;
      }

      return _addConId(usuarios, _userToMap(User(
        nombre: nombre,
        avatar: avatar,
        colorTema: colorLibre(),
        password: '1234',
        rol: 'integrante',
      )));
    }

    bool tareaNueva = false;

    Future<int> crearTarea(
      String titulo,
      String descripcion,
      int puntos,
      String dificultad,
      String dia,
    ) async {
      final id = idTarea(titulo, dia);
      if (id != null) {
        tareaNueva = false;
        return id;
      }
      tareaNueva = true;
      return _addConId(tareas, _taskToMap(Task(
        titulo: titulo,
        descripcion: descripcion,
        puntos: puntos,
        dificultad: dificultad,
        frecuencia: 'semanal',
        dia: dia,
      )));
    }

    Future<void> asignar(int usuarioId, int tareaId) async {
      if (tieneAsignacion(usuarioId, tareaId)) return;
      debugPrint('[seed:asignar] usuarioId=$usuarioId tareaId=$tareaId');
      await _addConId(asignaciones, _assignmentToMap(Assignment(
        usuarioId: usuarioId,
        tareaId: tareaId,
        fechaAsignada: DateTime.now(),
      )));
    }

    final nataliaId = await crearUsuario('Natalia', '👩');
    final emanuelId = await crearUsuario('Emanuel', '👦');
    final saraisId = await crearUsuario('Sarais', '👧');

    final ids = <String, int>{
      'Natalia': nataliaId,
      'Emanuel': emanuelId,
      'Sarais': saraisId,
    };

    String dificultad(int puntos) =>
        puntos >= 10 ? 'dificil' : (puntos >= 6 ? 'media' : 'facil');

    Future<void> conjunta(int tareaId) async {
      final existentes = await getAsignacionesPorTarea(tareaId);
      if (existentes.isNotEmpty) return;
      for (final id in ids.values) {
        await asignar(id, tareaId);
      }
    }

    // Distribución semanal de tareas del hogar: [día][niño] -> tareas.
    // Cada tarea: (título, descripción, puntos).
    const planHogar = <String, Map<String, List<(String, String, int)>>>{
      'domingo': {
        'Natalia': [
          ('Cocinar', 'Preparar la comida del día.', 8),
          ('Lavar ropa', 'Lavar la ropa de la semana.', 6),
        ],
        'Emanuel': [
          ('Lavar loza', 'Lavar los platos de las 3 comidas.', 4),
          ('Lavar baño', 'Lavar el baño completo.', 7),
          ('Arreglar peinadora', 'Arreglar las peinadoras.', 3),
        ],
        'Sarais': [
          ('Barrer', 'Barrer el piso de la casa.', 2),
          ('Ordenar cuarto', 'Organizar y ordenar el cuarto.', 1),
          ('Trapear', 'Trapear el piso.', 5),
          ('Doblar ropa', 'Doblar la ropa limpia.', 2),
          ('Arreglar multimueble', 'Arreglar el multimueble.', 3),
        ],
      },
      'lunes': {
        'Natalia': [
          ('Barrer', 'Barrer el piso de la casa.', 2),
          ('Ordenar cuarto', 'Organizar y ordenar el cuarto.', 1),
          ('Organizar patio', 'Organizar el patio.', 5),
        ],
        'Emanuel': [
          ('Cocinar', 'Preparar la comida del día.', 8),
        ],
        'Sarais': [
          ('Lavar loza', 'Lavar los platos de las 3 comidas.', 4),
        ],
      },
      'martes': {
        'Natalia': [
          ('Lavar loza', 'Lavar los platos de las 3 comidas.', 4),
          ('Lavar ropa', 'Lavar la ropa de la semana.', 6),
        ],
        'Emanuel': [
          ('Cocinar', 'Preparar la comida del día.', 8),
          ('Trapear', 'Trapear el piso.', 5),
        ],
        'Sarais': [
          ('Barrer', 'Barrer el piso de la casa.', 2),
          ('Ordenar cuarto', 'Organizar y ordenar el cuarto.', 1),
          ('Doblar ropa', 'Doblar la ropa limpia.', 2),
        ],
      },
      'miercoles': {
        'Natalia': [
          ('Cocinar', 'Preparar la comida del día.', 8),
          ('Arreglar multimueble', 'Arreglar el multimueble.', 3),
          ('Arreglar peinadora', 'Arreglar las peinadoras.', 3),
        ],
        'Emanuel': [
          ('Ordenar cuarto', 'Organizar y ordenar el cuarto.', 1),
          ('Lavar baño', 'Lavar el baño completo.', 7),
        ],
        'Sarais': [
          ('Barrer', 'Barrer el piso de la casa.', 2),
          ('Lavar loza', 'Lavar los platos de las 3 comidas.', 4),
        ],
      },
      'jueves': {
        'Natalia': [
          ('Barrer', 'Barrer el piso de la casa.', 2),
          ('Ordenar cuarto', 'Organizar y ordenar el cuarto.', 1),
          ('Lavar ropa', 'Lavar la ropa de la semana.', 6),
        ],
        'Emanuel': [
          ('Trapear', 'Trapear el piso.', 5),
          ('Organizar nevera', 'Organizar la nevera.', 5),
        ],
        'Sarais': [
          ('Cocinar', 'Preparar la comida del día.', 8),
          ('Lavar loza', 'Lavar los platos de las 3 comidas.', 4),
          ('Doblar ropa', 'Doblar la ropa limpia.', 2),
        ],
      },
      'viernes': {
        'Emanuel': [
          ('Barrer', 'Barrer el piso de la casa.', 2),
        ],
        'Sarais': [
          ('Ordenar cuarto', 'Organizar y ordenar el cuarto.', 1),
          ('Cocinar', 'Preparar la comida del día.', 8),
          ('Lavar loza', 'Lavar los platos de las 3 comidas.', 4),
        ],
        // Natalia: descanso, sin tareas del hogar.
      },
      // 'sabado': DÍA DEL SEÑOR, sin tareas del hogar.
    };

    // --- TAREAS DEL HOGAR (distribución fija por día y niño). ---
    for (var i = desdeHoy; i < dias.length; i++) {
      final dia = dias[i];
      final porPersona = planHogar[dia];
      if (porPersona == null) continue;
      for (final entry in porPersona.entries) {
        final usuarioId = ids[entry.key];
        if (usuarioId == null) continue;
        for (final (titulo, descripcion, puntos) in entry.value) {
          final tareaId = await crearTarea(
              titulo, descripcion, puntos, dificultad(puntos), dia);
          if (tareaNueva) await asignar(usuarioId, tareaId);
        }
      }
    }

    // --- VIDA ESPIRITUAL (todos): oración y Biblia cada día.
    // --- Sábado (DÍA DEL SEÑOR): además, ir a la iglesia. ---
    for (var i = desdeHoy; i < dias.length; i++) {
      final dia = dias[i];
      final oracion =
          await crearTarea('Orar', 'Hacer oración en familia.', 10, 'facil', dia);
      if (tareaNueva) await conjunta(oracion);
      final biblia = await crearTarea(
          'Leer la Biblia', 'Leer la Biblia en familia.', 10, 'facil', dia);
      if (tareaNueva) await conjunta(biblia);
      if (dia == 'sabado') {
        final iglesia = await crearTarea(
            'Ir a la iglesia', 'Asistir al servicio en familia.', 10, 'facil', dia);
        if (tareaNueva) await conjunta(iglesia);
      }
    }
  }

  // ---------------------------------------------------------------
  // CONVERSIÓN A/DE MAP
  // ---------------------------------------------------------------
  Map<String, dynamic> _userToMap(User u) {
    return {
      'id': u.id,
      'nombre': u.nombre,
      'avatar': u.avatar,
      'foto': u.foto,
      'foto_local': u.fotoLocal,
      'edad': u.edad,
      'color_tema': u.colorTema,
      'nivel': u.nivel,
      'puntos': u.puntos,
      'racha': u.racha,
      'password': u.password,
      'salt': u.salt,
      'rol': u.rol,
      'activo': u.activo ? 1 : 0,
      'pin': u.pin,
    };
  }

  User _mapToUser(Map map) {
    return User(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      avatar: (map['avatar'] as String?) ?? '',
      foto: (map['foto'] as String?) ?? '',
      fotoLocal: (map['foto_local'] as String?) ?? '',
      edad: (map['edad'] as int?) ?? 0,
      colorTema: (map['color_tema'] as String?) ?? '',
      nivel: (map['nivel'] as int?) ?? 1,
      puntos: (map['puntos'] as int?) ?? 0,
      racha: (map['racha'] as int?) ?? 0,
      password: (map['password'] as String?) ?? '',
      salt: (map['salt'] as String?) ?? '',
      rol: (map['rol'] as String?) ?? 'integrante',
      activo: (map['activo'] as int? ?? 1) == 1,
      pin: (map['pin'] as String?) ?? '',
    );
  }

  Map<String, dynamic> _castigoToMap(Castigo c) {
    return {
      'id': c.id,
      'usuario_id': c.usuarioId,
      'motivo': c.motivo,
      'puntos': c.puntos,
      'tipo': c.tipo,
      'tarea_id': c.tareaId,
      'fecha': c.fecha.toIso8601String(),
    };
  }

  Castigo _mapToCastigo(Map map) {
    return Castigo.fromMap(Map<String, Object?>.from(map));
  }

  Map<String, dynamic> _taskToMap(Task t) {
    return {
      'id': t.id,
      'titulo': t.titulo,
      'descripcion': t.descripcion,
      'puntos': t.puntos,
      'dificultad': t.dificultad,
      'fecha_limite': t.fechaLimite?.toIso8601String(),
      'frecuencia': t.frecuencia,
      'estado': t.estado,
      'dia': t.dia,
      'categoria': t.categoria,
    };
  }

  Task _mapToTask(Map map) {
    return Task(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      dificultad: (map['dificultad'] as String?) ?? 'media',
      fechaLimite: map['fecha_limite'] != null ? DateTime.tryParse(map['fecha_limite'] as String) : null,
      frecuencia: (map['frecuencia'] as String?) ?? 'unica',
      estado: (map['estado'] as String?) ?? 'activa',
      dia: (map['dia'] as String?) ?? '',
      categoria: (map['categoria'] as String?) ?? 'General',
    );
  }

  Map<String, dynamic> _assignmentToMap(Assignment a) {
    return {
      'id': a.id,
      'usuario_id': a.usuarioId,
      'tarea_id': a.tareaId,
      'completada': a.completada ? 1 : 0,
      'aprobada': a.aprobada ? 1 : 0,
      'castigada': a.castigada ? 1 : 0,
      'fecha_completada': a.fechaCompletada?.toIso8601String(),
      'fecha_asignada': a.fechaAsignada?.toIso8601String(),
      'fecha_aprobada': a.fechaAprobada?.toIso8601String(),
    };
  }

  Assignment _mapToAssignment(Map map) {
    return Assignment(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      tareaId: map['tarea_id'] as int,
      completada: (map['completada'] as int? ?? 0) == 1,
      aprobada: (map['aprobada'] as int? ?? 0) == 1,
      castigada: (map['castigada'] as int? ?? 0) == 1,
      fechaCompletada: map['fecha_completada'] != null ? DateTime.tryParse(map['fecha_completada'] as String) : null,
      fechaAsignada: map['fecha_asignada'] != null ? DateTime.tryParse(map['fecha_asignada'] as String) : null,
      fechaAprobada: map['fecha_aprobada'] != null ? DateTime.tryParse(map['fecha_aprobada'] as String) : null,
    );
  }

  Map<String, dynamic> _rewardToMap(Reward r) {
    return {
      'id': r.id,
      'nombre': r.nombre,
      'descripcion': r.descripcion,
      'costo_puntos': r.costoPuntos,
      'foto': r.foto,
    };
  }

  Reward _mapToReward(Map map) {
    return Reward(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      costoPuntos: (map['costo_puntos'] as int?) ?? 0,
      foto: (map['foto'] as String?) ?? '',
    );
  }

  Map<String, dynamic> _redemptionToMap(Redemption r) {
    return {
      'id': r.id,
      'usuario_id': r.usuarioId,
      'recompensa_id': r.recompensaId,
      'fecha': r.fecha.toIso8601String(),
      'estado': r.estado,
    };
  }

  Redemption _mapToRedemption(Map map) {
    return Redemption(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      recompensaId: map['recompensa_id'] as int,
      fecha: DateTime.tryParse(map['fecha'] as String) ?? DateTime.now(),
      estado: (map['estado'] as String?) ?? 'pendiente',
    );
  }

  Map<String, dynamic> _badgeToMap(Badge b) {
    return {
      'id': b.id,
      'nombre': b.nombre,
      'descripcion': b.descripcion,
      'icono': b.icono,
    };
  }

  Badge _mapToBadge(Map map) {
    return Badge(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      icono: (map['icono'] as String?) ?? 'emoji_events',
    );
  }

  // ---------------------------------------------------------------
  // USUARIOS
  // ---------------------------------------------------------------
  Future<int> _addConId(_Box box, Map<String, dynamic> map) async {
    final key = box.add(map);
    if (map['id'] == null) map['id'] = key;
    _sellar(map);
    // Al (re)crear un registro se cancela la marca de borrado previa de ese
    // id. Los ids se reusan, y si antes se borró otra tarea con el mismo id el
    // tombstone la ocultaría; al crearla otra vez el usuario debe verla.
    final idKey = 'id:${map['id']}';
    _tombstones.removeWhere((t) => t['k'] == idKey);
    _marcar();
    return key;
  }

  Future<int> insertUsuario(User u) async {
    final box = _box(_boxUsuarios);
    var usuario = u;
    if (User.claveColor(u.colorTema) == null) {
      final integrantes = await getIntegrantes(soloActivos: false);
      usuario = u.copyWith(colorTema: User.colorLibre(integrantes));
    }
    return _addConId(box, _userToMap(_asegurarHash(usuario)));
  }

  Future<List<User>> getUsuarios() async {
    final box = _box(_boxUsuarios);
    return box.items.map(_mapToUser).toList();
  }

  Future<List<User>> getIntegrantes({bool soloActivos = true}) async {
    final box = _box(_boxUsuarios);
    return box.items
        .where((m) => (m['rol'] as String?) != 'admin')
        .where((m) {
          if (!soloActivos) return true;
          final activo = m['activo'] as int?;
          return activo == null || activo == 1;
        })
        .map(_mapToUser)
        .toList();
  }

  Future<User?> getUserById(int id) async {
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == id) return _mapToUser(m);
    }
    return null;
  }

  Future<User?> login(String nombre, String password) async {
    // Auth server-side: la web ya no descarga las contraseñas.
    try {
      final remote = await _client.loginServerSide(nombre, password);
      if (remote != null) return _mapToUser(remote);
    } catch (_) {}

    // Fallback local (solo si el servidor no está disponible).
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['nombre'] == nombre) {
        // Un usuario sin el campo 'activo' se considera activo.
        final activo = m['activo'] as int?;
        if (activo != null && activo != 1) return null;
        // Migración: contraseña en texto plano (datos viejos)
        if (SecurityService.requiereMigracion(m)) {
          final salt = SecurityService.generarSalt();
          m['salt'] = salt;
          m['password'] = SecurityService.hashPassword(m['password'] as String, salt);
          _sellar(m);
          _marcar();
        }
        final salt = (m['salt'] as String?) ?? '';
        if (m['password'] == SecurityService.hashPassword(password, salt)) {
          return _mapToUser(m);
        }
        return null;
      }
    }
    return null;
  }

  Future<void> setUsuarioActivo(int id, bool activo) async {
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        m['activo'] = activo ? 1 : 0;
        _sellar(m);
        _marcar();
        return;
      }
    }
  }

  /// Restablece la contraseña de un usuario generando un nuevo salt+hash.
  Future<void> setPassword(int id, String nueva) async {
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        final salt = SecurityService.generarSalt();
        m['salt'] = salt;
        m['password'] = SecurityService.hashPassword(nueva, salt);
        _sellar(m);
        _marcar();
        return;
      }
    }
  }

  Future<int> updateUsuario(User u) async {
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == u.id) {
        final nuevo = _userToMap(_asegurarHash(u));
        _sellar(nuevo);
        box.items[i] = nuevo;
        _marcar();
        return i;
      }
    }
    return _addConId(box, _userToMap(_asegurarHash(u)));
  }

  /// Aplica hash a la contraseña si aún no tiene salt (nuevo/cambiado).
  User _asegurarHash(User u) {
    if (u.salt.isNotEmpty) return u;
    final salt = SecurityService.generarSalt();
    return u.copyWith(password: SecurityService.hashPassword(u.password, salt), salt: salt);
  }

  Future<void> deleteUsuario(int id) async {
    final box = _box(_boxUsuarios);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        // Delete related assignments
        final asignaciones = _box(_boxAsignaciones);
        for (var j = asignaciones.items.length - 1; j >= 0; j--) {
          final a = asignaciones.items[j];
          if (a != null && a['usuario_id'] == id) {
            _tombstone(_boxAsignaciones, a);
            asignaciones.items.removeAt(j);
          }
        }
        // Delete related redemptions
        final canjes = _box(_boxCanjes);
        for (var j = canjes.items.length - 1; j >= 0; j--) {
          final c = canjes.items[j];
          if (c != null && c['usuario_id'] == id) {
            _tombstone(_boxCanjes, c);
            canjes.items.removeAt(j);
          }
        }
        _tombstone(_boxUsuarios, m);
        box.items.removeAt(i);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // RESPALDO
  // ---------------------------------------------------------------

  /// Devuelve una copia completa de la base de datos local (para respaldo).
  Map<String, dynamic> exportarDb() => _exportar();

  /// Reemplaza la base de datos local por el contenido de un respaldo.
  /// Sella los registros con la hora actual para que, al sincronizar, el
  /// servidor prefiera esta versión (merge "último que escribe").
  Future<void> importarDb(Map<String, dynamic> data) async {
    final nombres = [
      _boxUsuarios,
      _boxTareas,
      _boxAsignaciones,
      _boxRecompensas,
      _boxCanjes,
      _boxInsignias,
      _boxCastigos,
      _boxRetos,
      _boxCatalogos,
      _boxMeta,
    ];
    for (final nombre in nombres) {
      final box = _box(nombre);
      final lista = data[nombre];
      final items = <Map<String, dynamic>>[];
      if (lista is List) {
        for (final raw in lista) {
          if (raw is Map) {
            final copia = Map<String, dynamic>.from(raw);
            _sellar(copia);
            items.add(copia);
          }
        }
      }
      box.items.clear();
      box.items.addAll(items);
    }
    _tombstones.clear();
    final dels = data['deleted'];
    if (dels is List) {
      for (final raw in dels) {
        if (raw is Map) {
          final copia = Map<String, dynamic>.from(raw);
          copia['updated_at'] = DateTime.now().millisecondsSinceEpoch;
          _tombstones.add(copia);
        }
      }
    }
    _cargado = true;
    _migrarContrasenas();
    _persistir();
  }

  /// Borra por completo la base de datos (cajas + tombstones + caché).
  /// Solo mantiene el usuario Admin para que el dueño pueda volver a entrar.
  Future<void> reiniciarDatos() async {
    for (final box in _boxes.values) {
      box.items.clear();
    }
    _tombstones.clear();
    // Crear solo el usuario Admin para que pueda entrar de nuevo.
    await _addConId(_box(_boxUsuarios), _userToMap(User(
      id: 0,
      nombre: 'Admin',
      avatar: '👑',
      edad: 0,
      colorTema: 'azul',
      nivel: 1,
      puntos: 0,
      racha: 0,
      password: 'admin123',
      rol: 'admin',
    )));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    _cargado = false;
    _persistir();
  }

  // ---------------------------------------------------------------
  // SINCRONIZACIÓN P2P LOCAL (misma red, sin internet)
  // ---------------------------------------------------------------

  /// Estado completo de la base para intercambiar con otro dispositivo en la
  /// misma red local. Reutiliza el formato de `_exportar` (cajas + tombstones
  /// con `updated_at`), de modo que el peer puede fusionarlo con LWW.
  Map<String, dynamic> exportarParaP2P() => _exportar();

  /// Fusiona el estado recibido de otro dispositivo (LWW + tombstones).
  Future<void> mezclarDesdePar(Map<String, dynamic> data) async {
    if (data is! Map || data.isEmpty) return;
    _mezclar(data);
    await _guardarCache();
    onRemoteChange?.call();
  }

  /// Código de hogar que acota la sincronización P2P a la misma familia.
  /// Se genera una vez y se propaga entre dispositivos vía la nube (meta).
  String get householdCode {
    final meta = _box(_boxMeta);
    final v = meta.get('household_code');
    if (v is Map && v['code'] is String && (v['code'] as String).isNotEmpty) {
      return v['code'] as String;
    }
    final code = _generarHouseholdCode();
    final copia = <String, dynamic>{'code': code};
    _sellar(copia);
    meta.put('household_code', copia);
    _marcar();
    return code;
  }

  static String _generarHouseholdCode() {
    final r = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ---------------------------------------------------------------
  // TAREAS
  // ---------------------------------------------------------------
  Future<int> insertTarea(Task t) async {
    final box = _box(_boxTareas);
    final map = _taskToMap(t);
    map['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
    final id = _addConId(box, map);
    unawaited(_guardarCache());
    return id;
  }

  Future<List<Task>> getTareas() async {
    final box = _box(_boxTareas);
    return box.items.map(_mapToTask).toList();
  }

  Future<List<Task>> getTareasActivas() async {
    final box = _box(_boxTareas);
    return box.items
        .where((m) => m['estado'] == 'activa' || m['estado'] == null)
        .map(_mapToTask)
        .toList();
  }

  Future<Task?> getTareaById(int id) async {
    final box = _box(_boxTareas);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == id) return _mapToTask(m);
    }
    return null;
  }

  Future<int> updateTarea(Task t) async {
    final box = _box(_boxTareas);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == t.id) {
        final nuevo = _taskToMap(t);
        nuevo['created_at'] = m['created_at'];
        _sellar(nuevo);
        box.items[i] = nuevo;
        _marcar();
        return i;
      }
    }
    return _addConId(box, _taskToMap(t));
  }

  Future<void> deleteTarea(int id) async {
    final box = _box(_boxTareas);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        final asignaciones = _box(_boxAsignaciones);
        for (var j = asignaciones.items.length - 1; j >= 0; j--) {
          final a = asignaciones.items[j];
          if (a != null && a['tarea_id'] == id) {
            _tombstone(_boxAsignaciones, a);
            asignaciones.items.removeAt(j);
          }
        }
        _tombstone(_boxTareas, m);
        box.items.removeAt(i);
        _marcar();
        unawaited(_guardarCache());
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // ASIGNACIONES
  // ---------------------------------------------------------------
  Future<int> insertAsignacion(Assignment a) async {
    final existing = await getAsignacion(a.usuarioId, a.tareaId);
    if (existing != null) {
      debugPrint('[insertAsignacion] DUPLICADO omitido usuarioId=${a.usuarioId} tareaId=${a.tareaId} existingId=${existing.id}');
      return existing.id!;
    }
    final box = _box(_boxAsignaciones);
    final id = _addConId(box, _assignmentToMap(a));
    debugPrint('[insertAsignacion] NUEVA usuarioId=${a.usuarioId} tareaId=${a.tareaId} newId=$id');
    return id;
  }

  Future<void> eliminarAsignacion(int id) async {
    final box = _box(_boxAsignaciones);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        _tombstone(_boxAsignaciones, m);
        box.items.removeAt(i);
        _marcar();
        return;
      }
    }
  }

  Future<int> updateAsignacion(Assignment a) async {
    final box = _box(_boxAsignaciones);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['usuario_id'] == a.usuarioId && m['tarea_id'] == a.tareaId) {
        final nuevo = _assignmentToMap(a);
        _sellar(nuevo);
        box.items[i] = nuevo;
        _marcar();
        return i;
      }
    }
    return _addConId(box, _assignmentToMap(a));
  }

  Future<List<Assignment>> getAsignacionesDeUsuario(int usuarioId) async {
    final box = _box(_boxAsignaciones);
    return box.items.where((m) => m['usuario_id'] == usuarioId).map(_mapToAssignment).toList();
  }

  Future<List<Assignment>> getAsignacionesPorTarea(int tareaId) async {
    final box = _box(_boxAsignaciones);
    return box.items.where((m) => m['tarea_id'] == tareaId).map(_mapToAssignment).toList();
  }

  Future<List<Assignment>> getAsignacionesPorAprobar() async {
    final box = _box(_boxAsignaciones);
    return box.items.where((m) => m['completada'] == 1 && m['aprobada'] == 0).map(_mapToAssignment).toList();
  }

  Future<Assignment?> getAsignacion(int usuarioId, int tareaId) async {
    final box = _box(_boxAsignaciones);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['usuario_id'] == usuarioId && m['tarea_id'] == tareaId) {
        return _mapToAssignment(m);
      }
    }
    return null;
  }

  /// Todas las asignaciones de todos los integrantes (para la vista semanal
  /// del admin: saber quién tiene cada tarea).
  Future<List<Assignment>> getTodasLasAsignaciones() async {
    final box = _box(_boxAsignaciones);
    return box.items.map(_mapToAssignment).toList();
  }

  /// Asignaciones no completadas (para detectar tareas vencidas).
  Future<List<Assignment>> getAsignacionesPendientes() async {
    final box = _box(_boxAsignaciones);
    return box.items
        .where((m) => m['completada'] == 0)
        .map(_mapToAssignment)
        .toList();
  }

  Future<List<Assignment>> getAsignacionesAprobadas(int usuarioId) async {
    final box = _box(_boxAsignaciones);
    return box.items
        .where((m) => m['usuario_id'] == usuarioId && m['aprobada'] == 1)
        .map(_mapToAssignment)
        .toList();
  }

  Future<List<Assignment>> getAsignacionesAprobadasDeUsuarioEnRango(
    int usuarioId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final box = _box(_boxAsignaciones);
    return box.items
        .where((m) =>
            m['usuario_id'] == usuarioId &&
            m['aprobada'] == 1 &&
            m['fecha_aprobada'] != null)
        .map(_mapToAssignment)
        .where((a) =>
            a.fechaAprobada != null &&
            a.fechaAprobada!.isAfter(inicio) &&
            a.fechaAprobada!.isBefore(fin))
        .toList();
  }

  /// Asignaciones aprobadas de todos los integrantes dentro del rango.
  Future<List<Assignment>> getAsignacionesAprobadasEnRango(
    DateTime inicio,
    DateTime fin,
  ) async {
    final box = _box(_boxAsignaciones);
    return box.items
        .where((m) => m['aprobada'] == 1 && m['fecha_aprobada'] != null)
        .map(_mapToAssignment)
        .where((a) =>
            a.fechaAprobada != null &&
            a.fechaAprobada!.isAfter(inicio) &&
            a.fechaAprobada!.isBefore(fin))
        .toList();
  }

  // ---------------------------------------------------------------
  // RECOMPENSAS
  // ---------------------------------------------------------------
  Future<int> insertRecompensa(Reward r) async {
    final box = _box(_boxRecompensas);
    return _addConId(box, _rewardToMap(r));
  }

  Future<List<Reward>> getRecompensas() async {
    final box = _box(_boxRecompensas);
    return box.items.map(_mapToReward).toList();
  }

  Future<int> updateRecompensa(Reward r) async {
    final box = _box(_boxRecompensas);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == r.id) {
        final nuevo = _rewardToMap(r);
        _sellar(nuevo);
        box.items[i] = nuevo;
        _marcar();
        return i;
      }
    }
    return _addConId(box, _rewardToMap(r));
  }

  Future<void> deleteRecompensa(int id) async {
    final box = _box(_boxRecompensas);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        final canjes = _box(_boxCanjes);
        for (var j = canjes.items.length - 1; j >= 0; j--) {
          final c = canjes.items[j];
          if (c != null && c['recompensa_id'] == id) {
            _tombstone(_boxCanjes, c);
            canjes.items.removeAt(j);
          }
        }
        _tombstone(_boxRecompensas, m);
        box.items.removeAt(i);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // CANJES
  // ---------------------------------------------------------------
  Future<int> insertCanje(Redemption r) async {
    final box = _box(_boxCanjes);
    return _addConId(box, _redemptionToMap(r));
  }

  Future<List<Redemption>> getCanjesDeUsuario(int usuarioId) async {
    final box = _box(_boxCanjes);
    return box.items.where((m) => m['usuario_id'] == usuarioId).map(_mapToRedemption).toList();
  }

  Future<List<Redemption>> getCanjes() async {
    final box = _box(_boxCanjes);
    return box.items.map(_mapToRedemption).toList();
  }

  Future<void> updateCanje(Redemption r) async {
    final box = _box(_boxCanjes);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == r.id) {
        box.items[i] = _redemptionToMap(r);
        _sellar(box.items[i]);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // INSIGNIAS
  // ---------------------------------------------------------------
  Future<List<Badge>> getInsignias() async {
    final box = _box(_boxInsignias);
    return box.items.map(_mapToBadge).toList();
  }

  Future<List<int>> getInsigniasDeUsuario(int usuarioId) async {
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == usuarioId) {
        final lista = m['insignias_obtenidas'];
        if (lista is List) return lista.cast<int>();
      }
    }
    return [];
  }

  Future<void> otorgarInsignia(int usuarioId, int insigniaId) async {
    final box = _box(_boxUsuarios);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == usuarioId) {
        final lista = List<int>.from(m['insignias_obtenidas'] ?? <int>[]);
        if (!lista.contains(insigniaId)) {
          lista.add(insigniaId);
          m['insignias_obtenidas'] = lista;
        }
        _sellar(m);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // CASTIGOS
  // ---------------------------------------------------------------
  Future<int> insertCastigo(Castigo c) async {
    final box = _box(_boxCastigos);
    return _addConId(box, _castigoToMap(c));
  }

  Future<List<Castigo>> getCastigos() async {
    final box = _box(_boxCastigos);
    return box.items.map(_mapToCastigo).toList();
  }

  Future<List<Castigo>> getCastigosDeUsuario(int usuarioId) async {
    final box = _box(_boxCastigos);
    return box.items
        .where((m) => m['usuario_id'] == usuarioId)
        .map(_mapToCastigo)
        .toList();
  }

  Future<void> eliminarCastigo(int id) async {
    final box = _box(_boxCastigos);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        _tombstone(_boxCastigos, m);
        box.items.removeAt(i);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // CONFIGURACIÓN (meta)
  // ---------------------------------------------------------------

  /// ¿Los castigos automáticos por tareas vencidas están activados?
  Future<bool> getAutoCastigos() async {
    final meta = _box(_boxMeta);
    final item = meta.get('auto_castigos');
    final valor = item?['valor'];
    return valor is bool ? valor : true;
  }

  /// Activa o desactiva los castigos automáticos. Se guarda en `meta` para
  /// que el ajuste se sincronice entre todos los dispositivos.
  Future<void> setAutoCastigos(bool valor) async {
    final meta = _box(_boxMeta);
    final registro = {'k': 'auto_castigos', 'valor': valor};
    _sellar(registro);
    meta.put('auto_castigos', registro);
    _marcar();
  }

  // ---------------------------------------------------------------
  // RETOS
  // ---------------------------------------------------------------
  Map<String, dynamic> _retoToMap(Reto r) {
    return {
      'id': r.id,
      'titulo': r.titulo,
      'descripcion': r.descripcion,
      'puntos': r.puntos,
      'fecha_inicio': r.fechaInicio.toIso8601String(),
      'fecha_fin': r.fechaFin?.toIso8601String(),
      'cumplidos': r.cumplidos,
      'aprobados': r.aprobados,
      'finalizado': r.finalizado ? 1 : 0,
    };
  }

  Reto _mapToReto(Map map) {
    return Reto.fromMap(Map<String, Object?>.from(map));
  }

  Future<int> insertReto(Reto r) async {
    final box = _box(_boxRetos);
    return _addConId(box, _retoToMap(r));
  }

  Future<List<Reto>> getRetos() async {
    final box = _box(_boxRetos);
    return box.items.map(_mapToReto).toList();
  }

  Future<void> updateReto(Reto r) async {
    final box = _box(_boxRetos);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == r.id) {
        box.items[i] = _retoToMap(r);
        _sellar(box.items[i]);
        _marcar();
        return;
      }
    }
  }

  Future<void> eliminarReto(int id) async {
    final box = _box(_boxRetos);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        _tombstone(_boxRetos, m);
        box.items.removeAt(i);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // CATÁLOGO DE TAREAS
  // ---------------------------------------------------------------
  Map<String, dynamic> _catalogoToMap(TareaCatalogo c) {
    return {'id': c.id, 'titulo': c.titulo, 'puntos': c.puntos};
  }

  TareaCatalogo _mapToCatalogo(Map map) {
    return TareaCatalogo(
      id: map['id'] as int?,
      titulo: (map['titulo'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
    );
  }

  Future<List<TareaCatalogo>> getCatalogo() async {
    final box = _box(_boxCatalogos);
    return box.items.map(_mapToCatalogo).toList();
  }

  Future<int> insertCatalogo(TareaCatalogo c) async {
    final box = _box(_boxCatalogos);
    return _addConId(box, _catalogoToMap(c));
  }

  Future<int> updateCatalogo(TareaCatalogo c) async {
    final box = _box(_boxCatalogos);
    for (var i = 0; i < box.items.length; i++) {
      final m = box.items[i];
      if (m != null && m['id'] == c.id) {
        final nuevo = _catalogoToMap(c);
        _sellar(nuevo);
        box.items[i] = nuevo;
        _marcar();
        return i;
      }
    }
    return _addConId(box, _catalogoToMap(c));
  }

  Future<void> deleteCatalogo(int id) async {
    final box = _box(_boxCatalogos);
    for (var i = box.items.length - 1; i >= 0; i--) {
      final m = box.items[i];
      if (m != null && m['id'] == id) {
        _tombstone(_boxCatalogos, m);
        box.items.removeAt(i);
        _marcar();
        return;
      }
    }
  }

  // ---------------------------------------------------------------
  // ESTADÍSTICAS
  // ---------------------------------------------------------------
  Future<Map<String, Object?>> getEstadisticas() async {
    final usuarios = _box(_boxUsuarios);
    final tareas = _box(_boxTareas);
    final asignaciones = _box(_boxAsignaciones);
    final canjes = _box(_boxCanjes);

    final integrantes = usuarios.items
        .where((m) => m['rol'] != 'admin')
        .where((m) {
          final activo = m['activo'] as int?;
          return activo == null || activo == 1;
        })
        .length;
    final tareasActivas = tareas.items.where((m) => m['estado'] == 'activa').length;
    final aprobadas = asignaciones.items.where((m) => m['aprobada'] == 1).length;
    final totalPuntos = usuarios.items.fold<int>(0, (sum, m) => sum + (m['puntos'] as int? ?? 0));

    return {
      'usuarios': integrantes,
      'tareasActivas': tareasActivas,
      'aprobadas': aprobadas,
      'canjes': canjes.items.length,
      'totalPuntos': totalPuntos,
    };
  }
}

/// Caja en memoria que imita la API de Hive usada por la app.
class _Box {
  final List<Map> items = [];

  /// Asigna un id único por caja (máximo existente + 1). No usa la posición
  /// como id: al borrar registros del medio, dos dispositivos podrían asignar
  /// el mismo id a personas/tareas distintas y el merge los confundiría.
  int add(Map map) {
    items.add(map);
    var maxId = 0;
    for (final m in items) {
      final id = m['id'];
      if (id is int && id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  bool get isEmpty => items.isEmpty;

  void put(dynamic key, Map map) {
    if (key is int && key < items.length) {
      items[key] = map;
    } else {
      items.add({'k': key, ...map});
    }
  }

  Map? get(dynamic key) {
    if (key is int && key < items.length) return items[key];
    for (final m in items) {
      if (m['k'] == key) return m;
    }
    return null;
  }
}
