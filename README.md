[![Pub](https://img.shields.io/pub/v/phoenix_wings.svg?style=flat-square)](https://pub.dartlang.org/packages/phoenix_wings)


# phoenix_wings.dart

A Phoenix Channel implementation for Dart

Attempts to feature match the Javascript implementation found at [phoenix.js](https://github.com/phoenixframework/phoenix/blob/master/assets/js/phoenix.js)

## Usage

[API Documentation](https://pub.dartlang.org/documentation/phoenix_wings/latest/)

Much of the library is the same whether your code is running in the VM/Flutter or in a browser. Due to differences between the two platforms, the connection setup differs slightly.

### Import & Connection (VM/Flutter)

```dart
import 'package:phoenix_wings/phoenix_wings.dart';


final socket = new PhoenixSocket("ws://localhost:4000/socket/websocket");

// equivalent to passing connectionProvider: PhoenixIoConnection.provider

// you can also pass params on connection if you for example want to authenticate using a user token like
final socket = PhoenixSocket("ws://localhost:4000/socket/websocket", socketOptions: PhoenixSocketOptions(params: {"user_token":  'user token here'}, ));
```
Options that can be passed on connection include :-
- **timeout** - How long to wait for a response in miliseconds. **Default** 10000
- **heartbeatIntervalMs** - How many milliseconds between heartbeats. **Default** 30000
- **reconnectAfterMs** - Optional list of milliseconds between reconnect attempts
- **params** - Parameters sent to your Phoenix backend on connection.

### Import & Connection (HTML)

```dart
import 'package:phoenix_wings/html.dart';


final socket = new PhoenixSocket("ws://localhost:4000/socket/websocket", connectionProvider: PhoenixHtmlConnection.provider);

```

### Common Usage

```dart
await socket.connect();

final chatChannel = socket.channel("room:chat", {"id": "myId"});

chatChannel.on("user_entered", PhoenixMessageCallback (Map payload, String _ref, String, _joinRef) {
    print(payload);
});

chatChannel.join();
```

### Examples

*Mobile* - when running the flutter example in your emulator, with the server
also running in the same computer host, remember that the emulator is running 
in a segregated VM, so you need to configure it to point your server that is
running on the host machine.

```bash

# check your IP configuration
$ ifconfig
enp0s20u5c4i2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
inet 10.0.0.2  netmask 255.255.255.240  broadcast 172.20.10.15
```

1. After checking your IP, go to your flutter Settings -> Proxy, and add the proxy
host configuration with your IP, and port where your phoenix server with the
websockets is listening.

2. Configure your flutter app to point to your phoenix websocket server.
```
final socket = PhoenixSocket("ws://10.0.0.2:4000/socket/websocket");
```
See
[here](https://stackoverflow.com/questions/6760585/accessing-localhostport-from-android-emulator)
for an illustrated example.

*Server* - phoenix server with a channel that will communicate with the flutter
app above.

*Console* - if you want to debug the websockets direclty, without phoenix_wings,
using the phoenix protocol. See
[here](http://graemehill.ca/websocket-clients-and-phoenix-channels/) for more
info about the json protocol. You will have a lot of fun, connecting, and seeing
the loop in this console app sending messages to your flutter app.
To run, simply:

```
dart console.dart
```

## Testing

Most of the tests are run on the VM. However, the PhoenixHtmlConnection tests must run in a browser. 

By default tests will run on VM, Chrome and Firefox.  This is set in dart_test.yaml

Tests are run via `pub run test`
