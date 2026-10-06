import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../models/harmonogram.dart';
import '../services/secure_storage_service.dart';

class HarmonogramyApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  HarmonogramyApiRepository(this._dio, this._storage);

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
      return list.map(Harmonogram.fromJson).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Sesja wygasła');
      }
      rethrow;
    }
  }

  Future<List<String>> uploadZalaczniki(int id, List<PlatformFile> files) async {
    try {
      final token = await _readToken();
      final formData = FormData();
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final name = file.name.trim().isEmpty ? 'zalacznik' : file.name.trim();
        formData.files.add(MapEntry(
          'zalaczniki',
          MultipartFile.fromBytes(bytes, filename: name),
        ));
      }
      if (formData.files.isEmpty) {
        return const [];
      }

      final resp = await _dio.post(
        '/api/harmonogramy/$id/zalaczniki',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List raw = resp.data as List;
      return raw.map((item) => item.toString()).toList();
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
      return Harmonogram.fromJson((resp.data as Map).cast<String, dynamic>());
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
      return Harmonogram.fromJson((resp.data as Map).cast<String, dynamic>());
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

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}
