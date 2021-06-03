import 'package:phoenix_wings/src/phoenix_message.dart';

/// Responsible for serializing and deserializing messages
class PhoenixSerializer {
  /// Converts a [PhoenixMessage] to a String of JSON
  static String encode(PhoenixMessage msg) {
    return msg.toJSON();
  }

  /// Converts a raw JSON String into a [PhoenixMessage]
  static PhoenixMessage decode(String? rawPayload) {
    return PhoenixMessage.decode(rawPayload);
  }
}
