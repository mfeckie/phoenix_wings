import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_channel.dart';
import 'package:phoenix_wings/phoenix_message.dart';
import 'package:phoenix_wings/phoenix_serializer.dart';
import 'package:phoenix_wings/phoenix_socket_options.dart';

class PhoenixSocket {
  Uri _endpoint;
  StateChangeCallbacks _stateChangeCallbacks = new StateChangeCallbacks();

  List<int> reconnectAfterMs = const [1000, 2000, 5000, 10000];
  int ref = 0;
  int tries = -1;
  var _encode = PhoenixSerializer.encode;
  var _decode = PhoenixSerializer.decode;
  Timer _heartbeatTimer, _reconnectTimer;
  String _pendingHeartbeatRef;
  List<Function()> _sendBuffer = [];
  List<PhoenixChannel> channels = [];
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
  get connectionState => conn?.readyState ?? WebSocket.CLOSED;
  get sendBufferLength => _sendBuffer.length;

  PhoenixChannel channel(String topic, [Map params = const {}]) {
    final channel = new PhoenixChannel(topic, params, this);
    channels.add(channel);
    return channel;
  }

  remove(PhoenixChannel channelToRemove) {
    channels.removeWhere(
        (channel) => channel.joinRef() == channelToRemove.joinRef());
  }

  connect() async {
    if (conn != null) {
      return;
    }

    try {
      conn = await WebSocket.connect(_endpoint.toString());
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      tries = -1;
      this.onConnOpened();
      conn.listen(onConnMessage, onDone: reconnect, onError: onConnectionError);
    } catch (reason) {
      print(reason);
      reconnect();
    }
  }

  onOpen(Function() callback) => _stateChangeCallbacks.open.add(callback);

  onClose(Function(dynamic) callback) =>
      _stateChangeCallbacks.close.add(callback);

  onError(Function(dynamic) callback) =>
      _stateChangeCallbacks.error.add(callback);

  onMessage(Function(PhoenixMessage) callback) =>
      _stateChangeCallbacks.message.add(callback);

  onConnOpened() async {
    flushSendBuffer();
    _heartbeatTimer = new Timer.periodic(
        new Duration(milliseconds: _options.heartbeatIntervalMs),
        sendHeartbeat);
    _stateChangeCallbacks.open.forEach((cb) => cb());
  }

  onConnClosed(message) async {
    _heartbeatTimer?.cancel();
    triggerChannelErrors();
    _stateChangeCallbacks.close.forEach((cb) => cb(message));
  }

  onConnectionError(error) async {
    triggerChannelErrors();
    _stateChangeCallbacks.error.forEach((cb) => cb(error));
  }

  onConnMessage(String rawJSON) {
    final message = this._decode(rawJSON);

    if (_pendingHeartbeatRef != null && message.ref == _pendingHeartbeatRef) {
      _pendingHeartbeatRef = null;
    }

    channels
        .where((channel) => channel.isMember(
            message.topic, message.event, message.payload, message.joinRef))
        .forEach((channel) => channel.trigger(
            message.event, message.payload, message.ref, message.joinRef));
    _stateChangeCallbacks.message.forEach((callback) => callback(message));
  }

  reconnect() {
    onConnClosed(null);
    conn = null;
    final reconnectInMs = reconnectTimeout();
    print("Reconnecting in $reconnectInMs");
    _reconnectTimer =
        new Timer(new Duration(milliseconds: reconnectInMs), connect);
  }

  int reconnectTimeout() {
    if (tries < reconnectAfterMs.length - 1) {
      tries++;
    }
    return reconnectAfterMs[tries];
  }

  disconnect({int code}) async {
    _heartbeatTimer?.cancel();
    if (code != null) {
      await conn?.close(code);
    } else {
      await conn?.close();
    }
    conn = null;
  }

  void flushSendBuffer() {
    if (isConnected) {
      _sendBuffer.forEach((callback) => callback());
      _sendBuffer = [];
    }
  }

  void triggerChannelErrors() {
    channels.forEach((channel) => channel.trigger(PhoenixChannelEvents.error));
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
      final encoded = _encode(msg);
      conn.add(encoded);
    };

    if (isConnected) {
      callback();
    } else {
      _sendBuffer.add(callback);
    }
  }

  String makeRef() {
    ref++;
    return "$ref";
  }
}

class StateChangeCallbacks {
  List<Function()> open;
  List<Function(dynamic error)> close, error;
  List<Function(PhoenixMessage)> message;

  StateChangeCallbacks() {
    this.open = [];
    this.close = [];
    this.error = [];
    this.message = [];
  }
}