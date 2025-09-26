class InstructionPartModel {
  final int partId;
  final String partNazwa;
  final int? ilosc;
  InstructionPartModel({required this.partId, required this.partNazwa, this.ilosc});
  factory InstructionPartModel.fromJson(Map<String, dynamic> j) => InstructionPartModel(
    partId: (j['partId'] as num).toInt(),
    partNazwa: (j['partNazwa'] ?? '').toString(),
    ilosc: (j['ilosc'] as num?)?.toInt(),
  );
}

class InstructionAttachmentModel {
  final int id;
  final String originalFilename;
  final String contentType;
  final int fileSize;
  InstructionAttachmentModel({required this.id, required this.originalFilename, required this.contentType, required this.fileSize});
  factory InstructionAttachmentModel.fromJson(Map<String, dynamic> j) => InstructionAttachmentModel(
    id: (j['id'] as num).toInt(),
    originalFilename: (j['originalFilename'] ?? '').toString(),
    contentType: (j['contentType'] ?? '').toString(),
    fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
  );
}

class InstructionModel {
  final int id;
  final String title;
  final String? description;
  final int? maszynaId;
  final String? maszynaNazwa;
  final String? createdBy;
  final DateTime? createdAt;
  final List<InstructionPartModel> parts;
  final List<InstructionAttachmentModel> attachments;
  InstructionModel({
    required this.id,
    required this.title,
    this.description,
    this.maszynaId,
    this.maszynaNazwa,
    this.createdBy,
    this.createdAt,
    this.parts = const [],
    this.attachments = const [],
  });
  factory InstructionModel.fromJson(Map<String, dynamic> j) => InstructionModel(
    id: (j['id'] as num).toInt(),
    title: (j['title'] ?? '').toString(),
    description: (j['description'] as String?),
    maszynaId: (j['maszynaId'] as num?)?.toInt(),
    maszynaNazwa: (j['maszynaNazwa'] as String?),
    createdBy: (j['createdBy'] as String?),
    createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
    parts: (j['parts'] as List?)?.cast<Map<String, dynamic>>().map(InstructionPartModel.fromJson).toList() ?? const [],
    attachments: (j['attachments'] as List?)?.cast<Map<String, dynamic>>().map(InstructionAttachmentModel.fromJson).toList() ?? const [],
  );
}

