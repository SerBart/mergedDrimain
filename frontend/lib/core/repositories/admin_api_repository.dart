import 'package:dio/dio.dart';
import '../models/dzial.dart';
import '../models/maszyna.dart';
import '../models/osoba.dart';
import '../services/secure_storage_service.dart';

class AdminApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;
  AdminApiRepository(this._dio, this._storage);

  Future<List<Dzial>> getDzialy() async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/admin/dzialy',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Dzial.fromJson).toList();
  }

  Future<Dzial> addDzial(String nazwa) async {
    final token = await _token();
    final resp = await _dio.post(
      '/api/admin/dzialy',
      data: {'nazwa': nazwa},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Dzial.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteDzial(int id) async {
    final token = await _token();
    await _dio.delete(
      '/api/admin/dzialy/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<List<Maszyna>> getMaszyny() async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/admin/maszyny',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Maszyna.fromJson).toList();
  }

  Future<Maszyna> addMaszyna(String nazwa, int dzialId) async {
    final token = await _token();
    final resp = await _dio.post(
      '/api/admin/maszyny',
      data: {'nazwa': nazwa, 'dzialId': dzialId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Maszyna.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteMaszyna(int id) async {
    final token = await _token();
    await _dio.delete(
      '/api/admin/maszyny/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<List<Osoba>> getOsoby() async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/admin/osoby',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Osoba.fromJson).toList();
  }

  Future<Osoba> addOsoba({
    required String login,
    required String haslo,
    String? imieNazwisko,
    String? rola,
  }) async {
    final token = await _token();
    final body = {
      'login': login,
      'haslo': haslo,
      if (imieNazwisko != null) 'imieNazwisko': imieNazwisko,
      if (rola != null) 'rola': rola,
    };
    final resp = await _dio.post(
      '/api/admin/osoby',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Osoba.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteOsoba(int id) async {
    final token = await _token();
    await _dio.delete(
      '/api/admin/osoby/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}

