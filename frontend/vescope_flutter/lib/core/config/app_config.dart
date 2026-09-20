import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const deviceId = String.fromEnvironment(
    'VESCOPE_DEVICE_ID',
    defaultValue: 'borne-01',
  );

  static const _configuredApiBase = String.fromEnvironment(
    'VESCOPE_API_BASE',
    defaultValue: '',
  );

  static const _configuredWsUrl = String.fromEnvironment(
    'VESCOPE_WS_URL',
    defaultValue: '',
  );

  static String get apiBase {
    if (_configuredApiBase.isNotEmpty) {
      return _configuredApiBase.replaceFirst(RegExp(r'/$'), '');
    }
    if (kIsWeb) return Uri.base.origin;
    return 'https://vescope.kerunjombor.net';
  }

  static Uri api(String path) => Uri.parse('$apiBase$path');

  static Uri get websocketUri {
    if (_configuredWsUrl.isNotEmpty) return Uri.parse(_configuredWsUrl);
    final base = Uri.parse(apiBase);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/api/v1/ws/devices/$deviceId',
      query: null,
      fragment: null,
    );
  }
}
