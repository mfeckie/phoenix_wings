import 'package:phoenix_wings/phoenix_message.dart';

class PhoenixSerializer {
  static String encode(PhoenixMessage msg, Function callback) {
    return msg.toJSON();
  }

  static decode(String rawPayload, Function callback) {
//    let [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload)
//
//    return callback({join_ref, ref, topic, event, payload})
  }
}

