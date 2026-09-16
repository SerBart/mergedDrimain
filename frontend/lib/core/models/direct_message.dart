class DirectMessage {
  final int id;
  final int senderId;
  final String senderUsername;
  final int recipientId;
  final String recipientUsername;
  final String content;
  final DateTime? createdAt;
  final bool read;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.recipientId,
    required this.recipientUsername,
    required this.content,
    this.createdAt,
    required this.read,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      senderUsername: (json['senderUsername'] ?? '').toString(),
      recipientId: (json['recipientId'] as num?)?.toInt() ?? 0,
      recipientUsername: (json['recipientUsername'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      read: json['read'] == true,
    );
  }
}

