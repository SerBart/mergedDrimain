class MessageContact {
  final int userId;
  final String username;
  final String? email;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  MessageContact({
    required this.userId,
    required this.username,
    this.email,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory MessageContact.fromJson(Map<String, dynamic> json) {
    return MessageContact(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      email: json['email']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessage: json['lastMessage']?.toString(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
    );
  }
}

