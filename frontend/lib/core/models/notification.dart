class NotificationModel {
  final int id;
  final String? module;
  final String? type;
  final String? title;
  final String? message;
  final String? link;
  final DateTime? createdAt;
  final bool read;

  NotificationModel({
    required this.id,
    this.module,
    this.type,
    this.title,
    this.message,
    this.link,
    this.createdAt,
    this.read = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final ca = json['createdAt'] ?? json['created_at'];
    if (ca is String && ca.isNotEmpty) {
      try {
        created = DateTime.parse(ca);
      } catch (_) {
        created = null;
      }
    }
    return NotificationModel(
      id: (json['id'] is int) ? json['id'] as int : ((json['id'] as num?)?.toInt() ?? 0),
      module: json['module']?.toString(),
      type: json['type']?.toString(),
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      link: json['link']?.toString(),
      createdAt: created,
      read: (json['read'] is bool) ? json['read'] as bool : (json['is_read'] is bool ? json['is_read'] as bool : false),
    );
  }
}

