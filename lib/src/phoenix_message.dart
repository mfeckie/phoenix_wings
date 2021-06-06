import 'dart:convert';

class PhoenixMessage {
  String? joinRef, ref, topic, event;
  Map? payload;

  PhoenixMessage(this.joinRef, this.ref, this.topic, this.event, this.payload);

  /// Convenience function for decoding received Phoenix messages
  static PhoenixMessage decode(rawPayload) {
    final decoded = json.decode(rawPayload);
    return new PhoenixMessage(
        decoded[0], decoded[1], decoded[2], decoded[3], decoded[4]);
  }

  String toJSON() {
    return json.encode([joinRef, ref, topic, event, payload]);
  }

  /// Constructor for a hearbeat message.
  PhoenixMessage.heartbeat(String? pendingHeartbeatRef) {
    ref = pendingHeartbeatRef;
    payload = {};
    event = "heartbeat";
    topic = "phoenix";
  }
}
