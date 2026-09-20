import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/app_config.dart';
import '../core/network/hub_api.dart';
import '../models/vescope_models.dart';

class VescopeController extends ChangeNotifier {
  VescopeController({HubApi api = const HubApi()}) : _api = api;

  final HubApi _api;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _retryTimer;
  Timer? _healthTimer;
  Timer? _freshnessTimer;
  Duration _retryDelay = const Duration(seconds: 1);
  bool _disposed = false;

  bool hubConnected = false;
  bool databaseConnected = false;
  bool mqttConnected = false;
  String? hubVersion;
  AcTelemetry? telemetry;
  CoreStatus? status;
  CoreDiagnostics? diagnostics;
  StationState stationState = StationState.offline;
  final List<double> powerHistory = <double>[];

  static const liveMaxAge = Duration(seconds: 180);

  bool get telemetryLive {
    final sample = telemetry;
    if (sample == null) return false;
    return DateTime.now().toUtc().difference(sample.timestamp.toUtc()) <= liveMaxAge;
  }

  bool get pzemOnline => telemetryLive || status?.pzemOnline == true || diagnostics?.pzemOnline == true;

  Future<void> start() async {
    await _refreshHealth();
    final history = await _api.fetchRecentPower();
    powerHistory
      ..clear()
      ..addAll(history.length > 60 ? history.sublist(history.length - 60) : history);
    notifyListeners();
    _connectSocket();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshHealth());
    _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  Future<void> _refreshHealth() async {
    final health = await _api.fetchHealth();
    if (_disposed) return;
    databaseConnected = health?.databaseConnected ?? false;
    mqttConnected = health?.mqttConnected ?? false;
    hubVersion = health?.version;
    notifyListeners();
  }

  void _connectSocket() {
    if (_disposed) return;
    _retryTimer?.cancel();
    try {
      _socket = WebSocketChannel.connect(AppConfig.websocketUri);
      _socketSubscription = _socket!.stream.listen(
        _onSocketMessage,
        onError: (_) => _handleSocketClosed(),
        onDone: _handleSocketClosed,
      );
      hubConnected = true;
      _retryDelay = const Duration(seconds: 1);
      notifyListeners();
    } catch (_) {
      _handleSocketClosed();
    }
  }

  void _handleSocketClosed() {
    if (_disposed) return;
    hubConnected = false;
    notifyListeners();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket = null;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _connectSocket);
    final nextSeconds = (_retryDelay.inSeconds * 2).clamp(1, 15);
    _retryDelay = Duration(seconds: nextSeconds);
  }

  void _onSocketMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map<String, dynamic>) return;
      final event = decoded['event']?.toString();
      if (event == 'connected') {
        _applySnapshot(decoded['snapshot']);
      } else if (event == 'telemetry_ac') {
        _applyTelemetry(_asMap(decoded['data']));
      } else if (event == 'status_update') {
        _applyStatus(_asMap(decoded['data']));
      } else if (event == 'diagnostics') {
        _applyDiagnostics(_asMap(decoded['data']));
      }
      notifyListeners();
    } catch (_) {
      // Ignore invalid frames; the Hub connection remains active.
    }
  }

  void _applySnapshot(Object? value) {
    final snapshot = _asMap(value);
    if (snapshot == null) return;
    _applyTelemetry(_payload(snapshot['telemetry/ac']));
    _applyStatus(_payload(snapshot['status']));
    _applyDiagnostics(_payload(snapshot['diagnostics']));
  }

  Map<String, dynamic>? _payload(Object? value) {
    final entry = _asMap(value);
    return _asMap(entry?['payload']);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
    return null;
  }

  void _applyTelemetry(Map<String, dynamic>? json) {
    if (json == null) return;
    final next = AcTelemetry.fromJson(json);
    final previous = telemetry;
    telemetry = next;
    if (previous == null || previous.timestamp != next.timestamp || previous.sequence != next.sequence) {
      powerHistory.add(next.activePowerW);
      if (powerHistory.length > 60) powerHistory.removeRange(0, powerHistory.length - 60);
    }
  }

  void _applyStatus(Map<String, dynamic>? json) {
    if (json == null) return;
    status = CoreStatus.fromJson(json);
    stationState = status!.state;
  }

  void _applyDiagnostics(Map<String, dynamic>? json) {
    if (json == null) return;
    diagnostics = CoreDiagnostics.fromJson(json);
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _healthTimer?.cancel();
    _freshnessTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.sink.close();
    super.dispose();
  }
}
