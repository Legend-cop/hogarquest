import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../sync/bluetooth_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/section_header.dart';

class BluetoothSyncScreen extends StatefulWidget {
  const BluetoothSyncScreen({super.key});

  @override
  State<BluetoothSyncScreen> createState() => _BluetoothSyncScreenState();
}

class _BluetoothSyncScreenState extends State<BluetoothSyncScreen> {
  final _svc = BluetoothSyncService.instance;

  @override
  void initState() {
    super.initState();
    for (final n in [_svc.activo, _svc.mensaje, _svc.peers, _svc.ultimaSync]) {
      n.addListener(_refrescar);
    }
  }

  @override
  void dispose() {
    for (final n in [_svc.activo, _svc.mensaje, _svc.peers, _svc.ultimaSync]) {
      n.removeListener(_refrescar);
    }
    super.dispose();
  }

  void _refrescar() => setState(() {});

  Future<void> _alternar(bool encender) async {
    if (!_svc.disponible) return;
    if (encender) {
      await _svc.start(DatabaseHelper.instance);
    } else {
      await _svc.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activo = _svc.activo.value;
    final peers = _svc.peers.value;
    final ultima = _svc.ultimaSync.value;
    final codigo = DatabaseHelper.instance.householdCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización por Bluetooth')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuoCard(
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: CircleAvatar(
                  backgroundColor: AppColors.azul.withValues(alpha: 0.15),
                  child: const Icon(Icons.bluetooth, color: AppColors.azul),
                ),
                title: const Text('Sincronización por Bluetooth',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_svc.mensaje.value),
                value: activo,
                onChanged: _svc.disponible ? _alternar : null,
              ),
            ),
            if (!_svc.disponible)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Esta función solo está disponible en Android.',
                  style: TextStyle(color: AppColors.grisMedio, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            if (activo) ...[
              DuoCard(
                child: ListTile(
                  leading: const Icon(Icons.key, color: AppColors.verdeOscuro),
                  title: const Text('Código del hogar'),
                  subtitle: const Text(
                    'Comparte este código con los dispositivos que deben '
                    'sincronizarse. Solo dispositivos con el mismo código '
                    'intercambian datos.',
                  ),
                  trailing: Text(
                    codigo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DuoButton(
                label: 'Sincronizar ahora',
                icon: Icons.sync,
                onPressed: _svc.sincronizarAhora,
              ),
              const SizedBox(height: 20),
              if (ultima != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Última sincronización: ${_hora(ultima)}',
                    style: TextStyle(color: AppColors.grisMedio, fontSize: 12),
                  ),
                ),
              SectionHeader(title: 'Dispositivos cercanos'),
              if (peers.isEmpty)
                const Text('No se han detectado dispositivos.',
                    style: TextStyle(color: AppColors.grisMedio))
              else
                for (final p in peers)
                  DuoCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.verde.withValues(alpha: 0.15),
                        child: const Icon(Icons.phone_android,
                            color: AppColors.verde),
                      ),
                      title: Text(p.nombre),
                      subtitle: Text(p.id),
                    ),
                  ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Activa la sincronización para compartir tareas, puntos y '
                  'recompensas con los demás dispositivos del hogar sin usar '
                  'internet (Bluetooth o Wi-Fi directo).',
                  style: TextStyle(color: AppColors.grisMedio),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
