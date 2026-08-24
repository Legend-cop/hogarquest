import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_provider.dart';

/// Servicio de notificaciones del sistema para la WEB.
/// En web no existen notificaciones locales: los push llegan por FCM y se
/// muestran con el service worker. La hora del recordatorio diario se guarda y
/// se sincroniza con el server, que es quien envía el push.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _claveMinutos = 'hq_recordatorio_minutos';
  static const _claveHora = 'hq_recordatorio_hora';

  Future<void> init({AppProvider? app}) async {}

  /// Cancela todos los recordatorios. No-op en web.
  Future<void> cancelarRecordatorios() async {}

  /// Solicita permiso de notificaciones. No-op en web (FCM lo gestiona).
  Future<bool> solicitarPermiso() async => true;

  /// En web no hay notificaciones locales que consultar.
  Future<bool> permisoConcedido() async => true;

  /// No-op en web.
  Future<bool> abrirAjustes() async => false;

  /// Hora configurada del recordatorio (minutos del día).
  Future<int> horaConfigurada(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final minutos = prefs.getInt('$_claveMinutos$userId');
    if (minutos != null) return minutos;
    final hora = prefs.getInt('$_claveHora$userId');
    return (hora ?? 8) * 60;
  }

  /// Guarda la hora del recordatorio (minutos del día) y la sincroniza.
  Future<void> guardarHora(
      {required AppProvider app,
      required int userId,
      required int minutos}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_claveMinutos$userId', minutos);
    await prefs.setInt('$_claveHora$userId', minutos ~/ 60);
    await sincronizar(app: app, userId: userId);
  }

  /// Envía la hora configurada y el offset UTC local al server.
  Future<void> sincronizar(
      {required AppProvider app, required int userId}) async {
    final minutos = await horaConfigurada(userId);
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    await app.guardarRecordatorioEnServer(
      userId: userId,
      minutos: minutos,
      offset: offset,
    );
  }

  /// No-op en web (no hay notificaciones locales programables).
  Future<void> programarTarea({
    required int id,
    required DateTime cuando,
    required String titulo,
    required String cuerpo,
  }) async {}

  /// No-op en web.
  Future<void> cancelarTarea(int id) async {}
}
