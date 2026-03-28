/// User model
class User {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? publicKey;
  final String status;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.publicKey,
    this.status = 'offline',
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      email: json['email'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      publicKey: json['public_key'] ?? json['publicKey'],
      status: json['status'] ?? 'offline',
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'email': email,
    'avatarUrl': avatarUrl,
    'publicKey': publicKey,
    'status': status,
  };

  bool get isOnline => status == 'online';
}

/// Channel model
class Channel {
  final String id;
  final String name;
  final String? description;
  final String type;
  final bool isPrivate;
  final String? avatarUrl;
  final int memberCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? role;

  Channel({
    required this.id,
    required this.name,
    this.description,
    this.type = 'group',
    this.isPrivate = false,
    this.avatarUrl,
    this.memberCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.role,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'group',
      isPrivate: json['is_private'] ?? false,
      avatarUrl: json['avatar_url'],
      memberCount: json['member_count'] ?? 0,
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      role: json['role'],
    );
  }
}

/// Message model
class Message {
  final String id;
  final String? channelId;
  final String senderId;
  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final String? content;
  final String? encryptedContent;
  final String messageType;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    this.channelId,
    required this.senderId,
    this.senderUsername,
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.content,
    this.encryptedContent,
    this.messageType = 'text',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.isEdited = false,
    this.isDeleted = false,
    this.isRead = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      channelId: json['channel_id'],
      senderId: json['sender_id'] ?? json['sender']?['id'] ?? '',
      senderUsername: json['username'] ?? json['sender']?['username'],
      senderDisplayName: json['display_name'] ?? json['sender']?['displayName'],
      senderAvatarUrl: json['avatar_url'] ?? json['sender']?['avatarUrl'],
      content: json['content'],
      encryptedContent: json['encrypted_content'],
      messageType: json['message_type'] ?? 'text',
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      fileType: json['file_type'],
      isEdited: json['is_edited'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  bool get isFile => messageType == 'file';
  bool get isImage => messageType == 'image';
}

/// Meeting model
class Meeting {
  final String id;
  final String title;
  final String roomId;
  final String hostId;
  final int participantCount;
  final List<MeetingParticipant> participants;
  final String status;
  final DateTime createdAt;

  Meeting({
    required this.id,
    required this.title,
    required this.roomId,
    required this.hostId,
    this.participantCount = 0,
    this.participants = const [],
    this.status = 'active',
    required this.createdAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Meeting',
      roomId: json['roomId'] ?? json['room_id'] ?? '',
      hostId: json['host'] ?? json['host_id'] ?? '',
      participantCount: json['participantCount'] ?? 0,
      participants: (json['participants'] as List?)
          ?.map((p) => MeetingParticipant.fromJson(p))
          .toList() ?? [],
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class MeetingParticipant {
  final String userId;
  final String username;
  final bool audio;
  final bool video;

  MeetingParticipant({
    required this.userId,
    required this.username,
    this.audio = true,
    this.video = true,
  });

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) {
    return MeetingParticipant(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      audio: json['audio'] ?? true,
      video: json['video'] ?? true,
    );
  }
}
