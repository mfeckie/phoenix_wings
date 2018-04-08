@TestOn("vm")

import 'package:test/test.dart';
import 'package:phoenix_wings/src/phoenix_message.dart';

void main() {
  test("Can encode a message", () {
    final message = new PhoenixMessage(
        "join_ref", "ref", "topic", "event", {"payload": ""});
    final json = message.toJSON();
    expect(json, '["join_ref","ref","topic","event",{"payload":""}]');
  });

  test("Can decode a payload into a message", () {
    final json = '["join_ref","ref","topic","event",{"payload":""}]';
    final decoded = PhoenixMessage.decode(json);
    expect(decoded.joinRef, "join_ref");
    expect(decoded.ref, "ref");
    expect(decoded.topic, "topic");
    expect(decoded.event, "event");
    expect(decoded.payload, {"payload": ""});
  });

  test("Can build a heartbeat message", () {
    final heartbeatMsg = new PhoenixMessage.heartbeat("pendingHeartbeatRef");
    final json = heartbeatMsg.toJSON();
    expect(json, '[null,"pendingHeartbeatRef","phoenix","heartbeat",{}]');
  });
}
