import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectHubSocket(Uri uri) => WebSocketChannel.connect(uri);
