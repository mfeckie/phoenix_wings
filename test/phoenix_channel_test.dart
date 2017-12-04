import 'package:test/test.dart';
import 'package:phoenix_wings/phoenix_socket.dart';

import 'mock_server.dart';

MockServer server;
PhoenixSocket socket;

void main() {
  setUp(() async {
    server = new MockServer(4001);
    await server.start();
    socket = new PhoenixSocket("ws://localhost:4001/socket/websocket");
  });

  tearDown(() async {
    await server.shutdown();
  });

  test("Returns channel with given topic and params", () {
    final channel = socket.channel("topic", {"one": "two"});

    expect(channel.socket, equals(socket));
    expect(channel.topic, "topic");
    expect(channel.params, {"one": "two"});
  });

  test("Adds channel to channel list", () {
    expect(socket.channels.length, 0);
    final channel = socket.channel("topic", {"one": "two"});
    expect(socket.channels.length, 1);
    expect(socket.channels[0], channel);
  });

  test("Removes given channel", () {
    final channel1 = socket.channel("topic-1");
    final channel2 = socket.channel("topic-2");

    expect(socket.channels.length, 2);

    socket.remove(channel1);

    expect(socket.channels.length, 1);

    expect(socket.channels.first, channel2);
  });
}
