class PhoenixSocketOptions {
  int timeout = 10000;
  int heartbeatIntervalMs = 30000;
  List<int> reconnectAfterMs;
  Function logger = () {};
  Map<String, String> params = {"vsn": "2.0.0"};
}
