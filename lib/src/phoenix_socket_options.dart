/// Options for your socket
class PhoenixSocketOptions {
  PhoenixSocketOptions({
    this.timeout = 10000,
    this.heartbeatIntervalMs = 30000,
    this.reconnectAfterMs,
    this.params,
  });

  /// How long to wait for a response
  int timeout;

  /// How many milliseconds between heartbeats
  int heartbeatIntervalMs;

  /// Optional list of milliseconds between reconnect attempts
  List<int> reconnectAfterMs;

  /// Parameters sent to your Phoenix backend on connection.
  Map<String, String> params = {"vsn": "2.0.0"};
}
