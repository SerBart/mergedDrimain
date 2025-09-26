import 'package:dio/dio.dart';
import '../models/harmonogram.dart';
import '../services/secure_storage_service.dart';

class HarmonogramyApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  HarmonogramyApiRepository(this._dio, this._storage);

  Future<List<Harmonogram>> fetchAll({int? year, int? month}) async {
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
  }

  Future<Harmonogram> create({
    required DateTime data,
    int? maszynaId,
    int? osobaId,
    int? dzialId,
    String? frequency,
    String? opis,
    int? durationMinutes,
  }) async {
    final token = await _readToken();
    final dto = {
      'data': _formatDateOnly(data),
      if (maszynaId != null) 'maszynaId': maszynaId,
      if (osobaId != null) 'osobaId': osobaId,
      if (dzialId != null) 'dzialId': dzialId,
      if (frequency != null) 'frequency': frequency,
      if (opis != null) 'opis': opis,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
    };
    final resp = await _dio.post(
      '/api/harmonogramy',
      data: dto,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Harmonogram.fromJson((resp.data as Map).cast<String, dynamic>());
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
  }) async {
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

    final resp = await _dio.put(
      '/api/harmonogramy/$id',
      data: dto,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Harmonogram.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) async {
    final token = await _readToken();
    await _dio.delete(
      '/api/harmonogramy/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
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
