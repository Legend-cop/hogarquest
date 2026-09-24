import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/theme_controller.dart';
import '../services/celebration_service.dart';
import '../services/haptics_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'bluetooth_sync_screen.dart';
import 'local_sync_screen.dart';

/// Ajustes de la app: apariencia/sonido, recordatorio diario y (para el
/// admin) administración avanzada. maxWidth 700 con tarjetas #1E1E1E
/// en dark mode (blancas en light).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final esAdmin = app.usuarioActual?.esAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AparienciaYSonido(),
                const SizedBox(height: 16),
                const _RecordatorioAjustes(),
                if (esAdmin) ...[
                  const SizedBox(height: 16),
                  _AdministracionCard(
                    onPin: _configurarPin,
                    onExportar: _exportarRespaldo,
                    onRestaurar: _restaurarRespaldo,
                    onReiniciar: _reiniciarDatos,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _configurarPin() async {
    final pin = TextEditingController();
    final confirmar = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN de administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Crea un PIN de 4 a 6 dígitos. Se pedirá cada vez que '
              'inicies sesión como administrador.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nuevo PIN'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmar,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (pin.text.length < 4 || pin.text != confirmar.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Los PIN no coinciden o son muy cortos.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, pin.text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null || !mounted) return;
    final app = context.read<AppProvider>();
    await app.fijarPin(nuevo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN de administrador configurado.')),
      );
    }
  }

  Future<void> _exportarRespaldo() async {
    try {
      final app = context.read<AppProvider>();
      final json = await app.exportarRespaldo();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final nombre =
          'hogarquest_respaldo_${DateTime.now().toIso8601String().substring(0, 10)}';
      await FileSaver.instance.saveFile(
        name: nombre,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.other,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo descargado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $e')),
        );
      }
    }
  }

  Future<void> _restaurarRespaldo() async {
    try {
      final app = context.read<AppProvider>();
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (resultado.isEmpty) return;
      final bytes = await resultado.single.readAsBytes();
      final contenido = utf8.decode(bytes);
      final data = jsonDecode(contenido);
      if (data is! Map<String, dynamic>) {
        throw Exception('El archivo no es un respaldo válido.');
      }
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: const Text(
            'Esto reemplazará los datos actuales por el contenido del '
            'respaldo en este y otros dispositivos. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      await app.importarRespaldo(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo restaurado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo restaurar: $e')),
        );
      }
    }
  }

  Future<void> _reiniciarDatos() async {
    final controller = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esta acción borrará TODOS los datos: usuarios, tareas, '
              'asignaciones, puntos, insignias, castigos y retos.\n\n'
              'No se puede deshacer. Solo se mantendrá tu usuario Admin '
              'para que puedas volver a entrar.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Escribe REINICIAR para confirmar',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim() == 'REINICIAR'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmar != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Reiniciando datos...'),
          ],
        ),
      ),
    );
    final app = context.read<AppProvider>();
    await app.reiniciarTodo();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Tarjeta oscura #1E1E1E (dark) / blanca (light) con encabezado.
