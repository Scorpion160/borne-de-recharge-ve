import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/vescope_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final VescopeController controller;

  @override
  Widget build(BuildContext context) {
    final telemetry = controller.telemetry;
    final isLive = controller.telemetryLive;
    final rssi = controller.diagnostics?.wifiRssiDbm;
    final weakWifi = rssi != null && rssi <= -85;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 640 ? 2 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 2.4 : 1.45,
              children: [
                _MetricCard(
                  title: 'Puissance',
                  value: '${((telemetry?.activePowerW ?? 0) / 1000).toStringAsFixed(2)} kW',
                  subtitle: telemetry == null ? 'En attente de mesure' : 'Mesure réelle · ${_time(telemetry.timestamp)}',
                  icon: Icons.bolt_outlined,
                  emphasized: true,
                ),
                const _MetricCard(
                  title: 'Énergie session',
                  value: '—',
                  subtitle: 'Aucune session active',
                  icon: Icons.storage_outlined,
                ),
                const _MetricCard(
                  title: 'Durée',
                  value: '—',
                  subtitle: 'Aucune session active',
                  icon: Icons.schedule_outlined,
                ),
                _MetricCard(
                  title: 'État',
                  value: controller.stationState.label,
                  subtitle: 'État reçu de VE-SCOPE Hub',
                  icon: Icons.monitor_heart_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
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
                        Text('DONNÉES RÉELLES', style: _eyebrow),
                        SizedBox(height: 6),
                        Text('Puissance appelée', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  _LiveChip(live: isLive),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 190,
                width: double.infinity,
                child: controller.powerHistory.length < 2
                    ? const Center(child: Text('En attente de plusieurs mesures réelles pour tracer la courbe.'))
                    : CustomPaint(painter: _SparklinePainter(controller.powerHistory)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mesures reçues récemment'),
                  Text('${((telemetry?.activePowerW ?? 0) / 1000).toStringAsFixed(2)} kW', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _QuickGrid(controller: controller),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 820;
            final children = [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('SESSION ACTIVE', style: _eyebrow),
                    SizedBox(height: 6),
                    Text('Aucune session active', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 18),
                    _InfoNote('La borne est actuellement hors session de recharge.'),
                  ],
                ),
              ),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('COMMUNICATIONS', style: _eyebrow),
                    const SizedBox(height: 6),
                    const Text('État des liaisons', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    _LinkRow('VE-SCOPE Hub', controller.hubConnected, 'WebSocket connecté'),
                    _LinkRow('Télémétrie borne', isLive, isLive ? 'Donnée réelle récente' : 'Aucune donnée récente'),
                    _LinkRow('Wi-Fi Core', controller.diagnostics?.wifiConnected == true, rssi == null ? 'État non disponible' : '$rssi dBm${weakWifi ? ' · signal faible' : ''}', warning: weakWifi),
                    _LinkRow('PZEM', controller.pzemOnline, controller.pzemOnline ? 'Acquisition confirmée' : 'Aucune mesure récente'),
                    _LinkRow('Bluetooth', controller.diagnostics?.bleConnected == true, controller.diagnostics?.bleConnected == true ? 'Client connecté' : 'Service disponible', ready: controller.diagnostics?.bleConnected != true),
                  ],
                ),
              ),
            ];
            if (horizontal) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: children[0]), const SizedBox(width: 16), Expanded(child: children[1])],
              );
            }
            return Column(children: [children[0], const SizedBox(height: 16), children[1]]);
          },
        ),
      ],
    );
  }
}

String _time(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

const _eyebrow = TextStyle(
  color: Color(0xFF70859D),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
);

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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.subtitle, required this.icon, this.emphasized = false});

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: emphasized ? const Color(0xFF10243A) : Theme.of(context).cardColor,
      border: Border.all(color: emphasized ? const Color(0xFF28557F) : Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF8699AF)))), Icon(icon, color: const Color(0xFF8093A8))]),
        const Spacer(),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Color(0xFF60758D), fontSize: 12)),
      ],
    ),
  );
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: live ? const Color(0xFF10251D) : const Color(0xFF29220F),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: live ? const Color(0xFF1E4B34) : const Color(0xFF5C4B25)),
    ),
    child: Text(live ? '●  flux actif' : '●  en attente', style: TextStyle(color: live ? const Color(0xFF75D79E) : const Color(0xFFEFC878), fontWeight: FontWeight.w700, fontSize: 11)),
  );
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.controller});
  final VescopeController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;
    final items = [
      ('Tension', '${(t?.voltageV ?? 0).toStringAsFixed(1)} V'),
      ('Courant', '${(t?.currentA ?? 0).toStringAsFixed(2)} A'),
      ('Facteur de puissance', (t?.powerFactor ?? 0).toStringAsFixed(3)),
      ('Fréquence', '${(t?.frequencyHz ?? 0).toStringAsFixed(2)} Hz'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 4 ? 2.8 : 2.1,
          children: items.map((item) => Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), color: Theme.of(context).cardColor),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.$1, style: const TextStyle(color: Color(0xFF6F8399), fontSize: 12)), const SizedBox(height: 8), Text(item.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]),
          )).toList(),
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.label, this.online, this.detail, {this.warning = false, this.ready = false});
  final String label;
  final bool online;
  final String detail;
  final bool warning;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final dot = warning ? const Color(0xFFF0B35A) : ready ? const Color(0xFF59AEFE) : online ? const Color(0xFF55D68A) : const Color(0xFF6B7B8F);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(11)),
      child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 10), Expanded(child: Text(label)), Flexible(child: Text(detail, textAlign: TextAlign.right, style: TextStyle(color: warning ? const Color(0xFFC99A58) : const Color(0xFF687D94), fontSize: 12)))]),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(color: Color(0xFF101E2E), border: Border(left: BorderSide(color: Color(0xFF537CA7), width: 3))),
    child: Text(text, style: const TextStyle(color: Color(0xFF8498AE))),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFF182B40)..strokeWidth = 1;
    for (final y in [0.15, 0.5, 0.85]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), grid);
    }
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = math.max(maxValue - minValue, 1.0);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final normalized = (values[i] - minValue) / span;
      final y = size.height * (0.85 - normalized * 0.7);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF5AB0FF)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.values != values;
}
