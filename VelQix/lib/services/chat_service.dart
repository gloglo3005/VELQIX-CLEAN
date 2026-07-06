import 'package:flutter/material.dart';
import 'chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String userId;

  ChatScreen({required this.conversationId, required this.userId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    chatService.connect(widget.conversationId, widget.userId);
  }

  @override
  void dispose() {
    chatService.disconnect();
    super.dispose();
  }

  void sendMessage() {
    chatService.sendMessage(widget.conversationId, widget.userId, controller.text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Conversation")),
      body: Column(
        children: [
          Expanded(child: Container(/* ici tu affiches les messages */)),
          Row(
            children: [
              Expanded(child: TextField(controller: controller)),
              IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
            ],
          )
        ],
      ),
    );
  }
}
Expanded(
  child: ListView.builder(
    itemCount: messages.length,
    itemBuilder: (context, index) {
      final msg = messages[index];
      return ListTile(
        title: Text(msg['content']),
        subtitle: Text("Envoyé par ${msg['senderId']}"),
      );
    },
  ),
)
