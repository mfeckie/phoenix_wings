import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/src/phoenix_channel.dart';
import 'package:phoenix_wings/src/phoenix_message.dart';
import 'package:phoenix_wings/src/phoenix_serializer.dart';
import 'package:phoenix_wings/src/phoenix_socket_options.dart';

class PhoenixSocket {
  Uri _endpoint;
  _StateChangeCallbacks _stateChangeCallbacks = new _StateChangeCallbacks();

  List<int> reconnectAfterMs = const [1000, 2000, 5000, 10000];
  int _ref = 0;
  int _tries = -1;
  var _encode = PhoenixSerializer.encode;
  var _decode = PhoenixSerializer.decode;
  Timer _heartbeatTimer, _reconnectTimer;
  String _pendingHeartbeatRef;
  List<Function()> _sendBuffer = [];
  List<PhoenixChannel> channels = [];
  WebSocket _conn;

  int timeout = 10000;
  PhoenixSocketOptions _options = new PhoenixSocketOptions();

/// Creates an instance of PhoenixSocket
///
/// endpoint is the full url to which you wish to connect e.g. `ws://localhost:4000/websocket/socket`
  PhoenixSocket(String endpoint, {socketOptions: PhoenixSocketOptions}) {
    if (socketOptions is PhoenixSocketOptions) {
      _options = socketOptions;
    }
    _buildEndpoint(endpoint);
  }

  _buildEndpoint(endpoint) {
    var decodedUri = Uri.parse(endpoint);

    _endpoint = new Uri(
        scheme: decodedUri.scheme,
        host: decodedUri.host,
        path: decodedUri.path,
        port: decodedUri.port,
        queryParameters: _options?.params);
  }

  WebSocket get conn => _conn;
  Uri get endpoint => _endpoint;
  int get ref => _ref;
  bool get isConnected => _conn?.readyState == WebSocket.OPEN;
  int get connectionState => _conn?.readyState ?? WebSocket.CLOSED;
  int get sendBufferLength => _sendBuffer.length;

/// [topic] is the name of the channel you wish to join
/// [params] are any options parameters you wish to send
  PhoenixChannel channel(String topic, [Map params = const {}]) {
    final channel = new PhoenixChannel(topic, params, this);
    channels.add(channel);
    return channel;
  }

  remove(PhoenixChannel channelToRemove) {
    channels.removeWhere(
        (chan) => chan.joinRef == channelToRemove.joinRef);
  }

/// Attempts to make a WebSocket connection to your backend
/// 
/// If the attempt fails, retries will be triggered at intervals specified
/// by retryAfterIntervalMS
  connect() async {
    if (_conn != null) {
      return;
    }

    try {
      _conn = await WebSocket.connect(_endpoint.toString());
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _tries = -1;
      _onConnOpened();
      _conn.listen(_onConnMessage, onDone: reconnect, onError: _onConnectionError);
    } catch (reason) {
      print(reason);
      reconnect();
    }
  }

/// Add a callback to be executed when the connection is successfully made
  onOpen(Function() callback) => _stateChangeCallbacks.open.add(callback);

/// Add a callback to be executed when the connection is closed
  onClose(Function(dynamic) callback) =>
      _stateChangeCallbacks.close.add(callback);

/// Add a callback to be executed if an error occurs
  onError(Function(dynamic) callback) =>
      _stateChangeCallbacks.error.add(callback);

/// Add a callback for when a message is received
  onMessage(Function(PhoenixMessage) callback) =>
      _stateChangeCallbacks.message.add(callback);

  _onConnOpened() async {
    _flushSendBuffer();
    _heartbeatTimer = new Timer.periodic(
        new Duration(milliseconds: _options.heartbeatIntervalMs),
        sendHeartbeat);
    _stateChangeCallbacks.open.forEach((cb) => cb());
  }

  _onConnClosed(message) async {
    _heartbeatTimer?.cancel();
    _triggerChannelErrors();
    _stateChangeCallbacks.close.forEach((cb) => cb(message));
  }

  _onConnectionError(error) async {
    _triggerChannelErrors();
    _stateChangeCallbacks.error.forEach((cb) => cb(error));
  }

  _onConnMessage(String rawJSON) {
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

/// In the event of a network dropout or other error, attempt to reconnect
  reconnect() {
    _onConnClosed(null);
    _conn = null;
    final reconnectInMs = reconnectTimeout();
    _reconnectTimer =
        new Timer(new Duration(milliseconds: reconnectInMs), connect);
  }

  int reconnectTimeout() {
    if (_tries < reconnectAfterMs.length - 1) {
      _tries++;
    }
    return reconnectAfterMs[_tries];
  }

/// Terminates the socket connection with an optional [code]
  disconnect({int code}) async {
    _heartbeatTimer?.cancel();
    if (code != null) {
      await _conn?.close(code);
    } else {
      await _conn?.close();
    }
    _conn = null;
  }

  void _flushSendBuffer() {
    if (isConnected) {
      _sendBuffer.forEach((callback) => callback());
      _sendBuffer = [];
    }
  }

  void _triggerChannelErrors() {
    channels.forEach((channel) => channel.trigger(PhoenixChannelEvents.error));
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  /// @nodoc
  void sendHeartbeat(Timer timer) {
    if (_conn?.readyState != WebSocket.OPEN) {
      return;
    }

    if (_pendingHeartbeatRef != null) {
      _pendingHeartbeatRef = null;
      _conn.close(WebSocketStatus.NORMAL_CLOSURE, "Heartbeat timeout");
      return;
    }
    _pendingHeartbeatRef = makeRef();

    push(new PhoenixMessage.heartbeat(_pendingHeartbeatRef));
  }

/// Pushes a message to the server
  void push(PhoenixMessage msg) {
    final callback = () {
      final encoded = _encode(msg);
      _conn.add(encoded);
    };

    if (isConnected) {
      callback();
    } else {
      _sendBuffer.add(callback);
    }
  }

  String makeRef() {
    _ref++;
    return "$_ref";
  }
}

class _StateChangeCallbacks {
  List<Function()> open;
  List<Function(dynamic error)> close, error;
  List<Function(PhoenixMessage)> message;

  _StateChangeCallbacks() {
    this.open = [];
    this.close = [];
    this.error = [];
    this.message = [];
  }
}