import 'dart:html';
import 'dart:async';

import 'package:phoenix_wings/src/phoenix_connection.dart';

/// PhoenixHtmlConnection handles the creation and use
/// of the underlying websocket connection on browser platforms.
class PhoenixHtmlConnection extends PhoenixConnection {
  final String _endpoint;

  late WebSocket _conn;
  late Future _opened;

  bool get isConnected => _conn.readyState == WebSocket.OPEN;
  int get readyState => _conn.readyState;

  static PhoenixConnection provider(String endpoint) {
    return new PhoenixHtmlConnection(endpoint);
  }

  PhoenixHtmlConnection(this._endpoint) {
    _conn = new WebSocket(_endpoint);
    _opened = _conn.onOpen.first;
  }

  // waitForConnection is idempotent, it can be called many
  // times before or after the connection is established
  Future<PhoenixConnection> waitForConnection() async {
    if (_conn.readyState == WebSocket.OPEN) {
      return this;
    }

    await _opened;
    return this;
  }

  void close([int? code, String? reason]) => _conn.close(code, reason);
  void send(String data) => _conn.sendString(data);

  void onClose(void callback()) => _conn.onClose.listen((e) {
        callback();
      });
  void onError(void callback(err)) => _conn.onError.listen((e) {
        callback(e);
      });
  void onMessage(void callback(String m)) => _conn.onMessage.listen((e) {
        callback(_messageToString(e));
      });

  String _messageToString(MessageEvent e) {
    // TODO: what are the types here?
    return e.data as String;
  }
}
