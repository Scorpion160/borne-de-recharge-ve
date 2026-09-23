import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'mobile_session.dart';

WebSocketChannel connectHubSocket(Uri uri) => IOWebSocketChannel.connect(
  uri,
  headers: MobileSession.headers,
  connectTimeout: const Duration(seconds: 15),
  pingInterval: const Duration(seconds: 25),
);
