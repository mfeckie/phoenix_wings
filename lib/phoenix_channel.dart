import 'dart:async';
import 'dart:io';

import 'package:phoenix_wings/phoenix_push.dart';
import 'package:phoenix_wings/phoenix_socket.dart';

enum PhoenixChannelState {
  closed, errored, joined, joining, leaving,
}

class PhoenixChannelEvents {
  static const close = "phx_close";
  static const error = "phx_error";
  static const join = "phx_join";
  static const reply = "phx_reply";
  static const leave = "phx_leave";
}

class PhoenixChannel {
  PhoenixChannelState _state = PhoenixChannelState.closed;
  String topic;
  Map params;
  PhoenixSocket socket;
  List _bindings, _pushBuffer;
  int _bindingRef = 0;
  int _timeout;
  var _joinedOnce = false;
  PhoenixPush joinPush;
  final _rejoinTimer = new Timer.periodic(new Duration(milliseconds: 10000), (_timer) {
    // TODO
  });
  PhoenixChannel(this.topic, this.params, this.socket) {
    joinPush = new PhoenixPush(this, PhoenixChannelEvents.join, this.params);

    joinPush.receive("ok", (msg) {

    });
  }

  joinRef(){ return this.joinPush.ref; }


}