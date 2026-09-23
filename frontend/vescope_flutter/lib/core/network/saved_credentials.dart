import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

abstract final class SavedCredentials {
  static const _storage = FlutterSecureStorage();
  // Scope the record to the configured server, never reuse it on another host.
  static String get _key => 'vescope.credentials.v1.${Uri.parse(AppConfig.apiBase).origin}';

  static Future<({String username, String password})?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map || data['username'] is! String || data['password'] is! String) {
      throw const FormatException('Identifiants enregistrés invalides.');
    }
    return (username: data['username'] as String, password: data['password'] as String);
  }

  static Future<void> save(String username, String password) => _storage.write(
    key: _key, value: jsonEncode({'username': username, 'password': password}));

  static Future<void> clear() => _storage.delete(key: _key);
}
