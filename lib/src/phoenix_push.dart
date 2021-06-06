import 'dart:async';

import 'package:phoenix_wings/src/phoenix_channel.dart';
import 'package:phoenix_wings/src/phoenix_message.dart';

class PhoenixPush {
  bool sent = false;
  Map? receivedResp;
  int? timeout;
  List recHooks = [];
  Map? payload = {};
  PhoenixChannel? channel;
  String? event;
  String? ref;
  String? refEvent;

  Timer? timeoutTimer;

  PhoenixPush(this.channel, this.event, this.payload, this.timeout) {
    ref = this.channel!.socket!.makeRef();
  }

  PhoenixPush receive(String status, Function(Map? response) callback) {
    if (hasReceived(status)) {
      callback(receivedResp);
    }

    this.recHooks.add(new _PhoenixPushStatus(status, callback));
    return this;
  }

  bool hasReceived(status) {
    return receivedResp != null && receivedResp!["status"] == status;
  }

  matchReceive(Map? payload) {
    recHooks
        .where((hook) => hook.status == payload!["status"])
        .forEach((hook) => hook.callback(payload!["response"]));
  }

  resend(int? timeout) {
    timeout = timeout;
    reset();
    send();
  }

  cancelRefEvent() {
    if (refEvent == null) {
      return;
    }
    channel!.off(refEvent);
  }

  reset() {
    cancelRefEvent();
    ref = null;
    refEvent = null;
    receivedResp = null;
    sent = false;
  }

  send() {
    startTimeout();
    refEvent = channel!.replyEventName(ref);
    sent = true;
    channel!.socket!.push(new PhoenixMessage(
        channel!.joinRef, ref, channel!.topic, event, payload));
  }

  startTimeout() {
    cancelTimeout();
    ref = channel!.socket!.makeRef();
    refEvent = channel!.replyEventName(ref);
    channel!.on(refEvent, (payload, _a, _b) {
      cancelRefEvent();
      cancelTimeout();
      receivedResp = payload;
      matchReceive(payload);
    });

    timeoutTimer = new Timer(new Duration(milliseconds: timeout!), () {
      trigger("timeout", {});
    });
  }

  cancelTimeout() {
    timeoutTimer?.cancel();
    timeoutTimer = null;
  }

  trigger(status, response) {
    channel!.trigger(refEvent, {"status": status, "response": response});
  }
}

class _PhoenixPushStatus {
  final status;
  final callback;
  _PhoenixPushStatus(this.status, this.callback);
}
