import 'dart:io' show WebSocket;
import 'dart:convert' show json;
import 'dart:async' show Timer;


/**
 * Connect to the example phoenix server, and send some messages, without using the phoenix_wings,
 * because sometimes we want to debug the websocket protocol straight on 'bare metal' :)
 */

main() {
  // change the ws:// address to point to your websocket server
  WebSocket.connect('ws://my_server:4000/socket/websocket').then((WebSocket ws) {
    if (ws?.readyState == WebSocket.open) {
      // as soon as websocket is connected and ready for use, we can start talking to other end
      ws.add(json.encode({
        'topic': 'flutter_chat:lobby',
        'event': 'phx_join',
        'payload': {},
        'ref': 0,
        'data': 'from client at ${DateTime.now().toString()}',
      })); // this is the JSON data format to be transmitted
      ws.listen( // gives a StreamSubscription
        (data) {
          print(data);
          Timer(Duration(seconds: 1), () {
            if (ws.readyState == WebSocket.open) // checking whether connection is open or not, is required before writing anything on socket
              ws.add(json.encode({
                'topic': 'flutter_chat:lobby',
                'event': 'say',
                'payload': {'message': 'dart app talking here !!!'},
                'ref': 0,
                'data': 'from client at ${DateTime.now().toString()}',
              }));
          });
        },
        onDone: () => print('[+]Done :)'),
        onError: (err) => print('[!]Error -- ${err.toString()}'),
        cancelOnError: true,
      );
    } else
      print('[!]Connection Denied');
      // in case the server is not running now
  }, onError: (err) => print('[!]Error -- ${err.toString()}'));
}
