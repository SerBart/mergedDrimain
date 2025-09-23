import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:html' as html;

abstract class TokenStorage {
  Future<void> saveTokens({required String access, String? refresh});
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> clear();
}

class TokenStorageImpl implements TokenStorage {
  final _secure = const FlutterSecureStorage();
  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';

  @override
  Future<void> saveTokens({required String access, String? refresh}) async {
    if (kIsWeb) {
      html.window.localStorage[_kAccess] = access;
      if (refresh != null) {
        html.window.localStorage[_kRefresh] = refresh;
      }
    } else {
      await _secure.write(key: _kAccess, value: access);
      if (refresh != null) {
        await _secure.write(key: _kRefresh, value: refresh);
      }
    }
  }

  @override
  Future<String?> readAccess() async {
    if (kIsWeb) return html.window.localStorage[_kAccess];
    return _secure.read(key: _kAccess);
  }

  @override
  Future<String?> readRefresh() async {
    if (kIsWeb) return html.window.localStorage[_kRefresh];
    return _secure.read(key: _kRefresh);
  }

  @override
  Future<void> clear() async {
    if (kIsWeb) {
      html.window.localStorage.remove(_kAccess);
      html.window.localStorage.remove(_kRefresh);
    } else {
      await _secure.delete(key: _kAccess);
      await _secure.delete(key: _kRefresh);
    }
  }
}