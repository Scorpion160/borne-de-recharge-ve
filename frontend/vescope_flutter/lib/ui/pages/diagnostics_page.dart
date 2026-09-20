import 'package:flutter/material.dart';

import '../../state/vescope_controller.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key, required this.controller});

  final VescopeController controller;

  @override
  Widget build(BuildContext context) {
    final telemetry = controller.telemetry;
    final status = controller.status;
    final diagnostics = controller.diagnostics;
    final pzemOnline = controller.pzemOnline;
    final wifiOnline = status?.wifi ?? diagnostics?.wifiConnected;
    final rssi = diagnostics?.wifiRssiDbm;
    final wifiWeak = wifiOnline == true && rssi != null && rssi <= -85;
    final durableAvailable = diagnostics?.durableStoreOk != null ||
        diagnostics?.durablePendingTelemetry != null ||
        status?.durablePending != null;
    final firmware = diagnostics?.firmware ?? status?.firmware ?? '—';
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 1100;

    final panels = <Widget>[
      _Panel(
        eyebrow: 'CONTRÔLEUR',
        title: 'État du système',
        icon: Icons.speed_outlined,
        child: _Details(rows: [
          ('Firmware', firmware),
          ('Boot ID', '${diagnostics?.bootId ?? telemetry?.bootId ?? '—'}'),
          ('Uptime', _uptime(diagnostics?.uptimeS)),
          ('Mémoire libre', _bytes(diagnostics?.freeHeapBytes)),
          ('Dernière séquence', telemetry == null ? '—' : '#${telemetry.sequence}'),
          ('Sample ID', telemetry?.sampleId ?? 'Non fourni'),
          ('Qualité donnée', telemetry == null ? 'UNAVAILABLE' : (controller.telemetryLive ? telemetry.quality : 'STALE')),
          ('Horodatage mesure', telemetry == null ? '—' : _dateTime(telemetry.timestamp)),
        ]),
      ),
      _Panel(
        eyebrow: 'RÉSEAU',
        title: 'Communications',
        icon: Icons.dns_outlined,
        child: Column(
          children: [
            _Link(label: 'VE-SCOPE Hub', state: controller.hubConnected ? _LinkState.online : _LinkState.offline, detail: controller.hubConnected ? 'WebSocket connecté' : 'Hors ligne'),
            _Link(label: 'PostgreSQL', state: controller.databaseConnected ? _LinkState.online : _LinkState.offline, detail: controller.databaseConnected ? 'Historisation active' : 'Indisponible'),
            _Link(label: 'Wi-Fi borne', state: wifiOnline == true ? (wifiWeak ? _LinkState.warning : _LinkState.online) : _LinkState.offline, detail: rssi == null ? 'État non disponible' : '$rssi dBm${wifiWeak ? ' · signal faible' : ''}'),
            _Link(label: 'PZEM', state: pzemOnline ? _LinkState.online : _LinkState.offline, detail: pzemOnline ? 'Acquisition confirmée' : 'Aucune mesure récente'),
            _Link(label: 'Bluetooth', state: diagnostics == null ? _LinkState.planned : (diagnostics.bleConnected == true ? _LinkState.online : _LinkState.ready), detail: diagnostics == null ? 'État non disponible' : (diagnostics.bleConnected == true ? 'Client connecté' : 'Service disponible')),
            const SizedBox(height: 12),
            _Details(rows: [
              ('Transport cloud', diagnostics?.cloudTransport ?? status?.cloudTransport ?? '—'),
              ('Adresse Wi-Fi', diagnostics?.wifiIp ?? '—'),
              ('RSSI', rssi == null ? '—' : '$rssi dBm${wifiWeak ? ' · faible' : ''}'),
              ('MQTT TLS', _boolLabel(diagnostics?.mqttConnected, yes: 'Connecté', no: 'Non connecté')),
              ('HTTPS', _boolLabel(diagnostics?.httpsFallbackOk, yes: 'Opérationnel', no: 'Non confirmé')),
              ('Portail captif', _portalLabel(status?.captivePortalEnabled ?? diagnostics?.captivePortalEnabled, status?.captivePortalAuthenticated ?? diagnostics?.captivePortalAuthenticated)),
            ]),
          ],
        ),
      ),
      _Panel(
        eyebrow: 'ACQUISITION',
        title: 'PZEM-004T',
        icon: Icons.sensors_outlined,
        child: _Details(rows: [
          ('État PZEM', pzemOnline ? 'EN LIGNE' : 'INDISPONIBLE'),
          ('Lectures OK', '${diagnostics?.pzemReadsOk ?? '—'}'),
          ('Erreurs cumulées', '${diagnostics?.pzemErrors ?? '—'}'),
          ('Erreurs consécutives', '${diagnostics?.pzemConsecutiveErrors ?? '—'}'),
          ('Dernière erreur', _errorLabel(diagnostics?.pzemLastError)),
          ('Tension instantanée', telemetry == null ? '—' : '${telemetry.voltageV.toStringAsFixed(1)} V'),
          ('Courant instantané', telemetry == null ? '—' : '${telemetry.currentA.toStringAsFixed(3)} A'),
        ]),
      ),
      _Panel(
        eyebrow: 'CONTINUITÉ DES DONNÉES',
        title: 'Stockage local',
        icon: Icons.hard_drive_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (durableAvailable)
              _Details(rows: [
                ('Stockage local', _boolLabel(diagnostics?.durableStoreOk, yes: 'Opérationnel', no: 'Erreur')),
                ('Erreur de file', _boolLabel(diagnostics?.durableQueueError, yes: 'Oui', no: 'Non')),
                ('Mesures en attente', '${diagnostics?.durablePendingTelemetry ?? status?.durablePending ?? '—'}'),
                ('Volume en attente', _bytes(diagnostics?.durablePendingBytes)),
                ('Sessions en attente', '${diagnostics?.durablePendingSummaries ?? '—'}'),
                ('Envois HTTPS réussis', '${diagnostics?.httpsPublishOk ?? '—'}'),
                ('Erreurs HTTPS', '${diagnostics?.httpsPublishErrors ?? '—'}'),
              ])
            else
              const _Note('Les informations de stockage local ne sont pas disponibles avec le firmware actuellement connecté.'),
            const SizedBox(height: 14),
            _Link(label: 'Stockage serveur', state: controller.databaseConnected ? _LinkState.online : _LinkState.offline, detail: 'PostgreSQL'),
            _Link(label: 'Stockage local borne', state: durableAvailable ? (diagnostics?.durableStoreOk == false ? _LinkState.offline : _LinkState.online) : _LinkState.planned, detail: durableAvailable ? 'Actif' : 'Non disponible'),
          ],
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = twoColumns ? (constraints.maxWidth - 18) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: panels.map((panel) => SizedBox(width: itemWidth, child: panel)).toList(),
            );
          },
        ),
      ],
    );
  }
}

