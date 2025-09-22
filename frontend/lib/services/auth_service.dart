import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<User> login(String username, String password) async {
    try {
      final res = await _api.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      final data = res.data as Map<String, dynamic>;
      // Backend zwraca "accessToken" lub dla kompatybilności "token"
      final token = (data['accessToken'] ?? data['token'])?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Brak tokenu w odpowiedzi logowania.');
      }

      // Ustaw token dla kolejnych wywołań
      _api.setAuthToken(token);

      // Pobierz informacje o użytkowniku i rolach
      final meRes = await _api.dio.get('/auth/me');
      final me = meRes.data as Map<String, dynamic>;
      final roles = (me['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final isAdmin = roles.contains('ROLE_ADMIN');
      final role = isAdmin ? 'ADMIN' : 'USER';

      return User(
        id: 0, // /auth/me nie zwraca ID numerycznego – zostawiamy placeholder
        username: (me['username'] ?? username).toString(),
        role: role,
        token: token,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? 'Błąd logowania';
      throw Exception(msg);
    }
  }

  Future<void> logout() async {
    // Czyścimy Authorization (w tym PR tylko pamięć, bez persystencji)
    _api.setAuthToken(null);
  }
}