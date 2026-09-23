import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Credentials stay in memory for this application session only.
abstract final class MobileSession {
  static String? _authorization;
  static Map<String, String> get headers => {
    if (_authorization != null) 'Authorization': _authorization!,
  };

  static void clear() => _authorization = null;

  static String encodeCredentials(String username, String password) {
    if (username.isEmpty || username.contains(':')) {
      throw const FormatException('Identifiant invalide.');
    }
    return 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  static Future<void> login(String username, String password, {http.Client? client}) async {
    clear();
    final api = AppConfig.api('/health');
    final ws = AppConfig.websocketUri;
    if (api.scheme != 'https' || ws.scheme != 'wss' ||
        api.host != ws.host || api.port != (ws.hasPort ? ws.port : 443) ||
        api.userInfo.isNotEmpty || ws.userInfo.isNotEmpty) {
      throw const FormatException('La connexion exige HTTPS et WSS sur le même serveur.');
    }
    final auth = encodeCredentials(username, password);
    final transport = client ?? http.Client();
    try {
      final request = http.Request('GET', api)
        ..followRedirects = false
        ..headers.addAll({'Accept': 'application/json', 'Authorization': auth});
      final response = await transport.send(request).then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const FormatException('Identifiant ou mot de passe refusé.');
      }
      if (response.statusCode != 200) {
        throw const FormatException('Serveur indisponible. Réessayez.');
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['service'] != 'vescope-hub') {
        throw const FormatException('Réponse inattendue du serveur.');
      }
      _authorization = auth;
    } finally {
      transport.close();
    }
  }
}
