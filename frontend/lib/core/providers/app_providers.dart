import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import '../repositories/mock_repository.dart';
import '../models/user.dart';

// Klient HTTP (później do realnego API)
final apiClientProvider = Provider((ref) => ApiClient());

// Bezpieczne przechowywanie tokenu
final secureStorageProvider = Provider((ref) => SecureStorageService());

// Serwis logowania (na razie mock)
final authServiceProvider = Provider((ref) => AuthService());

// Repozytorium mockowanych danych
final mockRepoProvider = Provider((ref) => MockRepository());

// Stan zalogowanego użytkownika
final authStateProvider = StateNotifierProvider<AuthController, User?>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<User?> {
  final Ref _ref; // Ref = dostęp do innych providerów
  AuthController(this._ref) : super(null);

  Future<void> login(String username, String password) async {
    final user = await _ref.read(authServiceProvider).login(username, password);
    state = user;
    if (user.token != null) {
      await _ref.read(secureStorageProvider).saveToken(user.token!);
    }
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    await _ref.read(secureStorageProvider).clear();
    state = null;
  }

  bool get isAdmin => state?.role == 'ADMIN';
  bool get isLoggedIn => state != null;
}