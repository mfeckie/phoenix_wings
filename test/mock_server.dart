import 'dart:convert';
import 'dart:io';

import 'package:phoenix_wings/src/phoenix_serializer.dart';

class MockServer {
  HttpServer _server;
  WebSocket _socket;
  var heartbeat = 0;
  int port;
  var heartbeatMessageReceived;

  MockServer(this.port);

  start() async {
    _server = await HttpServer.bind("localhost", port);
    _serve();
  }

  _serve() async {
    await for (HttpRequest req in _server) {
      if (req.uri.path == '/socket/websocket') {
        _socket = await WebSocketTransformer.upgrade(req);
        _socket.listen((msg) {
          final message = PhoenixSerializer.decode(msg);
          if (message.event == 'heartbeat') {
            handleHeartbeat(message);
          }
          if (message.event == 'test-push') {
            handleTestPush();
          }
        }, onError: (msg) {});
      }
    }
  }

  handleHeartbeat(message) {
    heartbeatMessageReceived = message;
    heartbeat++;
    final json = JSON.encode([
      null,
      "${message.ref}",
      "phoenix",
      "phx_reply",
      {"status": "ok", "response": {}}
    ]);
    sendMessage(json);
  }

  handleTestPush() {
    final success = JSON.encode([null, "ref", "phoenix", "phx_reply", {}]);
    sendMessage(success);
  }

  sendMessage(msg) {
    if (_socket.readyState != WebSocket.OPEN) {
      return;
    }
    _socket.add(msg);
  }

  testDisconnect() async {
    await _socket?.close();
  }

  shutdown() async {
    await _server.close();
    _server = null;
  }
}
