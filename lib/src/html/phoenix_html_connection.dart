import 'dart:html';
import 'dart:async';

import 'package:phoenix_wings/src/phoenix_connection.dart';


class PhoenixHtmlConnection extends PhoenixConnection {
  WebSocket _conn;
  final String _endpoint;

  bool get isConnected => _conn.readyState == WebSocket.OPEN;
  int get readyState => _conn.readyState ?? WebSocket.CLOSED;

  PhoenixHtmlConnection(this._endpoint) {
    _conn = new WebSocket(_endpoint);
  }

  Future<PhoenixConnection> waitForConnection() async {
    if (_conn.readyState == WebSocket.OPEN) return this;
    if (_conn.readyState != WebSocket.CONNECTING) throw new StateError("socket not open, not connecting");

    await _conn.onOpen.first;
    return this;
  }

  void close([int code, String reason]) => _conn.close(code, reason);
  void send(String data) => _conn.sendString(data);

  void onClose(void callback()) => _conn.onClose.listen((e) { callback(); });
  void onError(void callback(Event)) => _conn.onError.listen((e) { callback(e); });
  void onMessage(void callback(String)) => _conn.onMessage.listen((e) { callback(_messageToString(e)); } );

  String _messageToString(MessageEvent e) {
    // TODO: what are the types here?
    return e.data as String;
  }
}
