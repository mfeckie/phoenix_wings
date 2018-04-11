# phoenix_wings.dart

A Phoenix Channel implementation for Dart

Attempts to feature match the Javascript implementation found at [phoenix.js](https://github.com/phoenixframework/phoenix/blob/master/assets/js/phoenix.js)

## Usage

Much of the library is the same whether your code is running in the VM/Flutter or in a browser. Due to differences between the two platforms, the connection setup differs slightly.

### Import & Connection (VM/Flutter)

```dart
import 'package:phoenix_wings/phoenix_wings.dart';


final socket = new PhoenixSocket("ws://localhost:4000/websocket/socket");

// equivalent to passing connectionProvider: PhoenixIoConnection.provider

```

### Import & Connection (HTML)

```dart
import 'package:phoenix_wings/html.dart';


final socket = new PhoenixSocket("ws://localhost:4000/websocket/socket", connectionProvider: PhoenixHtmlConnection.provider);

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

## Testing

Most of the tests are run on the VM. However, the PhoenixHtmlConnection tests must run in a browser. You can use the following commands to run all tests for both platforms:


        # using firefox
        pub run test test/ -p vm,firefox

        # using chrome
        pub run test test/ -p vm,chrome
