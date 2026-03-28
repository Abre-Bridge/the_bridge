import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// WebSocket service for real-time messaging
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _messagingSocket;
  io.Socket? _signalingSocket;
  io.Socket? _fileSocket;

  String _serverUrl = 'http://192.168.204.92:3000';
  String? _token;

  // Stream controllers for events
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onDirectMessage => _dmController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  bool get isConnected => _messagingSocket?.connected ?? false;

  void initialize({required String serverUrl, required String token}) {
    _serverUrl = serverUrl;
    _token = token;
    _connectMessaging();
  }

  void _connectMessaging() {
    _messagingSocket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/ws/messaging')
          .setAuth({'token': _token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _messagingSocket!.onConnect((_) {
      _connectionController.add(true);
    });

    _messagingSocket!.onDisconnect((_) {
      _connectionController.add(false);
    });

    _messagingSocket!.onReconnect((_) {
      _connectionController.add(true);
    });

    // Message events
    _messagingSocket!.on('message:new', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _messagingSocket!.on('dm:new', (data) {
      _dmController.add(Map<String, dynamic>.from(data));
    });

    _messagingSocket!.on('message:edited', (data) {
      _messageController.add({
        'type': 'edit',
        ...Map<String, dynamic>.from(data),
      });
    });

    _messagingSocket!.on('message:deleted', (data) {
      _messageController.add({
        'type': 'delete',
        ...Map<String, dynamic>.from(data),
      });
    });

    _messagingSocket!.on('message:read', (data) {
      _dmController.add({'type': 'read', ...Map<String, dynamic>.from(data)});
    });

    // Presence events
    _messagingSocket!.on('presence:update', (data) {
      _presenceController.add(Map<String, dynamic>.from(data));
    });

    // Typing events
    _messagingSocket!.on('typing:start', (data) {
      _typingController.add({
        'typing': true,
        ...Map<String, dynamic>.from(data),
      });
    });

    _messagingSocket!.on('typing:stop', (data) {
      _typingController.add({
        'typing': false,
        ...Map<String, dynamic>.from(data),
      });
    });

    // Channel events
    _messagingSocket!.on('channel:user_joined', (data) {
      _messageController.add({
        'type': 'user_joined',
        ...Map<String, dynamic>.from(data),
      });
    });

    _messagingSocket!.on('channel:user_left', (data) {
      _messageController.add({
        'type': 'user_left',
        ...Map<String, dynamic>.from(data),
      });
    });
  }

  // ========== MESSAGING ACTIONS ==========

  void sendMessage({
    required String channelId,
    required String content,
    String? encryptedContent,
    String messageType = 'text',
    String? replyTo,
    Map<String, dynamic>? fileInfo,
  }) {
    _messagingSocket?.emitWithAck('message:send', {
      'channelId': channelId,
      'content': content,
      'encryptedContent': encryptedContent,
      'messageType': messageType,
      'replyTo': replyTo,
      'fileInfo': fileInfo,
    });
  }

  void sendDirectMessage({
    required String receiverId,
    required String content,
    String? encryptedContent,
    String messageType = 'text',
    Map<String, dynamic>? fileInfo,
  }) {
    _messagingSocket?.emitWithAck('dm:send', {
      'receiverId': receiverId,
      'content': content,
      'encryptedContent': encryptedContent,
      'messageType': messageType,
      'fileInfo': fileInfo,
    });
  }

  void startTyping({String? channelId, String? receiverId}) {
    _messagingSocket?.emit('typing:start', {
      'channelId': ?channelId,
      'receiverId': ?receiverId,
    });
  }

  void stopTyping({String? channelId, String? receiverId}) {
    _messagingSocket?.emit('typing:stop', {
      'channelId': channelId,
      'receiverId': receiverId,
    });
  }

  void markAsRead(String messageId, String senderId) {
    _messagingSocket?.emit('message:read', {
      'messageId': messageId,
      'senderId': senderId,
    });
  }

  void joinChannel(String channelId) {
    _messagingSocket?.emit('channel:join', {'channelId': channelId});
  }

  void leaveChannel(String channelId) {
    _messagingSocket?.emit('channel:leave', {'channelId': channelId});
  }

  // ========== SIGNALING ACTIONS ==========

  io.Socket? get signalingSocket => _signalingSocket;

  void connectSignaling() {
    _signalingSocket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/ws/signaling')
          .setAuth({'token': _token})
          .enableAutoConnect()
          .build(),
    );
  }

  void disconnectSignaling() {
    _signalingSocket?.disconnect();
    _signalingSocket = null;
  }

  // ========== FILE TRANSFER ==========

  io.Socket? get fileSocket => _fileSocket;

  void connectFileTransfer() {
    _fileSocket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/ws/files')
          .setAuth({'token': _token})
          .enableAutoConnect()
          .build(),
    );
  }

  void disconnectFileTransfer() {
    _fileSocket?.disconnect();
    _fileSocket = null;
  }

  void requestFileTransfer({
    required String receiverId,
    required String fileName,
    required int fileSize,
    required String fileType,
    required String fileHash,
    required Function(Map<String, dynamic>) onResponse,
  }) {
    _fileSocket?.emitWithAck('file:request', {
      'receiverId': receiverId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileType': fileType,
      'fileHash': fileHash,
    }, ack: (data) => onResponse(Map<String, dynamic>.from(data)));
  }

  void sendFileChunk({
    required String transferId,
    required int chunkIndex,
    required List<int> chunkData,
    required bool isLast,
  }) {
    _fileSocket?.emit('file:chunk', {
      'transferId': transferId,
      'chunkIndex': chunkIndex,
      'chunkData': chunkData,
      'isLast': isLast,
    });
  }

  void acceptFileTransfer(String transferId) {
    _fileSocket?.emit('file:accept', {'transferId': transferId});
  }

  void rejectFileTransfer(String transferId) {
    _fileSocket?.emit('file:reject', {'transferId': transferId});
  }

  // ========== LIFECYCLE ==========

  void disconnect() {
    _messagingSocket?.disconnect();
    _signalingSocket?.disconnect();
    _fileSocket?.disconnect();
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _dmController.close();
    _presenceController.close();
    _typingController.close();
    _connectionController.close();
  }
}
