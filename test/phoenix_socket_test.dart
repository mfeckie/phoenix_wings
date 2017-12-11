import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_channel.dart';
import 'package:phoenix_wings/phoenix_message.dart';
import 'package:phoenix_wings/phoenix_serializer.dart';
import 'package:phoenix_wings/phoenix_socket_options.dart';
import 'package:test/test.dart';
import 'package:phoenix_wings/phoenix_socket.dart';

import 'mock_server.dart';

PhoenixSocket socket;
MockServer server;

void main() {
  setUp(() async {
    server = new MockServer(4002);
    await server.start();
    socket = new PhoenixSocket("ws://localhost:4002/socket/websocket");
  });
  tearDown(() async {
    await server.shutdown();
  });

  test("Accepts query parameters via an options object", () {
    final endpoint = "ws://localhost:4002/socket";
    final options = new PhoenixSocketOptions();
    options.params = {"stuff": "things"};
    final socket = new PhoenixSocket(endpoint, socketOptions: options);
    expect(socket.endpoint.queryParameters, options.params);
  });

  test("Connects idempotently", () async {
    final connection = await socket.connect();
    final connection2 = await socket.connect();
    expect(connection, connection2);
  });

  test("Removes existing connection on disconnect", () async {
    await socket.connect();
    expect(socket.conn, isNotNull);
    await socket.disconnect();
    expect(socket.conn, isNull);
  });

  group("Connection state", () {
    test("defaults to closed", () {
      expect(socket.connectionState, WebSocket.CLOSED);
    });

    test("isConnected is false when not connected", () {
      expect(socket.isConnected, false);
    });
  });

  group("Callbacks", () {
    test("Triggers callbacks on open", () async {
      var callbackCalled = false;

      socket.onOpen(() {
        callbackCalled = true;
      });

      await socket.connect();

      await new Future<Null>.delayed(new Duration(milliseconds: 10));

      expect(callbackCalled, true);
    });

    test("Triggers callbacks on message", () {
      final message = PhoenixSerializer
          .encode(new PhoenixMessage(null, "ref", "topic", "event", {}));
      PhoenixMessage receivedMessage;
      socket.onMessage((msg) => receivedMessage = msg);

      socket.onConnMessage(message);

      expect(receivedMessage.ref, "ref");
      expect(receivedMessage.joinRef, null);
      expect(receivedMessage.topic, "topic");
      expect(receivedMessage.event, "event");
      expect(receivedMessage.payload, {});
    });

    test("Triggers callbacks on close", () async {
      var callbackCalled = false;
      socket.onClose((_) {
        callbackCalled = true;
      });

      await socket.connect();
      await server.testDisconnect();

      await new Future<Null>.delayed(new Duration(milliseconds: 10));

      expect(callbackCalled, true);
    });

    test("Triggers channel errors", () async {
      final channel = socket.channel("topic");
      var callbackCalled = false;
      channel.onError((a, b, c) {
        callbackCalled = true;
      });
      socket.onConnectionError(PhoenixChannelEvents.error);

      await new Future<Null>.delayed(new Duration(milliseconds: 100));
      expect(callbackCalled, true);
    });
  });

  group("Heartbeat", () {
    test("Sends heartbeat", () async {
      final options = new PhoenixSocketOptions();
      options.heartbeatIntervalMs = 5;
      final socket = new PhoenixSocket("ws://localhost:4002/socket/websocket",
          socketOptions: options);
      await socket.connect();

      await new Future<Null>.delayed(new Duration(milliseconds: 12));
      socket.stopHeartbeat();
      expect(server.heartbeat, greaterThan(0));
    });

    test("closes socket when heartbeat not ack'd within heartbeat window",
        () async {
      var closed = false;
      await socket.connect();
      socket.onClose((_) {
        closed = true;
      });
      final timeout = new Duration(milliseconds: 50);
      socket.sendHeartbeat(new Timer(timeout, () {}));
      expect(closed, false);
      socket.sendHeartbeat(new Timer(timeout, () {}));
      await new Future<Null>.delayed(new Duration(milliseconds: 100));
      expect(closed, true);
    });

    test("pushes heartbeat data when connected", () async {
      final options = new PhoenixSocketOptions();
      options.heartbeatIntervalMs = 5;
      final socket = new PhoenixSocket("ws://localhost:4002/socket/websocket",
          socketOptions: options);
      await socket.connect();
      await new Future<Null>.delayed(new Duration(milliseconds: 15));
      socket.stopHeartbeat();

      final hearbeatMessage = server.heartbeatMessageReceived;

      expect(hearbeatMessage.topic, 'phoenix');
      expect(hearbeatMessage.event, 'heartbeat');
    });

    // TODO - sendHeartbeat
  });
  group("push", () {
    final msg = new PhoenixMessage(
        "joinRef", "ref", "topic", "test-push", {"payload": "payload"});

    test("Sends data when connected", () async {
      await socket.connect();
      socket.push(msg);
      await new Future<Null>.delayed(new Duration(milliseconds: 60));
    });

    test("buffers data send when not connected", () async {
      await socket.connect();
      socket.push(msg);
      expect(socket.sendBufferLength, 0);
      await socket.disconnect();

      await new Future<Null>.delayed(new Duration(milliseconds: 100));
      msg.ref = "afterClose";
      socket.push(msg);
      expect(socket.sendBufferLength, 1);
    });

    test("flushes send buffer on connect", () async {
      socket.push(msg);
      socket.push(msg);
      expect(socket.sendBufferLength, 2);
      await socket.connect();

      await new Future<Null>.delayed(new Duration(milliseconds: 50));
      expect(socket.sendBufferLength, 0);
    });
  });

  group("makeRef", () {
    test("returns next message ref", () {
      expect(socket.ref, 0);
      expect(socket.makeRef(), "1");
      expect(socket.ref, 1);
      expect(socket.makeRef(), "2");
      expect(socket.ref, 2);
    });
  });
}
