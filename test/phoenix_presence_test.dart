import 'dart:async';

import 'package:phoenix_wings/src/phoenix_push.dart';
import 'package:phoenix_wings/src/phoenix_socket.dart';
@TestOn("vm")

import 'package:test/test.dart';
import 'package:phoenix_wings/src/phoenix_channel.dart';
import 'package:phoenix_wings/src/phoenix_presence.dart';

MockChannel? _mockChannel;

void main() {
  late Map<String, Map<String, dynamic>> presences;

  setUp(() {
    _mockChannel = MockChannel();

    presences = {
      'u1': {'metas': [{'id': 1, 'phx_ref': '1'}]},
      'u2': {'metas': [{'id': 2, 'phx_ref': '2'}]},
      'u3': {'metas': [{'id': 3, 'phx_ref': '3'}]}
    };
  });

  group("Presence construciton", () {
    test("Returns presence with defaults", () {
      final phoenixPresence = PhoenixPresence(_mockChannel);
      expect(phoenixPresence.channel, equals(_mockChannel));
      expect(phoenixPresence.opts, equals({}));
      expect(phoenixPresence.events.state, equals(PhoenixPresenceEvents.presenceState));
      expect(phoenixPresence.events.diff, equals(PhoenixPresenceEvents.presenceDiff));
    });
  });

  group("syncState", () {
    test("syncs empty state", () {
      final newState = {'u1': {'metas': [{'id': 1, 'phx_ref': '1'}]}};
      Map<dynamic, dynamic>? state = {};
      final stateBefore = {};

      PhoenixPresence.syncState(state, newState, null, null);
      expect(state, equals(stateBefore));

      state = PhoenixPresence.syncState(state, newState, null, null);
      expect(state, equals(newState));
    });

    test("onJoins new presences and onLeave's left presences", () {
      final newState = PhoenixPresence.clone(presences);
      final state = {'u4': {'metas': [{'id': 4, 'phx_ref': '4'}]}};
      final joined = {};
      final left = {};
      final onJoin = (key, current, newPres) {
        joined[key] = {'current': current, 'newPres': newPres};
      };

      final onLeave = (key, current, leftPres) {
        left[key] = {'current': current, 'leftPres': leftPres};
      };

      final stateBefore = new Map.from(state);
      PhoenixPresence.syncState(state, newState, onJoin, onLeave);
      expect(state, equals(stateBefore));

      final resultState = PhoenixPresence.syncState(state, newState, onJoin, onLeave);
      expect(resultState, equals(newState));
      expect(joined, equals({
        'u1': {'current': null, 'newPres': {'metas': [{'id': 1, 'phx_ref': '1'}]}},
        'u2': {'current': null, 'newPres': {'metas': [{'id': 2, 'phx_ref': '2'}]}},
        'u3': {'current': null, 'newPres': {'metas': [{'id': 3, 'phx_ref': '3'}]}}
      }));
      expect(left, equals({
        'u4': {'current': {'metas': []}, 'leftPres': {'metas': [{'id': 4, 'phx_ref': '4'}]}}
      }));
    });

    test("onJoins only newly added metas", () {
      final newState = {'u3': {'metas': [{'id': 3, 'phx_ref': '3'}, {'id': 3, 'phx_ref': '3.new'}]}};
      final state = {'u3': {'metas': [{'id': 3, 'phx_ref': '3'}]}};
      final joined = {};
      final left = {};

      final onJoin = (key, current, newPres) => {
        joined[key] = {'current': current, 'newPres': newPres}
      };

      final onLeave = (key, current, leftPres) => {
        left[key] = {'current': current, 'leftPres': leftPres}
      };

      final resultState = PhoenixPresence.syncState(state, newState, onJoin, onLeave);
      expect(resultState, equals(newState));
      expect(joined, equals({
        'u3': {'current': {'metas': [{'id': 3, 'phx_ref': '3'}]},
            'newPres': {'metas': [{'id': 3, 'phx_ref': '3'}, {'id': 3, 'phx_ref': '3.new'}]}}
      }));
      expect(left, equals({}));
    });
  });

  group("syncDiff", () {
    test("syncs empty state", () {
      final joins = {'u1': {'metas': [{'id': 1, 'phx_ref': '1'}]}};
      final state = {};
      PhoenixPresence.syncDiff(state, {'joins': joins, 'leaves': {}}, null, null);
      expect(state, equals({}));

      final resultState = PhoenixPresence.syncDiff(state, {
        'joins': joins,
        'leaves': {}
      }, null, null);

      expect(resultState, equals(joins));
    });

    test("removes presence when meta is empty and adds additional meta", () {
      final state = presences;
      final joins = {'u1': {'metas': <Map<String, dynamic>>[{'id': 1, 'phx_ref': '1.2'}]}};
      final leaves = {'u2': {'metas': <Map<String, dynamic>>[{'id': 2, 'phx_ref': '2'}]}};

      final resultState = PhoenixPresence.syncDiff(state, {'joins': joins, 'leaves': leaves}, null, null);

      expect(resultState, equals({
        'u1': {'metas': [{'id': 1, 'phx_ref': '1'}, {'id': 1, 'phx_ref': '1.2'}]},
        'u3': {'metas': [{'id': 3, 'phx_ref': '3'}]}
      }));
    });

    test("removes meta while leaving key if other metas exist", () {
      final state = {
        'u1': {'metas': [{'id': 1, 'phx_ref': '1'}, {'id': 1, 'phx_ref': '1.2'}]}
      };

      final resultState = PhoenixPresence.syncDiff(state, {
        'joins': {},
        'leaves': {'u1': {'metas': [{'id': 1, 'phx_ref': '1'}]}}
      }, null, null);

      expect(resultState, equals({
        'u1': {'metas': [{'id': 1, 'phx_ref': '1.2'}]}
      }));
    });
  });

  group("list", () {
    test("lists full presence by default", () {
      final phoenixPresence = PhoenixPresence(_mockChannel);
      phoenixPresence.state = presences;

      final result = phoenixPresence.list();

      expect(result, equals([
        {'metas': [{'id': 1, 'phx_ref': '1'}]},
        {'metas': [{'id': 2, 'phx_ref': '2'}]},
        {'metas': [{'id': 3, 'phx_ref': '3'}]}
      ]));
    });

    test("lists with custom function", () {
      final phoenixPresence = PhoenixPresence(_mockChannel);
      phoenixPresence.state = {'u1': {'metas': [
        {'id': 1, 'phx_ref': '1.first'},
        {'id': 1, 'phx_ref': '1.second'}]
      }};

      final result = phoenixPresence.list(by: (key, presence) {
        return presence['metas'].first;
      });

      expect(result, equals([
        {'id': 1, 'phx_ref': '1.first'}
      ]));
    });
  });

  group("instance", () {
    final listByFirst = (key, presence) {
      return presence['metas'].first;
    };

    test("syncs state and diffs", () {
      final phoenixPresence = PhoenixPresence(_mockChannel);

      final user1 = {'metas': [{'id': 1, 'phx_ref': '1'}]};
      final user2 = {'metas': [{'id': 2, 'phx_ref': '2'}]};
      final newState = {'u1': user1, 'u2': user2};

      _mockChannel!.triggerEvent("presence_state", newState);
      expect(phoenixPresence.list(by: listByFirst), equals([
        {'id': 1, 'phx_ref': '1'},
        {'id': 2, 'phx_ref': '2'}
      ]));

      _mockChannel!.triggerEvent("presence_diff", {'joins': {}, 'leaves': {'u1': user1}});
      expect(phoenixPresence.list(by: listByFirst), equals([{'id': 2, 'phx_ref': '2'}]));
    });

    test("applies pending diff if state is not yet synced", () {
      final phoenixPresence = PhoenixPresence(_mockChannel);

      final onJoins = [];
      final onLeaves = [];

      phoenixPresence.onJoin((id, current, newPres) => {
        onJoins.add({
          'id': id,
          'current': current,
          'newPres': newPres
        })
      });
      phoenixPresence.onLeave((id, current, leftPres) => {
        onLeaves.add({
          'id': id,
          'current': current,
          'leftPres': leftPres
        })
      });

      // new connection
      final user1 = {'metas': [{'id': 1, 'phx_ref': '1'}]};
      final user2 = {'metas': [{'id': 2, 'phx_ref': '2'}]};
      final user3 = {'metas': [{'id': 3, 'phx_ref': '3'}]};
      final newState = {'u1': user1, 'u2': user2};
      final leaves = {'u2': user2};

      _mockChannel!.triggerEvent("presence_diff", {'joins': {}, 'leaves': leaves});

      expect(phoenixPresence.list(by: listByFirst), equals([]));
      expect(phoenixPresence.pendingDiffs, [{'joins': {}, 'leaves': leaves}]);

      _mockChannel!.triggerEvent("presence_state", newState);
      expect(onLeaves, equals([
        {'id': 'u2', 'current': {'metas': []}, 'leftPres': {'metas': [{'id': 2, 'phx_ref': '2'}]}}
      ]));

      expect(phoenixPresence.list(by: listByFirst), equals([{'id': 1, 'phx_ref': '1'}]));
      expect(phoenixPresence.pendingDiffs, equals([]));
      expect(onJoins, equals([
        {'id': 'u1', 'current': null, 'newPres': {'metas': [{'id': 1, 'phx_ref': '1'}]}},
        {'id': 'u2', 'current': null, 'newPres': {'metas': [{'id': 2, 'phx_ref': '2'}]}}
      ]));

      // disconnect and reconnect
      expect(phoenixPresence.inPendingSyncState, equals(false));
      _mockChannel!.simulateDisconnectAndReconnect();
      expect(phoenixPresence.inPendingSyncState, equals(true));

      _mockChannel!.triggerEvent("presence_diff", {'joins': {}, 'leaves': {'u1': user1}});
      expect(phoenixPresence.list(by: listByFirst), equals([{'id': 1, 'phx_ref': '1'}]));

      _mockChannel!.triggerEvent("presence_state", {'u1': user1, 'u3': user3});
      expect(phoenixPresence.list(by: listByFirst), equals([{'id': 3, 'phx_ref': '3'}]));
    });

    test("allows custom channel events", () {
      final customEvents = new PresenceEvents('the_state', 'the_diff');
      final phoenixPresence = PhoenixPresence(_mockChannel, opts: {'events': customEvents});

      final user1 = {'metas': [{'id': 1, 'phx_ref': '1'}]};
      _mockChannel!.triggerEvent("the_state", {'user1': user1});
      expect(phoenixPresence.list(by: listByFirst), equals([{'id': 1, 'phx_ref': '1'}]));
      _mockChannel!.triggerEvent("the_diff", {'joins': {}, 'leaves': {'user1': user1}});
      expect(phoenixPresence.list(by: listByFirst), equals([]));
    });
  });
}

