@TestOn("vm")

import 'dart:async';

import 'package:test/test.dart';
import 'package:phoenix_wings/phoenix_wings.dart';

import 'mock_server.dart';

late MockServer server;
PhoenixSocket? socket;

void main() {
  setUp(() async {
    server = new MockServer(4001);
    await server.start();
    socket = new PhoenixSocket("ws://localhost:4001/socket/websocket");
  });

  tearDown(() async {
    await server.shutdown();
  });

  group("Channel construciton", () {
    test("Returns channel with given topic and params", () {
      final channel = socket!.channel("topic", {"one": "two"});

      expect(channel.socket, equals(socket));
      expect(channel.topic, "topic");
      expect(channel.params, {"one": "two"});
      expect(channel.joinPush!.payload, {"one": "two"});
      expect(channel.joinPush!.event, "phx_join");
    });

    test("Adds channel to channel list", () {
      expect(socket!.channels.length, 0);
      final channel = socket!.channel("topic", {"one": "two"});
      expect(socket!.channels.length, 1);
      expect(socket!.channels[0], channel);
    });

    test("Removes given channel", () {
      final channel1 = socket!.channel("topic-1");
      final channel2 = socket!.channel("topic-2");

      expect(socket!.channels.length, 2);

      socket!.remove(channel1);

      expect(socket!.channels.length, 1);

      expect(socket!.channels.first, channel2);
    });
  });

  group("joining a channel", () {
    late PhoenixChannel channel;
    setUp(() {
      channel = socket!.channel("topic", {"one": "two"});
    });

    test("Sets state to joining", () async {
      expect(channel.isJoined, false);
      channel.join();
      expect(channel.isJoining, true);

      expect(channel.join, throwsA("tried to join channel multiple times"));
    });
  });

  test("parses raw message and triggers channel event", () async {
    final message = PhoenixSerializer.encode(new PhoenixMessage(
        "1", "ref", "topic", "event", {"payload": "payload"}));

    await socket!.connect();
    final targetChannel = socket!.channel("topic");
    var callbackInvoked = false;
    var calledWithPayload;
    targetChannel.on("event", (payload, ref, joinRef) {
      callbackInvoked = true;
      calledWithPayload = payload;
    });

    final otherChannel = socket!.channel("off-topic");
    var otherCallbackInvoked = false;
    otherChannel.on("event", (event, payload, ref) {
      otherCallbackInvoked = true;
    });

    server.sendMessage(message);

    await new Future<Null>.delayed(new Duration(milliseconds: 100));

    expect(callbackInvoked, true);
    expect(calledWithPayload, {'payload': 'payload'});
    expect(otherCallbackInvoked, false);
  });
}
