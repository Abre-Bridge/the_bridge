import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/file_provider.dart';
import '../../../core/widgets/glass_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String name;
  final bool isChannel;

  const ChatScreen({super.key, required this.chatId, required this.name, this.isChannel = false});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msg = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider({'chatId': widget.chatId, 'isChannel': widget.isChannel}));

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final m = messages[i];
                final isMe = m.senderId == ref.read(authProvider).user?['id'];
                return Container(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GlassContainer(
                    color: isMe ? Colors.indigo.withOpacity(0.3) : Colors.white.withAlpha(10),
                    child: Text(m.content),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.attach_file), onPressed: () => ref.read(fileProvider).sendFile(widget.chatId, widget.isChannel)),
                Expanded(child: TextField(controller: _msg, decoration: const InputDecoration(hintText: 'Type something...'))),
                IconButton(icon: const Icon(Icons.send), onPressed: () {
                  if (_msg.text.isNotEmpty) {
                    ref.read(chatMessagesProvider({'chatId': widget.chatId, 'isChannel': widget.isChannel}).notifier).sendMessage(_msg.text);
                    _msg.clear();
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
