import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user.dart';
import 'secure_storage_service.dart';

/// Realna autoryzacja: POST /api/auth/login -> token, GET /api/auth/me -> role
class AuthService {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthService(this._dio, this._storage);

  Future<User> login(String username, String password, {bool rememberMe = false}) async {
    final resp = await _dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password, 'rememberMe': rememberMe},
    );

    final data = resp.data as Map<String, dynamic>;
    final token = (data['token'] ?? data['accessToken']) as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Brak access token w odpowiedzi logowania');
    }

    await _storage.saveToken(token);
    await _storage.saveRememberMe(rememberMe);
    // Na mobile przechowujemy refresh token lokalnie; na web polegamy na ciasteczku HttpOnly
    if (!kIsWeb && rememberMe && refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(refreshToken);
    }

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

  /// Próba odświeżenia access tokenu: używa lokalnego refreshToken (mobile)
  /// lub ciasteczka REFRESH_TOKEN (web/same-origin). Zwraca nowy token lub null.
  Future<String?> refresh() async {
    // Spróbuj z lokalnym refresh tokenem (mobile)
    final localRefresh = await _storage.readRefreshToken();
    try {
      Response resp;
      if (localRefresh != null && localRefresh.isNotEmpty) {
        resp = await _dio.post('/api/auth/refresh', data: {'refreshToken': localRefresh});
      } else {
        // Web/same-origin: ciasteczko HttpOnly powinno być automatycznie dołączone
        resp = await _dio.post('/api/auth/refresh');
      }
      final data = resp.data as Map<String, dynamic>;
      final token = (data['token'] ?? data['accessToken']) as String?;
      if (token != null && token.isNotEmpty) {
        await _storage.saveToken(token);
        return token;
      }
    } catch (_) {
      // Ignoruj – brak ważnego refresh tokenu
    }
    return null;
  }

  Future<Map<String, dynamic>?> me(String token) async {
    try {
      final meResp = await _dio.get(
        '/api/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (meResp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {}
    await _storage.clear();
  }
}