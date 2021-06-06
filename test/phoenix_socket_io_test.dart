@TestOn("vm")

import 'package:test/test.dart';

import 'package:phoenix_wings/phoenix_wings.dart';

import 'phoenix_socket_tests.dart';

PhoenixSocket makeSocket(String e, PhoenixSocketOptions? so) {
  return new PhoenixSocket("ws://localhost:4002/socket/websocket",
      socketOptions: so);
}

void main() {
  testPhoenixSocket(makeSocket);
}
