import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onDirectMessage => _dmController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void initialize({required String serverUrl, required String token}) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    _socket = io.io(serverUrl, 
      io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .build()
    );

    _socket!.onConnect((_) => print('Connected to socket'));
    _socket!.onDisconnect((_) => print('Disconnected from socket'));
    
    _socket!.on('message:new', (data) => _messageController.add(Map<String, dynamic>.from(data)));
    _socket!.on('dm:new', (data) => _dmController.add(Map<String, dynamic>.from(data)));
    _socket!.on('presence:update', (data) => _presenceController.add(Map<String, dynamic>.from(data)));
  }

  void sendMessage({
    required String channelId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? fileInfo,
    String? clientId,
  }) {
    _socket?.emit('message:send', {
      'channelId': channelId,
      'content': content,
      'messageType': type,
      'fileInfo': fileInfo,
      'clientId': clientId,
    });
  }

  void sendDirectMessage({
    required String receiverId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? fileInfo,
    String? clientId,
  }) {
    _socket?.emit('dm:send', {
      'receiverId': receiverId,
      'content': content,
      'messageType': type,
      'fileInfo': fileInfo,
      'clientId': clientId,
    });
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void dispose() {
    _socket?.dispose();
    _messageController.close();
    _dmController.close();
    _presenceController.close();
  }
}
