@TestOn("browser")

import 'package:test/test.dart';

import 'package:phoenix_wings/html.dart';

import 'phoenix_socket_tests.dart';

PhoenixSocket makeSocket(String e, PhoenixSocketOptions? so) {
  return new PhoenixSocket(e,
      socketOptions: so, connectionProvider: PhoenixHtmlConnection.provider);
}

void main() {
  testPhoenixSocket(makeSocket);
}
