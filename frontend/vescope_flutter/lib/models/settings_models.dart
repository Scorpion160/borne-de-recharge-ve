class AlarmThresholds {
  const AlarmThresholds({
    required this.lowVoltageV,
    required this.highVoltageV,
    required this.lowPowerFactor,
    required this.lowFrequencyHz,
    required this.highFrequencyHz,
    required this.staleAfterS,
  });

  final double lowVoltageV;
  final double highVoltageV;
  final double lowPowerFactor;
  final double lowFrequencyHz;
  final double highFrequencyHz;
  final double staleAfterS;

  factory AlarmThresholds.fromJson(Map<String, dynamic> json) => AlarmThresholds(
        lowVoltageV: (json['low_voltage_v'] as num?)?.toDouble() ?? 207,
        highVoltageV: (json['high_voltage_v'] as num?)?.toDouble() ?? 253,
        lowPowerFactor: (json['low_power_factor'] as num?)?.toDouble() ?? 0.9,
        lowFrequencyHz: (json['low_frequency_hz'] as num?)?.toDouble() ?? 49,
        highFrequencyHz: (json['high_frequency_hz'] as num?)?.toDouble() ?? 51,
        staleAfterS: (json['stale_after_s'] as num?)?.toDouble() ?? 180,
      );

  static const recommended = AlarmThresholds(
    lowVoltageV: 207,
    highVoltageV: 253,
    lowPowerFactor: 0.9,
    lowFrequencyHz: 49,
    highFrequencyHz: 51,
    staleAfterS: 180,
  );

  Map<String, dynamic> toJson() => {
        'low_voltage_v': lowVoltageV,
        'high_voltage_v': highVoltageV,
        'low_power_factor': lowPowerFactor,
        'low_frequency_hz': lowFrequencyHz,
        'high_frequency_hz': highFrequencyHz,
        'stale_after_s': staleAfterS,
      };

  AlarmThresholds copyWith({
    double? lowVoltageV,
    double? highVoltageV,
    double? lowPowerFactor,
    double? lowFrequencyHz,
    double? highFrequencyHz,
    double? staleAfterS,
  }) =>
      AlarmThresholds(
        lowVoltageV: lowVoltageV ?? this.lowVoltageV,
        highVoltageV: highVoltageV ?? this.highVoltageV,
        lowPowerFactor: lowPowerFactor ?? this.lowPowerFactor,
        lowFrequencyHz: lowFrequencyHz ?? this.lowFrequencyHz,
        highFrequencyHz: highFrequencyHz ?? this.highFrequencyHz,
        staleAfterS: staleAfterS ?? this.staleAfterS,
      );

  bool sameAs(AlarmThresholds other) =>
      lowVoltageV == other.lowVoltageV &&
      highVoltageV == other.highVoltageV &&
      lowPowerFactor == other.lowPowerFactor &&
      lowFrequencyHz == other.lowFrequencyHz &&
      highFrequencyHz == other.highFrequencyHz &&
      staleAfterS == other.staleAfterS;
}

class DeviceSettings {
  const DeviceSettings({
    required this.deviceId,
    required this.thresholds,
    this.persisted = false,
    this.updatedAt,
  });

  factory DeviceSettings.fromJson(Map<String, dynamic> json) => DeviceSettings(
        deviceId: json['device_id']?.toString() ?? 'borne-01',
        thresholds: AlarmThresholds.fromJson(
          (json['alarm_thresholds'] as Map?)?.map((key, value) => MapEntry(key.toString(), value)) ?? const {},
        ),
        persisted: json['persisted'] == true,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  final String deviceId;
  final AlarmThresholds thresholds;
  final bool persisted;
  final DateTime? updatedAt;
}
