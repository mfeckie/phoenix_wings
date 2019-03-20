@TestOn("vm")

import 'package:test/test.dart';
import 'package:phoenix_wings/src/phoenix_socket_options.dart';

void main() {
  test("Can create socket options with default values", () {
    final options = new PhoenixSocketOptions();
    expect(options.timeout, 10000);
    expect(options.heartbeatIntervalMs, 30000);
    expect(options.reconnectAfterMs, null);
    expect(options.params, {"vsn": "2.0.0"});
  });

  test("Can create socket options with overridden timeout", () {
    final options = new PhoenixSocketOptions(timeout: 99);
    expect(options.timeout, 99);
    expect(options.heartbeatIntervalMs, 30000);
    expect(options.reconnectAfterMs, null);
    expect(options.params, {"vsn": "2.0.0"});
  });

  test("Can create socket options with overridden heartbeatIntervalMs", () {
    final options = new PhoenixSocketOptions(heartbeatIntervalMs: 99);
    expect(options.timeout, 10000);
    expect(options.heartbeatIntervalMs, 99);
    expect(options.reconnectAfterMs, null);
    expect(options.params, {"vsn": "2.0.0"});
  });

  test("Cannot override socket options with vsn params", () {
    final options = new PhoenixSocketOptions(params: {});
    expect(options.timeout, 10000);
    expect(options.heartbeatIntervalMs, 30000);
    expect(options.reconnectAfterMs, null);
    expect(options.params, {"vsn": "2.0.0"});
  });

  test("Can create socket options with overridden params", () {
    final options = new PhoenixSocketOptions(params: {"token": "test"});
    expect(options.timeout, 10000);
    expect(options.heartbeatIntervalMs, 30000);
    expect(options.reconnectAfterMs, null);
    expect(options.params, {"token": "test", "vsn": "2.0.0"});
  });
}
