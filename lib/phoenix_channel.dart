import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_push.dart';
import 'package:phoenix_wings/phoenix_socket.dart';

enum PhoenixChannelState {
  closed,
  errored,
  joined,
  joining,
  leaving,
}

class PhoenixChannelEvents {
  static const close = "phx_close";
  static const error = "phx_error";
  static const join = "phx_join";
  static const reply = "phx_reply";
  static const leave = "phx_leave";
  static const lifecycleEvents = const [close, error, join, reply, leave];
  static bool lifecycleEvent(event) =>
      lifecycleEvents.any((eventName) => event == eventName);
}

class PhoenixChannel {
  PhoenixChannelState _state = PhoenixChannelState.closed;
  String topic;
  Map params = {};
  PhoenixSocket socket;
  List<PhoenixChannelBinding> _bindings = [];
  List _pushBuffer = [];
  int _bindingRef = 0;
  int _timeout;
  var _joinedOnce = false;
  PhoenixPush joinPush;
  final Timer _rejoinTimer =
      new Timer.periodic(new Duration(milliseconds: 10000), (_timer) {
    // TODO
  });
  PhoenixChannel(this.topic, this.params, this.socket) {
    joinPush = new PhoenixPush(this, PhoenixChannelEvents.join, this.params);

    joinPush.receive("ok", (msg) {});

    onError((reason, _a, _b) {
      if (isLeaving || isClosed) { return; }
      _state = PhoenixChannelState.errored;
      // _rejoinTimer.scheduleTimeout();
    });
  }

  get isClosed => _state == PhoenixChannelState.closed;
  get isErrored => _state == PhoenixChannelState.errored;
  get isJoined => _state == PhoenixChannelState.joined;
  get isJoining => _state == PhoenixChannelState.joining;
  get isLeaving => _state == PhoenixChannelState.leaving;

  String joinRef() => this.joinPush.ref;

  trigger(String event, [String payload, String ref, String joinRefParam]) {
    final handledPayload = this.onMessage(event, payload, ref);
    if (payload != null && handledPayload == null) {
      throw ("channel onMessage callback must return payload modified or unmodified");
    }

    _bindings.where((bound) => bound.event == event).forEach((bound) =>
        bound.callback(handledPayload, ref, joinRefParam ?? joinRef()));
  }

  int on(String event, Function(dynamic, dynamic, dynamic) callback) {
    final ref = _bindingRef++;
    _bindings.add(new PhoenixChannelBinding(event, ref, callback));
    return ref;
  }

  onError(callback) =>
      on(PhoenixChannelEvents.error, (payload, ref, joinRef) => callback(payload, ref, joinRef));

  onMessage(event, payload, ref) => payload;
}

class PhoenixChannelBinding {
  String event;
  int ref;
  Function(dynamic, dynamic, dynamic) callback;
  PhoenixChannelBinding(this.event, this.ref, this.callback);
}