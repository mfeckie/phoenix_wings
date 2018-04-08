import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'package:phoenix_wings/phoenix_wings.dart';


class MockServer {
  HttpServer _server;
  WebSocket _socket;
  var heartbeat = 0;
  int port;
  String heartbeatMessageReceived;

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
            heartbeatMessageReceived = msg;
            handleHeartbeat(message);
          }
          if (message.event == 'test-push') {
            handleTestPush();
          }
        }, onError: (msg) { print("mock server socket error! $msg"); });
      } else {
        req.response
          ..write("did not understand request: ${req.uri.path}")
          ..statusCode = HttpStatus.NOT_FOUND
          ..close();
      }
    }
  }

  handleHeartbeat(message) {
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

  sendMessage(String msg) {
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

class RemoteMockServer {
  final StreamChannel _channel;
  final Stream _serverMessages;

  RemoteMockServer.forChannel(this._channel)
    : _serverMessages = _channel.stream.asBroadcastStream();

  RemoteMockServer.hybrid()
    : this.forChannel(spawnHybridUri("mock_server.dart")) ;

  Future<int> get heartbeat async {
    final result = _serverMessages.
      firstWhere((e) => (e is List && e[0] == "heartbeat"));
    _channel.sink.add("get_heartbeat");
    return (await result)[1] as int;
  }

  Future<PhoenixMessage> get heartbeatMessageReceived async {
    final result = _serverMessages.
      firstWhere((e) => (e is List && e[0] == "heartbeat_message"));
    _channel.sink.add("get_heartbeat_message");

    return PhoenixSerializer.decode((await result)[1] as String);
  }

  testDisconnect() async {
    final disconnected = _serverMessages.
      firstWhere((e) => (e is String && e == "test_disconnect returned"));
    _channel.sink.add("test_disconnect");
    await disconnected;
  }

  shutdown() async {
    await _channel.sink.add("shutdown");
    await _channel.sink.close();
  }

  sendMessage(String message) {
    _channel.sink.add(["send", message]);
  }

  waitForServer() async {
    // send a ping and wait for pong, which will only
    // be sent once the server is up
    final next_pong = _serverMessages.
      firstWhere((e) => (e is String && e == "pong"));
    _channel.sink.add("ping");
    await next_pong;
  }

  print(String s) {
    _channel.sink.add(["print", s]);
  }
}


// used for hybrid tests
hybridMain(StreamChannel channel) async {
  var server = new MockServer(4002);
  await server.start();

  channel.stream.listen((message) async {
    if (message is String && message == "test_disconnect") {
      await server.testDisconnect();
      channel.sink.add("test_disconnect returned");
    } else if (message is String && message == "shutdown") {
      server.shutdown();
    } else if (message is String && message == "get_heartbeat") {
      channel.sink.add(["heartbeat", server.heartbeat]);
    } else if (message is String && message == "get_heartbeat_message") {
      channel.sink.add(["heartbeat_message", server.heartbeatMessageReceived]);
    } else if (message is String && message == "ping") {
      channel.sink.add("pong");
    } else if (message is List && message.length == 2 && message[0] == "send") {
      server.sendMessage(message[1]);
    } else if (message is List && message.length == 2 && message[0] == "print") {
      print(message[1]);
    } else {
      throw new UnsupportedError("message not supported: $message");
    }
  });
}
