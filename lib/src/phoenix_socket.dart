import 'dart:async';
import 'dart:math';

import 'package:phoenix_wings/src/phoenix_channel.dart';
import 'package:phoenix_wings/src/phoenix_connection.dart';
import 'package:phoenix_wings/src/phoenix_message.dart';
import 'package:phoenix_wings/src/phoenix_serializer.dart';
import 'package:phoenix_wings/src/phoenix_socket_options.dart';

import 'package:phoenix_wings/src/phoenix_io_connection.dart';

class PhoenixSocket {
  Uri? _endpoint;
  _StateChangeCallbacks _stateChangeCallbacks = new _StateChangeCallbacks();

  List<int> reconnectAfterMs = const [1000, 2000, 5000, 10000];
  int _ref = 0;

  // exit flag to abort connect loop
  bool _connecting = false;

  var _encode = PhoenixSerializer.encode;
  var _decode = PhoenixSerializer.decode;
  Timer? _heartbeatTimer;
  String? _pendingHeartbeatRef;
  List<Function()> _sendBuffer = [];
  List<PhoenixChannel> channels = [];

  bool _reconnect = false;

  PhoenixConnection? _conn;
  PhoenixConnection? get conn => _conn;

  int timeout = 10000;
  PhoenixSocketOptions _options = new PhoenixSocketOptions();
  PhoenixConnectionProvider _connectionProvider = PhoenixIoConnection.provider;

  /// Creates an instance of PhoenixSocket
  ///
  /// endpoint is the full url to which you wish to connect e.g. `ws://localhost:4000/websocket/socket`
  PhoenixSocket(String endpoint,
      {socketOptions: PhoenixSocketOptions,
      connectionProvider: PhoenixConnectionProvider}) {
    if (socketOptions is PhoenixSocketOptions) {
      _options = socketOptions;
    }

    if (connectionProvider is PhoenixConnectionProvider) {
      _connectionProvider = connectionProvider;
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
        queryParameters: _options.params);
  }

  Uri? get endpoint => _endpoint;
  int get ref => _ref;
  bool get isConnected => _conn?.isConnected ?? false;
  int get connectionState => _conn?.readyState ?? 3; // WebSocket CLOSED
  int get sendBufferLength => _sendBuffer.length;

  /// [topic] is the name of the channel you wish to join
  /// [params] are any options parameters you wish to send
  PhoenixChannel channel(String topic, [Map params = const {}]) {
    final channel = new PhoenixChannel(topic, params, this);
    channels.add(channel);
    return channel;
  }

  remove(PhoenixChannel channelToRemove) {
    channels.removeWhere((chan) => chan.joinRef == channelToRemove.joinRef);
  }

  /// Attempts to make a WebSocket connection to your backend
  ///
  /// If the attempt fails, retries will be triggered at intervals specified
  /// by retryAfterIntervalMS
  connect() async {
    if (_conn != null) {
      return;
    }

    _connecting = true;

    for (int tries = 0; _conn == null && _connecting; tries += 1) {
      try {
        _conn = _connectionProvider(_endpoint.toString());
        await _conn!.waitForConnection();
      } catch (reason) {
        _conn = null;
        print(
            "WebSocket connection to ${_endpoint.toString()} failed!: $reason");

        var wait = reconnectAfterMs[min(tries, reconnectAfterMs.length - 1)];
        await new Future.delayed(new Duration(milliseconds: wait));

        continue;
      }

      _reconnect = true;
      _onConnOpened();

      if (_conn != null) {
        _conn!
          ..onClose(reconnect)
          ..onMessage(_onConnMessage)
          ..onError(_onConnectionError);
      }
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

  void _onConnClosed(message) {
    _heartbeatTimer?.cancel();
    _triggerChannelErrors();
    _stateChangeCallbacks.close.forEach((cb) => cb(message));
  }

  void _onConnectionError(error) {
    _triggerChannelErrors();
    _stateChangeCallbacks.error.forEach((cb) => cb(error));
  }

  void _onConnMessage(String? rawJSON) {
    final message = this._decode(rawJSON);

    if (_pendingHeartbeatRef != null && message.ref == _pendingHeartbeatRef) {
      _pendingHeartbeatRef = null;
    }

    List.from(channels)
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
    if (_reconnect) {
      connect();
    }
  }

  /// Terminates the socket connection with an optional [code]
  disconnect({int code: PhoenixConnection.CLOSE_NORMAL}) {
    _heartbeatTimer?.cancel();
    _reconnect = false;

    // abort any connecting loop
    _connecting = false;

    if (_conn == null) {
      return;
    }

    _conn!.close(code);
    _conn = null;
  }

  void _flushSendBuffer() {
    if (isConnected) {
      _sendBuffer.forEach((callback) => callback());
      _sendBuffer = [];
    }
  }

  void _triggerChannelErrors() {
    channels.forEach((channel) => channel.triggerError());
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  /// @nodoc
  void sendHeartbeat(Timer timer) {
    if (_conn == null || !_conn!.isConnected) {
      return;
    }

    if (_pendingHeartbeatRef != null) {
      _pendingHeartbeatRef = null;
      _conn!.closeNormal("Heartbeat timeout");
      return;
    }
    _pendingHeartbeatRef = makeRef();

    push(new PhoenixMessage.heartbeat(_pendingHeartbeatRef));
  }

  /// Pushes a message to the server
  void push(PhoenixMessage msg) {
    final callback = () {
      final encoded = _encode(msg);
      _conn!.send(encoded);
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
  List<Function()> open = [];
  List<Function(dynamic error)> close = [], error = [];
  List<Function(PhoenixMessage)> message = [];

  _StateChangeCallbacks();
}
