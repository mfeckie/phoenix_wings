
class PhoenixSocketOptions {
  int timeout = 10000;
  int heartbeatIntervalMs = 30000;
  List<int> reconnectAfterMs;
  Function logger = () {};
  Map<String, String> params;

  PhoenixSocketOptions({params: Map}) {
    this.params = params;
  }
}