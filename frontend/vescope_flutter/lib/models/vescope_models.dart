enum StationState {
  offline,
  idle,
  sessionStarting,
  charging,
  chargingLimited,
  finishing,
  complete,
  interrupted,
  fault,
  maintenance;

  static StationState fromWire(Object? value) {
    switch (value?.toString().toUpperCase()) {
      case 'IDLE': return StationState.idle;
      case 'SESSION_STARTING': return StationState.sessionStarting;
      case 'CHARGING': return StationState.charging;
      case 'CHARGING_LIMITED': return StationState.chargingLimited;
      case 'FINISHING': return StationState.finishing;
      case 'COMPLETE': return StationState.complete;
      case 'INTERRUPTED': return StationState.interrupted;
      case 'FAULT': return StationState.fault;
      case 'MAINTENANCE': return StationState.maintenance;
      default: return StationState.offline;
    }
  }

  String get label => switch (this) {
    StationState.offline => 'HORS LIGNE',
    StationState.idle => 'DISPONIBLE',
    StationState.sessionStarting => 'DÉMARRAGE',
    StationState.charging => 'EN CHARGE',
    StationState.chargingLimited => 'CHARGE LIMITÉE',
    StationState.finishing => 'FIN DE CHARGE',
    StationState.complete => 'CHARGE TERMINÉE',
    StationState.interrupted => 'INTERROMPUE',
    StationState.fault => 'DÉFAUT',
    StationState.maintenance => 'MAINTENANCE',
  };
}

double _number(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble() ?? 0;

int _integer(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toInt() ?? 0;

class AcTelemetry {
  const AcTelemetry({
    required this.deviceId,
    required this.timestamp,
    required this.sequence,
    required this.quality,
    required this.voltageV,
    required this.currentA,
    required this.activePowerW,
    required this.apparentPowerVa,
    required this.nonActivePowerVarEst,
    required this.powerFactor,
    required this.frequencyHz,
    required this.energyTotalWh,
    this.sampleId,
    this.bootId,
    this.sessionId,
    this.durableReplay = false,
  });

  factory AcTelemetry.fromJson(Map<String, dynamic> json) => AcTelemetry(
    deviceId: json['device_id']?.toString() ?? 'borne-01',
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now().toUtc(),
    sequence: _integer(json, 'sequence'),
    quality: json['quality']?.toString() ?? 'UNAVAILABLE',
    voltageV: _number(json, 'voltage_v'),
    currentA: _number(json, 'current_a'),
    activePowerW: _number(json, 'active_power_w'),
    apparentPowerVa: _number(json, 'apparent_power_va'),
    nonActivePowerVarEst: _number(json, 'non_active_power_var_est'),
    powerFactor: _number(json, 'power_factor'),
    frequencyHz: _number(json, 'frequency_hz'),
    energyTotalWh: _number(json, 'energy_total_wh'),
    sampleId: json['sample_id']?.toString(),
    bootId: (json['boot_id'] as num?)?.toInt(),
    sessionId: json['session_id']?.toString(),
    durableReplay: json['durable_replay'] == true,
  );

  final String deviceId;
  final DateTime timestamp;
  final int sequence;
  final String quality;
  final double voltageV;
  final double currentA;
  final double activePowerW;
  final double apparentPowerVa;
  final double nonActivePowerVarEst;
  final double powerFactor;
  final double frequencyHz;
  final double energyTotalWh;
  final String? sampleId;
  final int? bootId;
  final String? sessionId;
  final bool durableReplay;
}

class CoreStatus {
  const CoreStatus({
    this.state = StationState.offline,
    this.firmware,
    this.pzemOnline,
    this.wifi,
    this.ble,
    this.cloudTransport,
  });

  factory CoreStatus.fromJson(Map<String, dynamic> json) => CoreStatus(
    state: StationState.fromWire(json['state']),
    firmware: json['firmware']?.toString(),
    pzemOnline: json['pzem_online'] as bool?,
    wifi: json['transport_wifi'] as bool?,
    ble: json['transport_ble'] as bool?,
    cloudTransport: json['cloud_transport']?.toString(),
  );

  final StationState state;
  final String? firmware;
  final bool? pzemOnline;
  final bool? wifi;
  final bool? ble;
  final String? cloudTransport;
}

class CoreDiagnostics {
  const CoreDiagnostics({
    this.firmware,
    this.uptimeS,
    this.freeHeapBytes,
    this.wifiConnected,
    this.wifiRssiDbm,
    this.wifiIp,
    this.mqttConnected,
    this.httpsFallbackOk,
    this.bleConnected,
    this.pzemOnline,
    this.pzemReadsOk,
    this.pzemErrors,
    this.bootId,
  });

  factory CoreDiagnostics.fromJson(Map<String, dynamic> json) => CoreDiagnostics(
    firmware: json['firmware']?.toString(),
    uptimeS: (json['uptime_s'] as num?)?.toInt(),
    freeHeapBytes: (json['free_heap_bytes'] as num?)?.toInt(),
    wifiConnected: json['wifi_connected'] as bool?,
    wifiRssiDbm: (json['wifi_rssi_dbm'] as num?)?.toInt(),
    wifiIp: json['wifi_ip']?.toString(),
    mqttConnected: json['mqtt_connected'] as bool?,
    httpsFallbackOk: json['https_fallback_ok'] as bool?,
    bleConnected: json['ble_connected'] as bool?,
    pzemOnline: json['pzem_online'] as bool?,
    pzemReadsOk: (json['pzem_reads_ok'] as num?)?.toInt(),
    pzemErrors: (json['pzem_errors'] as num?)?.toInt(),
    bootId: (json['boot_id'] as num?)?.toInt(),
  );

  final String? firmware;
  final int? uptimeS;
  final int? freeHeapBytes;
  final bool? wifiConnected;
  final int? wifiRssiDbm;
  final String? wifiIp;
  final bool? mqttConnected;
  final bool? httpsFallbackOk;
  final bool? bleConnected;
  final bool? pzemOnline;
  final int? pzemReadsOk;
  final int? pzemErrors;
  final int? bootId;
}

class HubHealth {
  const HubHealth({required this.ok, required this.databaseConnected, required this.mqttConnected, this.version});

  factory HubHealth.fromJson(Map<String, dynamic> json) => HubHealth(
    ok: json['ok'] == true,
    databaseConnected: json['database_connected'] == true,
    mqttConnected: json['mqtt_connected'] == true,
    version: json['version']?.toString(),
  );

  final bool ok;
  final bool databaseConnected;
  final bool mqttConnected;
  final String? version;
}
