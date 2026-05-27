class User {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String status;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.status = 'offline',
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? '',
    username: json['username'] ?? '',
    displayName: json['display_name'] ?? json['displayName'] ?? '',
    email: json['email'],
    avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
    status: json['status'] ?? 'offline',
  );
}

class Message {
  final String id;
  final String? channelId;
  final String senderId;
  final String content;
  final String messageType;
  final String? fileUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? sender;
  final String? clientId;

  Message({
    required this.id,
    this.channelId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.fileUrl,
    required this.createdAt,
    this.sender,
    this.clientId,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] ?? '',
    channelId: json['channel_id'],
    senderId: json['sender_id'] ?? '',
    content: json['content'] ?? '',
    messageType: json['message_type'] ?? 'text',
    fileUrl: json['file_url'],
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    sender: json['sender'],
    clientId: json['client_id'],
  );
}
