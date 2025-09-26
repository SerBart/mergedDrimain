import 'package:dio/dio.dart';
import '../models/maszyna.dart';
import '../models/osoba.dart';
import '../services/secure_storage_service.dart';

class MetaApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  MetaApiRepository(this._dio, this._storage);

  Future<List<Maszyna>> fetchMaszynySimple() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/meta/maszyny-simple',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Maszyna.fromJson).toList();
  }

  Future<List<Osoba>> fetchOsobySimple() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/meta/osoby-simple',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Osoba.fromJson).toList();
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}

