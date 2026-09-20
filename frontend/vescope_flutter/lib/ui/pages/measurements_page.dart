import 'package:flutter/material.dart';

import '../../state/vescope_controller.dart';

class MeasurementsPage extends StatelessWidget {
  const MeasurementsPage({super.key, required this.controller});

  final VescopeController controller;

  @override
  Widget build(BuildContext context) {
    final telemetry = controller.telemetry;
    if (telemetry == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PZEM-004T', style: _eyebrow),
                SizedBox(height: 6),
                Text(
                  'Mesures électriques AC',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 18),
                Text('Aucune mesure réelle n’a encore été reçue depuis la borne.'),
              ],
            ),
          ),
        ],
      );
    }

    final live = controller.telemetryLive;
    final displayedQuality = live ? telemetry.quality : 'STALE';
    final source = telemetry.durableReplay
        ? 'PZEM / Hub · relecture durable'
        : live
            ? 'PZEM / Hub · temps réel'
            : 'PZEM / Hub · dernière mesure réelle';

    final rows = <_MeasureRowData>[
      _MeasureRowData('Tension efficace', telemetry.voltageV.toStringAsFixed(2), 'V', source),
      _MeasureRowData('Courant efficace', telemetry.currentA.toStringAsFixed(3), 'A', source),
      _MeasureRowData('Puissance active', telemetry.activePowerW.toStringAsFixed(1), 'W', source),
      _MeasureRowData('Puissance apparente', telemetry.apparentPowerVa.toStringAsFixed(1), 'VA', 'Calculée depuis la mesure réelle'),
      _MeasureRowData('Puissance non active', telemetry.nonActivePowerVarEst.toStringAsFixed(1), 'var', 'Estimée depuis S et P'),
      _MeasureRowData('Facteur de puissance', telemetry.powerFactor.toStringAsFixed(3), '—', source),
      _MeasureRowData('Fréquence', telemetry.frequencyHz.toStringAsFixed(3), 'Hz', source),
      _MeasureRowData('Énergie totale compteur', (telemetry.energyTotalWh / 1000).toStringAsFixed(3), 'kWh', source),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PZEM-004T · MESURE RÉELLE', style: _eyebrow),
                        SizedBox(height: 6),
                        Text(
                          'Mesures électriques AC',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  _QualityBadge(displayedQuality),
                ],
              ),
              const SizedBox(height: 18),
              ...rows.map((row) => _MeasurementRow(row)),
              const SizedBox(height: 12),
              _InfoNote(
                'Horodatage de la mesure : ${_dateTime(telemetry.timestamp)}. '
                'La puissance non active est une estimation dérivée de la puissance apparente S et de la puissance active P.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 760;
            final cards = <Widget>[
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fingerprint, color: Color(0xFF59AEFE)),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IDENTITÉ ÉCHANTILLON', style: _eyebrow),
                            SizedBox(height: 3),
                            Text('Traçabilité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow('Device ID', telemetry.deviceId),
                    _DetailRow('Boot ID', telemetry.bootId?.toString() ?? 'Non fourni'),
                    _DetailRow('Séquence', '#${telemetry.sequence}'),
                    _DetailRow('Sample ID', telemetry.sampleId ?? 'Non fourni'),
                  ],
                ),
              ),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cell_tower_outlined, color: Color(0xFF59AEFE)),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACHEMINEMENT', style: _eyebrow),
                            SizedBox(height: 3),
                            Text('Contexte de réception', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow('État temps réel', live ? 'LIVE' : 'STALE'),
                    _DetailRow('Relecture durable', telemetry.durableReplay ? 'Oui' : 'Non'),
                    _DetailRow('Session associée', telemetry.sessionId ?? 'Aucune'),
                    _DetailRow('Qualité déclarée', telemetry.quality),
                  ],
                ),
              ),
            ];
            if (!horizontal) {
              return Column(children: [cards[0], const SizedBox(height: 16), cards[1]]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])],
            );
          },
        ),
      ],
    );
  }
}

class _MeasureRowData {
  const _MeasureRowData(this.name, this.value, this.unit, this.source);
  final String name;
  final String value;
  final String unit;
  final String source;
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow(this.row);
  final _MeasureRowData row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: const TextStyle(color: Color(0xFF8FA3B8))),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: row.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      TextSpan(text: ' ${row.unit}', style: const TextStyle(color: Color(0xFF8195AA))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(row.source, style: const TextStyle(color: Color(0xFF667B91), fontSize: 12)),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: Text(row.name, style: const TextStyle(color: Color(0xFF8FA3B8)))),
              Expanded(
                flex: 2,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: row.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      TextSpan(text: ' ${row.unit}', style: const TextStyle(color: Color(0xFF8195AA))),
                    ],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 170,
                child: Text(row.source, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF667B91), fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge(this.quality);
  final String quality;

  @override
  Widget build(BuildContext context) {
    final normalized = quality.toUpperCase();
    final color = switch (normalized) {
      'GOOD' => const Color(0xFF55D68A),
      'STALE' => const Color(0xFFF0B35A),
      'INVALID' => const Color(0xFFFF6B6B),
      'ESTIMATED' => const Color(0xFF59AEFE),
      _ => const Color(0xFF7C8DA1),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(normalized, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF7E93A9)))),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(
      color: Color(0xFF101E2E),
      border: Border(left: BorderSide(color: Color(0xFF537CA7), width: 3)),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xFF8498AE))),
  );
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

const _eyebrow = TextStyle(
  color: Color(0xFF70859D),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
);
