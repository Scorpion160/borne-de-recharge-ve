import 'package:flutter/material.dart';

import '../../models/vescope_models.dart';
import '../../state/vescope_controller.dart';
import '../pages/alerts_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/data_page.dart';
import '../pages/diagnostics_page.dart';
import '../pages/historical_page.dart';
import '../pages/measurements_page.dart';
import '../pages/sessions_page.dart';
import '../pages/settings_page.dart';

class VescopeShell extends StatefulWidget {
  const VescopeShell({
    super.key,
    this.onLogout,
    required this.controller,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final VoidCallback? onLogout;
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
                state: widget.controller.stationState,
                isDark: widget.themeMode != ThemeMode.light,
                onToggleTheme: widget.onToggleTheme,
                compact: mobile,
                onLogout: widget.onLogout,
              ),
              body: _page(),
              bottomNavigationBar: mobile
                  ? _MobileNav(
                      items: _items,
                      selectedIndex: _index,
                      onSelected: (value) => setState(() => _index = value),
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
      case 3:
        return DataPage(controller: widget.controller);
      case 4:
        return SessionsPage(controller: widget.controller);
      case 5:
        return const AlertsPage();
      case 6:
        return DiagnosticsPage(controller: widget.controller);
      case 7:
        return SettingsPage(controller: widget.controller);
      default:
        return DashboardPage(controller: widget.controller);
    }
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<({String label, IconData icon})> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .98),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: divider))),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return Expanded(
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF173C63) : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          border: selected
                              ? const Border(bottom: BorderSide(color: Color(0xFF58B0FF), width: 2))
                              : null,
                        ),
                        child: Icon(
                          item.icon,
                          size: 21,
                          color: selected ? const Color(0xFFBFDFFF) : const Color(0xFF8CA0B6),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    this.onLogout,
    required this.title,
    required this.state,
    required this.isDark,
    required this.onToggleTheme,
    required this.compact,
  });

  final VoidCallback? onLogout;
  final String title;
  final StationState state;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final bool compact;

  @override
  Size get preferredSize => Size.fromHeight(compact ? 72 : 88);

  @override
  Widget build(BuildContext context) {
    final stateColor = switch (state) {
      StationState.offline || StationState.fault => const Color(0xFFFF7070),
      StationState.interrupted || StationState.maintenance => const Color(0xFFF0B24D),
      StationState.sessionStarting ||
      StationState.charging ||
      StationState.chargingLimited ||
      StationState.finishing => const Color(0xFF58B0FF),
      StationState.idle || StationState.complete => const Color(0xFF55D68A),
    };

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: compact ? 72 : 88,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .96),
      surfaceTintColor: Colors.transparent,
      titleSpacing: compact ? 16 : 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            const Text('BORNE DE RECHARGE VE', style: TextStyle(color: Color(0xFF70859D), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.7)),
          if (!compact) const SizedBox(height: 3),
          Text(title, style: TextStyle(fontSize: compact ? 20 : 24, fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        if (onLogout != null) IconButton(
          tooltip: 'Se déconnecter', onPressed: onLogout,
          icon: const Icon(Icons.logout)),
        Container(
          margin: EdgeInsets.symmetric(vertical: compact ? 17 : 22),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: .12),
            border: Border.all(color: stateColor.withValues(alpha: .38)),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(
                state.label,
                style: TextStyle(color: stateColor, fontWeight: FontWeight.w700, fontSize: compact ? 10 : 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onToggleTheme,
          tooltip: isDark ? 'Mode clair' : 'Mode sombre',
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        SizedBox(width: compact ? 4 : 12),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.asset('assets/branding/vescope_icon.png', width: 48, height: 48),
      );
}
