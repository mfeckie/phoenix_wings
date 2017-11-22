import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:phoenix_wings/phoenix_serializer.dart';
import 'package:phoenix_wings/phoenix_socket_options.dart';
import 'package:test/test.dart';
import 'package:phoenix_wings/phoenix_socket.dart';

class MockServer {
  HttpServer _server;
  WebSocket _socket;
  var heartbeat = 0;

  start() async {
    _server = await HttpServer.bind('localhost', 4000);
    _serve();
  }

  _serve() async {
    await for (HttpRequest req in _server) {
      if (req.uri.path == '/socket/websocket') {
        _socket = await WebSocketTransformer.upgrade(req);
        _socket.listen((msg) {
          final message = PhoenixSerializer.decode(msg);
          if (message.event == 'heartbeat') {
            heartbeat++;
            final json = JSON.encode([null,"${message.ref}","phoenix","phx_reply",{"status":"ok","response":{}}]);
            _socket.add(json);
          }
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
    final options = new PhoenixSocketOptions();
    options.params = {"stuff": "things"};
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

  test("Triggers callbacks on close", () async {
    final socket = new PhoenixSocket("ws://localhost:4000/socket/websocket");

    var callbackCalled = false;
    socket.onClose(() { callbackCalled = true; });

    await socket.connect();
    await server.testDisconnect();

    await new Future<Null>.delayed(new Duration(milliseconds: 10));

    expect(callbackCalled, true);
  });

  test("Sends heartbeat", () async {
    final options = new PhoenixSocketOptions();
    options.heartbeatIntervalMs = 9;
    final socket = new PhoenixSocket("ws://localhost:4000/socket/websocket", socketOptions: options);
    await socket.connect();

    await new Future<Null>.delayed(new Duration(milliseconds: 15));
    expect(server.heartbeat, greaterThan(0));
  });

}
