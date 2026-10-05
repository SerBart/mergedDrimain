import 'secure_storage_service_io.dart' if (dart.library.html) 'secure_storage_service_web.dart' as impl;

class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _rememberKey = 'remember_me';

  Future<void> saveToken(String token) => impl.writeString(_tokenKey, token);
  Future<String?> readToken() => impl.readString(_tokenKey);

  Future<void> saveRefreshToken(String token) => impl.writeString(_refreshKey, token);
  Future<String?> readRefreshToken() => impl.readString(_refreshKey);
  Future<void> clearRefreshToken() => impl.deleteByKey(_refreshKey);

  Future<void> saveRememberMe(bool value) => impl.writeString(_rememberKey, value ? '1' : '0');
  Future<bool> readRememberMe() async {
    final value = await impl.readString(_rememberKey);
    if (value == null) return true;
    return value == '1';
  }

  Future<void> writeString(String key, String value) => impl.writeString(key, value);
  Future<String?> readString(String key) => impl.readString(key);
  Future<void> deleteByKey(String key) => impl.deleteByKey(key);

  Future<void> clear() => impl.clear();
}