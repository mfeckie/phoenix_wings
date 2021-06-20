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
  String _topic;
  Map _params = {};
  PhoenixSocket? socket;
  List<_PhoenixChannelBinding> _bindings = [];
  List _pushBuffer = [];
  int _bindingRef = 0;
  var _joinedOnce = false;
  PhoenixPush? _joinPush;
  Timer? rejoinTimer;

  /// To create a channel use [PhoenixSocket.channel]
  ///
  /// Channels are isolated, concurrent processes on the server that
  /// subscribe to topics and broker events between the client and server.
  /// To join a channel, you must provide the topic, and channel params for
  /// authorization.
  ///
  PhoenixChannel(this._topic, this._params, this.socket) {
    _joinPush =
        new PhoenixPush(this, PhoenixChannelEvents.join, _params, timeout);

    _joinPush!.receive("ok", (msg) {
      _state = PhoenixChannelState.joined;
      _pushBuffer.forEach((pushEvent) => pushEvent.send());
      _pushBuffer = [];
    });

    _joinPush!.receive("timeout", (_) {
      if (!isJoining) {
        return;
      }
      final leavePush =
          new PhoenixPush(this, PhoenixChannelEvents.leave, {}, timeout);
      leavePush.send();
      _state = PhoenixChannelState.errored;
      _joinPush!.reset();
      _startRejoinTimer();
    });

    onClose((a, b, c) {
      rejoinTimer?.cancel();
      _state = PhoenixChannelState.closed;
      socket!.remove(this);
    });

    on(PhoenixChannelEvents.reply, (payload, ref, _joinRef) {
      trigger(replyEventName(ref), payload);
    });

    onError((reason, _a, _b) {
      if (isLeaving || isClosed) {
        return;
      }
      _state = PhoenixChannelState.errored;
      _startRejoinTimer();
    });
  }

  _startRejoinTimer() {
    rejoinTimer =
        new Timer.periodic(new Duration(milliseconds: timeout!), (timer) {
      if (_state == PhoenixChannelState.joined) {
        timer.cancel();
        rejoinTimer = null;
        return;
      }

      if (socket!.isConnected) {
        _rejoin(timeout);
      }
    });
  }

  bool get canPush => socket!.isConnected && isJoined;
  bool get isClosed => _state == PhoenixChannelState.closed;
  bool get isErrored => _state == PhoenixChannelState.errored;
  bool get isJoined => _state == PhoenixChannelState.joined;
  bool get isJoining => _state == PhoenixChannelState.joining;
  bool get isLeaving => _state == PhoenixChannelState.leaving;
  PhoenixPush? get joinPush => _joinPush;
  String? get topic => _topic;
  Map? get params => _params;

  String? get joinRef => _joinPush!.ref;

  int? get timeout => socket!.timeout;

  String? replyEventName(ref) => "chan_reply_$ref";

  /// @nodoc
  bool isMember(
      String topicParam, String event, Map payload, String? joinRefParam) {
    if (_topic != topicParam) {
      return false;
    }
    final isLifecycleEvent = PhoenixChannelEvents.lifecycleEvent(event);
    if (joinRef != null && isLifecycleEvent && (joinRefParam != joinRef)) {
      return false;
    }
    return true;
  }

  /// Attempts to join the Phoenix Channel
  ///
  /// Attempting to join a channel more than once is an error.
  ///
  /// If the channel join attempt fails, it will attempt to rejoin
  /// based on the timeout settings of the [PhoenixSocket]
  PhoenixPush? join() {
    if (_joinedOnce) {
      throw ("tried to join channel multiple times");
    } else {
      _joinedOnce = true;
      _rejoin(timeout);
      return _joinPush;
    }
  }

  /// Leaves the channel
  ///
  /// Notifies the server and triggers onCloseCallback(s)
  PhoenixPush? leave() {
    _state = PhoenixChannelState.leaving;

    Function onCloseCallback = (_) {
      trigger(PhoenixChannelEvents.close);
    };

    final leavePush =
        new PhoenixPush(this, PhoenixChannelEvents.leave, {}, timeout);

    leavePush
        .receive("ok", onCloseCallback as dynamic Function(Map<dynamic, dynamic>?))
        .receive("timeout", onCloseCallback);

    leavePush.send();

    if (!canPush) {
      leavePush.trigger("ok", {});
    }

    return leavePush;
  }

  /// Pushes a message to the server
  PhoenixPush? push({String? event, Map? payload}) {
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

  _rejoin(timeout) {
    if (isLeaving) {
      return;
    }
    _sendJoin(timeout);
  }

  _sendJoin(timeout) {
    _state = PhoenixChannelState.joining;
    _joinPush!.resend(timeout);
  }

  /// @nodoc
  trigger(String? event, [Map? payload, String? ref, String? joinRefParam]) {
    final handledPayload = this.onMessage(event, payload, ref);
    if (payload != null && handledPayload == null) {
      throw ("channel onMessage callback must return payload modified or unmodified");
    }
    _bindings.where((bound) => bound.event == event).forEach((bound) =>
        bound.callback(handledPayload, ref, joinRefParam ?? joinRef));
  }

  triggerError() {
    trigger(PhoenixChannelEvents.error);
  }

  /// Adds a callback which will be triggered on receiving an [event]
  /// with matching name
  int on(String? event, PhoenixMessageCallback callback) {
    final ref = _bindingRef++;
    _bindings.add(new _PhoenixChannelBinding(event, ref, callback));
    return ref;
  }

  /// Removes an event callback
  void off(event, [ref]) {
    _bindings = _bindings
        .where((binding) =>
            binding.event != event && (ref == null || ref == binding.ref))
        .toList();
  }

  /// Adds a callback to be triggered on channel close
  onClose(PhoenixMessageCallback callback) {
    on(PhoenixChannelEvents.close, callback);
  }

  /// Adds a callback to be trigger on channel error
  onError(callback) => on(PhoenixChannelEvents.error,
      (payload, ref, joinRef) => callback(payload, ref, joinRef));

  onMessage(event, payload, ref) => payload;
}

class _PhoenixChannelBinding {
  String? event;
  int ref;
  PhoenixMessageCallback callback;
  _PhoenixChannelBinding(this.event, this.ref, this.callback);
}

/// A function that describes how to responsd to a received message
///
/// ### Example
///     final PhoenixMessageCallback myCallback = (payload, ref, joinRef) {
///       return payload;
///     }
typedef void PhoenixMessageCallback(Map? payload, String? ref, String? joinRef);