class _AjustesTarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color colorIcono;
  final Widget child;

  const _AjustesTarjeta({
    required this.titulo,
    required this.icono,
    required this.colorIcono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : AppColors.linea,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: colorIcono, size: 20),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: textoTema(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Tarjeta 1: tema (claro/oscuro/sistema), sonidos y vibración.
class _AparienciaYSonido extends StatefulWidget {
  const _AparienciaYSonido();

  @override
  State<_AparienciaYSonido> createState() => _AparienciaYSonidoState();
}

class _AparienciaYSonidoState extends State<_AparienciaYSonido> {
  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ThemeController>();
    return _AjustesTarjeta(
      titulo: 'Apariencia y sonido',
      icono: Icons.tune,
      colorIcono: AppColors.morado,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dark_mode, color: AppColors.morado),
            title: const Text('Tema'),
            subtitle: Text(switch (tema.mode) {
              ThemeMode.dark => 'Oscuro',
              ThemeMode.system => 'Según el sistema',
              ThemeMode.light => 'Claro',
            }),
            onTap: () => _elegirTema(context, tema),
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up, color: AppColors.azul),
            title: const Text('Sonidos'),
            subtitle: const Text('Celebraciones y recompensas'),
            value: CelebrationService.instance.habilitado,
            onChanged: (v) {
              CelebrationService.instance.habilitado = v;
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary:
                const Icon(Icons.vibration, color: AppColors.verdeOscuro),
            title: const Text('Vibración'),
            subtitle: const Text('Retroalimentación táctil al tocar'),
            value: HapticsService.habilitado,
            onChanged: (v) async {
              await HapticsService.setHabilitado(v);
              HapticsService.seleccion();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Future<void> _elegirTema(BuildContext context, ThemeController tema) async {
    final modo = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tema'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: tema.mode,
            onChanged: (v) {
              if (v != null) Navigator.pop(ctx, v);
            },
            child: const Column(
              children: [
                RadioListTile(
                  title: Text('Claro'),
                  value: ThemeMode.light,
                ),
                RadioListTile(
                  title: Text('Oscuro'),
                  value: ThemeMode.dark,
                ),
                RadioListTile(
                  title: Text('Según el sistema'),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (modo != null) await tema.setModo(modo);
  }
}

/// Tarjeta 2: recordatorio diario de tareas (hora + permisos).
class _RecordatorioAjustes extends StatefulWidget {
  const _RecordatorioAjustes();

  @override
  State<_RecordatorioAjustes> createState() => _RecordatorioAjustesState();
}

class _RecordatorioAjustesState extends State<_RecordatorioAjustes> {
  int? _minutos;
  bool _cargando = true;
  bool _permisoConcedido = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final userId = app.usuarioActual?.id;
    if (userId == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final minutos = await NotificationService.instance.horaConfigurada(userId);
    final permiso = await NotificationService.instance.permisoConcedido();
    if (mounted) {
      setState(() {
        _minutos = minutos;
        _permisoConcedido = permiso;
        _cargando = false;
      });
    }
  }

  Future<void> _elegirHora() async {
    final actual = _minutos ?? 8 * 60;
    final app = context.read<AppProvider>();
    final userId = app.usuarioActual?.id;
    if (userId == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: actual ~/ 60,
        minute: actual % 60,
      ),
      helpText: 'Hora del recordatorio diario',
    );
    if (picked == null || !mounted) return;
    final minutos = picked.hour * 60 + picked.minute;
    await NotificationService.instance.guardarHora(
      app: app,
      userId: userId,
      minutos: minutos,
    );
    if (mounted) {
      setState(() => _minutos = minutos);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio actualizado')),
      );
    }
  }

  Future<void> _solicitarPermiso() async {
    final concedido = await NotificationService.instance.solicitarPermiso();
    if (!concedido) return;
    if (mounted) setState(() => _permisoConcedido = true);
  }

  Future<void> _abrirAjustes() async {
    await NotificationService.instance.abrirAjustes();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const _AjustesTarjeta(
        titulo: 'Notificaciones',
        icono: Icons.notifications,
        colorIcono: AppColors.amarillo,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final minutos = _minutos ?? 8 * 60;
    final hora = minutos ~/ 60;
    final minuto = minutos % 60;
    final horaTexto =
        '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
    return _AjustesTarjeta(
      titulo: 'Notificaciones',
      icono: Icons.notifications,
      colorIcono: AppColors.amarillo,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.amarillo.withValues(alpha: 0.2),
              child: const Icon(Icons.alarm, color: AppColors.amarillo),
            ),
            title: const Text('Recordatorio diario',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Notificación a las $horaTexto para tus tareas del día'),
            trailing: TextButton(
              onPressed: _elegirHora,
              child: const Text('Cambiar hora'),
            ),
          ),
          if (!_permisoConcedido) ...[
            const Divider(height: 1),
            Row(
              children: [
                const Icon(Icons.notifications_off,
                    color: AppColors.rojo, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notificaciones bloqueadas. Actívalas desde los Ajustes '
                    'del sistema.',
                    style:
                        TextStyle(fontSize: 12, color: textoSuaveTema(context)),
                  ),
                ),
                TextButton(
                  onPressed: _abrirAjustes,
                  child: const Text('Abrir Ajustes'),
                ),
                TextButton(
                  onPressed: _solicitarPermiso,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta 3 (solo admin): PIN, respaldos, sincronización y reinicio.
class _AdministracionCard extends StatelessWidget {
  final VoidCallback onPin;
  final VoidCallback onExportar;
  final VoidCallback onRestaurar;
  final VoidCallback onReiniciar;

  const _AdministracionCard({
    required this.onPin,
    required this.onExportar,
    required this.onRestaurar,
    required this.onReiniciar,
  });

  @override
  Widget build(BuildContext context) {
    return _AjustesTarjeta(
      titulo: 'Administración',
      icono: Icons.admin_panel_settings,
      colorIcono: AppColors.azul,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.pin, color: AppColors.azul),
            title: const Text('PIN de administrador'),
            subtitle:
                const Text('Protege el acceso al panel de administración.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onPin,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download, color: AppColors.verdeOscuro),
            title: const Text('Exportar respaldo'),
            subtitle:
                const Text('Descarga una copia completa de la base de datos.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onExportar,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore, color: AppColors.azul),
            title: const Text('Restaurar respaldo'),
            subtitle: const Text('Carga un respaldo previamente descargado.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onRestaurar,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wifi_tethering, color: AppColors.azul),
            title: const Text('Sincronización local'),
            subtitle: const Text(
                'Sincroniza con otros dispositivos sin internet (misma Wi-Fi).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocalSyncScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bluetooth, color: AppColors.azul),
            title: const Text('Sincronización por Bluetooth'),
            subtitle:
                const Text('Sincroniza sin internet (Bluetooth/Wi-Fi directo).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BluetoothSyncScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever, color: AppColors.rojo),
            title: const Text('Reiniciar datos',
                style: TextStyle(color: AppColors.rojo)),
            subtitle: const Text('Borra TODOS los datos y empieza de cero.'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.rojo),
            onTap: onReiniciar,
          ),
        ],
      ),
    );
  }
}
