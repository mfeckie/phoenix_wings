import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'package:phoenix_wings/phoenix_wings.dart';

class MockServer {
  HttpServer? _server;
  WebSocket? _socket;
  var heartbeat = 0;
  int port;
  String? heartbeatMessageReceived;

  MockServer(this.port);

  start() async {
    _server = await HttpServer.bind("localhost", port, shared: true);
    _serve();
  }

  _serve() async {
    await for (HttpRequest req in _server!) {
      if (req.uri.path == '/socket/websocket') {
        _socket = await WebSocketTransformer.upgrade(req);
        _socket!.listen((msg) {
          final message = PhoenixSerializer.decode(msg);
          if (message.event == 'heartbeat') {
            heartbeatMessageReceived = msg;
            handleHeartbeat(message);
          }
          if (message.event == 'test-push') {
            handleTestPush();
          }
        }, onError: (msg) {
          print("mock server socket error! $msg");
        });
      } else {
        req.response
          ..write("did not understand request: ${req.uri.path}")
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    }
  }

  handleHeartbeat(message) {
    heartbeat++;
    final json = jsonEncode([
      null,
      "${message.ref}",
      "phoenix",
      "phx_reply",
      {"status": "ok", "response": {}}
    ]);
    sendMessage(json);
  }

  handleTestPush() {
    final success = jsonEncode([null, "ref", "phoenix", "phx_reply", {}]);
    sendMessage(success);
  }

  sendMessage(String msg) {
    if (_socket?.readyState != WebSocket.open) {
      return;
    }
    _socket!.add(msg);
  }

  testDisconnect() async {
    await _socket?.close();
  }

  shutdown() async {
    await _server!.close();
    _server = null;
  }
}

// RemoteMockServer wraps a MockServer running in a separate isolate.
// This is used for hybrid tests where the test code and mock server may
// be running in different processes (eg: Browser/VM).
//
// Communiation is done by message passing with a simple protocol.
//
//   String -> a command
//   [String, dynamic] -> a command/result with one argument

class RemoteMockServer {
  final StreamChannel _channel;
  final Stream _serverMessages;

  RemoteMockServer.forChannel(this._channel)
      : _serverMessages = _channel.stream.asBroadcastStream();

  RemoteMockServer.hybrid()
      : this.forChannel(spawnHybridUri("mock_server.dart"));

  Future<int?> get heartbeat async {
    final response = _listResponse("heartbeat");
    _sendCommand("get_heartbeat");
    return (await response)[1] as int?;
  }

  Future<PhoenixMessage> get heartbeatMessageReceived async {
    final response = _listResponse("heartbeat_message");
    _sendCommand("get_heartbeat_message");

    final rawMessage = (await response)[1];
    return PhoenixSerializer.decode(rawMessage as String);
  }

  testDisconnect() async {
    final disconnected = _stringResponse("test_disconnect returned");
    _sendCommand("test_disconnect");
    await disconnected;
  }

  shutdown() async {
    _channel.sink.add("shutdown");
    await _channel.sink.close();
  }

  sendMessage(String message) {
    _sendCommand("send", message);
  }

  waitForServer() async {
    // send a ping and wait for pong, which will only
    // be sent once the server is up
    final next_pong = _stringResponse("pong");
    _sendCommand("ping");
    await next_pong;
  }

  // print a string on the VM proccess, helpful for debugging
  // browser tests.
  remotePrint(String s) {
    _sendCommand("print");
  }

  void _sendCommand(String command, [dynamic param]) {
    if (param == null) {
      _channel.sink.add(command);
    } else {
      _channel.sink.add([command, param]);
    }
  }

  // wait for a string response from the server
  Future<dynamic> _stringResponse(String command) {
    final response = _serverMessages
        .firstWhere((message) => (message is String && message == command));
    return response;
  }

  // wait for a list response from the server
  Future<dynamic> _listResponse(String command) async {
    final response = _serverMessages
        .firstWhere((message) => (message is List && message[0] == command));

    return response;
  }
}

handleStringMessage(
    MockServer server, StreamChannel channel, String message) async {
  switch (message) {
    case "test_disconnect":
      await server.testDisconnect();
      channel.sink.add("test_disconnect returned");
      break;
    case "shutdown":
      server.shutdown();
      break;
    case "get_heartbeat":
      channel.sink.add(["heartbeat", server.heartbeat]);
      break;
    case "get_heartbeat_message":
      channel.sink.add(["heartbeat_message", server.heartbeatMessageReceived]);
      break;
    case "ping":
      channel.sink.add("pong");
      break;
    default:
      throw new UnsupportedError("message not supported: $message");
  }
}

handleListMessage(MockServer server, List message) {
  final command = message[0];
  final param = message[1];

  switch (command) {
    case "send":
      server.sendMessage(param);
      break;
    case "print":
      print(param);
      break;
    default:
      throw new UnsupportedError("message not supported: $message");
  }
}

// used for hybrid tests
hybridMain(StreamChannel channel) async {
  final server = new MockServer(4002);
  await server.start();

  channel.stream.listen((message) async {
    if (message is String) {
      await handleStringMessage(server, channel, message);
    } else if (message is List) {
      handleListMessage(server, message);
    } else {
      throw new UnsupportedError("message not supported: $message");
    }
  });
}
