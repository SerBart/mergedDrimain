import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import '../repositories/mock_repository.dart';
import '../models/user.dart';

// Klient HTTP z bazowym adresem konfigurowanym przez --dart-define=API_BASE lub domyślnie /api
final apiClientProvider = Provider((ref) => ApiClient());

// Bezpieczne przechowywanie tokenu (nieużywane w tym PR – trzymamy w pamięci)
final secureStorageProvider = Provider((ref) => SecureStorageService());

// Serwis logowania – realne wywołania backendu
final authServiceProvider = Provider((ref) => AuthService(ref.read(apiClientProvider)));

// Repozytorium mockowanych danych (dla innych ekranów)
final mockRepoProvider = Provider((ref) => MockRepository());

// Stan zalogowanego użytkownika
final authStateProvider = StateNotifierProvider<AuthController, User?>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<User?> {
  final Ref _ref;
  AuthController(this._ref) : super(null);

  Future<void> login(String username, String password) async {
    final authService = _ref.read(authServiceProvider);
    final user = await authService.login(username, password);
    state = user;
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    state = null;
  }
}