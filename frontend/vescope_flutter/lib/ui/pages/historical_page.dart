import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/network/hub_api.dart';
import '../../models/telemetry_series.dart';

enum _Metric {
  power('Puissance active', 'kW', 2, 1000),
  voltage('Tension', 'V', 1, 1),
  current('Courant', 'A', 2, 1),
  powerFactor('Facteur de puissance', '', 3, 1),
  frequency('Fréquence', 'Hz', 2, 1);

  const _Metric(this.label, this.unit, this.decimals, this.scale);
  final String label;
  final String unit;
  final int decimals;
  final double scale;
}

class HistoricalPage extends StatefulWidget {
  const HistoricalPage({super.key});

  @override
  State<HistoricalPage> createState() => _HistoricalPageState();
}

class _HistoricalPageState extends State<HistoricalPage> {
  static const _api = HubApi();
  static const _ranges = <String, String>{
    '1m': '1 min',
    '15m': '15 min',
    '1h': '1 h',
    '24h': '24 h',
    '7d': '7 j',
  };

  String _range = '15m';
  _Metric _metric = _Metric.power;
  TelemetrySeriesResponse? _series;
  bool _loading = true;
  bool _error = false;
  DateTime? _lastRefresh;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartPolling() {
    _timer?.cancel();
    _refresh();
    final seconds = (_range == '1m' || _range == '15m') ? 5 : 15;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final result = await _api.fetchTelemetrySeries(range: _range);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result == null;
      if (result != null) {
        _series = result;
        _lastRefresh = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    final points = series?.items ?? const <TelemetrySeriesPoint>[];
    final bucketSeconds = series?.bucketSeconds ?? 0;
    final stats = _Stats.from(points, bucketSeconds);
    final selectedAverage = _weightedAverage(points, _metric);
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ListView(
      padding: EdgeInsets.all(compact ? 16 : 24),
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
                        Text('POSTGRESQL · ANALYSE OPÉRATIONNELLE', style: _eyebrow),
                        SizedBox(height: 6),
                        Text('Historique des mesures AC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(_loading ? Icons.sync : Icons.refresh, size: 18, color: const Color(0xFF7E93A9)),
                  const SizedBox(width: 8),
                  Text(
                    _error
                        ? 'API indisponible'
                        : _lastRefresh == null
                            ? 'chargement'
                            : _time(_lastRefresh!),
                    style: const TextStyle(color: Color(0xFF6F849A), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ranges.entries.map((entry) {
                  final selected = _range == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) {
                      if (_range == entry.key) return;
                      setState(() {
                        _range = entry.key;
                        _loading = true;
                        _error = false;
                      });
                      _restartPolling();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _KpiGrid(stats: stats),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _Metric.values.map((metric) {
                  return ChoiceChip(
                    label: Text(metric.label),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 300;
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('COURBE AGRÉGÉE', style: _eyebrow),
                      const SizedBox(height: 5),
                      Text(_metric.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  );
                  final average = Column(
                    crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      const Text('Moyenne pondérée', style: TextStyle(color: Color(0xFF6F849A), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_formatScaled(selectedAverage, _metric), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  );
                  if (narrow) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), average]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: title), const SizedBox(width: 12), average],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (_error && points.isEmpty)
                const SizedBox(
                  height: 240,
                  child: Center(child: Text('Impossible de charger l’historique depuis VE-SCOPE Hub.')),
                )
              else if (points.length < 2)
                const SizedBox(
                  height: 240,
                  child: Center(child: Text('Pas encore assez de données continues pour tracer cette période.')),
                )
              else
                SizedBox(
                  height: compact ? 230 : 260,
                  width: double.infinity,
                  child: _SeriesChart(points: points, metric: _metric, bucketSeconds: bucketSeconds),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 18,
                runSpacing: 6,
                children: [
                  Text('Fenêtre d’agrégation : ${bucketSeconds > 0 ? '$bucketSeconds s' : '—'}', style: const TextStyle(color: Color(0xFF6F849A), fontSize: 12)),
                  Text('${points.length} points · ${stats.gaps} interruption${stats.gaps > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFF6F849A), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SecondaryKpis(stats: stats),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (icon: Icons.bar_chart_outlined, label: 'Puissance moyenne pondérée', value: _format(stats.averagePowerW == null ? null : stats.averagePowerW! / 1000, 2, 'kW')),
      (icon: Icons.monitor_heart_outlined, label: 'Puissance maximale', value: _format(stats.maxPowerW == null ? null : stats.maxPowerW! / 1000, 2, 'kW')),
      (icon: Icons.storage_outlined, label: 'Variation compteur énergie', value: _format(stats.energyDeltaWh == null ? null : stats.energyDeltaWh! / 1000, 3, 'kWh')),
      (icon: Icons.schedule_outlined, label: 'Mesures sources', value: stats.sampleCount == 0 ? '—' : stats.sampleCount.toString()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: columns == 1 ? 124 : 148,
          ),
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = items[index];
            return _KpiCard(icon: item.icon, label: item.label, value: item.value);
          },
        );
      },
    );
  }
}

class _SecondaryKpis extends StatelessWidget {
  const _SecondaryKpis({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Tension min.', _format(stats.minVoltageV, 1, 'V')),
      ('Tension max.', _format(stats.maxVoltageV, 1, 'V')),
      ('Courant max.', _format(stats.maxCurrentA, 2, 'A')),
      ('PF moyen pondéré', _format(stats.averagePowerFactor, 3, '')),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 500 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: columns == 1 ? 104 : 118,
          ),
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => _KpiCard(label: items[index].$1, value: items[index].$2),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFF59AEFE), size: 20),
          const SizedBox(height: 7),
        ],
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7E93A9), fontSize: 12)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({required this.points, required this.metric, required this.bucketSeconds});
  final List<TelemetrySeriesPoint> points;
  final _Metric metric;
  final int bucketSeconds;

  @override
  Widget build(BuildContext context) {
    final valid = points.where((point) => _value(point, metric) != null).toList();
    if (valid.length < 2) {
      return const Center(child: Text('Pas encore assez de données continues pour tracer cette période.'));
    }
    final values = valid.map((point) => _value(point, metric)! / metric.scale).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final first = valid.first.bucketAt;
    final last = valid.last.bucketAt;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text('${maxValue.toStringAsFixed(metric.decimals)} ${metric.unit}', style: const TextStyle(color: Color(0xFF6F849A), fontSize: 11)),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: CustomPaint(
            painter: _SeriesPainter(points: valid, metric: metric, bucketSeconds: bucketSeconds),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${minValue.toStringAsFixed(metric.decimals)} ${metric.unit}', style: const TextStyle(color: Color(0xFF6F849A), fontSize: 11)),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(_shortDateTime(first), style: const TextStyle(color: Color(0xFF6F849A), fontSize: 11))),
            const SizedBox(width: 8),
            Flexible(child: Text(_shortDateTime(last), textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF6F849A), fontSize: 11))),
          ],
        ),
      ],
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({required this.points, required this.metric, required this.bucketSeconds});
  final List<TelemetrySeriesPoint> points;
  final _Metric metric;
  final int bucketSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final data = points
        .map((point) => (point: point, value: _value(point, metric)))
        .where((item) => item.value != null)
        .map((item) => (point: item.point, value: item.value! / metric.scale))
        .toList();
    if (data.length < 2) return;

