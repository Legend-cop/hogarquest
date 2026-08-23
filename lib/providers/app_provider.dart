import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/assignment.dart';
import '../models/badge.dart';
import '../models/castigo.dart';
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

  User? get usuarioActual => _usuarioActual;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get huboErrorInicializacion => _errorInicializacion;
  bool get adminDesbloqueado => _adminDesbloqueado;
  bool get sinConexion => _sinConexion;
  List<User> get listaUsuarios => _usuarios;
  List<User> _usuarios = [];

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
      unawaited(NotificationService.instance
          .sincronizar(app: this, userId: user.id!));
    }
  }

  /// Cuando otro dispositivo cambia datos, se recargan y se notifica a las
  /// pantallas para que se actualicen al instante. También se aplican castigos.
  Future<void> _datosRemotos() async {
    _sinConexion = _db.sinConexion;
    final id = _usuarioActual?.id;
    if (id != null) {
      final u = await _db.getUserById(id);
      if (u != null) _usuarioActual = u;
    }
    await aplicarCastigosVencidos();
    await finalizarRetosVencidos();
    notifyListeners();
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
        _bloqueadoHasta =
            DateTime.now().add(Duration(minutes: _bloqueoMinutos));
      }
      _error = 'Usuario o contraseña incorrectos.';
      notifyListeners();
      return false;
    }
    _intentosFallidos = 0;
    _bloqueadoHasta = null;
    _usuarioActual = user;
    _adminDesbloqueado = false;
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
    final usuarios = await _db.getUsuarios();
    _usuarios = usuarios;
    notifyListeners();
    return usuarios;
  }
  Future<List<User>> listarIntegrantes({bool soloActivos = true}) =>
      _db.getIntegrantes(soloActivos: soloActivos);

  /// Busca un usuario por id (sin marcar sesión).
  Future<User?> buscarUsuario(int id) => _db.getUserById(id);

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
    String colorTema = '',
    required String password,
    String rol = 'integrante',
  }) async {
    final u = User(
      nombre: nombre,
      avatar: avatar,
      edad: edad,
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

  Future<void> crearTarea({
    required String titulo,
    String descripcion = '',
    required int puntos,
    String dificultad = 'media',
    DateTime? fechaLimite,
    String frecuencia = 'unica',
    List<int> integrantesIds = const [],
    String dia = '',
  }) async {
    final tarea = Task(
      titulo: titulo,
      descripcion: descripcion,
      puntos: puntos,
      dificultad: dificultad,
      fechaLimite: fechaLimite,
      frecuencia: frecuencia,
      dia: dia,
    );
    final tareaId = await _db.insertTarea(tarea);
    for (final uid in integrantesIds) {
      await _db.insertAsignacion(Assignment(
        usuarioId: uid,
        tareaId: tareaId,
        fechaAsignada: DateTime.now(),
      ));
      unawaited(_db.enviarPush(uid, 'Nueva tarea', titulo));
    }
    notifyListeners();
  }

  Future<void> editarTarea(Task t, {List<int> integrantesIds = const []}) async {
    await _db.updateTarea(t);
    if (integrantesIds.isNotEmpty) {
      final asignaciones = await _db.getAsignacionesDeUsuario(t.id!);
      for (final a in asignaciones) {
        if (!a.completada && !a.aprobada) {
          await _db.updateAsignacion(a.copyWith(completada: false, aprobada: false));
        }
      }
      for (final uid in integrantesIds) {
        await _db.insertAsignacion(Assignment(
          usuarioId: uid,
          tareaId: t.id!,
          fechaAsignada: DateTime.now(),
        ));
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
          await _db.updateUsuario(user.copyWith(
            puntos: nuevos,
            nivel: GamificationService.nivelPara(nuevos),
          ));
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
    final uid = _usuarioActual!.id!;
    var a = await _db.getAsignacion(uid, tareaId);
    if (a == null) return;
    a = a.copyWith(completada: true, fechaCompletada: DateTime.now());
    await _db.updateAsignacion(a);
    notifyListeners();
  }

  Future<void> aprobarAsignacion(int asignacionId) async {
    final asignaciones = await _db.getAsignacionesPorAprobar();
    final a = asignaciones.firstWhere((x) => x.id == asignacionId, orElse: () => Assignment(usuarioId: 0, tareaId: 0));
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

    final nuevosPuntos = user.puntos + tarea.puntos + GamificationService.bonusRacha(racha);
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);

    await _db.updateUsuario(user.copyWith(
      puntos: nuevosPuntos,
      nivel: nuevoNivel,
      racha: racha,
    ));

    final tareas = await _db.getTareas();
    final ganadas = GamificationService.insigniasGanadas(
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
    unawaited(_db.enviarPush(
      a.usuarioId,
      '¡Tarea aprobada!',
      'Ganaste ${tarea.puntos} puntos con "${tarea.titulo}".',
    ));
    notifyListeners();
  }

  Future<void> rechazarAsignacion(int asignacionId) async {
    final asignaciones = await _db.getAsignacionesPorAprobar();
    final a = asignaciones.firstWhere((x) => x.id == asignacionId, orElse: () => Assignment(usuarioId: 0, tareaId: 0));
    if (a.id == null) return;
    await _db.updateAsignacion(a.copyWith(completada: false, aprobada: false, fechaCompletada: null));
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
    final pendientes =
        todo.where((t) => !t.$2.completada && _esDelDiaDeHoy(t.$1)).toList();
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
  }) async {
    await _db.insertRecompensa(Reward(
      nombre: nombre,
      descripcion: descripcion,
      costoPuntos: costoPuntos,
      foto: foto,
    ));
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
    // Bloqueo: no se pueden canjear recompensas con tareas vencidas.
    if (await tieneTareasVencidas(user.id!)) {
      _error = 'Tienes tareas vencidas. Complétalas antes de canjear.';
      notifyListeners();
      return false;
    }
    final nuevosPuntos = user.puntos - r.costoPuntos;
    final nuevoNivel = GamificationService.nivelPara(nuevosPuntos);
    await _db.updateUsuario(user.copyWith(puntos: nuevosPuntos, nivel: nuevoNivel));
    await _db.insertCanje(Redemption(
      usuarioId: user.id!,
      recompensaId: r.id!,
      fecha: DateTime.now(),
    ));
    final admins = (await _db.getUsuarios()).where((u) => u.esAdmin);
    for (final a in admins) {
      unawaited(_db.enviarPush(
          a.id!, 'Canje solicitado', '${user.nombre} canjeó: ${r.nombre}'));
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
    unawaited(_db.enviarPush(
        c.usuarioId, 'Recompensa entregada', 'Tu canje fue entregado'));
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
  Future<List<int>> insigniasDe(int usuarioId) => _db.getInsigniasDeUsuario(usuarioId);

  Future<Map<String, Object?>> estadisticas() => _db.getEstadisticas();

  /// Puntos aprobados por día (últimos `dias` días) de un integrante.
  Future<List<(DateTime, int)>> puntosPorDia(int usuarioId,
      {int dias = 7}) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(Duration(days: dias - 1));
    final fin = hoy.add(const Duration(days: 1));
    final aps =
        await _db.getAsignacionesAprobadasDeUsuarioEnRango(usuarioId, inicio, fin);
    return _agruparPuntosPorDia(aps, dias: dias, inicio: inicio);
  }

  /// Puntos aprobados por día (últimos `dias` días) de TODA la familia.
  Future<List<(DateTime, int)>> puntosPorDiaGlobal({int dias = 7}) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(Duration(days: dias - 1));
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
        (inicio.add(Duration(days: i)), porDia[inicio.add(Duration(days: i))] ?? 0),
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
        usuarioId, inicio, fin);
    var puntosSemana = 0;
    var puntosHoy = 0;
    for (final a in aprobadas) {
      final t = await _db.getTareaById(a.tareaId);
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
      'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo',
    ];
    final idx = dias.indexOf(t.dia);
    return idx >= 0 && hoy_weekdayIdx == idx;
  }

  int get hoy_weekdayIdx => DateTime.now().weekday - 1;

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
      final inicioReto =
          DateTime(r.fechaInicio.year, r.fechaInicio.month, r.fechaInicio.day);
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
      final inicio =
          hoy.subtract(Duration(days: hoy.weekday % 7));
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
      await _db.updateUsuario(user.copyWith(
        puntos: user.puntos - _puntosCastigo(t),
        nivel: GamificationService.nivelPara(user.puntos - _puntosCastigo(t)),
      ));
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
    await _db.updateUsuario(user.copyWith(
      puntos: nuevosPuntos,
      nivel: GamificationService.nivelPara(nuevosPuntos),
    ));
    await _db.insertCastigo(Castigo(
      usuarioId: usuarioId,
      motivo: motivo,
      puntos: puntos,
      tipo: tipo,
      fecha: DateTime.now(),
    ));
    unawaited(_db.enviarPush(usuarioId, 'Tienes un castigo', motivo));
    if (_usuarioActual?.id == usuarioId) {
      final u = await _db.getUserById(usuarioId);
      if (u != null) _usuarioActual = u;
    }
    notifyListeners();
  }

  Future<List<Castigo>> listarCastigos() => _db.getCastigos();
  Future<List<Castigo>> castigosDe(int usuarioId) => _db.getCastigosDeUsuario(usuarioId);

  Future<void> eliminarCastigo(int id) async {
    await _db.eliminarCastigo(id);
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // RETOS
  // ---------------------------------------------------------------

  Future<List<Reto>> listarRetos() => _db.getRetos();

  // ---------------------------------------------------------------
  // CATÁLOGO DE TAREAS (puntos por defecto)
  // ---------------------------------------------------------------

  Future<List<TareaCatalogo>> listarCatalogo() => _db.getCatalogo();

  Future<void> crearCatalogo({
    required String titulo,
    required int puntos,
  }) async {
    await _db.insertCatalogo(TareaCatalogo(titulo: titulo, puntos: puntos));
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

  /// Busca los puntos por defecto del catálogo para un título (si existe).
  TareaCatalogo? buscarEnCatalogo(List<TareaCatalogo> catalogo, String titulo) {
    final t = titulo.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final c in catalogo) {
      if (c.titulo.trim().toLowerCase() == t) return c;
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

  Future<void> crearReto({
    required String titulo,
    required String descripcion,
    required int puntos,
    DateTime? fechaFin,
  }) async {
    final hoy = DateTime.now();
    final lunes =
        hoy.subtract(Duration(days: hoy.weekday - 1));
    final inicio = DateTime(lunes.year, lunes.month, lunes.day);
    await _db.insertReto(Reto(
      titulo: titulo,
      descripcion: descripcion,
      puntos: puntos,
      fechaInicio: inicio,
      fechaFin: fechaFin,
    ));
    notifyListeners();
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
  Future<void> marcarRetoCumplido(Reto reto) async {
    final uid = _usuarioActual!.id!;
    if (reto.cumplidos.contains(uid)) return;
    await _db.updateReto(reto.copyWith(
      cumplidos: [...reto.cumplidos, uid],
    ));
    notifyListeners();
  }

  /// Otorga los puntos bonus del reto a quienes lo cumplieron y lo marca
  /// finalizado. Usado tanto por la aprobación manual del admin como por el
  /// vencimiento automático.
  Future<void> _otorgarPuntosReto(Reto reto) async {
    final cumplidos = reto.cumplidos;
    for (final uid in cumplidos) {
      final user = await _db.getUserById(uid);
      if (user == null) continue;
      final nuevosPuntos = user.puntos + reto.puntos;
      await _db.updateUsuario(user.copyWith(
        puntos: nuevosPuntos,
        nivel: GamificationService.nivelPara(nuevosPuntos),
      ));
    }
    await _db.updateReto(reto.copyWith(
      aprobados: cumplidos,
      finalizado: true,
    ));
  }

  /// El admin aprueba el reto: otorga los puntos bonus a quienes lo cumplieron.
  Future<void> aprobarReto(Reto reto) async {
    await _otorgarPuntosReto(reto);
    if (reto.cumplidos.isNotEmpty) notifyListeners();
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
      await _otorgarPuntosReto(r);
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
      await _db.updateUsuario(user.copyWith(
        puntos: nuevosPuntos,
        nivel: GamificationService.nivelPara(nuevosPuntos),
      ));
      if (_usuarioActual?.id == castigo.usuarioId) {
        final u = await _db.getUserById(castigo.usuarioId);
        if (u != null) _usuarioActual = u;
      }
    }

    await _db.eliminarCastigo(castigoId);
    notifyListeners();
  }

  /// ¿El usuario tiene tareas vencidas sin completar? (bloquea recompensas)
  Future<bool> tieneTareasVencidas(int usuarioId) async {
    final pendientes = await _db.getAsignacionesPendientes();
    final hoy = DateTime.now();
    for (final a in pendientes) {
      if (a.usuarioId != usuarioId || a.castigada) continue;
      final t = await _db.getTareaById(a.tareaId);
      if (t == null) continue;
      final vence = _fechaVencimiento(t);
      if (vence == null || !hoy.isAfter(vence) || !t.activa) continue;
      final asignada = a.fechaAsignada;
      if (asignada != null && asignada.isAfter(vence)) continue;
      // Asignaciones de semanas anteriores no cuentan como vencidas.
      final inicio =
          hoy.subtract(Duration(days: hoy.weekday % 7));
      final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
      if (asignada != null && asignada.isBefore(inicioDia)) continue;
      return true;
    }
    return false;
  }

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
      'domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado',
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