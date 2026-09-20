class TelemetrySeriesPoint {
  const TelemetrySeriesPoint({
    required this.bucketAt,
    required this.samples,
    this.voltageV,
    this.voltageMinV,
    this.voltageMaxV,
    this.currentA,
    this.currentMaxA,
    this.activePowerW,
    this.activePowerMaxW,
    this.powerFactor,
    this.powerFactorMin,
    this.frequencyHz,
    this.frequencyMinHz,
    this.frequencyMaxHz,
    this.energyStartWh,
    this.energyEndWh,
  });

  factory TelemetrySeriesPoint.fromJson(Map<String, dynamic> json) =>
      TelemetrySeriesPoint(
        bucketAt: DateTime.tryParse(json['bucket_at']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        samples: (json['samples'] as num?)?.toInt() ?? 0,
        voltageV: _nullableDouble(json['voltage_v']),
        voltageMinV: _nullableDouble(json['voltage_min_v']),
        voltageMaxV: _nullableDouble(json['voltage_max_v']),
        currentA: _nullableDouble(json['current_a']),
        currentMaxA: _nullableDouble(json['current_max_a']),
        activePowerW: _nullableDouble(json['active_power_w']),
        activePowerMaxW: _nullableDouble(json['active_power_max_w']),
        powerFactor: _nullableDouble(json['power_factor']),
        powerFactorMin: _nullableDouble(json['power_factor_min']),
        frequencyHz: _nullableDouble(json['frequency_hz']),
        frequencyMinHz: _nullableDouble(json['frequency_min_hz']),
        frequencyMaxHz: _nullableDouble(json['frequency_max_hz']),
        energyStartWh: _nullableDouble(json['energy_start_wh']),
        energyEndWh: _nullableDouble(json['energy_end_wh']),
      );

  final DateTime bucketAt;
  final int samples;
  final double? voltageV;
  final double? voltageMinV;
  final double? voltageMaxV;
  final double? currentA;
  final double? currentMaxA;
  final double? activePowerW;
  final double? activePowerMaxW;
  final double? powerFactor;
  final double? powerFactorMin;
  final double? frequencyHz;
  final double? frequencyMinHz;
  final double? frequencyMaxHz;
  final double? energyStartWh;
  final double? energyEndWh;
}

class TelemetrySeriesResponse {
  const TelemetrySeriesResponse({
    required this.range,
    required this.rangeSeconds,
    required this.bucketSeconds,
    required this.items,
  });

  factory TelemetrySeriesResponse.fromJson(Map<String, dynamic> json) =>
      TelemetrySeriesResponse(
        range: json['range']?.toString() ?? '15m',
        rangeSeconds: (json['range_seconds'] as num?)?.toInt() ?? 0,
        bucketSeconds: (json['bucket_seconds'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TelemetrySeriesPoint.fromJson)
            .toList(growable: false),
      );

  final String range;
  final int rangeSeconds;
  final int bucketSeconds;
  final List<TelemetrySeriesPoint> items;
}

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : null;