    final values = data.map((item) => item.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = math.max(maxValue - minValue, math.max(maxValue.abs() * .002, .001));
    final firstMs = data.first.point.bucketAt.millisecondsSinceEpoch;
    final lastMs = data.last.point.bucketAt.millisecondsSinceEpoch;
    final timeSpan = math.max(lastMs - firstMs, 1);
    final gapThresholdMs = math.max(bucketSeconds * 2.5, bucketSeconds + 2) * 1000;

    final grid = Paint()
      ..color = const Color(0xFF182B40)
      ..strokeWidth = 1;
    for (final factor in const [0.12, 0.5, 0.88]) {
      canvas.drawLine(Offset(0, size.height * factor), Offset(size.width, size.height * factor), grid);
    }

    final line = Paint()
      ..color = const Color(0xFF5AB0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    Path? path;
    int? previousMs;
    for (final item in data) {
      final currentMs = item.point.bucketAt.millisecondsSinceEpoch;
      final x = ((currentMs - firstMs) / timeSpan) * size.width;
      final normalized = (item.value - minValue) / span;
      final y = size.height * (.88 - normalized * .76);
      final isGap = previousMs != null && currentMs - previousMs > gapThresholdMs;
      if (path == null || isGap) {
        if (path != null) canvas.drawPath(path, line);
        path = Path()..moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      previousMs = currentMs;
    }
    if (path != null) canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.metric != metric ||
      oldDelegate.bucketSeconds != bucketSeconds;
}

class _Stats {
  const _Stats({
    required this.averagePowerW,
    required this.maxPowerW,
    required this.minVoltageV,
    required this.maxVoltageV,
    required this.maxCurrentA,
    required this.averagePowerFactor,
    required this.sampleCount,
    required this.energyDeltaWh,
    required this.gaps,
  });

  factory _Stats.from(List<TelemetrySeriesPoint> points, int bucketSeconds) {
    final energyPoints = points.where((point) => point.energyStartWh != null && point.energyEndWh != null).toList();
    final energyDelta = energyPoints.isEmpty
        ? null
        : math.max(0.0, energyPoints.last.energyEndWh! - energyPoints.first.energyStartWh!);
    return _Stats(
      averagePowerW: _weightedAverage(points, _Metric.power),
      maxPowerW: _max(points.map((p) => p.activePowerMaxW ?? p.activePowerW)),
      minVoltageV: _min(points.map((p) => p.voltageMinV ?? p.voltageV)),
      maxVoltageV: _max(points.map((p) => p.voltageMaxV ?? p.voltageV)),
      maxCurrentA: _max(points.map((p) => p.currentMaxA ?? p.currentA)),
      averagePowerFactor: _weightedAverage(points, _Metric.powerFactor),
      sampleCount: points.fold(0, (sum, point) => sum + point.samples),
      energyDeltaWh: energyDelta,
      gaps: _gapCount(points, bucketSeconds),
    );
  }

  final double? averagePowerW;
  final double? maxPowerW;
  final double? minVoltageV;
  final double? maxVoltageV;
  final double? maxCurrentA;
  final double? averagePowerFactor;
  final int sampleCount;
  final double? energyDeltaWh;
  final int gaps;
}

double? _value(TelemetrySeriesPoint point, _Metric metric) => switch (metric) {
  _Metric.power => point.activePowerW,
  _Metric.voltage => point.voltageV,
  _Metric.current => point.currentA,
  _Metric.powerFactor => point.powerFactor,
  _Metric.frequency => point.frequencyHz,
};

double? _weightedAverage(List<TelemetrySeriesPoint> points, _Metric metric) {
  double weightedSum = 0;
  int weight = 0;
  for (final point in points) {
    final value = _value(point, metric);
    if (value == null) continue;
    final samples = math.max(1, point.samples);
    weightedSum += value * samples;
    weight += samples;
  }
  return weight == 0 ? null : weightedSum / weight;
}

double? _min(Iterable<double?> values) {
  final filtered = values.whereType<double>().toList();
  return filtered.isEmpty ? null : filtered.reduce(math.min);
}

double? _max(Iterable<double?> values) {
  final filtered = values.whereType<double>().toList();
  return filtered.isEmpty ? null : filtered.reduce(math.max);
}

int _gapCount(List<TelemetrySeriesPoint> points, int bucketSeconds) {
  if (points.length < 2 || bucketSeconds <= 0) return 0;
  final thresholdMs = math.max(bucketSeconds * 2.5, bucketSeconds + 2) * 1000;
  var gaps = 0;
  for (var i = 1; i < points.length; i++) {
    final gap = points[i].bucketAt.millisecondsSinceEpoch - points[i - 1].bucketAt.millisecondsSinceEpoch;
    if (gap > thresholdMs) gaps += 1;
  }
  return gaps;
}

String _formatScaled(double? value, _Metric metric) =>
    value == null ? '—' : '${(value / metric.scale).toStringAsFixed(metric.decimals)}${metric.unit.isEmpty ? '' : ' ${metric.unit}'}';

String _format(double? value, int decimals, String unit) =>
    value == null ? '—' : '${value.toStringAsFixed(decimals)}${unit.isEmpty ? '' : ' $unit'}';

String _time(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String _shortDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
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

const _eyebrow = TextStyle(
  color: Color(0xFF70859D),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
);
