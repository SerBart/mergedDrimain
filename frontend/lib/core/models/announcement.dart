class AnnouncementAttachment {
  final int id;
  final String originalFilename;
  final String? contentType;
  final int fileSize;

  AnnouncementAttachment({
    required this.id,
    required this.originalFilename,
    this.contentType,
    required this.fileSize,
  });

  factory AnnouncementAttachment.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      originalFilename: (json['originalFilename'] ?? '').toString(),
      contentType: json['contentType']?.toString(),
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
    );
  }
}

class Announcement {
  final int id;
  final String title;
  final String content;
  final DateTime? createdAt;
  final String? createdByUsername;
  final bool active;
  final String targetType;
  final int? targetDzialId;
  final String? targetDzialNazwa;
  final List<int> targetUserIds;
  final List<AnnouncementAttachment> attachments;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.createdAt,
    this.createdByUsername,
    required this.active,
    this.targetType = 'ALL',
    this.targetDzialId,
    this.targetDzialNazwa,
    this.targetUserIds = const [],
    this.attachments = const [],
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      createdByUsername: json['createdByUsername']?.toString(),
      active: json['active'] == true,
      targetType: (json['targetType'] ?? 'ALL').toString(),
      targetDzialId: (json['targetDzialId'] as num?)?.toInt(),
      targetDzialNazwa: json['targetDzialNazwa']?.toString(),
      targetUserIds: (json['targetUserIds'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      attachments: (json['attachments'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(AnnouncementAttachment.fromJson)
              .toList() ??
          const [],
    );
  }
}

