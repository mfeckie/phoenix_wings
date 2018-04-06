
import 'package:phoenix_wings/src/phoenix_socket.dart';
import 'package:phoenix_wings/src/phoenix_connection.dart';
import 'package:phoenix_wings/src/phoenix_socket_options.dart';

import 'package:phoenix_wings/src/html/phoenix_html_connection.dart';

class PhoenixHtmlSocket extends PhoenixSocket {
  PhoenixHtmlSocket(String endpoint, {socketOptions: PhoenixSocketOptions})
    :
    super(endpoint, socketOptions: socketOptions);

  @override
  PhoenixConnection createConnection(String endpoint) {
    return new PhoenixHtmlConnection(endpoint);
  }
}
