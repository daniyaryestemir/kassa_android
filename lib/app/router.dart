import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/kassa/presentation/kassa_screen.dart';
import '../features/kassa/presentation/kassa_sync_screen.dart';
import '../features/nomenklatura/presentation/nomenklatura_screen.dart';
import '../features/otchety/presentation/otchety_screen.dart';
import '../features/postupleniya/presentation/postupleniya_screen.dart';
import '../features/print_queue/presentation/print_queue_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sync/presentation/sync_screen.dart';

class AppRouter {
  static const home = '/';
  static const otchety = '/otchety';
  static const printQueue = '/print-queue';
  static const settings = '/settings';
  static const kassaSync = '/kassa-sync';
  static const sync = '/sync';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeShell());
      case otchety:
        return MaterialPageRoute(builder: (_) => const OtchetyScreen());
      case printQueue:
        return MaterialPageRoute(builder: (_) => const PrintQueueScreen());
      case AppRouter.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRouter.kassaSync:
        return MaterialPageRoute(builder: (_) => const KassaSyncScreen());
      case AppRouter.sync:
        return MaterialPageRoute(builder: (_) => const SyncScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeShell());
    }
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    KassaScreen(),
    PostupleniyaScreen(),
    NomenklaturaScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _HomeNavigationBar(
        currentIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    _HomeNavigationDestination(Icons.home_outlined, 'Главная'),
    _HomeNavigationDestination(Icons.point_of_sale_outlined, 'Касса'),
    _HomeNavigationDestination(Icons.inventory_2_outlined, 'Поступления'),
    _HomeNavigationDestination(Icons.list_alt_outlined, 'Товары'),
    _HomeNavigationDestination(Icons.more_horiz, 'Еще'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Material(
        color: colorScheme.surface,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              for (var index = 0; index < _destinations.length; index++)
                Expanded(
                  // The longer middle label needs a little more room than the
                  // surrounding destinations on narrow phones.
                  flex: index == 2 ? 12 : 10,
                  child: _HomeNavigationItem(
                    destination: _destinations[index],
                    selected: currentIndex == index,
                    selectedColor: colorScheme.primary,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNavigationItem extends StatelessWidget {
  const _HomeNavigationItem({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final _HomeNavigationDestination destination;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? selectedColor
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(destination.icon, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                destination.label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeNavigationDestination {
  const _HomeNavigationDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Еще')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreTile(
            title: 'Синхронизация',
            subtitle: 'Общий статус данных и ручной запуск sync',
            icon: Icons.sync_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.sync),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            title: 'Синхронизация кассы',
            subtitle: 'Очередь офлайн-чеков и повторная отправка',
            icon: Icons.receipt_long_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.kassaSync),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            title: 'Отчет',
            subtitle: 'Продажи, прибыль и сводка по оплатам',
            icon: Icons.bar_chart_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.otchety),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            title: 'Очередь печати',
            subtitle: 'Статусы заданий и количество копий',
            icon: Icons.print_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.printQueue),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            title: 'Настройки',
            subtitle: 'Изменение адреса backend без пересборки',
            icon: Icons.settings_outlined,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 30),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
