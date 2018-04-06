import 'dart:async';

abstract class PhoenixConnection {
  bool get isConnected;
  int get readyState;

  Future<PhoenixConnection> waitForConnection();

  void close([int code, String reason]);
  void closeNormal([String reason]) => close(1000, reason);

  void send(String data);

  void onClose(void callback());
  void onError(void callback(dynamic));
  void onMessage(void callback(String));
}
