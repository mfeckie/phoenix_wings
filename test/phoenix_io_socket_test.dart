@TestOn("vm")

import 'package:test/test.dart';

import 'package:phoenix_wings/io.dart';

import 'phoenix_socket_tests.dart';


PhoenixSocket makeSocket(String e, PhoenixSocketOptions so) {
  return new PhoenixIoSocket("ws://localhost:4002/socket/websocket", socketOptions: so);
}


void main() {
  testPhoenixSocket(makeSocket);
}
