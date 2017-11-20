import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_socket_options.dart';
import 'package:test/test.dart';
import 'package:phoenix_wings/phoenix_socket.dart';

class MockServer {
  HttpServer _server;
  WebSocket _socket;

  start() async {
    _server = await HttpServer.bind('localhost', 4000);
    _serve();
  }

  _serve() async {
    await for (HttpRequest req in _server) {
      if (req.uri.path == '/socket/websocket') {
        _socket = await WebSocketTransformer.upgrade(req);
        _socket.listen((msg) {
          print(msg);
        }, onError: (msg) {});
      }
    }
  }

  sendMessage(msg) {
    _socket.add(msg);
  }

  testDisconnect() async {
    await _socket.close();
  }

  shutdown() async {
    await _socket?.close();
    await _server.close(force: true);
    _server = null;
  }
}

MockServer server;

void main() {
  setUp(() async {
    server = new MockServer();
    await server.start();
  });

  tearDown(() async {
    await server.shutdown();
  });

  test("Accepts query parameters via an options object", () {
    final endpoint = "ws://localhost:4000/socket";
    final options = new PhoenixSocketOptions(params: {"stuff": "things"});
    final socket = new PhoenixSocket(endpoint, socketOptions: options);
    expect(socket.endpoint.queryParameters, options.params);
  });

  test("Triggers callbacks on open", () async {
    final socket = new PhoenixSocket("ws://localhost:4000/socket/websocket");

    var callbackCalled = false;
    socket.onOpen(() { callbackCalled = true; });

    await socket.connect();

    await new Future<Null>.delayed(new Duration(milliseconds: 10));

    expect(callbackCalled, true);
  });
}
