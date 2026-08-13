import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/assignment.dart';
import '../models/badge.dart';
import '../models/castigo.dart';
import '../models/redemption.dart';
import '../models/reto.dart';
import '../models/reward.dart';
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
  bool _sinConexion = false;

  User? get usuarioActual => _usuarioActual;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get sinConexion => _sinConexion;
  List<User> get listaUsuarios => _usuarios;
  List<User> _usuarios = [];

  Future<void> init() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await _db.init();
      await _restaurarSesion();
    } catch (e) {
      _error = e.toString();
    }
    _db.onRemoteChange = _datosRemotos;
    await aplicarCastigosVencidos();
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
          .programarRecordatorios(app: this, usuario: user));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_claveSesion, user.id!);
    unawaited(NotificationService.instance
        .solicitarPermiso());
    unawaited(NotificationService.instance
        .programarRecordatorios(app: this, usuario: user));
    notifyListeners();
    return true;
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
    unawaited(NotificationService.instance.cancelarRecordatorios());
    unawaited(_limpiarSesion());
    notifyListeners();
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
    await _db.deleteTarea(id);
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
  }) async {
    await _db.insertRecompensa(
        Reward(nombre: nombre, descripcion: descripcion, costoPuntos: costoPuntos));
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
    final pendientes = await _db.getAsignacionesPendientes();
    final hoy = DateTime.now();
    for (final a in pendientes) {
      if (a.castigada) continue;
      final t = await _db.getTareaById(a.tareaId);
      if (t == null) continue;
      final vence = _fechaVencimiento(t);
      // Solo se castiga si el día/plazo ya pasó y la tarea sigue activa.
      if (vence != null && hoy.isAfter(vence) && t.activa) {
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

  /// Reto vigente de la semana en curso (si el admin creó uno).
  Future<Reto?> retoDeLaSemana() async {
    final retos = await _db.getRetos();
    final hoy = DateTime.now();
    for (final r in retos) {
      if (r.vigente && r.perteneceASemana(hoy)) return r;
    }
    return null;
  }

  Future<void> crearReto({
    required String titulo,
    required String descripcion,
    required int puntos,
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
    ));
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

  /// El admin aprueba el reto: otorga los puntos bonus a quienes lo cumplieron.
  Future<void> aprobarReto(Reto reto) async {
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
    if (cumplidos.isNotEmpty) notifyListeners();
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
      if (vence != null && hoy.isAfter(vence) && t.activa) return true;
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
    if (t.fechaLimite != null) return t.fechaLimite;
    if (t.dia.isEmpty) return null;
    const dias = [
      'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo',
    ];
    final idx = dias.indexOf(t.dia);
    if (idx < 0) return null;
    final hoy = DateTime.now();
    // Fecha del día asignado en la semana actual.
    final diff = hoy.weekday - 1 - idx;
    final fecha = hoy.subtract(Duration(days: diff));
    return DateTime(fecha.year, fecha.month, fecha.day, 23, 59);
  }

  /// Puntos a descontar por una tarea vencida (mitad del valor, mínimo 5).
  int _puntosCastigo(Task t) {
    final mitad = (t.puntos / 2).round();
    return mitad < 5 ? 5 : mitad;
  }
}