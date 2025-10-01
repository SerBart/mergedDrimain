import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _rememberKey = 'remember_me';

  final _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveRefreshToken(String token) => _storage.write(key: _refreshKey, value: token);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
  Future<void> clearRefreshToken() => _storage.delete(key: _refreshKey);

  Future<void> saveRememberMe(bool value) => _storage.write(key: _rememberKey, value: value ? '1' : '0');
  Future<bool> readRememberMe() async => (await _storage.read(key: _rememberKey)) == '1';

  Future<void> clear() => _storage.deleteAll();
}