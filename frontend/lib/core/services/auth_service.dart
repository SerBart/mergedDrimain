import '../models/user.dart';

/// Na razie mock. Podmień na realne wywołanie API (POST /auth/login).
class AuthService {
  Future<User> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (username == 'admin' && password == 'admin') {
      return User(id: 1, username: 'admin', role: 'ADMIN', token: 'mock-token-admin');
    }
    if (username == 'user' && password == 'user') {
      return User(id: 2, username: 'user', role: 'USER', token: 'mock-token-user');
    }
    throw Exception('Nieprawidłowy login lub hasło');
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}