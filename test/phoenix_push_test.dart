@TestOn("vm")

import 'dart:async';

import 'package:mockito/annotations.dart';
import 'package:phoenix_wings/src/phoenix_channel.dart';
import 'package:phoenix_wings/src/phoenix_push.dart';
import 'package:phoenix_wings/src/phoenix_socket.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'phoenix_push_test.mocks.dart';

@GenerateMocks([], customMocks: [
  MockSpec<PhoenixChannel>(
      as: #MockPhoenixChannel, returnNullOnMissingStub: true),
  MockSpec<PhoenixSocket>(
      as: #MockPhoenixSocket, returnNullOnMissingStub: true),
])
void main() {
  late MockPhoenixSocket socket;
  late MockPhoenixChannel channel;

  setUp(() {
    socket = MockPhoenixSocket();
    channel = MockPhoenixChannel();
    when(channel.socket).thenReturn(socket);
    when(channel.on(any, any)).thenReturn(0);
    when(socket.makeRef()).thenReturn("1");
    when(socket.timeout).thenReturn(0);
  });

  test("Builds a new Push", () {
    final push = new PhoenixPush(channel, "phx_join", {}, 100);

    expect(push.ref, "1");
    expect(push.event, "phx_join");
    expect(push.payload, {});
    expect(push.timeout, 100);
  });

  test("Executes callback when hasReceived message", () {
    final push = new PhoenixPush(channel, "event", {}, 100);
    push.receivedResp = {"status": "ok"};

    var callbackExecuted = false;

    push.receive("ok", (resp) {
      callbackExecuted = true;
    });

    expect(callbackExecuted, true);
  });

  test("Registers callback and executes matching hooks", () {
    final push = new PhoenixPush(channel, "event", {}, 100);

    var callbackExecuted = false;
    Map? payload;
    var notReceiveExecuted = false;

    push.receive("ok", (resp) {
      callbackExecuted = true;
      payload = resp;
    });

    push.receive("notOk", (_) {
      notReceiveExecuted = true;
    });

    push.matchReceive({
      "status": "ok",
      "response": {"success": "credibility"}
    });

    expect(callbackExecuted, isTrue);
    expect(payload, {"success": "credibility"});
    expect(notReceiveExecuted, isFalse);
  });

  test("Can reset", () {
    final push = new PhoenixPush(channel, "event", {}, 100);

    push.refEvent = "refEvent";
    expect(push.ref, "1");
    expect(push.refEvent, "refEvent");

    push.reset();

    verify(channel.off("refEvent"));
    expect(push.ref, null);
  });

  test("triggers timeout when response not received in time", () async {
    final push = new PhoenixPush(channel, "event", {}, 10);
    when(channel.replyEventName("1")).thenReturn("chan_reply_1");
    push.send();

    await new Future<Null>.delayed(new Duration(milliseconds: 90));
    verify(
        channel.trigger("chan_reply_1", {"status": "timeout", "response": {}}));
  });

  test("clears timer when response received in time", () async {
    final realChannel = new PhoenixChannel("topic", {}, socket);
    final push = new PhoenixPush(realChannel, "event", {}, 100);
    push.send();
    expect(push.timeoutTimer, isNotNull);
    realChannel.trigger(push.refEvent, {"status": "ok", "response": {}});
    expect(push.timeoutTimer, isNull);
  });
}
