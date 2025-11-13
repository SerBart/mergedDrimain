import 'package:dio/dio.dart';
import '../models/dzial.dart';
import '../models/maszyna.dart';
import '../models/osoba.dart';
import '../models/admin_user.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_service.dart';

class AdminApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;
  final AuthService _auth;
  AdminApiRepository(this._dio, this._storage, this._auth);

  Future<List<String>> getModulesCatalog() async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/admin/modules',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (resp.data as List).map((e) => e.toString()).toList();
  }

  Future<List<AdminUser>> getUsers() async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/admin/users',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(AdminUser.fromJson).toList();
  }

  Future<AdminUser> createUser({
    required String username,
    required String password,
    required String email,
    int? dzialId,
    Set<String>? roles,
    Set<String>? modules,
  }) async {
    final token = await _token();
    final body = <String, dynamic>{
      'username': username,
      'password': password,
      'email': email,
      if (dzialId != null) 'dzialId': dzialId,
      if (roles != null) 'roles': roles.toList(),
      if (modules != null) 'modules': modules.toList(),
    };
    final resp = await _dio.post(
      '/api/admin/users',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AdminUser.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<AdminUser> updateUser({
    required int id,
    required String username,
    String? password,
    required String email,
    int? dzialId,
    Set<String>? roles,
    Set<String>? modules,
  }) async {
    final token = await _token();
    final body = <String, dynamic>{
      'username': username,
      if (password != null && password.isNotEmpty) 'password': password,
      'email': email,
      if (dzialId != null) 'dzialId': dzialId,
      if (roles != null) 'roles': roles.toList(),
      if (modules != null) 'modules': modules.toList(),
    };
    final resp = await _dio.put(
      '/api/admin/users/$id',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AdminUser.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteUser(int id) async {
    final token = await _token();
    await _dio.delete(
      '/api/admin/users/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

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
    required String imieNazwisko,
    int? dzialId,
    String? login,
    String? haslo,
    String? rola,
  }) async {
    final token = await _token();
    final body = <String, dynamic>{
      'imieNazwisko': imieNazwisko,
      if (dzialId != null) 'dzialId': dzialId,
      if (login != null && login.isNotEmpty) 'login': login,
      if (haslo != null && haslo.isNotEmpty) 'haslo': haslo,
      if (rola != null && rola.isNotEmpty) 'rola': rola,
    };
    final resp = await _dio.post(
      '/api/admin/osoby',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Osoba.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteOsoba(int id) async {
    String? token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      // Spróbuj odświeżyć token
      token = await _auth.refresh();
      if (token == null) throw Exception('Brak autoryzacji. Zaloguj się ponownie.');
    }
    try {
      await _dio.delete(
        '/api/admin/osoby/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final newToken = await _auth.refresh();
        if (newToken != null) {
          await _dio.delete(
            '/api/admin/osoby/$id',
            options: Options(headers: {'Authorization': 'Bearer $newToken'}),
          );
          return;
        }
      }
      rethrow;
    }
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}
