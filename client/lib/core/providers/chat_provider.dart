import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

// Provides the list of online users
final onlineUsersProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getOnlineUsers();
});

// Provides conversations (recent chats)
final conversationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getConversations();
});

// Provides channels
final channelsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getChannels();
});

// StateNotifier for a specific chat's messages
class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final String chatId;
  final bool isChannel;
  final Ref ref;

  ChatMessagesNotifier({
    required this.chatId,
    required this.isChannel,
    required this.ref,
  }) : super(const AsyncValue.loading()) {
    _loadMessages();
    _listenToSockets();
  }

  Future<void> _loadMessages() async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiServiceProvider);
      List<dynamic> messages;
      if (isChannel) {
        messages = await api.getChannelMessages(chatId);
      } else {
        messages = await api.getDirectMessages(chatId);
      }
      state = AsyncValue.data(messages.reversed.toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _listenToSockets() {
    final socketService = ref.read(socketServiceProvider);
    
    socketService.onMessage.listen((msg) {
      if (isChannel && msg['channel_id'] == chatId) {
        state = state.whenData((msgs) => [msg, ...msgs]);
      }
    });

    socketService.onDirectMessage.listen((msg) {
      if (!isChannel) {
        final senderId = msg['sender_id'];
        final receiverId = msg['receiver_id'];
        if (senderId == chatId || receiverId == chatId) {
          state = state.whenData((msgs) => [msg, ...msgs]);
        }
      }
    });
  }

  void sendMessage(String content) {
    final socketService = ref.read(socketServiceProvider);
    if (isChannel) {
      socketService.sendMessage(channelId: chatId, content: content);
    } else {
      socketService.sendDirectMessage(receiverId: chatId, content: content);
    }
    
    // Optimistic update
    final me = ref.read(authProvider).user;
    final optimisticMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'content': content,
      'sender_id': me?['id'],
      'created_at': DateTime.now().toIso8601String(),
      'isMe': true,
    };
    state = state.whenData((msgs) => [optimisticMsg, ...msgs]);
  }
}

final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<dynamic>>, Map<String, dynamic>>(
  (ref, args) {
    return ChatMessagesNotifier(
      chatId: args['chatId'] as String,
      isChannel: args['isChannel'] as bool,
      ref: ref,
    );
  },
);
