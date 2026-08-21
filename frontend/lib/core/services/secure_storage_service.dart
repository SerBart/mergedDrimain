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
  Future<bool> readRememberMe() async {
    final value = await _storage.read(key: _rememberKey);
    if (value == null) return true;
    return value == '1';
  }

  Future<void> writeString(String key, String value) => _storage.write(key: key, value: value);
  Future<String?> readString(String key) => _storage.read(key: key);
  Future<void> deleteByKey(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();
}