import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
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
    try {
      final response = await http.get(
        AppConfig.api('/api/v1/devices/${AppConfig.deviceId}/telemetry/series?range=$range'),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map((item) => (item['active_power_w'] as num?)?.toDouble())
          .whereType<double>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
