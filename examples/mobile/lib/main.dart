import 'package:flutter/material.dart';
import 'package:phoenix_wings/phoenix_wings.dart';
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Phoenix Wings Chat'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);
  final String? title;
  // if you want to run both phoenix and flutter [with emulator] in the same
  // machine, point to your local machine [not localhost], as described in 
  // the README.md file.
  final socket = PhoenixSocket("ws://my_server:4000/socket/websocket");

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late PhoenixChannel _channel;
  List<ChatMessage> messages = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    connectSocket();
    super.initState();
  }

  connectSocket() async {
    await widget.socket.connect();
    // Create a new PhoenixChannel
    _channel = widget.socket.channel("flutter_chat:lobby");
    // Setup listeners for channel events
    _channel.on("say", _say);
    // Make the request to the server to join the channel
    _channel.join();
  }

  _say(payload, _ref, _joinRef) {
    setState(() {
      messages.insert(0, ChatMessage(text: payload["message"]));
    });
  }

  _sendMessage(message) {
    _channel.push(event: "say", payload: {"message": message});
    _textController.clear();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: Column(
        children: <Widget>[
          Flexible(
            child: ListView.builder(
              reverse: true,
              itemBuilder: (BuildContext context, int index) {
                final message = messages[index];
                return Card(
                    child: Column(
                  children: <Widget>[
                    ListTile(
                        leading: Icon(Icons.message),
                        title: Text(message.text!),
                        subtitle: Text(message.time)),
                  ],
                ));
              },
              itemCount: messages.length,
            ),
          ),
          Divider(
              height: 1.0,
          ),
          Container(
              child: MessageComposer(
            textController: _textController,
            sendMessage: _sendMessage,
          ))
        ],
      ),
    );
  }
}

/**
 * Represents the chat message
 */

class ChatMessage {
  final String? text;
  final DateTime received = DateTime.now();
  ChatMessage({this.text});

  get time => DateFormat.Hms().format(received);
}

/**
 * Messaage box to compose and press the send button
 */

class MessageComposer extends StatelessWidget {
  final textController;
  final sendMessage;

  MessageComposer({this.textController, this.sendMessage});
  build(BuildContext context) {
    return Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                  controller: textController,
                  onSubmitted: sendMessage,
                  decoration:
                      InputDecoration.collapsed(hintText: "Send a message")),
            ),
            Container(
              child: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => sendMessage(textController.text)),
            )
          ],
        ));
  }
}
