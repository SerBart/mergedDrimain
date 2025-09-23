import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthState {
  final bool isAuthenticated;
  final String? username;
  final List<String> roles;
  const AuthState({required this.isAuthenticated, this.username, this.roles = const []});

  AuthState copyWith({bool? isAuthenticated, String? username, List<String>? roles}) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        username: username ?? this.username,
        roles: roles ?? this.roles,
      );

  bool hasAnyRole(List<String> r) =>
      roles.any((x) => r.contains(x));
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isAuthenticated: false));

  final TokenStorage _storage = TokenStorageImpl();
  late ApiClient _client;
  String _baseUrl = '';
  String? _access;

  void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
    _client = ApiClient(
      baseUrl: baseUrl,
      tokenProvider: () async => _access ?? await _storage.readAccess(),
      tokenRefresher: _refreshToken,
    );
  }

  ApiClient get client => _client;

  Future<bool> login(String username, String password) async {
    final res = await _client.dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });
    final token = res.data['token'] as String?;
    final refresh = res.data['refreshToken'] as String?;
    if (token == null) return false;
    _access = token;
    await _storage.saveTokens(access: token, refresh: refresh);
    await loadMe();
    return true;
  }

  Future<void> loadMe() async {
    try {
      final me = await _client.dio.get('/api/auth/me');
      final name = me.data['username']?.toString() ?? me.data['login']?.toString();
      final rolesDyn = me.data['roles'] ?? me.data['authorities'];
      final roles = (rolesDyn is List)
          ? rolesDyn.map((e) => e.toString()).toList()
          : <String>[];
      state = AuthState(isAuthenticated: true, username: name, roles: roles);
    } catch (_) {
      state = const AuthState(isAuthenticated: false);
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.readRefresh();
      if (refresh == null) return false;
      final res = await _client.dio.post('/api/auth/refresh', data: {
        'refreshToken': refresh,
      });
      final token = res.data['token'] as String?;
      if (token == null) return false;
      _access = token;
      await _storage.saveTokens(access: token);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    _access = null;
    await _storage.clear();
    state = const AuthState(isAuthenticated: false);
  }
}

final authServiceProvider = Provider<AuthNotifier>((ref) => AuthNotifier());
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return ref.read(authServiceProvider);
});