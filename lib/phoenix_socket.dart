import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_serializer.dart';
import 'package:phoenix_wings/phoenix_socket_options.dart';
import 'package:phoenix_wings/phoenix_timer.dart';

class PhoenixSocket {
  Uri _endpoint;
  StateChangeCallbacks _stateChangeCallbacks = new StateChangeCallbacks();

  List<int> reconnectAfterMs = const [1000, 2000, 5000, 10000];
  int _ref = 0;
  var _encode = PhoenixSerializer.encode;
  var _decode = PhoenixSerializer.decode;
  Timer _heartbeatTimer;
  int _pendingHeartbeatRef;
  PhoenixTimer _reconnectTimer;
  List<Function> _sendBuffer;
  WebSocket conn;

  // Optionals
  int timeout = 10000;
  PhoenixSocketOptions options;

  PhoenixSocket(String endpoint, {socketOptions: PhoenixSocketOptions}) {
    if (socketOptions is PhoenixSocketOptions) {
      options = socketOptions;
    }

    buildEndpoint(endpoint);
  }

  buildEndpoint(endpoint) {
    var decodedUri = Uri.parse(endpoint);

    _endpoint = new Uri(
        scheme: decodedUri.scheme,
        host: decodedUri.host,
        path: decodedUri.path,
        port: decodedUri.port,
        queryParameters: options?.params);
  }

  get endpoint => _endpoint;

  connect() async {
    if (conn != null) {
      return;
    }

    try {
      conn = await WebSocket.connect(_endpoint.toString());
      this.onConnOpened();
      conn.listen(onReceive, onDone: reconnect, onError: onConnectionError);
    } catch (reason) {
      print(reason);
    }
  }

  onOpen(Function() callback) => _stateChangeCallbacks.open.add(callback);

  onClose(Function() callback) => _stateChangeCallbacks.close.add(callback);

  onError(Function() callback) => _stateChangeCallbacks.error.add(callback);

  onMessage(Function() callback) => _stateChangeCallbacks.message.add(callback);

  onConnOpened() async => _stateChangeCallbacks.open.forEach((cb) => cb());
  onConnClosed() async => _stateChangeCallbacks.close.forEach((cb) => cb());

  onReceive(dynamic msg) {
    print(msg);
  }

  onConnectionError(error) {
    print("CONN ERROR");
    print(error);
  }

  reconnect() async {
    this.conn = null;
    await new Future<Null>.delayed(new Duration(milliseconds: 100));
    await this.connect();
  }

  disconnect({code: int}) {
    if (code != null) {
      this.conn.close(code);
    }
  }
}

class StateChangeCallbacks {
  List<Function()> open, close, error, message;

  StateChangeCallbacks() {
    this.open = [];
    this.close = [];
    this.error = [];
    this.message = [];
  }
}
