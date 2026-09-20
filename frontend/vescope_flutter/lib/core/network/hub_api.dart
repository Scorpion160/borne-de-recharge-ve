import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../models/operational_models.dart';
import '../../models/telemetry_series.dart';
import '../../models/vescope_models.dart';

class HubApi {
  const HubApi();

  Future<HubHealth?> fetchHealth() async {
    try {
      final response = await http.get(
        AppConfig.api('/health'),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HubHealth.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<double>> fetchRecentPower({String range = '15m'}) async {
    final response = await fetchTelemetrySeries(range: range);
    if (response == null) return const [];
    return response.items
        .map((item) => item.activePowerW)
        .whereType<double>()
        .toList(growable: false);
  }

  Future<TelemetrySeriesResponse?> fetchTelemetrySeries({
    String range = '15m',
  }) async {
    try {
      final response = await http.get(
        AppConfig.api(
          '/api/v1/devices/${AppConfig.deviceId}/telemetry/series?range=$range',
        ),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TelemetrySeriesResponse.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<StoredSession>> fetchStoredSessions({int limit = 50}) async {
    try {
      final response = await http.get(
        AppConfig.api('/api/v1/devices/${AppConfig.deviceId}/sessions?limit=$limit'),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(StoredSession.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoredEvent>> fetchStoredEvents({int limit = 100}) async {
    try {
      final response = await http.get(
        AppConfig.api('/api/v1/devices/${AppConfig.deviceId}/events?limit=$limit'),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(StoredEvent.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Uri telemetryCsvUri(String range) => AppConfig.api(
        '/api/v1/devices/${AppConfig.deviceId}/exports/telemetry.csv?range=$range',
      );

  Uri trustedTelemetryCsvUri(String range) => AppConfig.api(
        '/api/v1/devices/${AppConfig.deviceId}/exports/telemetry-trusted.csv?range=$range',
      );

  Uri sessionsCsvUri() => AppConfig.api(
        '/api/v1/devices/${AppConfig.deviceId}/exports/sessions.csv',
      );

  Uri eventsCsvUri() => AppConfig.api(
        '/api/v1/devices/${AppConfig.deviceId}/exports/events.csv',
      );
}
