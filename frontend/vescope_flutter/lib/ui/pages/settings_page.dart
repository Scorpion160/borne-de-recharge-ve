import 'package:flutter/material.dart';

import '../../core/network/hub_api.dart';
import '../../models/settings_models.dart';
import '../../state/vescope_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final VescopeController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final HubApi _api = const HubApi();
  AlarmThresholds _current = AlarmThresholds.recommended;
  AlarmThresholds _saved = AlarmThresholds.recommended;
  bool _loading = true;
  bool _saving = false;
  bool _persisted = false;
  String _message = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.fetchDeviceSettings();
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _current = result.thresholds;
        _saved = result.thresholds;
        _persisted = result.persisted;
      }
      _loading = false;
    });
  }

  bool get _dirty => !_current.sameAs(_saved);

  void _update(AlarmThresholds value) {
    setState(() {
      _current = value;
      _message = '';
      _error = '';
    });
  }

  String? _validate() {
    if (_current.lowVoltageV >= _current.highVoltageV) {
      return 'La tension minimale doit être inférieure à la tension maximale.';
    }
    if (_current.lowFrequencyHz >= _current.highFrequencyHz) {
      return 'La fréquence minimale doit être inférieure à la fréquence maximale.';
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
      _error = '';
    });
    try {
      final result = await _api.saveDeviceSettings(_current);
      if (!mounted) return;
      setState(() {
        _current = result.thresholds;
        _saved = result.thresholds;
        _persisted = true;
        _message = 'Paramètres enregistrés et appliqués.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _current = AlarmThresholds.recommended;
      _message = 'Valeurs recommandées chargées. Enregistrez pour les appliquer.';
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 1100;
    final cards = <Widget>[
      _SettingsCard(
        icon: Icons.speed_outlined,
        title: 'Tension AC',
        subtitle: 'Plage de tension considérée comme normale.',
        child: _FieldsRow(
          compact: !twoColumns,
          children: [
            _NumberField(
              label: 'Seuil bas',
              value: _current.lowVoltageV,
              unit: 'V',
              min: 100,
              max: 299,
              step: 1,
              description: 'Une alerte est créée si la tension descend sous cette valeur.',
              onChanged: (value) => _update(_current.copyWith(lowVoltageV: value)),
            ),
            _NumberField(
              label: 'Seuil haut',
              value: _current.highVoltageV,
              unit: 'V',
              min: 101,
              max: 300,
              step: 1,
              description: 'Une alerte est créée si la tension dépasse cette valeur.',
              onChanged: (value) => _update(_current.copyWith(highVoltageV: value)),
            ),
          ],
        ),
      ),
      _SettingsCard(
        icon: Icons.warning_amber_outlined,
        title: 'Facteur de puissance',
        subtitle: 'Valeur minimale admise en fonctionnement.',
        child: _NumberField(
          label: 'Facteur de puissance minimal',
          value: _current.lowPowerFactor,
          unit: 'PF',
          min: 0.1,
          max: 1,
          step: 0.01,
          description: 'Une alerte est créée lorsque le facteur de puissance passe sous ce seuil.',
          onChanged: (value) => _update(_current.copyWith(lowPowerFactor: value)),
        ),
      ),
      _SettingsCard(
        icon: Icons.speed_outlined,
        title: 'Fréquence réseau',
        subtitle: 'Plage admissible autour de 50 Hz.',
        child: _FieldsRow(
          compact: !twoColumns,
          children: [
            _NumberField(
              label: 'Fréquence minimale',
              value: _current.lowFrequencyHz,
              unit: 'Hz',
              min: 40,
              max: 69,
              step: 0.1,
              description: 'Une alerte est créée sous cette fréquence.',
              onChanged: (value) => _update(_current.copyWith(lowFrequencyHz: value)),
            ),
            _NumberField(
              label: 'Fréquence maximale',
              value: _current.highFrequencyHz,
              unit: 'Hz',
              min: 41,
              max: 70,
              step: 0.1,
              description: 'Une alerte est créée au-dessus de cette fréquence.',
              onChanged: (value) => _update(_current.copyWith(highFrequencyHz: value)),
            ),
          ],
        ),
      ),
      _SettingsCard(
        icon: Icons.history_toggle_off_outlined,
        title: 'Disponibilité des données',
        subtitle: 'Délai avant de signaler une interruption de télémétrie.',
        child: _NumberField(
          label: 'Délai sans nouvelle mesure',
          value: _current.staleAfterS,
          unit: 's',
          min: 2,
          max: 300,
          step: 1,
          description: 'Une alerte est créée si aucune nouvelle mesure n’est reçue pendant ce délai.',
          onChanged: (value) => _update(_current.copyWith(staleAfterS: value)),
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SUPERVISION', style: _eyebrow),
                        SizedBox(height: 7),
                        Text('Seuils et alertes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_user_outlined),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Configurez les seuils utilisés par la supervision pour détecter les écarts de tension, de fréquence, de facteur de puissance et de disponibilité des données.',
                style: TextStyle(color: Color(0xFF8EA4BC), height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusChip(
                    icon: Icons.circle,
                    label: widget.controller.hubConnected ? 'Supervision connectée' : 'Supervision indisponible',
                    ok: widget.controller.hubConnected,
                  ),
                  _StatusChip(
                    icon: Icons.storage_outlined,
                    label: _persisted ? 'Configuration enregistrée' : 'Configuration non enregistrée',
                    ok: _persisted,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = twoColumns ? (constraints.maxWidth - 18) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: cards.map((card) => SizedBox(width: itemWidth, child: card)).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        _Panel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final status = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading ? 'Chargement de la configuration…' : (_dirty ? 'Modifications non enregistrées' : 'Configuration à jour'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  const Text('Les nouveaux seuils sont appliqués dès leur enregistrement.', style: TextStyle(color: Color(0xFF8297AE))),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_message, style: const TextStyle(color: Color(0xFF55D68A))),
                  ],
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_error, style: const TextStyle(color: Color(0xFFFF7070))),
                  ],
                ],
              );
              final buttons = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(onPressed: (_loading || _saving) ? null : _reset, child: const Text('Valeurs recommandées')),
                  FilledButton.icon(
                    onPressed: (!_dirty || _loading || _saving || !widget.controller.hubConnected) ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                  ),
                ],
              );
              if (compact) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [status, const SizedBox(height: 16), buttons]);
              }
              return Row(children: [Expanded(child: status), const SizedBox(width: 18), buttons]);
            },
          ),
        ),
      ],
    );
  }
}

