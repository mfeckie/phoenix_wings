
import 'package:phoenix_wings/src/phoenix_connection.dart';
import 'package:phoenix_wings/src/phoenix_socket.dart';
import 'package:phoenix_wings/src/phoenix_socket_options.dart';

import 'package:phoenix_wings/src/io/phoenix_io_connection.dart';

/// PhoenixIOSocket handles the creation of a phoenix socket on browser platforms.
class PhoenixIoSocket extends PhoenixSocket {
  PhoenixIoSocket(String endpoint, {socketOptions: PhoenixSocketOptions})
    :
    super(endpoint, socketOptions: socketOptions);

  @override
  PhoenixConnection createConnection(String endpoint) {
    return new PhoenixIoConnection(endpoint);
  }
}
