import 'package:dio/dio.dart';
import '../models/user.dart';
import 'secure_storage_service.dart';

/// Realna autoryzacja: POST /api/auth/login -> token, GET /api/auth/me -> role
class AuthService {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthService(this._dio, this._storage);

  Future<User> login(String username, String password) async {
    final resp = await _dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );

    final data = resp.data as Map<String, dynamic>;
    final token = (data['token'] ?? data['accessToken']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Brak access token w odpowiedzi logowania');
    }

    await _storage.saveToken(token);

    final meResp = await _dio.get(
      '/api/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final me = meResp.data as Map<String, dynamic>;
    final roles = (me['roles'] as List<dynamic>? ?? const []).cast<String>();
    final role = roles.contains('ROLE_ADMIN') ? 'ADMIN' : 'USER';

    return User(
      id: 0,
      username: (me['username'] as String?) ?? username,
      role: role,
      token: token,
    );
  }

  Future<void> logout() async {
    await _storage.clear();
  }
}