class _FieldsRow extends StatelessWidget {
  const _FieldsRow({required this.children, required this.compact});
  final List<Widget> children;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (compact) return Column(children: children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 14), child: child)).toList());
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: children[0]), const SizedBox(width: 18), Expanded(child: children[1])]);
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({required this.label, required this.value, required this.unit, required this.min, required this.max, required this.step, required this.description, required this.onChanged});
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final double step;
  final String description;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && double.tryParse(_controller.text.replaceAll(',', '.')) != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  void _emit(String raw) {
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null) return;
    widget.onChanged(value.clamp(widget.min, widget.max).toDouble());
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _emit,
            decoration: InputDecoration(suffixText: widget.unit),
          ),
          const SizedBox(height: 8),
          Text(widget.description, style: const TextStyle(color: Color(0xFF70859D), fontSize: 12, height: 1.4)),
        ],
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.icon, required this.title, required this.subtitle, required this.child});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: const Color(0xFF58B0FF)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF7890A8))),
              ])),
            ]),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label, required this.ok});
  final IconData icon;
  final String label;
  final bool ok;
  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF55D68A) : const Color(0xFFF0B24D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), border: Border.all(color: color.withValues(alpha: .3)), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: color), const SizedBox(width: 7), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

const _eyebrow = TextStyle(color: Color(0xFF7890A8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.7);
