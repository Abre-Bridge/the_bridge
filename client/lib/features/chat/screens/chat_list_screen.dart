import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/widgets/glass_widgets.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: chats.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final chat = list[i];
            return ListTile(
              leading: UserAvatar(displayName: chat['display_name'] ?? chat['username']),
              title: Text(chat['display_name'] ?? chat['username']),
              subtitle: Text(chat['last_message']?['content'] ?? 'No messages'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                chatId: chat['id'],
                name: chat['display_name'] ?? chat['username'],
              ))),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