enum _LinkState { online, offline, warning, ready, planned }

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.state, required this.detail});
  final String label;
  final _LinkState state;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _LinkState.online => const Color(0xFF55D68A),
      _LinkState.warning => const Color(0xFFF0B24D),
      _LinkState.ready => const Color(0xFF58B0FF),
      _LinkState.offline => const Color(0xFFFF7070),
      _LinkState.planned => const Color(0xFF65798E),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Flexible(child: Text(detail, textAlign: TextAlign.right, style: TextStyle(color: color == const Color(0xFFFF7070) ? color : const Color(0xFF778DA5), fontSize: 12))),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.eyebrow, required this.title, required this.icon, required this.child});
  final String eyebrow;
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(eyebrow, style: _eyebrow),
                  const SizedBox(height: 6),
                  Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                ])),
                Icon(icon, color: const Color(0xFFBED0E2)),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

class _Details extends StatelessWidget {
  const _Details({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
        children: rows.map((row) => Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
          child: Row(children: [
            Expanded(child: Text(row.$1, style: const TextStyle(color: Color(0xFF7F94AA)))),
            const SizedBox(width: 14),
            Flexible(child: Text(row.$2, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        )).toList(),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: const BoxDecoration(color: Color(0xFF101E2E), border: Border(left: BorderSide(color: Color(0xFF58B0FF), width: 3))),
        child: Text(text, style: const TextStyle(color: Color(0xFF8498AE), height: 1.4)),
      );
}

String _boolLabel(bool? value, {String yes = 'Oui', String no = 'Non'}) => value == null ? '—' : (value ? yes : no);

String _portalLabel(bool? enabled, bool? authenticated) {
  if (enabled != true) return 'Désactivé';
  return authenticated == true ? 'Authentifié' : 'Non authentifié';
}

String _errorLabel(String? value) {
  if (value == null || value.trim().isEmpty) return 'Aucune';
  final normalized = value.trim().toLowerCase();
  if (normalized == 'none' || normalized == 'null' || normalized == 'ok') return 'Aucune';
  return value;
}

String _uptime(int? seconds) {
  if (seconds == null) return '—';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (days > 0) return '$days j $hours h $minutes min';
  if (hours > 0) return '$hours h $minutes min';
  return '$minutes min';
}

String _bytes(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes o';
  return '${(bytes / 1024).toStringAsFixed(1)} KiB';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

const _eyebrow = TextStyle(color: Color(0xFF7890A8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.7);
