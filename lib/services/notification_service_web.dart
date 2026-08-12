import '../models/user.dart';
import '../providers/app_provider.dart';

/// Servicio de notificaciones del sistema para la WEB.
/// En web no existen notificaciones locales: se muestra un aviso in-app.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> init({AppProvider? app}) async {}

  /// Programa el recordatorio diario de tareas. No-op en web.
  Future<void> programarRecordatorios(
      {required AppProvider app, required User usuario}) async {}

  /// Cancela todos los recordatorios. No-op en web.
  Future<void> cancelarRecordatorios() async {}

  /// Solicita permiso de notificaciones. No-op en web.
  Future<bool> solicitarPermiso() async => true;

  /// En web siempre se considera concedido (no hay notificaciones locales).
  Future<bool> permisoConcedido() async => true;

  /// No-op en web.
  Future<bool> abrirAjustes() async => false;

  /// Hora configurada del recordatorio (minutos del día). No-op en web.
  Future<int> horaConfigurada(int userId) async => 8 * 60;

  /// Guarda la hora del recordatorio (minutos del día). No-op en web.
  Future<void> guardarHora(
      {required AppProvider app,
      required int userId,
      required int minutos}) async {}
}
