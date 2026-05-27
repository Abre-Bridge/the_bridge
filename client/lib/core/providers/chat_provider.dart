import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../models/models.dart';

final onlineUsersProvider = FutureProvider<List<dynamic>>((ref) async => ref.read(apiServiceProvider).getOnlineUsers());
final conversationsProvider = FutureProvider<List<dynamic>>((ref) async => ref.read(apiServiceProvider).getConversations());
final channelsProvider = FutureProvider<List<dynamic>>((ref) async => ref.read(apiServiceProvider).getChannels());

final chatMessagesProvider = StateNotifierProvider.family<ChatNotifier, List<Message>, Map<String, dynamic>>((ref, args) {
  return ChatNotifier(ref, args['chatId'], args['isChannel']);
});

class ChatNotifier extends StateNotifier<List<Message>> {
  final Ref _ref;
  final String _chatId;
  final bool _isChannel;
  StreamSubscription? _sub;

  ChatNotifier(this._ref, this._chatId, this._isChannel) : super([]) {
    _loadHistory();
    _listen();
  }

  Future<void> _loadHistory() async {
    final api = _ref.read(apiServiceProvider);
    final List<dynamic> data = _isChannel 
      ? await api.getChannelMessages(_chatId)
      : await api.getDirectMessages(_chatId);
    state = data.map((m) => Message.fromJson(m)).toList();
  }

  void _listen() {
    final socket = _ref.read(socketServiceProvider);
    _sub = (_isChannel ? socket.onMessage : socket.onDirectMessage).listen((data) {
      final isMatch = _isChannel 
        ? data['channel_id'] == _chatId
        : (data['sender_id'] == _chatId || data['receiver_id'] == _chatId);
      
      if (isMatch) {
        final newMsg = Message.fromJson(data);
        // Remove optimistic message if it exists
        if (newMsg.clientId != null) {
          state = state.where((m) => m.clientId != newMsg.clientId).toList();
        }
        state = [...state, newMsg];
      }
    });
  }

  void sendMessage(String content, {String type = 'text', Map<String, dynamic>? fileInfo}) {
    final socket = _ref.read(socketServiceProvider);
    final clientId = 'c_${DateTime.now().microsecondsSinceEpoch}';

    if (_isChannel) {
      socket.sendMessage(channelId: _chatId, content: content, type: type, fileInfo: fileInfo, clientId: clientId);
    } else {
      socket.sendDirectMessage(receiverId: _chatId, content: content, type: type, fileInfo: fileInfo, clientId: clientId);
    }
    
    final me = _ref.read(authProvider).user;
    final optimisticMsg = Message(
      id: 'opt_$clientId',
      senderId: me?['id'] ?? '',
      content: content,
      messageType: type,
      createdAt: DateTime.now(),
      sender: me,
      clientId: clientId,
    );
    state = [...state, optimisticMsg];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
