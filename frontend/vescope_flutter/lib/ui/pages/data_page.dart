import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/hub_api.dart';
import '../../state/vescope_controller.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key, required this.controller});

  final VescopeController controller;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  static const _ranges = <String, String>{
    '1h': '1 heure',
    '24h': '24 heures',
    '7d': '7 jours',
    '30d': '30 jours',
  };

  final HubApi _api = const HubApi();
  String _range = '24h';

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir cet export.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final databaseOnline = widget.controller.databaseConnected;
    final hubOnline = widget.controller.hubConnected;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200 ? 2 : 1;

    final cards = <Widget>[
      _ExportCard(
        icon: Icons.storage_outlined,
        eyebrow: 'MESURES AC',
        title: 'Export opérationnel',
        description: 'Toutes les mesures enregistrées sur la période sélectionnée pour le suivi, le diagnostic et l’analyse de fonctionnement.',
        enabled: databaseOnline,
        range: _range,
        ranges: _ranges,
        onRangeChanged: (value) => setState(() => _range = value),
        note: _range == '1h' || _range == '24h'
            ? 'Mesures détaillées'
            : 'Export optimisé pour une période longue',
        buttonLabel: 'Télécharger les mesures',
        onPressed: () => _open(_api.telemetryCsvUri(_range)),
      ),
      _ExportCard(
        icon: Icons.verified_user_outlined,
        eyebrow: 'MESURES VALIDÉES',
        title: 'Export de référence',
        description: 'Mesures approuvées pour les analyses avancées, les études de performance et l’alimentation du jumeau numérique.',
        enabled: databaseOnline,
        range: _range,
        ranges: _ranges,
        onRangeChanged: (value) => setState(() => _range = value),
        note: 'Une ligne par mesure validée disponible',
        buttonLabel: 'Télécharger les mesures validées',
        onPressed: () => _open(_api.trustedTelemetryCsvUri(_range)),
      ),
      _ExportCard(
        icon: Icons.description_outlined,
        eyebrow: 'SESSIONS',
        title: 'Historique des recharges',
        description: 'Début, fin, durée, énergie, puissances moyenne et maximale, courant maximal et facteur de puissance moyen.',
        enabled: databaseOnline,
        buttonLabel: 'Télécharger les sessions',
        onPressed: () => _open(_api.sessionsCsvUri()),
      ),
      _ExportCard(
        icon: Icons.shield_outlined,
        eyebrow: 'ÉVÉNEMENTS',
        title: 'Alarmes et journal système',
        description: 'Sévérité, code, message, source, valeur mesurée et seuil associé pour chaque événement enregistré.',
        enabled: databaseOnline,
        buttonLabel: 'Télécharger les événements',
        onPressed: () => _open(_api.eventsCsvUri()),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DONNÉES · EXPORTS', style: _eyebrowStyle),
              const SizedBox(height: 8),
              const Text('Journalisation et téléchargement', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text(
                'Les mesures AC, les sessions de recharge et les événements sont enregistrés automatiquement. Les exports CSV sont prêts à être ouverts dans Excel ou exploités par vos outils d’analyse.',
                style: TextStyle(color: Color(0xFF8EA4BC), height: 1.5),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Status(label: 'Supervision', value: hubOnline ? 'Connectée' : 'Hors ligne', ok: hubOnline),
                  _Status(label: 'Historisation', value: databaseOnline ? 'Active' : 'Indisponible', ok: databaseOnline),
                  const _Status(label: 'Format', value: 'CSV UTF-8', ok: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards.map((card) => SizedBox(width: itemWidth, child: card)).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const _Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UTILISATION DES EXPORTS', style: _eyebrowStyle),
                    SizedBox(height: 8),
                    Text('Deux niveaux de données', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Text(
                  'L’export opérationnel regroupe les mesures disponibles pour le suivi quotidien. L’export de référence contient uniquement les mesures qui ont été validées pour les analyses scientifiques et le jumeau numérique.',
                  style: TextStyle(color: Color(0xFF8EA4BC), height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.value, required this.ok});
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8EA4BC)))),
            const SizedBox(width: 20),
            Text(value, style: TextStyle(color: ok ? const Color(0xFF55D68A) : const Color(0xFFF0B24D), fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.enabled,
    required this.buttonLabel,
    required this.onPressed,
    this.range,
    this.ranges,
    this.onRangeChanged,
    this.note,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final bool enabled;
  final String buttonLabel;
  final VoidCallback onPressed;
  final String? range;
  final Map<String, String>? ranges;
  final ValueChanged<String>? onRangeChanged;
  final String? note;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFF10375D), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF58B0FF)),
            ),
            const SizedBox(height: 20),
            Text(eyebrow, style: _eyebrowStyle),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: Color(0xFF8EA4BC), height: 1.5)),
            const SizedBox(height: 18),
            if (range != null && ranges != null && onRangeChanged != null) ...[
              const Text('Période à exporter', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: range,
                items: ranges!.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: (value) {
                  if (value != null) onRangeChanged!(value);
                },
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note!, style: const TextStyle(color: Color(0xFF6F849A), fontSize: 12)),
              ],
              const SizedBox(height: 18),
            ] else
              const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: const Icon(Icons.download_outlined),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      );
}

const _eyebrowStyle = TextStyle(
  color: Color(0xFF7890A8),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.7,
);
