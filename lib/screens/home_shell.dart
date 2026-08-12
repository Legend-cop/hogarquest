import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'rewards_screen.dart';
import 'tasks_screen.dart';

/// Controlador de navegación por pestañas, compartido entre pantallas
/// para poder saltar de tab desde el dashboard.
class HomeTabs {
  static final ValueNotifier<int> index = ValueNotifier<int>(0);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    HomeTabs.index.addListener(_onTabChange);
  }

  @override
  void dispose() {
    HomeTabs.index.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted) setState(() => _index = HomeTabs.index.value);
  }

  void _cambiarTab(int i) {
    HomeTabs.index.value = i;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin =
        context.select<AppProvider, bool>((p) => p.usuarioActual?.esAdmin ?? false);

    final screens = [
      const DashboardScreen(),
      const TasksScreen(),
      const RankingScreen(),
      const RewardsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          context.select<AppProvider, bool>((p) => p.sinConexion)
              ? const _BannerSinConexion()
              : const SizedBox.shrink(),
          Expanded(child: IndexedStack(index: _index, children: screens)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _cambiarTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(esAdmin ? Icons.fact_check_outlined : Icons.checklist_outlined),
            selectedIcon:
                Icon(esAdmin ? Icons.fact_check : Icons.checklist),
            label: 'Tareas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
          const NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard),
            label: 'Premios',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Aviso cuando el servidor está apagado y se muestran datos de la copia local.
class _BannerSinConexion extends StatelessWidget {
  const _BannerSinConexion();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Material(
      color: colores.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 16, color: colores.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Servidor apagado: mostrando la última copia guardada. Los cambios se sincronizarán al reconectar.',
                  style: TextStyle(fontSize: 12, color: colores.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
