/// Options for your socket
class PhoenixSocketOptions {
  /// How long to wait for a response
  int timeout = 10000;
  /// How many milliseconds between heartbeats
  int heartbeatIntervalMs = 30000;
  /// Optional list of milliseconds between reconnect attempts
  List<int> reconnectAfterMs;
  /// Parameters sent to your Phoenix backend on connection.
  Map<String, String> params = {"vsn": "2.0.0"};
}
