import 'dart:async';

import 'package:phoenix_wings/src/phoenix_push.dart';
import 'package:phoenix_wings/src/phoenix_socket.dart';

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
  List<_PhoenixChannelBinding> _bindings = [];
  List _pushBuffer = [];
  int _bindingRef = 0;
  var _joinedOnce = false;
  PhoenixPush joinPush;
  Timer rejoinTimer;

  PhoenixChannel(this.topic, this.params, this.socket) {
    joinPush =
        new PhoenixPush(this, PhoenixChannelEvents.join, this.params, timeout);

    joinPush.receive("ok", (msg) {
      _state = PhoenixChannelState.joined;
      _pushBuffer.forEach((pushEvent) => pushEvent.send());
      _pushBuffer = [];
    });

    joinPush.receive("timeout", (_) {
      if (!isJoining) {
        return;
      }
      final leavePush =
          new PhoenixPush(this, PhoenixChannelEvents.leave, {}, timeout);
      leavePush.send();
      _state = PhoenixChannelState.errored;
      joinPush.reset();
      startRejoinTimer();
    });

    onClose((a, b, c) {
      rejoinTimer?.cancel();
      _state = PhoenixChannelState.closed;
      socket.remove(this);
    });

    on(PhoenixChannelEvents.reply, (payload, ref, _joinRef) {
      trigger(replyEventName(ref), payload);
    });

    onError((reason, _a, _b) {
      if (isLeaving || isClosed) {
        return;
      }
      _state = PhoenixChannelState.errored;
      startRejoinTimer();
    });
  }

  startRejoinTimer() {
    rejoinTimer = new Timer.periodic(new Duration(milliseconds: timeout), (timer) {
      if (_state == PhoenixChannelState.joined) {
        timer.cancel();
        rejoinTimer = null;
        return;
      }

      if (socket.isConnected) {
        rejoin(timeout);
      }
    });
  }

  get canPush => socket.isConnected && isJoined;

  get isClosed => _state == PhoenixChannelState.closed;
  get isErrored => _state == PhoenixChannelState.errored;
  get isJoined => _state == PhoenixChannelState.joined;
  get isJoining => _state == PhoenixChannelState.joining;
  get isLeaving => _state == PhoenixChannelState.leaving;
  
  get joinRef => this.joinPush.ref;

  get timeout => socket.timeout;

  replyEventName(ref) => "chan_reply_$ref";

  bool isMember(
      String topicParam, String event, Map payload, String joinRefParam) {
    if (topic != topicParam) {
      return false;
    }
    final isLifecycleEvent = PhoenixChannelEvents.lifecycleEvent(event);
    if (joinRef != null && isLifecycleEvent && (joinRefParam != joinRef)) {
      return false;
    }
    return true;
  }

  PhoenixPush join() {
    if (_joinedOnce) {
      throw ("tried to join channel multiple times");
    } else {
      _joinedOnce = true;
      rejoin(timeout);
      return joinPush;
    }
  }

  leave() {
    _state = PhoenixChannelState.leaving;

    Function onCloseCallback = (_) {
      trigger(PhoenixChannelEvents.close);
    };

    final leavePush =
        new PhoenixPush(this, PhoenixChannelEvents.leave, {}, timeout);

    leavePush
        .receive("ok", onCloseCallback)
        .receive("timeout", onCloseCallback);

    leavePush.send();

    if (!canPush) {
      leavePush.trigger("ok", {});
    }

    return leavePush;
  }

  PhoenixPush push({String event, Map payload}) {
    if (!_joinedOnce) {
      throw ("Tried to push event before joining channel");
    }
    final pushEvent = new PhoenixPush(this, event, payload, timeout);
    if (canPush) {
      pushEvent.send();
    } else {
      pushEvent.startTimeout();
      _pushBuffer.add(pushEvent);
    }
    return pushEvent;
  }

  rejoin(timeout) {
    if (isLeaving) {
      return;
    }
    sendJoin(timeout);
  }

  sendJoin(timeout) {
    _state = PhoenixChannelState.joining;
    joinPush.resend(timeout);
  }


  trigger(String event, [Map payload, String ref, String joinRefParam]) {
    final handledPayload = this.onMessage(event, payload, ref);
    if (payload != null && handledPayload == null) {
      throw ("channel onMessage callback must return payload modified or unmodified");
    }
    _bindings.where((bound) => bound.event == event).forEach((bound) =>
        bound.callback(handledPayload, ref, joinRefParam ?? joinRef));
  }

  int on(String event, PhoenixMessageCallback callback) {
    final ref = _bindingRef++;
    _bindings.add(new _PhoenixChannelBinding(event, ref, callback));
    return ref;
  }

  void off(event, [ref]) {
    _bindings = _bindings
        .where((binding) =>
            binding.event != event && (ref == null || ref == binding.ref))
        .toList();
  }

  onClose(PhoenixMessageCallback callback) {
    on(PhoenixChannelEvents.close, callback);
  }

  onError(callback) => on(PhoenixChannelEvents.error,
      (payload, ref, joinRef) => callback(payload, ref, joinRef));

  onMessage(event, payload, ref) => payload;
}

class _PhoenixChannelBinding {
  String event;
  int ref;
  PhoenixMessageCallback callback;
  _PhoenixChannelBinding(this.event, this.ref, this.callback);
}

typedef void PhoenixMessageCallback (Map payload, String ref, String joinRef);
