import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../db/photo_store.dart';
import '../sync/local_sync.dart';
import '../db/server_config.dart';
import '../db/upload_client.dart';
import '../models/assignment.dart';
import '../models/aviso_robo.dart';
import '../models/badge.dart';
import '../models/castigo.dart';
import '../models/logro.dart';
import '../services/biometria_service.dart';
import '../services/push_service.dart';
import '../models/redemption.dart';
import '../models/reto.dart';
import '../models/reward.dart';
import '../models/tarea_catalogo.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  static const _claveSesion = 'hq_sesion_usuario_id';

  User? _usuarioActual;
  bool _cargando = true;
  String? _error;
  bool _errorInicializacion = false;
  bool _sinConexion = false;
  bool _adminDesbloqueado = false;
  bool _ninoDesbloqueado = false;

  User? get usuarioActual => _usuarioActual;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get huboErrorInicializacion => _errorInicializacion;
  bool get adminDesbloqueado => _adminDesbloqueado;
  bool get ninoDesbloqueado => _ninoDesbloqueado;
  bool get sinConexion => _sinConexion;
  List<User> get listaUsuarios => _usuarios;
  List<User> _usuarios = [];

  /// Notifica a todas las vistas que recarguen sus datos (pull-to-refresh).
  void refrescar() => notifyListeners();

  Future<void> init() async {
    _cargando = true;
    _error = null;
    _errorInicializacion = false;
    notifyListeners();
    try {
      await _db.init();
      await _restaurarSesion();
    } catch (e) {
      _errorInicializacion = true;
      _error = e.toString();
    }
    _db.onRemoteChange = _datosRemotos;
    // Sincronización P2P local (misma red, sin internet). No bloquea el init.
    unawaited(LocalSyncService.instance.start(_db));
    await aplicarCastigosVencidos();
    await finalizarRetosVencidos();
    _cargando = false;
    _sinConexion = _db.sinConexion;
    notifyListeners();
  }

  /// Reanuda la sesión del último usuario que inició sesión, si todavía existe.
  Future<void> _restaurarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_claveSesion);
    if (id == null) return;
    final user = await _db.getUserById(id);
    if (user != null) {
      _usuarioActual = user;
      _ninoDesbloqueado = false;
      // Carga la preferencia biométrica del usuario restaurado.
      unawaited(BiometriaService.cargarPara(user.id!));
      unawaited(
        NotificationService.instance.sincronizar(app: this, userId: user.id!),
      );
    }
  }

  /// Cuando otro dispositivo cambia datos, se recargan y se notifica a las
  /// pantallas para que se actualicen al instante. También se aplican castigos.
  bool _recargaRemotaEnCurso = false;
  bool _recargaRemotaPendiente = false;
  Future<void> _datosRemotos() async {
    if (_recargaRemotaEnCurso) {
      _recargaRemotaPendiente = true;
      return;
    }
    _recargaRemotaEnCurso = true;
    try {
      do {
        _recargaRemotaPendiente = false;
        _sinConexion = _db.sinConexion;
        final id = _usuarioActual?.id;
        if (id != null) {
          final u = await _db.getUserById(id);
          if (u != null) _usuarioActual = u;
        }
        await aplicarCastigosVencidos();
        await finalizarRetosVencidos();
        if (!_db.sinConexion) {
          unawaited(_subirFotosPendientes());
          unawaited(_cachearFotosMiembros());
          unawaited(_cachearFotosRecompensas());
        }
        notifyListeners();
      } while (_recargaRemotaPendiente);
    } finally {
      _recargaRemotaEnCurso = false;
    }
  }

  /// Descarga y guarda localmente la foto de cada miembro que tenga URL remota
  /// pero aún no tenga copia local, para que se vean sin internet.
  Future<void> _cachearFotosMiembros() async {
    if (kIsWeb) return; // en web no hay almacenamiento local de fotos
    try {
      final usuarios = await listarUsuarios();
      for (final u in usuarios) {
        if (u.foto.isEmpty) continue;
        if (u.fotoLocal.isNotEmpty && PhotoStore.existe(u.fotoLocal)) continue;
        final url = u.foto.startsWith('http')
            ? u.foto
            : '${ServerConfig.baseUrl}${u.foto}';
        try {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            final local = await PhotoStore.guardarBytes(resp.bodyBytes);
            await editarUsuario(u.copyWith(fotoLocal: local));
          }
        } catch (_) {
          // Se reintenta en la próxima sincronización.
        }
      }
    } catch (e) {
      debugPrint('Error al cachear fotos de miembros: $e');
    }
  }

  /// Descarga y guarda localmente la foto de cada recompensa que tenga URL
  /// remota pero aún no tenga copia local, para que se vean sin internet y
  /// no parpadeen al icono por defecto al recargar.
  Future<void> _cachearFotosRecompensas() async {
    if (kIsWeb) return; // en web no hay almacenamiento local de fotos
    try {
      final recompensas = await listarRecompensas();
      for (final r in recompensas) {
        if (r.foto.isEmpty) continue;
        if (r.fotoLocal.isNotEmpty && PhotoStore.existe(r.fotoLocal)) continue;
        final url = r.foto.startsWith('http')
            ? r.foto
            : '${ServerConfig.baseUrl}${r.foto}';
        try {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            final local = await PhotoStore.guardarBytes(resp.bodyBytes);
            await editarRecompensa(r.copyWith(fotoLocal: local));
          }
        } catch (_) {
          // Se reintenta en la próxima sincronización.
        }
      }
    } catch (e) {
      debugPrint('Error al cachear fotos de recompensas: $e');
    }
  }

  /// Sube al servidor las fotos que se agregaron sin conexión (tienen copia
  /// local pero aún no tienen URL remota) y actualiza el registro local.
  Future<void> _subirFotosPendientes() async {
    if (kIsWeb) {
      return; // en web las fotos se suben desde memoria, no de archivo
    }
    try {
      final recompensas = await listarRecompensas();
      for (final r in recompensas) {
        if (r.fotoLocal.isNotEmpty &&
            r.foto.isEmpty &&
            PhotoStore.existe(r.fotoLocal)) {
          final bytes = await File(r.fotoLocal).readAsBytes();
          final url = await UploadClient().subirFoto(bytes);
          if (url != null) await editarRecompensa(r.copyWith(foto: url));
        }
      }
      final usuarios = await listarUsuarios();
      for (final u in usuarios) {
        if (u.fotoLocal.isNotEmpty &&
            u.foto.isEmpty &&
            PhotoStore.existe(u.fotoLocal)) {
          final bytes = await File(u.fotoLocal).readAsBytes();
          final url = await UploadClient().subirFoto(bytes);
          if (url != null) await editarUsuario(u.copyWith(foto: url));
        }
      }
    } catch (e) {
      debugPrint('Error al subir fotos pendientes: $e');
    }
  }

  Future<bool> login(String nombre, String password) async {
    _error = null;
    if (_estaBloqueado) {
      _error = 'Demasiados intentos. Espera ${_minutosRestantes()} min.';
      notifyListeners();
      return false;
    }
    final user = await _db.login(nombre, password);
    if (user == null) {
      _intentosFallidos++;
      if (_intentosFallidos >= _maxIntentos) {
        _bloqueadoHasta = DateTime.now().add(
          Duration(minutes: _bloqueoMinutos),
        );
      }
      _error = 'Usuario o contraseña incorrectos.';
      notifyListeners();
      return false;
    }
    _intentosFallidos = 0;
    _bloqueadoHasta = null;
    _usuarioActual = user;
    _adminDesbloqueado = false;
    // Login explícito con contraseña: ya se autenticó, no se pide huella.
    _ninoDesbloqueado = true;
    // Carga la preferencia biométrica por usuario (para el gate al reabrir).
    await BiometriaService.cargarPara(user.id!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_claveSesion, user.id!);
    notifyListeners();
    unawaited(_posLogin(user.id!));
    return true;
  }

  /// Tareas posteriores al login (permiso, push y recordatorio). Corren en
  /// segundo plano y nunca pueden bloquear ni romper el login aunque fallen.
  Future<void> _posLogin(int userId) async {
    try {
      await NotificationService.instance.solicitarPermiso();
    } catch (e) {
      debugPrint('solicitarPermiso: $e');
    }
    try {
      await NotificationService.instance.sincronizar(app: this, userId: userId);
    } catch (e) {
      debugPrint('sincronizar recordatorio: $e');
    }
    try {
      await PushService.instance.registrarPara(userId);
    } catch (e) {
      debugPrint('registrarPara: $e');
    }
  }

  static const _maxIntentos = 5;
  static const _bloqueoMinutos = 5;
  int _intentosFallidos = 0;
  DateTime? _bloqueadoHasta;

  bool get _estaBloqueado {
    final b = _bloqueadoHasta;
    return b != null && DateTime.now().isBefore(b);
  }

  int _minutosRestantes() {
    final b = _bloqueadoHasta;
    if (b == null) return 0;
    return (b.difference(DateTime.now()).inSeconds / 60).ceil();
  }

  void logout() {
    _usuarioActual = null;
    _error = null;
    _adminDesbloqueado = false;
    _ninoDesbloqueado = false;
    notifyListeners();
    unawaited(_limpiarSesion());
    unawaited(_cleanupLogout());
  }

  /// Limpieza tras salir: cancela push/recordatorios sin bloquear la UI.
  Future<void> _cleanupLogout() async {
    try {
      await NotificationService.instance.cancelarRecordatorios();
    } catch (_) {}
    try {
      await PushService.instance.desregistrar();
    } catch (_) {}
  }

  Future<void> _limpiarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesion);
  }

  Future<List<User>> listarUsuarios() async {
    // Lectura pura: NO debe llamar a notifyListeners(). Hacerlo provocaba un
    // bucle infinito (onChange -> listarUsuarios -> notify -> onChange ...)
    // que saturaba el event loop y congelaba la pantalla ("no responde").
    final usuarios = await _db.getUsuarios();
    _usuarios = usuarios;
    return usuarios;
  }

  /// Integrantes de la familia (sin el admin, salvo `incluirAdmin`: solo
  /// donde él gestiona sus propias tareas; retos/ranking siguen viendo
  /// únicamente a los niños).
  Future<List<User>> listarIntegrantes({
    bool soloActivos = true,
    bool incluirAdmin = false,
  }) =>
      _db.getIntegrantes(
        soloActivos: soloActivos,
        incluirAdmin: incluirAdmin,
      );

  /// Busca un usuario por id (sin marcar sesión).
  Future<User?> buscarUsuario(int id) => _db.getUserById(id);

  /// Bono diario del admin: 10 puntos una vez por día (fecha local del
  /// dispositivo, clave por usuario). Devuelve los puntos otorgados, o 0
  /// si el usuario no es admin o ya se cobró hoy. No toca racha ni
  /// insignias: solo puntos.
  Future<int> darBonoDiarioAdmin() async {
    final user = _usuarioActual;
    if (user == null || !user.esAdmin) return 0;
    final prefs = await SharedPreferences.getInstance();
    final clave = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'hq_admin_bono_${user.id}';
    if (prefs.getString(key) == clave) return 0;
    const bono = 10;
    final nuevosPuntos = user.puntos + bono;
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);
    await _db.updateUsuario(
      user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel),
    );
    _usuarioActual = user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel);
    await prefs.setString(key, clave);
    notifyListeners();
    return bono;
  }

  /// Envía la hora del recordatorio diario del usuario al server.
  Future<void> guardarRecordatorioEnServer({
    required int userId,
    required int minutos,
    required int offset,
  }) async {
    try {
      await _db.enviarRecordatorioConfig(userId, minutos, offset);
    } catch (_) {}
  }

  Future<void> crearUsuario({
    required String nombre,
    String avatar = '',
    int edad = 0,
    DateTime? fechaNacimiento,
    String colorTema = '',
    required String password,
    String rol = 'integrante',
  }) async {
    final u = User(
      nombre: nombre,
      avatar: avatar,
      edad: edad,
      fechaNacimiento: fechaNacimiento,
      colorTema: colorTema,
      password: password,
      rol: rol,
    );
    await _db.insertUsuario(u);
    notifyListeners();
  }

  Future<void> editarUsuario(User u) async {
    await _db.updateUsuario(u);
    if (_usuarioActual?.id == u.id) _usuarioActual = u;
    notifyListeners();
  }

  /// Marca la sesión de administrador como desbloqueada (tras el PIN).
  void desbloquearAdmin() {
    _adminDesbloqueado = true;
    notifyListeners();
  }

  /// Marca la sesión de niño como desbloqueada (tras la biometría).
  void desbloquearNino() {
    _ninoDesbloqueado = true;
    notifyListeners();
  }

  /// Comprueba el PIN contra el del usuario actual.
  bool verificarPin(String pin) => _usuarioActual?.pin == pin;

  /// Guarda (o borra, con cadena vacía) el PIN del administrador actual.
  Future<void> fijarPin(String pin) async {
    final u = _usuarioActual;
    if (u == null || u.id == null) return;
    final actualizado = u.copyWith(pin: pin);
    await _db.updateUsuario(actualizado);
    _usuarioActual = actualizado;
    notifyListeners();
  }

  /// Genera una copia de seguridad completa de la base de datos en JSON.
  Future<String> exportarRespaldo() async {
    final db = _db.exportarDb();
    db['exportadoEn'] = DateTime.now().toIso8601String();
    return jsonEncode(db);
  }

  /// Restaura la base de datos desde un respaldo previamente exportado.
  Future<void> importarRespaldo(Map<String, dynamic> data) async {
    await _db.importarDb(data);
    // Recarga la caché en memoria para que la UI refleje el cambio en caliente.
    await listarUsuarios();
    notifyListeners();
  }

  /// Borra todos los datos y deja la app lista para empezar de cero.
  Future<void> reiniciarTodo() async {
    await LocalSyncService.instance.stop();
    await _db.reiniciarDatos();
    _usuarioActual = null;
    _usuarios = [];
    _adminDesbloqueado = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesion);
    notifyListeners();
  }

  Future<void> eliminarUsuario(int id) async {
    await _db.deleteUsuario(id);
    notifyListeners();
  }

  Future<void> setUsuarioActivo(int id, bool activo) async {
    await _db.setUsuarioActivo(id, activo);
    notifyListeners();
  }

  /// El administrador restablece la contraseña de un integrante.
  Future<void> cambiarPassword(int id, String nueva) async {
    await _db.setPassword(id, nueva);
    notifyListeners();
  }

  Future<List<Task>> listarTareas() => _db.getTareas();
  Future<List<Task>> listarTareasActivas() => _db.getTareasActivas();

  /// Mapa `tareaId -> integrantes asignados`, para que el admin vea quién
  /// tiene cada tarea en la planificación semanal y detecte repeticiones.
  Future<Map<int, List<User>>> asignadosPorTarea() async {
    final tareas = await _db.getTareas();
    final asignaciones = await _db.getTodasLasAsignaciones();
    final usuarios = await _db.getIntegrantes();
    final mapU = {for (final u in usuarios) u.id: u};
    final result = <int, List<User>>{};
    for (final t in tareas) {
      final asignados = <User>[];
      for (final a in asignaciones) {
        if (a.tareaId == t.id) {
          final u = mapU[a.usuarioId];
          if (u != null && !asignados.any((x) => x.id == u.id)) {
            asignados.add(u);
          }
        }
      }
      result[t.id!] = asignados;
    }
    return result;
  }

  Future<Task> crearTarea({
    required String titulo,
    String descripcion = '',
    required int puntos,
    String dificultad = 'media',
    DateTime? fechaLimite,
    String frecuencia = 'unica',
    List<int> integrantesIds = const [],
    String dia = '',
    String categoria = 'General',
    String icono = '',
  }) async {
    final tarea = Task(
      titulo: titulo,
      descripcion: descripcion,
      puntos: puntos,
      dificultad: dificultad,
      fechaLimite: fechaLimite,
      frecuencia: frecuencia,
      dia: dia,
      categoria: categoria,
      icono: icono,
    );
    final tareaId = await _db.insertTarea(tarea);
    debugPrint(
      '[crearTarea] tareaId=$tareaId titulo="$titulo" dia="$dia" integrantes=$integrantesIds',
    );
    for (final uid in integrantesIds) {
      await _db.insertAsignacion(
        Assignment(
          usuarioId: uid,
          tareaId: tareaId,
          fechaAsignada: DateTime.now(),
        ),
      );
      debugPrint(
        '[crearTarea] asignacion creada usuarioId=$uid tareaId=$tareaId',
      );
      unawaited(_db.enviarPush(uid, 'Nueva tarea', titulo));
    }
    final verificacion = await _db.getAsignacionesPorTarea(tareaId);
    debugPrint(
      '[crearTarea] verificacion: ${verificacion.length} asignaciones para tarea $tareaId',
    );
    notifyListeners();
    return tarea.copyWith(id: tareaId);
  }

  Future<void> editarTarea(
    Task t, {
    List<int> integrantesIds = const [],
  }) async {
    await _db.updateTarea(t);
    if (integrantesIds.isNotEmpty) {
      final asignacionesActuales = await _db.getAsignacionesPorTarea(t.id!);
      for (final a in asignacionesActuales) {
        if (!a.completada && !a.aprobada) {
          await _db.eliminarAsignacion(a.id!);
        }
      }
      for (final uid in integrantesIds) {
        await _db.insertAsignacion(
          Assignment(
            usuarioId: uid,
            tareaId: t.id!,
            fechaAsignada: DateTime.now(),
          ),
        );
      }
    }
    notifyListeners();
  }

  Future<void> eliminarTarea(int id) async {
    // Si la tarea tenía castigos automáticos, se revierten al eliminarla
    // (se devuelven los puntos que se descontaron).
    final castigos = await _db.getCastigos();
    for (final c in castigos) {
      if (c.tipo == 'tarea' && c.tareaId == id) {
        final user = await _db.getUserById(c.usuarioId);
        if (user != null) {
          final nuevos = user.puntos + c.puntos;
          await _db.updateUsuario(
            user.copyWith(
              puntos: nuevos,
              nivel: GamificationService.nivelPara(nuevos),
            ),
          );
          if (_usuarioActual?.id == c.usuarioId) {
            final u = await _db.getUserById(c.usuarioId);
            if (u != null) _usuarioActual = u;
          }
        }
        final cid = c.id;
        if (cid != null) await _db.eliminarCastigo(cid);
      }
    }
    await _db.deleteTarea(id);
    notifyListeners();
  }

  /// ¿Están activados los castigos automáticos por tareas vencidas?
  Future<bool> getAutoCastigos() => _db.getAutoCastigos();

  /// Cambia los castigos automáticos (se sincroniza entre dispositivos).
  Future<void> setAutoCastigos(bool valor) async {
    await _db.setAutoCastigos(valor);
    notifyListeners();
  }

  Future<void> completarTarea(int tareaId) async {
    final uid = _usuarioActual?.id;
    if (uid == null) return;
    var a = await _db.getAsignacion(uid, tareaId);
    if (a == null) return;
    a = a.copyWith(completada: true, fechaCompletada: DateTime.now());
    await _db.updateAsignacion(a);
    notifyListeners();
  }

  /// La ventana de robo diaria (18:00–21:30) está abierta ahora. Solo en
  /// ese horario se puede robar: tareas de "Para robar" y slots de reto.
  static bool enVentanaRobo([DateTime? ahora]) {
    final a = ahora ?? DateTime.now();
    if (a.hour < 18) return false;
    if (a.hour < 21) return true;
    return a.hour == 21 && a.minute < 30;
  }

  /// Próxima apertura de la ventana de robo (18:00 de hoy, o de mañana si
  /// ya pasó): sirve para los contadores verdes fuera de ventana.
  static DateTime proximaVentanaRobo([DateTime? ahora]) {
    final a = ahora ?? DateTime.now();
    final h18 = DateTime(a.year, a.month, a.day, 18);
    return a.isBefore(h18) ? h18 : h18.add(const Duration(days: 1));
  }

  /// Tareas que otro hijo dejó vencidas (sin completar en su tiempo) y que
  /// ya pueden robarse: sigue activa, de la semana actual y sin robar.
  /// Mismas reglas de vencimiento que `aplicarCastigosVencidos`.
  Future<List<(Task, Assignment, User)>> tareasRobables() async {
    final yo = _usuarioActual?.id;
    if (yo == null) return const [];
    final pendientes = await _db.getAsignacionesPendientes();
    final hoy = DateTime.now();
    final inicio = hoy.subtract(Duration(days: hoy.weekday % 7));
    final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
    final result = <(Task, Assignment, User)>[];
    for (final a in pendientes) {
      // Lo tuyo no se roba; las ya robadas desaparecen de la lista.
      if (a.usuarioId == yo || a.robadaPor != null) continue;
      final t = await _db.getTareaById(a.tareaId);
      if (t == null || !t.activa) continue;
      final vence = _fechaVencimiento(t);
      if (vence == null || !hoy.isAfter(vence)) continue;
      // Solo tareas cuyo vencimiento cae en el día de hoy.
      if (vence.year != hoy.year ||
          vence.month != hoy.month ||
          vence.day != hoy.day) {
        continue;
      }
      final asignada = a.fechaAsignada;
      if (asignada != null && asignada.isAfter(vence)) continue;
      if (asignada != null && asignada.isBefore(inicioDia)) continue;
      final dueno = await _db.getUserById(a.usuarioId);
      if (dueno == null) continue;
      result.add((t, a, dueno));
    }
    return result;
  }

  /// El usuario actual roba una tarea vencida: se queda `tarea.puntos`
  /// al instante. La fila del dueño NO se marca completada, para que el
  /// castigo automático normal siga aplicándose igual. Primero en robar,
  /// gana. Nunca descuenta puntos.
  Future<bool> robarTarea(int asignacionId) async {
    final uid = _usuarioActual?.id;
    if (uid == null || !enVentanaRobo()) return false;
    final robables = await tareasRobables();
    final hit = robables
        .where((r) => r.$2.id == asignacionId)
        .firstOrNull;
    if (hit == null) return false;
    final (t, a, dueno) = hit;
    final yo = await _db.getUserById(uid);
    if (yo == null) return false;

    await _db.updateAsignacion(
      a.copyWith(robadaPor: uid, fechaRobo: DateTime.now()),
    );
    // Ventana de frenesí activa: el robo también se paga con el multiplicador.
    final frenesi = await retoFrenesiActivo();
    final mult = frenesi?.multiplicador ?? 1;
    final gano = t.puntos * mult;
    final nuevosPuntos = yo.puntos + gano;
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);
    await _db.updateUsuario(
      yo.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel),
    );
    if (_usuarioActual?.id == uid) {
      _usuarioActual = yo.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel);
    }
    await _acumularEnFrenesi(frenesi, uid, gano);
    unawaited(
      _db.enviarPush(
        dueno.id!,
        'Te robaron una tarea',
        mult > 1
            ? '${yo.nombre} robó "${t.titulo}" y ganó $gano puntos (x$mult).'
            : '${yo.nombre} robó "${t.titulo}" y ganó ${t.puntos} puntos.',
      ),
    );
    notifyListeners();
    return true;
  }

  /// El reto frenesí cuya ventana de multiplicador está corriendo ahora
  /// (null si no hay ninguna). Solo el más reciente aplica.
  Future<Reto?> retoFrenesiActivo() async {
    final ahora = DateTime.now();
    final retos = await _db.getRetos();
    Reto? mejor;
    for (final r in retos) {
      if (!r.ventanaFrenesiActiva(ahora)) continue;
      if (mejor == null || r.id! > mejor.id!) mejor = r;
    }
    return mejor;
  }

  /// Suma `puntos` al acumulado del reto frenesí activo para `uid`.
  Future<void> _acumularEnFrenesi(Reto? frenesi, int uid, int puntos) async {
    if (frenesi == null || puntos <= 0) return;
    final acumulados = {...frenesi.acumulados};
    acumulados[uid] = (acumulados[uid] ?? 0) + puntos;
    await _db.updateReto(frenesi.copyWith(acumulados: acumulados));
  }

  Future<void> aprobarAsignacion(int asignacionId) async {
    final asignaciones = await _db.getAsignacionesPorAprobar();
    final a = asignaciones.firstWhere(
      (x) => x.id == asignacionId,
      orElse: () => Assignment(usuarioId: 0, tareaId: 0),
    );
    if (a.id == null || a.aprobada) return;

    final tarea = await _db.getTareaById(a.tareaId);
    final user = await _db.getUserById(a.usuarioId);
    if (tarea == null || user == null) return;

    final aprobada = a.copyWith(aprobada: true, fechaAprobada: DateTime.now());
    await _db.updateAsignacion(aprobada);

    final historial = await _db.getAsignacionesAprobadas(a.usuarioId);
    final fechas = historial
        .map((x) => x.fechaAprobada)
        .whereType<DateTime>()
        .toList();
    final racha = GamificationService.calcularRacha(fechas);

    // Ventana de frenesí activa: la tarea se paga con el multiplicador.
    final frenesi = await retoFrenesiActivo();
    final mult = frenesi?.multiplicador ?? 1;
    final puntosTarea = tarea.puntos * mult;

    final nuevosPuntos =
        user.puntos + puntosTarea + GamificationService.bonusRacha(racha);
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);

    await _db.updateUsuario(
      user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel, racha: racha),
    );

    final tareas = await _db.getTareas();
    final catalogoInsignias = await _db.getInsignias();
    final ganadas = GamificationService.insigniasGanadas(
      catalogo: catalogoInsignias,
      puntos: nuevosPuntos,
      racha: racha,
      aprobadas: historial,
      tareas: tareas,
    );
    for (final badgeId in ganadas) {
      await _db.otorgarInsignia(a.usuarioId, badgeId);
    }
    // Avisar al niño que su tarea fue aprobada (push, si el servidor tiene
    // FIREBASE_CREDENTIALS configurado). El niño también ve confeti en su
    // dispositivo cuando suben sus puntos.
    await _acumularEnFrenesi(frenesi, a.usuarioId, puntosTarea);
    unawaited(
      _db.enviarPush(
        a.usuarioId,
        '¡Tarea aprobada!',
        mult > 1
            ? 'Ganaste $puntosTarea puntos (x$mult) con "${tarea.titulo}".'
            : 'Ganaste ${tarea.puntos} puntos con "${tarea.titulo}".',
      ),
    );
    notifyListeners();
  }

  Future<void> rechazarAsignacion(int asignacionId) async {
    final asignaciones = await _db.getAsignacionesPorAprobar();
    final a = asignaciones.firstWhere(
      (x) => x.id == asignacionId,
      orElse: () => Assignment(usuarioId: 0, tareaId: 0),
    );
    if (a.id == null) return;
    await _db.updateAsignacion(
      a.copyWith(completada: false, aprobada: false, fechaCompletada: null),
    );
    notifyListeners();
  }

  Future<List<(Task, Assignment)>> tareasConAsignacionDe(int usuarioId) async {
    final tareas = await _db.getTareasActivas();
    final asignaciones = await _db.getAsignacionesDeUsuario(usuarioId);
    final map = {for (final a in asignaciones) a.tareaId: a};
    final result = <(Task, Assignment)>[];
    for (final t in tareas) {
      final a = map[t.id];
      if (a != null) result.add((t, a));
    }
    return result;
  }

  /// Tareas pendientes del usuario para el día de HOY (sin completar).
  Future<List<(Task, Assignment)>> tareasPendientesDeHoy(int usuarioId) async {
    final todo = await tareasConAsignacionDe(usuarioId);
    final pendientes = todo
        .where((t) => !t.$2.completada && _esDelDiaDeHoy(t.$1))
        .toList();
    return pendientes;
  }

  Future<List<(Task, Assignment, User)>> pendientesDeAprobacion() async {
    final asignaciones = await _db.getAsignacionesPorAprobar();
    final result = <(Task, Assignment, User)>[];
    for (final a in asignaciones) {
      final t = await _db.getTareaById(a.tareaId);
      final u = await _db.getUserById(a.usuarioId);
      if (t != null && u != null) result.add((t, a, u));
    }
    return result;
  }

  Future<List<(Task, Assignment)>> historialDe(int usuarioId) async {
    final aprobadas = await _db.getAsignacionesAprobadas(usuarioId);
    final result = <(Task, Assignment)>[];
    for (final a in aprobadas) {
      final t = await _db.getTareaById(a.tareaId);
      if (t != null) result.add((t, a));
    }
    return result;
  }

  Future<List<Reward>> listarRecompensas() => _db.getRecompensas();

  Future<void> crearRecompensa({
    required String nombre,
    String descripcion = '',
    required int costoPuntos,
    String foto = '',
    String fotoLocal = '',
  }) async {
    await _db.insertRecompensa(
      Reward(
        nombre: nombre,
        descripcion: descripcion,
        costoPuntos: costoPuntos,
        foto: foto,
        fotoLocal: fotoLocal,
      ),
    );
    notifyListeners();
  }

  Future<void> editarRecompensa(Reward r) async {
    await _db.updateRecompensa(r);
    notifyListeners();
  }

  Future<void> eliminarRecompensa(int id) async {
    await _db.deleteRecompensa(id);
    notifyListeners();
  }

  Future<bool> canjearRecompensa(Reward r) async {
    final user = _usuarioActual!;
    if (user.puntos < r.costoPuntos) return false;
    final nuevosPuntos = user.puntos - r.costoPuntos;
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);
    await _db.updateUsuario(
      user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel),
    );
    await _db.insertCanje(
      Redemption(
        usuarioId: user.id!,
        recompensaId: r.id!,
        fecha: DateTime.now(),
      ),
    );
    final admins = (await _db.getUsuarios()).where((u) => u.esAdmin);
    for (final a in admins) {
      unawaited(
        _db.enviarPush(
          a.id!,
          'Canje solicitado',
          '${user.nombre} canjeó: ${r.nombre}',
        ),
      );
    }
    _usuarioActual = user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel);
    notifyListeners();
    return true;
  }

  Future<List<(Redemption, Reward)>> canjesDe(int usuarioId) async {
    final canjes = await _db.getCanjesDeUsuario(usuarioId);
    final recompensas = await _db.getRecompensas();
    final map = {for (final r in recompensas) r.id: r};
    final result = <(Redemption, Reward)>[];
    for (final c in canjes) {
      final r = map[c.recompensaId];
      if (r != null) result.add((c, r));
    }
    return result;
  }

  /// Todos los canjes de la familia (para que el admin entregue las recompensas).
  Future<List<(Redemption, Reward, User)>> canjesFamilia() async {
    final canjes = await _db.getCanjes();
    final recompensas = await _db.getRecompensas();
    final usuarios = await _db.getUsuarios();
    final mapR = {for (final r in recompensas) r.id: r};
    final mapU = {for (final u in usuarios) u.id: u};
    final result = <(Redemption, Reward, User)>[];
    for (final c in canjes) {
      final r = mapR[c.recompensaId];
      final u = mapU[c.usuarioId];
      if (r != null && u != null) result.add((c, r, u));
    }
    result.sort((a, b) => b.$1.fecha.compareTo(a.$1.fecha));
    return result;
  }

  /// El admin marca una recompensa canjeada como entregada.
  Future<void> marcarCanjeEntregado(int canjeId) async {
    final canjes = await _db.getCanjes();
    final c = canjes.where((x) => x.id == canjeId).firstOrNull;
    if (c == null) return;
    await _db.updateCanje(c.copyWith(estado: 'entregada'));
    unawaited(
      _db.enviarPush(
        c.usuarioId,
        'Recompensa entregada',
        'Tu canje fue entregado',
      ),
    );
    notifyListeners();
  }

  /// El admin revierte un canje pendiente a entregado (al revés).
  Future<void> marcarCanjePendiente(int canjeId) async {
    final canjes = await _db.getCanjes();
    final c = canjes.where((x) => x.id == canjeId).firstOrNull;
    if (c == null) return;
    await _db.updateCanje(c.copyWith(estado: 'pendiente'));
    notifyListeners();
  }

  Future<List<Badge>> listarInsignias() => _db.getInsignias();
  Future<List<int>> insigniasDe(int usuarioId) =>
      _db.getInsigniasDeUsuario(usuarioId);

  Future<void> crearInsignia(Badge b) async {
    await _db.insertInsignia(b);
    notifyListeners();
  }

  Future<void> editarInsignia(Badge b) async {
    await _db.updateInsignia(b);
    notifyListeners();
  }

  Future<void> eliminarInsignia(int id) async {
    await _db.deleteInsignia(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // LOGROS EN CAMINO (metas de progreso editables por el admin)
  // ---------------------------------------------------------------
  Future<List<Logro>> listarLogros() => _db.getLogros();

  Future<void> crearLogro(Logro logro) async {
    await _db.insertLogro(logro);
    notifyListeners();
  }

  Future<void> editarLogro(Logro logro) async {
    await _db.updateLogro(logro);
    notifyListeners();
  }

  Future<void> eliminarLogro(int id) async {
    await _db.deleteLogro(id);
    notifyListeners();
  }

  Future<Map<String, Object?>> estadisticas() => _db.getEstadisticas();

  /// Puntos aprobados por día (últimos `dias` días) de un integrante.
  Future<List<(DateTime, int)>> puntosPorDia(
    int usuarioId, {
    int dias = 7,
  }) async {
    final hoy = DateTime.now();
    final inicio = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: dias - 1));
    final fin = hoy.add(const Duration(days: 1));
    final aps = await _db.getAsignacionesAprobadasDeUsuarioEnRango(
      usuarioId,
      inicio,
      fin,
    );
    return _agruparPuntosPorDia(aps, dias: dias, inicio: inicio);
  }

  /// Puntos aprobados por día (últimos `dias` días) de TODA la familia.
  Future<List<(DateTime, int)>> puntosPorDiaGlobal({int dias = 7}) async {
    final hoy = DateTime.now();
    final inicio = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: dias - 1));
    final fin = hoy.add(const Duration(days: 1));
    final aps = await _db.getAsignacionesAprobadasEnRango(inicio, fin);
    return _agruparPuntosPorDia(aps, dias: dias, inicio: inicio);
  }

  Future<List<(DateTime, int)>> _agruparPuntosPorDia(
    List<Assignment> aps, {
    required int dias,
    required DateTime inicio,
  }) async {
    final porDia = <DateTime, int>{};
    for (final a in aps) {
      final t = await _db.getTareaById(a.tareaId);
      if (t == null || a.fechaAprobada == null) continue;
      final dia = a.fechaAprobada!;
      final clave = DateTime(dia.year, dia.month, dia.day);
      porDia[clave] = (porDia[clave] ?? 0) + t.puntos;
    }
    return [
      for (var i = 0; i < dias; i++)
        (
          inicio.add(Duration(days: i)),
          porDia[inicio.add(Duration(days: i))] ?? 0,
        ),
    ];
  }

  /// Resumen de un integrante para un periodo: puntos, aprobadas, pendientes,
  /// completadas hoy, castigos del periodo y tareas de hoy.
  Future<Map<String, Object?>> resumenIntegrante(int usuarioId) async {
    final hoy = DateTime.now();
    final hoyInicio = DateTime(hoy.year, hoy.month, hoy.day);
    final inicio = hoyInicio.subtract(const Duration(days: 6));
    final fin = hoy.add(const Duration(days: 1));

    final aprobadas = await _db.getAsignacionesAprobadasDeUsuarioEnRango(
      usuarioId,
      inicio,
      fin,
    );
    // Una sola lectura de todas las tareas y búsqueda en memoria (evita
    // N consultas getTareaById, que escaneaban la caja una por una).
    final tareasPorId = {for (final t in await _db.getTareas()) t.id: t};
    var puntosSemana = 0;
    var puntosHoy = 0;
    for (final a in aprobadas) {
      final t = tareasPorId[a.tareaId];
      if (t == null) continue;
      puntosSemana += t.puntos;
      final fa = a.fechaAprobada;
      if (fa != null &&
          fa.year == hoyInicio.year &&
          fa.month == hoyInicio.month &&
          fa.day == hoyInicio.day) {
        puntosHoy += t.puntos;
      }
    }

    // Tareas de HOY (asignación activa del día)
    final tareasHoy = <Map<String, Object?>>[];
    final activas = await _db.getTareasActivas();
    final asignaciones = await _db.getAsignacionesDeUsuario(usuarioId);
    final mapAsig = {for (final a in asignaciones) a.tareaId: a};
    for (final t in activas) {
      final a = mapAsig[t.id];
      if (a == null) continue;
      if (!_esDelDiaDeHoy(t)) continue;
      tareasHoy.add({
        'titulo': t.titulo,
        'puntos': t.puntos,
        'estado': a.completada
            ? (a.aprobada ? 'aprobada' : 'completada')
            : 'pendiente',
      });
    }

    final castigos = await _db.getCastigosDeUsuario(usuarioId);
    final castigosSemana = castigos
        .where((c) => !c.fecha.isBefore(inicio))
        .fold<int>(0, (s, c) => s + c.puntos);

    final user = await _db.getUserById(usuarioId);
    return {
      'usuario': user,
      'puntosSemana': puntosSemana,
      'puntosHoy': puntosHoy,
      'aprobadasSemana': aprobadas.length,
      'pendientes': tareasHoy.where((m) => m['estado'] == 'pendiente').length,
      'castigosSemana': castigosSemana,
      'tareasHoy': tareasHoy,
    };
  }

  bool _esDelDiaDeHoy(Task t) {
    if (t.dia.isEmpty) return true;
    const dias = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
    final idx = dias.indexOf(t.dia);
    return idx >= 0 && hoyWeekdayIdx == idx;
  }

  int get hoyWeekdayIdx => DateTime.now().weekday - 1;

  Future<List<(User, int)>> ranking(String periodo) async {
    final usuarios = await _db.getIntegrantes();
    final hoy = DateTime.now();
    final inicio = periodo == 'semanal'
        ? hoy.subtract(const Duration(days: 6))
        : DateTime(hoy.year, hoy.month, 1);
    // Retos finalizados de la semana incluida en el periodo: suman sus puntos
    // bonus a quienes fueron aprobados.
    final retos = await _db.getRetos();
    final retosPuntos = <int, int>{};
    for (final r in retos) {
      if (!r.finalizado) continue;
      final inicioReto = DateTime(
        r.fechaInicio.year,
        r.fechaInicio.month,
        r.fechaInicio.day,
      );
      if (inicioReto.isBefore(inicio) || inicioReto.isAfter(hoy)) continue;
      for (final uid in r.aprobados) {
        retosPuntos[uid] = (retosPuntos[uid] ?? 0) + r.puntos;
      }
    }
    final resultado = <(User, int)>[];
    for (final u in usuarios) {
      final aps = await _db.getAsignacionesAprobadasDeUsuarioEnRango(
        u.id!,
        inicio,
        hoy.add(const Duration(days: 1)),
      );
      var pts = 0;
      for (final a in aps) {
        final t = await _db.getTareaById(a.tareaId);
        pts += t?.puntos ?? 0;
      }
      pts += retosPuntos[u.id!] ?? 0;
      resultado.add((u, pts));
    }
    resultado.sort((a, b) => b.$2.compareTo(a.$2));
    return resultado;
  }

  /// Neto (ganado − castigado) de cada integrante en un rango de fechas.
  /// Base derivada de las ligas y de la meta familiar (sin tablas nuevas).
  Future<List<(User, int, int)>> _netoEnRango(
    DateTime inicio,
    DateTime fin,
  ) async {
    final usuarios = await _db.getIntegrantes();
    final retos = await _db.getRetos();
    final retosPuntos = <int, int>{};
    for (final r in retos) {
      if (!r.finalizado) continue;
      final inicioReto = DateTime(
        r.fechaInicio.year,
        r.fechaInicio.month,
        r.fechaInicio.day,
      );
      if (inicioReto.isBefore(inicio) || !inicioReto.isBefore(fin)) continue;
      for (final uid in r.aprobados) {
        retosPuntos[uid] = (retosPuntos[uid] ?? 0) + r.puntos;
      }
    }
    final resultado = <(User, int, int)>[];
    for (final u in usuarios) {
      final aps = await _db.getAsignacionesAprobadasDeUsuarioEnRango(
        u.id!,
        inicio,
        fin,
      );
      var pts = 0;
      for (final a in aps) {
        final t = await _db.getTareaById(a.tareaId);
        pts += t?.puntos ?? 0;
      }
      pts += retosPuntos[u.id!] ?? 0;
      final castigos = await _db.getCastigosDeUsuario(u.id!);
      final perdidos = castigos
          .where((c) => !c.fecha.isBefore(inicio) && c.fecha.isBefore(fin))
          .fold<int>(0, (s, c) => s + c.puntos);
      resultado.add((u, pts, perdidos));
    }
    return resultado;
  }

  /// Ranking NETO de la semana de calendario anterior (domingo a sábado).
  /// Devuelve lista vacía si no hubo actividad, para mostrar el estado de
  /// bloqueo de la liga (se desbloquea tras la primera semana completa).
  Future<List<(User, int, int)>> rankingSemanaAnterior() async {
    final hoy = DateTime.now();
    final inicioEsta = hoy.subtract(Duration(days: hoy.weekday % 7));
    final fin = DateTime(inicioEsta.year, inicioEsta.month, inicioEsta.day);
    final inicio = fin.subtract(const Duration(days: 7));
    final base = await _netoEnRango(inicio, fin);
    final hayDatos = base.any((e) => e.$2 > 0 || e.$3 > 0);
    if (!hayDatos) return [];
    base.sort((a, b) => (b.$2 - b.$3).compareTo(a.$2 - a.$3));
    return base;
  }

  /// Puntos netos de TODA la familia en la semana de calendario en curso
  /// (para la meta familiar del panel de ligas).
  Future<int> puntosFamiliaSemana() async {
    final hoy = DateTime.now();
    final inicio = hoy.subtract(Duration(days: hoy.weekday % 7));
    final base = await _netoEnRango(
      DateTime(inicio.year, inicio.month, inicio.day),
      hoy.add(const Duration(days: 1)),
    );
    final total = base.fold<int>(0, (s, e) => s + (e.$2 - e.$3));
    return total < 0 ? 0 : total;
  }
  // ---------------------------------------------------------------
  // CASTIGOS
  // ---------------------------------------------------------------

  /// Aplica castigo automático por tareas vencidas. Se invoca al iniciar y
  /// cuando llegan datos remotos, para que ningún dispositivo pierda castigos.
  Future<void> aplicarCastigosVencidos() async {
    final auto = await _db.getAutoCastigos();
    if (!auto) return;
    final pendientes = await _db.getAsignacionesPendientes();
    final hoy = DateTime.now();
    for (final a in pendientes) {
      if (a.castigada) continue;
      final t = await _db.getTareaById(a.tareaId);
      if (t == null) continue;
      final vence = _fechaVencimiento(t);
      // Solo se castiga si el día/plazo ya pasó y la tarea sigue activa.
      if (vence == null || !hoy.isAfter(vence) || !t.activa) continue;
      // No castigar tareas asignadas a un día que ya había vencido cuando se
      // crearon (retroactivas): p. ej. agregar una tarea para el domingo el
      // martes no debe descontar puntos al instante.
      final asignada = a.fechaAsignada;
      if (asignada != null && asignada.isAfter(vence)) continue;
      // Tampoco castigar asignaciones de semanas anteriores a la actual.
      final inicio = hoy.subtract(Duration(days: hoy.weekday % 7));
      final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
      if (asignada != null && asignada.isBefore(inicioDia)) continue;
      final user = await _db.getUserById(a.usuarioId);
      if (user == null) continue;
      final castigo = Castigo(
        usuarioId: a.usuarioId,
        motivo: 'Tarea sin cumplir: ${t.titulo}',
        puntos: _puntosCastigo(t),
        tipo: 'tarea',
        tareaId: t.id,
        fecha: hoy,
      );
      await _db.insertCastigo(castigo);
      await _db.updateAsignacion(a.copyWith(castigada: true));
      await _db.updateUsuario(
        user.copyWith(
          puntos: user.puntos - _puntosCastigo(t),
          nivel: GamificationService.nivelPara(user.puntos - _puntosCastigo(t)),
        ),
      );
      if (_usuarioActual?.id == a.usuarioId) {
        final u = await _db.getUserById(a.usuarioId);
        if (u != null) _usuarioActual = u;
      }
    }
    notifyListeners();
  }

  /// Aplica un castigo manual del admin a un integrante.
  /// `tipo`: 'disciplina' (portarse mal) o 'tarea' (no cumplió la tarea).
  Future<void> castigarManual(
    int usuarioId,
    String motivo,
    int puntos, {
    String tipo = 'disciplina',
  }) async {
    final user = await _db.getUserById(usuarioId);
    if (user == null) return;
    final nuevosPuntos = user.puntos - puntos;
    await _db.updateUsuario(
      user.copyWith(
        puntos: nuevosPuntos,
        nivel: GamificationService.nivelPara(nuevosPuntos),
      ),
    );
    await _db.insertCastigo(
      Castigo(
        usuarioId: usuarioId,
        motivo: motivo,
        puntos: puntos,
        tipo: tipo,
        fecha: DateTime.now(),
      ),
    );
    unawaited(_db.enviarPush(usuarioId, 'Tienes un castigo', motivo));
    if (_usuarioActual?.id == usuarioId) {
      final u = await _db.getUserById(usuarioId);
      if (u != null) _usuarioActual = u;
    }
    notifyListeners();
  }

  Future<List<Castigo>> listarCastigos() => _db.getCastigos();
  Future<List<Castigo>> castigosDe(int usuarioId) =>
      _db.getCastigosDeUsuario(usuarioId);

  Future<void> eliminarCastigo(int id) async {
    await _db.eliminarCastigo(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // RETOS
  // ---------------------------------------------------------------

  Future<List<Reto>> listarRetos() => _db.getRetos();

  /// Ids de tareas con al menos una asignación sin completar
  /// (para pintar la etiqueta "Vencida" en el planificador semanal).
  Future<Set<int>> idsTareasPendientes() async {
    final lista = await _db.getAsignacionesPendientes();
    return lista.map((a) => a.tareaId).toSet();
  }

  // ---------------------------------------------------------------
  // CATÁLOGO DE TAREAS (puntos por defecto)
  // ---------------------------------------------------------------

  Future<List<TareaCatalogo>> listarCatalogo() => _db.getCatalogo();

  Future<void> crearCatalogo({
    required String titulo,
    required int puntos,
    String categoria = 'General',
    String dificultad = 'media',
    String icono = '',
  }) async {
    await _db.insertCatalogo(
      TareaCatalogo(
        titulo: titulo,
        puntos: puntos,
        categoria: categoria,
        dificultad: dificultad,
        icono: icono,
      ),
    );
    notifyListeners();
  }

  Future<void> editarCatalogo(TareaCatalogo c) async {
    await _db.updateCatalogo(c);
    notifyListeners();
  }

  Future<void> eliminarCatalogo(int id) async {
    await _db.deleteCatalogo(id);
    notifyListeners();
  }

  /// Busca la entrada del catálogo para un título (si existe).
  TareaCatalogo? buscarEnCatalogo(List<TareaCatalogo> catalogo, String titulo) {
    final t = titulo.trim().toLowerCase();
    if (t.isEmpty) return null;
    // Coincidencia exacta primero, después por prefijo ("Tra" → "Trapear").
    for (final c in catalogo) {
      if (c.titulo.trim().toLowerCase() == t) return c;
    }
    for (final c in catalogo) {
      final ct = c.titulo.trim().toLowerCase();
      if (ct.startsWith(t) || t.startsWith(ct)) return c;
    }
    return null;
  }

  Future<Reto?> retoDeLaSemana() async {
    final retos = await retosDeLaSemana();
    return retos.isEmpty ? null : retos.first;
  }

  /// Todos los retos vigentes de la semana actual (puede haber varios).
  Future<List<Reto>> retosDeLaSemana() async {
    await finalizarRetosVencidos(notificar: false);
    final retos = await _db.getRetos();
    final hoy = DateTime.now();
    return retos.where((r) => r.vigente && r.perteneceASemana(hoy)).toList();
  }

  Future<Reto?> crearReto({
    required String titulo,
    required String descripcion,
    required int puntos,
    DateTime? fechaFin,
    String modo = Reto.modoNormal,
    DateTime? fechaLluvia,
    DateTime? plazoIndividual,
    DateTime? ventanaInicio,
    DateTime? ventanaFin,
    int multiplicador = 1,
  }) async {
    final hoy = DateTime.now();
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
    final inicio = DateTime(lunes.year, lunes.month, lunes.day);
    var fin = fechaFin;
    var diaLluvia = fechaLluvia;
    var plazo = plazoIndividual;
    var vinicio = ventanaInicio;
    var vfin = ventanaFin;
    if (modo == Reto.modoLluvia) {
      // Día aleatorio de la semana (se puede re-sortear desde el diálogo).
      // fechaInicio sigue siendo el lunes (ancla de la semana); la lluvia
      // corre en su ventana horaria y vence al terminarla.
      diaLluvia ??= sortearDiaLluvia(inicio);
      final d = DateTime(diaLluvia.year, diaLluvia.month, diaLluvia.day);
      diaLluvia = d;
      vinicio ??= DateTime(d.year, d.month, d.day, 16);
      vfin ??= DateTime(d.year, d.month, d.day, 18);
      fin ??= vfin;
    }
    if (modo == Reto.modoFrenesi) {
      // Compatibilidad: plazoIndividual (legacy) = fin de la ventana.
      plazo ??= vfin;
    }
    final creado = Reto(
      titulo: titulo,
      descripcion: descripcion,
      puntos: puntos,
      fechaInicio: inicio,
      fechaFin: fin,
      modo: modo,
      fechaLluvia: diaLluvia,
      plazoIndividual: plazo,
      ventanaInicio:
          (modo == Reto.modoFrenesi || modo == Reto.modoLluvia) ? vinicio : null,
      ventanaFin:
          (modo == Reto.modoFrenesi || modo == Reto.modoLluvia) ? vfin : null,
      multiplicador: modo == Reto.modoFrenesi ? multiplicador : 1,
    );
    final id = await _db.insertReto(creado);
    notifyListeners();
    return creado.copyWith(id: id);
  }

  /// Sortea un día aleatorio dentro de la semana de hoy, excluyendo los días
  /// ya pasados (si no, el reto se autodestruiría al crearse por vencido).
  /// Devuelve el día a las 00:00.
  static DateTime sortearDiaLluvia([DateTime? base]) {
    final ref = base ?? DateTime.now();
    final lunes = ref.subtract(Duration(days: ref.weekday - 1));
    final inicio = DateTime(lunes.year, lunes.month, lunes.day);
    final hoy = DateTime.now();
    final diasRestantes =
        inicio.add(const Duration(days: 7)).difference(hoy).inDays + 1;
    if (diasRestantes <= 0) return hoy;
    final maxDias = diasRestantes > 7 ? 7 : diasRestantes;
    final offset = Random().nextInt(maxDias);
    final elegido = inicio.add(Duration(days: offset));
    final d = DateTime(elegido.year, elegido.month, elegido.day);
    return d.isBefore(DateTime(hoy.year, hoy.month, hoy.day))
        ? DateTime(hoy.year, hoy.month, hoy.day)
        : d;
  }

  /// El admin edita un reto (título, descripción o puntos).
  Future<void> editarReto(Reto reto) async {
    await _db.updateReto(reto);
    notifyListeners();
  }

  /// El admin elimina un reto (solo se quita el reto; los puntos ya
  /// otorgados por retos aprobados no se tocan).
  Future<void> eliminarReto(int id) async {
    await _db.eliminarReto(id);
    notifyListeners();
  }

  /// Un integrante marca que cumplió el reto de la semana.
  /// - normal: solo registra la marca (la aprueba el admin).
  /// - lluvia: solo en su día; el PRIMERO gana al instante y cierra el reto.
  /// - frenesí: solo hasta "su tiempo"; después su slot queda para robar.
  Future<void> marcarRetoCumplido(Reto reto) async {
    final uid = _usuarioActual?.id;
    if (uid == null) return;
    if (reto.finalizado || reto.cumplidos.contains(uid)) return;
    final ahora = DateTime.now();

    if (reto.esLluvia) {
      if (!reto.lluviaActiva(ahora)) return;
      if (reto.ganador == null && reto.marcas.isEmpty) {
        // ¡Fue el primero!: paga ya, pero el reto queda vigente el resto
        // del día para que todos vean quién ganó (cierra solo al vencer).
        final actualizado = reto.copyWith(
          marcas: {uid: ahora.millisecondsSinceEpoch},
          cumplidos: [...reto.cumplidos, uid],
          ganador: uid,
        );
        await _db.updateReto(actualizado);
        await _pagarReto(actualizado);
        unawaited(
          _db.enviarPush(
            uid,
            '¡Ganaste la lluvia!',
            'Llegaste primero al reto "${reto.titulo}" y ganaste ${reto.puntos} puntos.',
          ),
        );
      } else {
        // Ya hay un ganador: solo registra el intento (no gana puntos).
        await _db.updateReto(
          reto.copyWith(
            marcas: {...reto.marcas, uid: ahora.millisecondsSinceEpoch},
          ),
        );
      }
      notifyListeners();
      return;
    }

    if (reto.esFrenesi && !reto.puedeMarcarFrenesi(ahora)) return;
    // Modo normal/frenesí: no se puede marcar un reto ya vencido (antes
    // competía contra el cierre automático y el cobro se perdía).
    if (!reto.esLluvia && reto.vencido(ahora)) return;
    await _db.updateReto(reto.copyWith(cumplidos: [...reto.cumplidos, uid]));
    notifyListeners();
  }

  /// Tareas del día de la lluvia que NADIE tiene asignadas: el "pozo" que
  /// se abre durante la ventana. El primero en tomarla cobra al instante.
  Future<List<Task>> tareasPozoLluvia(Reto reto) async {
    if (!reto.esLluvia) return const [];
    final fin = reto.finLluvia;
    if (fin == null) return const [];
    const nombres = [
      'domingo',
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
    ];
    final dia = nombres[fin.weekday % 7];
    final tareas = await _db.getTareas();
    final result = <Task>[];
    for (final t in tareas) {
      if (!t.activa) continue;
      final esDelDia = t.dia == dia ||
          (t.fechaLimite != null &&
              t.fechaLimite!.year == fin.year &&
              t.fechaLimite!.month == fin.month &&
              t.fechaLimite!.day == fin.day);
      if (!esDelDia) continue;
      // El pozo incluye las tareas del día de TODOS los niños (aunque ya
      // tengan asignación: la carrera es por quien la toma primero). Solo
      // fuera del pozo las que alguien ya tomó aquí (`tomas`) o las que ya
      // pagaron (asignación aprobada) para no duplicar puntos.
      if (reto.tomas.containsKey(t.id!)) continue;
      final asignadas = await _db.getAsignacionesPorTarea(t.id!);
      if (asignadas.any((a) => a.aprobada)) continue;
      result.add(t);
    }
    return result;
  }

  /// El usuario actual toma una tarea del pozo de la lluvia: queda
  /// completada y aprobada al instante y cobra `tarea.puntos` sin esperar
  /// al admin. La tarea desaparece del pozo (ya tiene asignación).
  Future<bool> tomarDelPozo(Reto reto, int tareaId) async {
    final uid = _usuarioActual?.id;
    if (uid == null) return false;
    final ahora = DateTime.now();
    if (!reto.lluviaEnVentana(ahora)) return false;
    final pozo = await tareasPozoLluvia(reto);
    if (!pozo.any((t) => t.id == tareaId)) return false;
    final tarea = pozo.firstWhere((t) => t.id == tareaId);
    final yo = await _db.getUserById(uid);
    if (yo == null) return false;

    // Fuera del pozo las asignaciones de esta tarea que aún no pagaron: el
    // dueño pierde la carrera sin castigo y nadie cobra dos veces.
    final previas = await _db.getAsignacionesPorTarea(tareaId);
    for (final p in previas) {
      if (!p.aprobada) await _db.eliminarAsignacion(p.id!);
    }

    await _db.insertAsignacion(
      Assignment(
        usuarioId: uid,
        tareaId: tareaId,
        completada: true,
        aprobada: true,
        fechaAsignada: ahora,
        fechaCompletada: ahora,
        fechaAprobada: ahora,
      ),
    );
    final nuevosPuntos = yo.puntos + tarea.puntos;
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);
    await _db.updateUsuario(
      yo.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel),
    );
    if (_usuarioActual?.id == uid) {
      _usuarioActual = yo.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel);
    }

    // Registra la marca (la más antigua = primera en llegar) y el
    // acumulado: al cerrar la ventana, el mayor acumulado gana el bonus.
    final marcas = {...reto.marcas};
    marcas.putIfAbsent(uid, () => ahora.millisecondsSinceEpoch);
    final acumulados = {...reto.acumulados};
    acumulados[uid] = (acumulados[uid] ?? 0) + tarea.puntos;
    final actualizado = await _db
        .getRetos()
        .then(
          (lista) => lista.firstWhere((r) => r.id == reto.id, orElse: () => reto),
        );
    await _db.updateReto(
      actualizado.copyWith(
        marcas: marcas,
        acumulados: acumulados,
        // Marca la tarea como tomada: sale del pozo para todos.
        tomas: {...actualizado.tomas, tareaId: uid},
      ),
    );
    unawaited(
      _db.enviarPush(
        uid,
        '¡Lluvia de tareas!',
        'Tomaste "${tarea.titulo}" y ganaste ${tarea.puntos} puntos.',
      ),
    );
    notifyListeners();
    return true;
  }

  /// El usuario actual roba el slot de `originalId` en un reto frenesí:
  /// paga `reto.puntos` al ladrón al instante. Solo si el plazo individual
  /// ya venció, el reto sigue vigente y el slot no fue robado. Nunca
  /// descuenta puntos.
  Future<bool> robarReto(Reto reto, int originalId) async {
    final uid = _usuarioActual?.id;
    if (uid == null || uid == originalId) return false;
    if (!reto.slotRobable(originalId)) return false;
    if (!DateTime.now().isAfter(reto.plazoEfectivo)) return false;
    if (!enVentanaRobo()) return false;
    final dueno = await _db.getUserById(originalId);

    final actualizado = reto.copyWith(
      robados: {...reto.robados, originalId: uid},
    );
    await _db.updateReto(actualizado);
    await _pagarReto(actualizado);
    if (dueno != null) {
      unawaited(
        _db.enviarPush(
          originalId,
          'Te robaron el reto',
          'Pasó tu tiempo en "${reto.titulo}" y ${_usuarioActual?.nombre ?? 'otro hijo'} se llevó sus ${reto.puntos} puntos.',
        ),
      );
    }
    notifyListeners();
    return true;
  }

  /// Robos que el usuario actual aún no ha visto en pantalla: tareas suyas
  /// robadas (con fecha posterior a la última vez que vio el aviso) y slots
  /// de reto frenesí que le robaron. La consulta los marca como vistos para
  /// no repetir el diálogo en cada arranque.
  Future<List<AvisoRobo>> robosNoVistos() async {
    final uid = _usuarioActual?.id;
    if (uid == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsVisto = prefs.getInt('hq_robo_vista_$uid') ?? 0;
      final claveRetos = 'hq_reto_robos_vista_$uid';
      final retosVistos =
          (prefs.getStringList(claveRetos) ?? const <String>[]).toSet();
      final ahora = DateTime.now();
      final avisos = <AvisoRobo>[];

      final asignaciones = await _db.getAsignacionesDeUsuario(uid);
      for (final a in asignaciones) {
        final fechaRobo = a.fechaRobo;
        if (a.robadaPor == null || fechaRobo == null) continue;
        if (fechaRobo.millisecondsSinceEpoch <= tsVisto) continue;
        final ladron = await _db.getUserById(a.robadaPor!);
        final tarea = await _db.getTareaById(a.tareaId);
        if (ladron == null || tarea == null) continue;
        avisos.add(
          AvisoRobo(
            ladron: ladron.nombre,
            titulo: tarea.titulo,
            puntos: tarea.puntos,
          ),
        );
      }

      final retos = await _db.getRetos();
      for (final r in retos) {
        final ladronUid = r.robados[uid];
        if (ladronUid == null || retosVistos.contains('${r.id}')) continue;
        final ladron = await _db.getUserById(ladronUid);
        if (ladron == null) continue;
        avisos.add(
          AvisoRobo(
            ladron: ladron.nombre,
            titulo: r.titulo,
            puntos: r.puntos,
            esReto: true,
          ),
        );
        retosVistos.add('${r.id}');
      }

      if (avisos.isNotEmpty) {
        await prefs.setInt(
          'hq_robo_vista_$uid',
          ahora.millisecondsSinceEpoch,
        );
        await prefs.setStringList(claveRetos, retosVistos.toList());
      }
      return avisos;
    } catch (e) {
      debugPrint('Error al detectar robos pendientes: $e');
      return const [];
    }
  }

  /// Paga `reto.puntos` a los candidatos del reto según su modo (nunca a
  /// quienes ya están en `aprobados`) y actualiza `aprobados`. Si `finalizar`,
  /// cierra el reto. Nunca descuenta puntos.
  Future<void> _pagarReto(Reto reto, {bool finalizar = false}) async {
    final candidatos = <int>{};
    if (reto.esLluvia) {
      // En lluvia solo cobra el ganador (los demás intentos quedan en
      // `marcas`, sin puntos).
      if (reto.ganador != null) candidatos.add(reto.ganador!);
    } else if (reto.esFrenesi) {
      candidatos.addAll(reto.cumplidos);
      candidatos.addAll(reto.robados.values);
    } else {
      candidatos.addAll(reto.cumplidos);
    }
    final pagados = {...reto.aprobados};
    for (final uid in candidatos.difference(pagados)) {
      final user = await _db.getUserById(uid);
      if (user == null) continue;
      final nuevosPuntos = user.puntos + reto.puntos;
      final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);
      await _db.updateUsuario(
        user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel),
      );
      pagados.add(uid);
      if (_usuarioActual?.id == uid) {
        _usuarioActual = user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel);
      }
    }
    await _db.updateReto(
      reto.copyWith(aprobados: pagados.toList(), finalizado: finalizar || reto.finalizado),
    );
  }

  /// Otorga los puntos bonus del reto a sus candidatos y lo marca
  /// finalizado. Usado tanto por la aprobación manual del admin como por el
  /// vencimiento automático.
  Future<void> _otorgarPuntosReto(Reto reto) => _pagarReto(reto, finalizar: true);

  /// El admin aprueba el reto: otorga los puntos bonus a quienes lo cumplieron.
  /// Guarda doble pago: un reto ya finalizado no se vuelve a pagar (y
  /// `_pagarReto` nunca repite a quienes ya están en `aprobados`).
  Future<void> aprobarReto(Reto reto) async {
    if (reto.finalizado) return;
    await _otorgarPuntosReto(reto);
    notifyListeners();
  }

  /// Cierra automáticamente los retos vencidos: da los puntos a quienes ya lo
  /// cumplieron y los quita de los retos vigentes. Nunca descuenta puntos.
  Future<void> finalizarRetosVencidos({bool notificar = true}) async {
    final retos = await _db.getRetos();
    final hoy = DateTime.now();
    var huboCambio = false;
    for (final r in retos) {
      if (r.finalizado) continue;
      final vencido = r.vencido(hoy) || !r.perteneceASemana(hoy);
      if (!vencido) continue;
      var paraPagar = r;
      if (r.esLluvia && r.ganador == null && r.acumulados.isNotEmpty) {
        // La lluvia cerró sin botón de "¡Lo cumplí!": gana el que más
        // puntos acumuló tomando del pozo (empate: quien llegó primero).
        final orden = [...r.acumulados.entries]
          ..sort((a, b) {
            if (a.value != b.value) return b.value.compareTo(a.value);
            final ta = r.marcas[a.key] ?? 9007199254740991;
            final tb = r.marcas[b.key] ?? 9007199254740991;
            return ta.compareTo(tb);
          });
        paraPagar = r.copyWith(ganador: orden.first.key);
        await _db.updateReto(paraPagar);
      }
      await _otorgarPuntosReto(paraPagar);
      huboCambio = true;
    }
    if (huboCambio && notificar) notifyListeners();
  }

  /// Revierte un castigo (lo perdona): devuelve los puntos al integrante,
  /// elimina el registro del castigo y mantiene la asignación marcada como
  /// castigada para que no se vuelva a cobrar automáticamente.
  Future<void> revertirCastigo(int castigoId) async {
    final castigos = await _db.getCastigos();
    final castigo = castigos.where((c) => c.id == castigoId).firstOrNull;
    if (castigo == null) return;

    // Devolver los puntos.
    final user = await _db.getUserById(castigo.usuarioId);
    if (user != null) {
      final nuevosPuntos = user.puntos + castigo.puntos;
      await _db.updateUsuario(
        user.copyWith(
          puntos: nuevosPuntos,
          nivel: GamificationService.nivelPara(nuevosPuntos),
        ),
      );
      if (_usuarioActual?.id == castigo.usuarioId) {
        final u = await _db.getUserById(castigo.usuarioId);
        if (u != null) _usuarioActual = u;
      }
    }

    await _db.eliminarCastigo(castigoId);
    notifyListeners();
  }

  /// ¿El usuario tiene tareas vencidas sin completar? (bloquea recompensas)
  /// Puntos perdidos por castigos de un integrante en los últimos `dias`.
  Future<int> puntosCastigadosRecientes(int usuarioId, {int dias = 7}) async {
    final castigos = await _db.getCastigosDeUsuario(usuarioId);
    final corte = DateTime.now().subtract(Duration(days: dias));
    return castigos
        .where((c) => c.fecha.isAfter(corte))
        .fold<int>(0, (sum, c) => sum + c.puntos);
  }

  /// Fecha límite de una tarea según su día de la semana o fecha explícita.
  DateTime? _fechaVencimiento(Task t) {
    if (t.fechaLimite != null) {
      final fl = t.fechaLimite!;
      // Si solo se eligió fecha (medianoche), la tarea vence al final de ese día.
      if (fl.hour == 0 && fl.minute == 0 && fl.second == 0) {
        return DateTime(fl.year, fl.month, fl.day, 23, 59);
      }
      return fl;
    }
    if (t.dia.isEmpty) return null;
    // La semana empieza en domingo (día 0), igual que el plan semanal.
    const dias = [
      'domingo',
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
    ];
    final idx = dias.indexOf(t.dia);
    if (idx < 0) return null;
    final hoy = DateTime.now();
    // weekday%7: domingo=0, lunes=1 … sábado=6 (mismo índice que `dias`).
    final diff = hoy.weekday % 7 - idx;
    final fecha = hoy.subtract(Duration(days: diff));
    return DateTime(fecha.year, fecha.month, fecha.day, 23, 59);
  }

  /// Puntos a descontar por una tarea vencida (mitad del valor, mínimo 5).
  int _puntosCastigo(Task t) {
    final mitad = (t.puntos / 2).round();
    return mitad < 5 ? 5 : mitad;
  }
}
