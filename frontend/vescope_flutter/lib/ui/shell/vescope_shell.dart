import 'package:flutter/material.dart';

import '../../state/vescope_controller.dart';
import '../pages/dashboard_page.dart';
import '../pages/historical_page.dart';
import '../pages/measurements_page.dart';

class VescopeShell extends StatefulWidget {
  const VescopeShell({
    super.key,
    required this.controller,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final VescopeController controller;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<VescopeShell> createState() => _VescopeShellState();
}

class _VescopeShellState extends State<VescopeShell> {
  int _index = 0;

  static const _items = <({String label, IconData icon})>[
    (label: 'Vue générale', icon: Icons.grid_view_outlined),
    (label: 'Mesures AC', icon: Icons.speed_outlined),
    (label: 'Historique', icon: Icons.trending_up_outlined),
    (label: 'Données', icon: Icons.storage_outlined),
    (label: 'Sessions', icon: Icons.history_outlined),
    (label: 'Alarmes', icon: Icons.warning_amber_outlined),
    (label: 'Diagnostic', icon: Icons.tune_outlined),
    (label: 'Paramètres', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 760;
            final extended = constraints.maxWidth >= 1280;
            final body = Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: _TopBar(
                title: _items[_index].label,
                stateLabel: widget.controller.stationState.label,
                isDark: widget.themeMode != ThemeMode.light,
                onToggleTheme: widget.onToggleTheme,
              ),
              body: _page(),
              bottomNavigationBar: mobile
                  ? NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (value) => setState(() => _index = value),
                      destinations: _items
                          .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
                          .toList(),
                    )
                  : null,
            );

            if (mobile) return body;

            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  extended: extended,
                  minExtendedWidth: 248,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 18),
                    child: extended
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BrandMark(),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('VE-SCOPE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                  Text('Supervisor', style: TextStyle(color: Color(0xFF7F91A7), fontSize: 12)),
                                ],
                              ),
                            ],
                          )
                        : const _BrandMark(),
                  ),
                  destinations: _items
                      .map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)))
                      .toList(),
                  onDestinationSelected: (value) => setState(() => _index = value),
                ),
                VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                Expanded(child: body),
              ],
            );
          },
        );
      },
    );
  }

  Widget _page() {
    switch (_index) {
      case 0:
        return DashboardPage(controller: widget.controller);
      case 1:
        return MeasurementsPage(controller: widget.controller);
      case 2:
        return const HistoricalPage();
      default:
        return _MigrationPage(title: _items[_index].label, icon: _items[_index].icon);
    }
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.title,
    required this.stateLabel,
    required this.isDark,
    required this.onToggleTheme,
  });

  final String title;
  final String stateLabel;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 88,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .96),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.sizeOf(context).width >= 760)
            const Text('BORNE DE RECHARGE VE', style: TextStyle(color: Color(0xFF70859D), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.7)),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 22),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF102A20),
            border: Border.all(color: const Color(0xFF22573B)),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF55D68A), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(stateLabel, style: const TextStyle(color: Color(0xFF89DDB0), fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: onToggleTheme,
          tooltip: isDark ? 'Mode clair' : 'Mode sombre',
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(color: const Color(0xFF173C63), borderRadius: BorderRadius.circular(13)),
    child: const Icon(Icons.bolt_outlined, color: Color(0xFF8EC8FF)),
  );
}

class _MigrationPage extends StatelessWidget {
  const _MigrationPage({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Migration Flutter en cours. Cette page sera raccordée au même VE-SCOPE Hub que la version Web de référence.', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
