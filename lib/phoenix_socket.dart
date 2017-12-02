import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_message.dart';
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
  String _pendingHeartbeatRef;
  PhoenixTimer _reconnectTimer;
  List<Function> _sendBuffer;
  WebSocket conn;

  // Optionals
  int timeout = 10000;
  PhoenixSocketOptions _options = new PhoenixSocketOptions();

  PhoenixSocket(String endpoint, {socketOptions: PhoenixSocketOptions}) {
    if (socketOptions is PhoenixSocketOptions) {
      _options = socketOptions;
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
        queryParameters: _options?.params);
  }

  get endpoint => _endpoint;
  get isConnected => conn?.readyState == WebSocket.OPEN;

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

  onMessage(Function(PhoenixMessage) callback) =>
      _stateChangeCallbacks.message.add(callback);

  onConnOpened() async {
    _heartbeatTimer = new Timer.periodic(
        new Duration(milliseconds: _options.heartbeatIntervalMs),
        sendHeartbeat);
    _stateChangeCallbacks.open.forEach((cb) => cb());
  }

  onConnClosed() async => _stateChangeCallbacks.close.forEach((cb) => cb());
  onErrorOccur() async => _stateChangeCallbacks.error.forEach((cb) => cb());

  onReceive(String rawJSON) {
    final message = this._decode(rawJSON);
    print(rawJSON);
    if (message.ref == _pendingHeartbeatRef) {
      _pendingHeartbeatRef = null;
    }
    // this.channels.filter( channel => channel.isMember(topic, event, payload, join_ref) )
    //              .forEach( channel => channel.trigger(event, payload, ref, join_ref) )
    _stateChangeCallbacks.message.forEach((callback) => callback(message));
  }

  onConnectionError(error) {
    onErrorOccur();
    print(error);
  }

  reconnect() async {
    onConnClosed();
    this.conn = null;
    await new Future<Null>.delayed(new Duration(milliseconds: 100));
    await this.connect();
  }

  disconnect({code: int}) {
    if (code != null) {
      this.conn.close(code);
    }
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  void sendHeartbeat(Timer timer) {
    if (conn?.readyState != WebSocket.OPEN) {
      return;
    }
    if (_pendingHeartbeatRef != null) {
      _pendingHeartbeatRef = null;
      conn.close(WebSocketStatus.NORMAL_CLOSURE, "Heartbeat timeout");
      return;
    }
    _pendingHeartbeatRef = makeRef();

    push(new PhoenixMessage.heartbeat(_pendingHeartbeatRef));
  }

  void push(PhoenixMessage msg) {
    final callback = () {
      final encoded = this._encode(msg);
      conn.add(encoded);
    };

    if (isConnected) {
      callback();
    } else {
      _sendBuffer.add(callback);
    }
  }

  String makeRef() {
    final newRef = _ref + 1;
    if (newRef == _ref) {
      _ref = 0;
    } else {
      _ref = newRef;
    }
    return "$_ref";
  }
}

class StateChangeCallbacks {
  List<Function()> open, close, error;
  List<Function(PhoenixMessage)> message;

  StateChangeCallbacks() {
    this.open = [];
    this.close = [];
    this.error = [];
    this.message = [];
  }
}
