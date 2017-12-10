// import 'dart:async';

import 'package:phoenix_wings/phoenix_channel.dart';
import 'package:phoenix_wings/phoenix_message.dart';
// import 'package:phoenix_wings/phoenix_message.dart';

class PhoenixPush {
  PhoenixChannel channel;
  Map payload;
  String ref;
  String event;
//   String payload;
  var _timeout = 10000;
//   Timer timeoutTimer;
  dynamic receivedResp;
  List recHooks = [];
  var _sent = false;
//   dynamic refEvent;
  PhoenixPush(this.channel, this.event, this.payload, [this._timeout]) {
    ref = this.channel.socket.makeRef();
  }

  PhoenixPush receive(String status, Function(dynamic response) callback) {
    if (hasReceived(status)) {
      callback(receivedResp.response);
    }

    this.recHooks.add(new PhoenixPushStatus(status, callback));
    return this;
  }

  hasReceived(status) {
    return false;
  }

//   resend(int timeout) {
//     _timeout = timeout;
//     reset();
//     send();
//   }
resend() {
  send();
}

//   reset() {
//     cancelRefEvent();
//   }

//   cancelRefEvent() {
//     if(refEvent != null) {
//       channel.off(event);
//     }
//   }
send() {
  _sent = true;
  channel
  .socket
  .push(new PhoenixMessage(channel.joinRef(), ref, channel.topic, event, payload));
}

//   send() {
//     _sent = true;
//     // startTimeout
//     _startTimeout();
//     channel
//     .socket
//     .push(new PhoenixMessage(channel.joinRef(), _ref, topic, event, payload));

//   }

//   _startTimeout() {

//   }
}

class PhoenixPushStatus {
  final status;
  final callback;
  PhoenixPushStatus(this.status, this.callback);
}
