import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/hub_api.dart';
import '../../models/operational_models.dart';
import '../../models/vescope_models.dart';
import '../../state/vescope_controller.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.controller});

  final VescopeController controller;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final HubApi _api = const HubApi();
  final TextEditingController _search = TextEditingController();
  Timer? _timer;
  List<StoredSession> _items = const [];
  String _state = 'ALL';
  String? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = await _api.fetchStoredSessions();
    if (!mounted) return;
    setState(() {
      _items = next;
      _loading = false;
      if (_selectedId == null && next.isNotEmpty) _selectedId = next.first.sessionId;
    });
  }

  List<StoredSession> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _items.where((item) {
      final stateMatches = _state == 'ALL' || item.state.name.toUpperCase() == _state;
      final queryMatches = query.isEmpty || item.sessionId.toLowerCase().contains(query);
      return stateMatches && queryMatches;
    }).toList(growable: false);
  }

  Future<void> _downloadMeasurements(String sessionId) async {
    try {
      final opened = await launchUrl(_api.sessionTelemetryCsvUri(sessionId), mode: LaunchMode.platformDefault);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir les mesures de cette session.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir les mesures de cette session.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    StoredSession? selected;
    for (final item in rows) {
      if (item.sessionId == _selectedId) {
        selected = item;
        break;
      }
    }
    selected ??= rows.isEmpty ? null : rows.first;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final wide = viewportWidth >= 1100;
    final compact = viewportWidth < 600;

    return ListView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      children: [
        _panel(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('POSTGRESQL · DONNÉES RÉELLES', style: _eyebrowStyle),
                        SizedBox(height: 7),
                        Text('Sessions de recharge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  _badge(widget.controller.hubConnected ? 'HUB LIVE' : 'HISTORIQUE'),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 680;
                  final searchWidth = narrow ? constraints.maxWidth : (wide ? 520.0 : 340.0);
                  final stateWidth = narrow ? constraints.maxWidth : 220.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Rechercher une session',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: stateWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _state,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Tous les états')),
                            DropdownMenuItem(value: 'CHARGING', child: Text('En charge')),
                            DropdownMenuItem(value: 'COMPLETE', child: Text('Terminées')),
                            DropdownMenuItem(value: 'INTERRUPTED', child: Text('Interrompues')),
                            DropdownMenuItem(value: 'FAULT', child: Text('Défaut')),
                          ],
                          onChanged: (value) => setState(() => _state = value ?? 'ALL'),
                        ),
                      ),
                      Text('${rows.length} session${rows.length > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFF7D91A8))),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _listPanel(rows)),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _detailPanel(selected)),
            ],
          )
        else ...[
          _listPanel(rows),
          const SizedBox(height: 18),
          _detailPanel(selected),
        ],
      ],
    );
  }

  Widget _listPanel(List<StoredSession> rows) => _panel(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const LinearProgressIndicator()
            else if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucune session réelle disponible pour ces filtres.'),
              )
            else
              ...rows.map((item) {
                final selected = item.sessionId == _selectedId;
                return InkWell(
                  onTap: () => setState(() => _selectedId = item.sessionId),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF112E4A) : Colors.transparent,
                      border: Border.all(color: selected ? const Color(0xFF2E6D9F) : Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 560) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.sessionId, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _sessionMeta(Icons.timer_outlined, _duration(item.durationS)),
                                  _sessionMeta(Icons.storage_outlined, '${((item.energyWh ?? 0) / 1000).toStringAsFixed(3)} kWh'),
                                  _sessionMeta(Icons.bolt_outlined, '${((item.maxPowerW ?? 0) / 1000).toStringAsFixed(2)} kW'),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 3, child: Text(item.sessionId, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(child: Text(_duration(item.durationS))),
                            Expanded(child: Text('${((item.energyWh ?? 0) / 1000).toStringAsFixed(3)} kWh')),
                            Expanded(child: Text('${((item.maxPowerW ?? 0) / 1000).toStringAsFixed(2)} kW')),
                          ],
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      );

  Widget _detailPanel(StoredSession? selected) {
    final endReason = selected == null ? null : _endReason(selected.endReason);
    return _panel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DÉTAIL SESSION', style: _eyebrowStyle),
          const SizedBox(height: 7),
          Text(selected?.sessionId ?? 'Aucune session', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (selected == null)
            const Text('Aucune session réelle à afficher.')
          else ...[
            _badge(_stateLabel(selected.state)),
            const SizedBox(height: 18),
            _detail('Début', _dateTime(selected.startedAt), Icons.schedule_outlined),
            _detail('Fin', _dateTime(selected.endedAt), Icons.schedule_outlined),
            _detail('Énergie', '${((selected.energyWh ?? 0) / 1000).toStringAsFixed(3)} kWh', Icons.storage_outlined),
            _detail('Puissance moy.', '${((selected.averagePowerW ?? 0) / 1000).toStringAsFixed(2)} kW', Icons.bolt_outlined),
            _detail('Puissance max.', '${((selected.maxPowerW ?? 0) / 1000).toStringAsFixed(2)} kW', Icons.bolt_outlined),
            _detail('Courant max.', '${(selected.maxCurrentA ?? 0).toStringAsFixed(2)} A', Icons.speed_outlined),
            _detail('PF moyen', (selected.averagePowerFactor ?? 0).toStringAsFixed(3), Icons.speed_outlined),
            _detail('Durée', _duration(selected.durationS), Icons.timer_outlined),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.controller.databaseConnected
                    ? () => _downloadMeasurements(selected!.sessionId)
                    : null,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Télécharger les mesures de cette session'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mesures brutes de cette recharge, sans limite de 24 heures. Le navigateur peut demander vos identifiants.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8297AE)),
            ),
            if (endReason != null) ...[
              const SizedBox(height: 12),
              Text('Cause de fin : $endReason', style: const TextStyle(color: Color(0xFF8EA4BC))),
            ],
          ],
        ],
      ),
    );
  }
}

Widget _panel(BuildContext context, {required Widget child}) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

Widget _badge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        border: Border.all(color: const Color(0xFF22573B)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF75D69E), fontWeight: FontWeight.w700, fontSize: 12)),
    );

Widget _sessionMeta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF58B0FF)),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Color(0xFF9AAABD), fontSize: 12)),
      ],
    );

Widget _detail(String label, String value, IconData icon) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF58B0FF)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8297AE)))),
          const SizedBox(width: 10),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );

String _duration(int? seconds) {
  final value = seconds ?? 0;
  String two(int v) => v.toString().padLeft(2, '0');
  final hours = value ~/ 3600;
  final minutes = (value % 3600) ~/ 60;
  final secs = value % 60;
  return '${two(hours)}:${two(minutes)}:${two(secs)}';
}

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String _stateLabel(StationState state) => switch (state) {
      StationState.offline => 'Hors ligne',
      StationState.idle => 'Disponible',
      StationState.sessionStarting => 'Démarrage',
      StationState.charging => 'En charge',
      StationState.chargingLimited => 'Charge limitée',
      StationState.finishing => 'Fin de charge',
      StationState.complete => 'Terminée',
      StationState.interrupted => 'Interrompue',
      StationState.fault => 'Défaut',
      StationState.maintenance => 'Maintenance',
    };

String? _endReason(String? reason) {
  if (reason == null || reason.isEmpty || reason == 'RECOVERED_FROM_REBOOT_FRAGMENTS') return null;
  if (reason == 'CURRENT_BELOW_THRESHOLD') return 'Courant sous le seuil de fin de charge';
  return reason;
}

const _eyebrowStyle = TextStyle(
  color: Color(0xFF7890A8),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.7,
);
