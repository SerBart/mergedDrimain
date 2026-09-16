import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../models/announcement.dart';
import '../services/secure_storage_service.dart';

class AnnouncementsApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  AnnouncementsApiRepository(this._dio, this._storage);

  Future<List<Announcement>> fetchAll() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/announcements',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(Announcement.fromJson).toList();
  }

  Future<Announcement> create({
    required String title,
    required String content,
    required String targetType,
    int? targetDzialId,
    List<int> targetUserIds = const [],
  }) async {
    final token = await _readToken();
    final resp = await _dio.post(
      '/api/announcements',
      data: {
        'title': title,
        'content': content,
        'targetType': targetType,
        if (targetDzialId != null) 'targetDzialId': targetDzialId,
        if (targetUserIds.isNotEmpty) 'targetUserIds': targetUserIds,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Announcement.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> uploadAttachments({required int announcementId, required List<PlatformFile> files}) async {
    if (files.isEmpty) return;
    final token = await _readToken();

    final multipart = <MultipartFile>[];
    for (final f in files) {
      if (f.bytes != null) {
        multipart.add(MultipartFile.fromBytes(f.bytes!, filename: f.name));
      } else if (f.path != null && f.path!.isNotEmpty) {
        multipart.add(await MultipartFile.fromFile(f.path!, filename: f.name));
      }
    }
    if (multipart.isEmpty) return;

    final form = FormData.fromMap({'files': multipart});
    await _dio.post(
      '/api/announcements/$announcementId/attachments',
      data: form,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/form-data',
      }),
    );
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu - zaloguj się ponownie.');
    }
    return token;
  }
}

