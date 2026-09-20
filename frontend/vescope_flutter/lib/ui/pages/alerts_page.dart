import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/hub_api.dart';
import '../../models/operational_models.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final HubApi _api = const HubApi();
  final TextEditingController _search = TextEditingController();
  Timer? _timer;
  List<StoredEvent> _items = const [];
  String _severity = 'ALL';
  String _source = 'ALL';
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
    final next = await _api.fetchStoredEvents();
    if (!mounted) return;
    setState(() {
      _items = next;
      _loading = false;
    });
  }

  List<StoredEvent> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _items.where((item) {
      final severityMatches = _severity == 'ALL' || item.severity == _severity;
      final electrical = item.source == 'pzem_ac';
      final sourceMatches = _source == 'ALL' || (_source == 'ELECTRICAL' && electrical) || (_source == 'SYSTEM' && !electrical);
      final queryMatches = query.isEmpty ||
          item.code.toLowerCase().contains(query) ||
          item.message.toLowerCase().contains(query) ||
          (item.source?.toLowerCase().contains(query) ?? false);
      return severityMatches && sourceMatches && queryMatches;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final critical = _items.where((item) => item.severity == 'ALERT' || item.severity == 'CRITICAL').length;
    final warnings = _items.where((item) => item.severity == 'WARNING').length;
    final info = _items.where((item) => item.severity == 'INFO').length;
    final electrical = _items.where((item) => item.source == 'pzem_ac').length;
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ListView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 920 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summary(context, width, 'Alertes critiques', critical),
                _summary(context, width, 'Avertissements', warnings),
                _summary(context, width, 'Informations', info),
                _summary(context, width, 'Événements électriques', electrical),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _panel(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('POSTGRESQL · JOURNAL DE PRODUCTION', style: _eyebrowStyle),
                        SizedBox(height: 7),
                        Text('Alarmes et événements', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(Icons.shield_outlined, color: Color(0xFF8EA4BC)),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 680;
                  final searchWidth = narrow ? constraints.maxWidth : 420.0;
                  final severityWidth = narrow ? constraints.maxWidth : 210.0;
                  final sourceWidth = narrow ? constraints.maxWidth : 220.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Code, message ou source'),
                        ),
                      ),
                      SizedBox(
                        width: severityWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _severity,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Toutes les sévérités')),
                            DropdownMenuItem(value: 'CRITICAL', child: Text('Critique')),
                            DropdownMenuItem(value: 'ALERT', child: Text('Alerte')),
                            DropdownMenuItem(value: 'WARNING', child: Text('Avertissement')),
                            DropdownMenuItem(value: 'INFO', child: Text('Information')),
                          ],
                          onChanged: (value) => setState(() => _severity = value ?? 'ALL'),
                        ),
                      ),
                      SizedBox(
                        width: sourceWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _source,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Toutes les sources')),
                            DropdownMenuItem(value: 'ELECTRICAL', child: Text('Qualité électrique')),
                            DropdownMenuItem(value: 'SYSTEM', child: Text('Système / supervision')),
                          ],
                          onChanged: (value) => setState(() => _source = value ?? 'ALL'),
                        ),
                      ),
                      Text('${filtered.length} événement${filtered.length > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFF7D91A8))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              if (_loading)
                const LinearProgressIndicator()
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Aucun événement ne correspond aux filtres.'),
                )
              else
                ...filtered.map((item) => _eventCard(context, item)),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _summary(BuildContext context, double width, String label, int value) => Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8297AE))),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        ],
      ),
    );

Widget _eventCard(BuildContext context, StoredEvent item) {
  final color = switch (item.severity) {
    'CRITICAL' || 'ALERT' => const Color(0xFFEF6C73),
    'WARNING' => const Color(0xFFF0B24D),
    _ => const Color(0xFF59AEFE),
  };
  final badge = Container(
    constraints: const BoxConstraints(minWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
    alignment: Alignment.center,
    child: Text(item.severity, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
  );
  final details = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(item.message, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('${item.code} · ${_dateTime(item.timestamp)}', softWrap: true, style: const TextStyle(color: Color(0xFF7890A8), fontSize: 12)),
      const SizedBox(height: 9),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (item.source != null) _meta('Source : ${item.source}'),
          if (item.value != null) _meta('Valeur : ${item.value}'),
          if (item.threshold != null) _meta('Seuil : ${item.threshold}'),
        ],
      ),
    ],
  );

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [badge, const SizedBox(height: 12), details],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [badge, const SizedBox(width: 14), Expanded(child: details)],
        );
      },
    ),
  );
}

Widget _meta(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFF102237), borderRadius: BorderRadius.circular(7)),
      child: Text(text, style: const TextStyle(color: Color(0xFF7890A8), fontSize: 11)),
    );

Widget _panel(BuildContext context, {required Widget child}) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

const _eyebrowStyle = TextStyle(
  color: Color(0xFF7890A8),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.7,
);
