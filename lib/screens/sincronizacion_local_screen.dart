import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../sync/local_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';

/// Pantalla de estado y emparejamiento de la sincronización P2P local.
class SincronizacionLocalScreen extends StatefulWidget {
  const SincronizacionLocalScreen({super.key});

  @override
  State<SincronizacionLocalScreen> createState() => _SincronizacionLocalScreenState();
}

class _SincronizacionLocalScreenState extends State<SincronizacionLocalScreen> {
  final _ipController = TextEditingController();
  Timer? _refresco;
  StreamSubscription<void>? _cambios;

  @override
  void initState() {
    super.initState();
    _cambios = LocalSyncService.instance.onCambio.listen((_) => _refrescar());
    _refresco = Timer.periodic(const Duration(seconds: 2), (_) => _refrescar());
    _refrescar();
  }

  @override
  void dispose() {
    _refresco?.cancel();
    _cambios?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  String _haceCuanto(DateTime? t) {
    if (t == null) return 'nunca';
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return 'hace $s s';
    final m = (s / 60).floor();
    return 'hace $m min';
  }

  @override
  Widget build(BuildContext context) {
    final sync = LocalSyncService.instance;
    final estado = sync.isRunning ? 'Activa' : 'Inactiva';
    final colorEstado = sync.isRunning ? AppColors.verde : AppColors.rojo;
    final peers = sync.peersDetectados;

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización local')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_tethering, color: colorEstado),
                      const SizedBox(width: 8),
                      Text(
                        'Estado: $estado',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          estado,
                          style: TextStyle(
                            color: colorEstado,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Código de hogar',
                    style: TextStyle(color: textoSuaveTema(context)),
                  ),
                  SelectableText(
                    sync.householdCode ?? '—',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Los dispositivos de tu familia deben mostrar el mismo código '
                    'para sincronizarse sin internet.',
                    style: TextStyle(
                      color: textoSuaveTema(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.wifi, size: 16, color: textoSuaveTema(context)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tu IP: ${sync.ipsLocales.isEmpty ? 'sin conexión de red' : sync.ipsLocales.join(', ')}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Última sincronización: ${_haceCuanto(sync.ultimaSincronizacion)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (sync.ultimaAlerta != null)
            Card(
              color: Colors.amber.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                title: Text(
                  sync.ultimaAlerta!,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: sync.limpiarAlerta,
                ),
              ),
            ),
          if (!sync.permisoRedOk)
            Card(
              color: AppColors.rojo.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(Icons.wifi_off, color: AppColors.rojo),
                title: const Text(
                  'Permiso de red local denegado',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Sin este permiso la app no puede ver otros dispositivos '
                  'en tu Wi-Fi.',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => unawaited(sync.solicitarPermisoRed()),
                      child: const Text('Permitir'),
                    ),
                    TextButton(
                      onPressed: openAppSettings,
                      child: const Text('Ajustes'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => unawaited(sync.sincronizarAhora()),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar ahora'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Dispositivos en tu red',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (peers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Ninguno detectado todavía. Revisa que:\n'
                '• Ambos estén en la misma Wi-Fi (no datos móviles).\n'
                '• La app esté abierta en el otro celular.\n'
                '• Ambos tengan el mismo código de hogar.\n'
                'Si tu IP y la del otro celular comparten los primeros tres '
                'números (ej. 192.168.1.x) pero aún no aparece, agrega su IP '
                'manualmente abajo.',
                style: TextStyle(color: textoSuaveTema(context)),
              ),
            )
          else
            ...peers.map(
              (p) => ListTile(
                leading: const Icon(Icons.smartphone, color: AppColors.azul),
                title: Text(p.ip),
                subtitle: Text('puerto ${p.port} · ${_haceCuanto(p.lastSeen)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.rojo),
                  onPressed: () => sync.quitarPeer(p.ip),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          Text(
            'Agregar dispositivo manualmente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'IP del otro dispositivo',
                    hintText: '192.168.1.23',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DuoButton(
                fullWidth: false,
                onPressed: () {
                  final ip = _ipController.text.trim();
                  if (ip.isNotEmpty) {
                    sync.agregarPeerManual(ip);
                    _ipController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sincronizando con $ip…')),
                    );
                  }
                },
                label: 'Agregar',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: AppColors.fondo,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acerca de Bluetooth',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Si no hay Wi-Fi compartida, usa la "Sincronización por '
                    'Bluetooth" desde Ajustes → Sincronización entre '
                    'dispositivos: funciona sin internet entre celulares '
                    'cercanos con el mismo código de hogar.',
                    style: TextStyle(
                      color: textoSuaveTema(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
