import 'vescope_models.dart';

double? _double(Object? value) => value is num ? value.toDouble() : null;
int? _int(Object? value) => value is num ? value.toInt() : null;
DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString());

class StoredSession {
  const StoredSession({
    required this.sessionId,
    required this.state,
    this.startedAt,
    this.endedAt,
    this.durationS,
    this.energyWh,
    this.averagePowerW,
    this.maxPowerW,
    this.maxCurrentA,
    this.averagePowerFactor,
    this.endReason,
    this.updatedAt,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
        sessionId: json['session_id']?.toString() ?? '—',
        state: StationState.fromWire(json['state']),
        startedAt: _date(json['started_at']),
        endedAt: _date(json['ended_at']),
        durationS: _int(json['duration_s']),
        energyWh: _double(json['energy_wh']),
        averagePowerW: _double(json['average_power_w']),
        maxPowerW: _double(json['max_power_w']),
        maxCurrentA: _double(json['max_current_a']),
        averagePowerFactor: _double(json['average_power_factor']),
        endReason: json['end_reason']?.toString(),
        updatedAt: _date(json['updated_at']),
      );

  final String sessionId;
  final StationState state;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationS;
  final double? energyWh;
  final double? averagePowerW;
  final double? maxPowerW;
  final double? maxCurrentA;
  final double? averagePowerFactor;
  final String? endReason;
  final DateTime? updatedAt;
}

class StoredEvent {
  const StoredEvent({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.code,
    required this.message,
    this.source,
    this.value,
    this.threshold,
  });

  factory StoredEvent.fromJson(Map<String, dynamic> json) => StoredEvent(
        id: _int(json['id']) ?? 0,
        timestamp: _date(json['event_at']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        severity: json['severity']?.toString() ?? 'INFO',
        code: json['code']?.toString() ?? 'EVENT',
        message: json['message']?.toString() ?? 'Événement VE-SCOPE',
        source: json['source']?.toString(),
        value: _double(json['value']),
        threshold: _double(json['threshold']),
      );

  final int id;
  final DateTime timestamp;
  final String severity;
  final String code;
  final String message;
  final String? source;
  final double? value;
  final double? threshold;
}
