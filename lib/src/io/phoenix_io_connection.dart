import 'dart:io';
import 'dart:async';


import 'package:phoenix_wings/src/phoenix_connection.dart';


class PhoenixIoConnection extends PhoenixConnection {
  WebSocket _conn;
  final String _endpoint;

  // Use completer for close event because:
  //  * onDone of WebSocket doesn't fire consistently :(
  //  * this enables setting onClose/onDone/onError separately
  Completer _closed = new Completer();

  bool get isConnected => _conn?.readyState == WebSocket.OPEN;

  PhoenixIoConnection(this._endpoint);

  Future<PhoenixConnection> waitForConnection() async {
    _conn = await WebSocket.connect(_endpoint);
    return this;
  }

  void close([int code, String reason]) => _conn.close(code, reason);
  void send(String data) => _conn.add(data);

  void onClose(void callback()) {
    _closed.future.then((e) {
      callback();
    });
  }

  void onError(void callback(dynamic)) {
    _conn.handleError(callback);
    _conn.done.catchError(callback);
  }

  String _messageToString(dynamic e) {
    // TODO: types are String or List<int>
    return e as String;
  }

  void onMessage(void callback(String)) {
    final doneStream = new StreamController();
    _conn.listen((e) {
      callback(_messageToString(e));
    }, onDone: () { _closed.complete(); });
  }
}
