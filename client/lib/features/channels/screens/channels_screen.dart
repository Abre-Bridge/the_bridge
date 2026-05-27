import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/chat_provider.dart';
import '../../chat/screens/chat_screen.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Channels')),
      body: channels.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final channel = list[i];
            return ListTile(
              leading: const Icon(Icons.tag),
              title: Text(channel['name']),
              subtitle: Text('${channel['_count']?['members'] ?? 0} members'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                chatId: channel['id'],
                name: '#${channel['name']}',
                isChannel: true,
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