class MockChannel implements PhoenixChannel {
  int _ref = 1;
  Map<String?, List<Function>> _bindings = {};

  MockChannel();

  void triggerEvent(String event, Map<String, dynamic> payload) {
    if (_bindings.containsKey(event)) {
      _bindings[event]!.forEach((cb) => cb(payload, null, null));
    }
  }

  @override
  int on(String? event, Function(Map<dynamic, dynamic>, String, String) cb) {
    if (!_bindings.containsKey(event)) {
      _bindings[event] = [];
    }
    _bindings[event]!.add(cb);
    return _ref;
  }

  @override
  String get joinRef => '${_ref}';

  void simulateDisconnectAndReconnect() {
    _ref++;
  }

  @override
  Timer? rejoinTimer;

  @override
  PhoenixSocket? socket;

  @override
  bool get canPush => true;

  @override
  bool get isClosed => false;

  @override
  bool get isErrored => false;

  @override
  bool get isJoined => true;

  @override
  bool get isJoining => false;

  @override
  bool get isLeaving => false;

  @override
  bool isMember(String topicParam, String event, Map payload, String? joinRefParam) {
    return true;
  }

  @override
  PhoenixPush? join() {
    return null;
  }

  @override
  PhoenixPush? get joinPush => null;

  @override
  PhoenixPush? leave() {
    return null;
  }

  @override
  void off(event, [ref]) {
  }

  @override
  onClose(PhoenixMessageCallback callback) {
    return null;
  }

  @override
  onError(callback) {
    return null;
  }

  @override
  onMessage(event, payload, ref) {
    return null;
  }

  @override
  Map? get params => null;

  @override
  PhoenixPush? push({String? event, Map? payload}) {
    return null;
  }

  @override
  String? replyEventName(ref) {
    return null;
  }

  @override
  int? get timeout => null;

  @override
  String? get topic => null;

  @override
  trigger(String? event, [Map? payload, String? ref, String? joinRefParam]) {
    return null;
  }

  @override
  triggerError() {
    return null;
  }
}