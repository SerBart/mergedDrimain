import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/harmonogram.dart';
import '../services/secure_storage_service.dart';

class HarmonogramyApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;
  late final String _baseUrl;
  late final String _apiRoot;

  HarmonogramyApiRepository(this._dio, this._storage) {
    _baseUrl = _trimTrailingSlashes(_dio.options.baseUrl);
    _apiRoot = _normalizeApiRoot(_baseUrl);
  }

  Future<List<Harmonogram>> fetchAll({int? year, int? month}) async {
    try {
      final token = await _readToken();
      final resp = await _dio.get(
        '/api/harmonogramy',
        queryParameters: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = (resp.data as List).cast<Map<String, dynamic>>();
      return list.map(_fromDto).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  Future<List<String>> uploadZalaczniki(int id, List<PlatformFile> files) async {
    final payload = <_UploadPayload>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.trim().isEmpty ? 'zalacznik' : file.name.trim();
      payload.add(_UploadPayload(name, bytes));
    }
    if (payload.isEmpty) {
      return const [];
    }
    return _uploadFiles(id, payload);
  }

  Future<List<String>> uploadZdjecia(int id, List<XFile> files) async {
    final payload = <_UploadPayload>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      payload.add(_UploadPayload(file.name, bytes));
    }
    if (payload.isEmpty) {
      return const [];
    }
    return _uploadFiles(id, payload);
  }

  Future<List<String>> uploadPdfFiles(int id, List<PlatformFile> files) async {
    final payload = <_UploadPayload>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.trim().isEmpty ? 'dokument.pdf' : file.name.trim();
      payload.add(_UploadPayload(name, bytes));
    }
    if (payload.isEmpty) {
      return const [];
    }
    return _uploadFiles(id, payload);
  }

  Future<void> deleteZalacznik(int id, String attachmentUrl) async {
    try {
      final token = await _readToken();
      final normalized = attachmentUrl.replaceAll('\\', '/');
      final uri = Uri.tryParse(normalized);
      final lastSegment = (uri != null && uri.pathSegments.isNotEmpty)
          ? uri.pathSegments.last
          : normalized.split('/').last;
      final filename = Uri.decodeComponent(lastSegment);

      await _dio.delete(
        '/api/harmonogramy/$id/zalaczniki/$filename',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  Future<Harmonogram> create({
    required DateTime data,
    int? maszynaId,
    int? osobaId,
    int? dzialId,
    String? frequency,
    DateTime? planEndDate,
    String? opis,
    int? durationMinutes,
  }) async {
    try {
      final token = await _readToken();
      final dto = {
        'data': _formatDateOnly(data),
        if (maszynaId != null) 'maszynaId': maszynaId,
        if (osobaId != null) 'osobaId': osobaId,
        if (dzialId != null) 'dzialId': dzialId,
        if (frequency != null) 'frequency': frequency,
        if (planEndDate != null) 'planEndDate': _formatDateOnly(planEndDate),
        if (opis != null) 'opis': opis,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
      };
      final resp = await _dio.post(
        '/api/harmonogramy',
        data: dto,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return _fromDto((resp.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  Future<Harmonogram> update({
    required int id,
    DateTime? data,
    int? maszynaId,
    int? osobaId,
    int? dzialId,
    String? opis,
    int? durationMinutes,
    String? status,
    String? frequency,
    DateTime? planEndDate,
    bool? applyToSeriesFuture,
  }) async {
    try {
      final token = await _readToken();
      final Map<String, dynamic> dto = {};
      if (data != null) dto['data'] = _formatDateOnly(data);
      if (maszynaId != null) dto['maszynaId'] = maszynaId;
      if (osobaId != null) dto['osobaId'] = osobaId;
      if (dzialId != null) dto['dzialId'] = dzialId;
      if (opis != null) dto['opis'] = opis;
      if (durationMinutes != null) dto['durationMinutes'] = durationMinutes;
      if (status != null) dto['status'] = status;
      if (frequency != null) dto['frequency'] = frequency;
      if (planEndDate != null) dto['planEndDate'] = _formatDateOnly(planEndDate);
      if (applyToSeriesFuture != null) dto['applyToSeriesFuture'] = applyToSeriesFuture;

      final resp = await _dio.put(
        '/api/harmonogramy/$id',
        data: dto,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return _fromDto((resp.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    try {
      final token = await _readToken();
      await _dio.delete(
        '/api/harmonogramy/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> complete(int id) async {
    try {
      final token = await _readToken();
      final resp = await _dio.post(
        '/api/harmonogramy/$id/complete',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (resp.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła - zaloguj się ponownie');
      }
      throw Exception('Błąd serwera: ${e.message}');
    }
  }

  String _formatDateOnly(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Harmonogram _fromDto(Map<String, dynamic> json) {
    final id = _toInt(json['id']) ?? 0;
    final normalized = Map<String, dynamic>.from(json);
    normalized['zalaczniki'] = _normalizeAttachmentUrls(id, json['zalaczniki']);
    return Harmonogram.fromJson(normalized);
  }

  Future<List<String>> _uploadFiles(int id, List<_UploadPayload> files) async {
    try {
      final token = await _readToken();
      final formData = FormData();
      for (final file in files) {
        formData.files.add(MapEntry(
          'zalaczniki',
          MultipartFile.fromBytes(file.bytes, filename: file.name),
        ));
      }

      final resp = await _dio.post(
        '/api/harmonogramy/$id/zalaczniki',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List raw = resp.data as List;
      return _normalizeAttachmentUrls(id, raw);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  List<String> _normalizeAttachmentUrls(int harmonogramId, dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => _toAttachmentUrl(harmonogramId, item?.toString() ?? ''))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _toAttachmentUrl(int harmonogramId, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/api/')) {
      return '$_apiRoot$value';
    }
    final normalized = value.replaceAll('\\', '/');
    final filename = normalized.split('/').last;
    final encoded = Uri.encodeComponent(filename);
    return '$_apiRoot/api/harmonogramy/$harmonogramId/zalaczniki/$encoded';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _normalizeApiRoot(String rawBaseUrl) {
    final base = _trimTrailingSlashes(rawBaseUrl);
    final uri = Uri.tryParse(base);
    if (uri == null) return base;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      final trimmed = segments.sublist(0, segments.length - 1);
      final path = trimmed.isEmpty ? '' : '/${trimmed.join('/')}';
      return _trimTrailingSlashes(uri.replace(path: path).toString());
    }
    return base;
  }

  String _trimTrailingSlashes(String input) =>
      input.replaceFirst(RegExp(r'/+$'), '');

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}

class _UploadPayload {
  final String name;
  final List<int> bytes;

  _UploadPayload(this.name, this.bytes);
}

