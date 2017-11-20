import 'dart:convert';

class PhoenixMessage {
  String joinRef, ref, topic, event;
  Map payload;

  PhoenixMessage(this.joinRef, this.ref, this.topic, this.event, this.payload);

  String toJSON() {
    return JSON.encode({
      "join_ref": joinRef,
      "ref": ref,
      "topic": topic,
      "event": event,
      "payload": payload
    });
  }
}
