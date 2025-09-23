import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_service.dart';
import '../repositories/zgloszenia_api_repository.dart';
import '../repositories/mock_repository.dart';
import '../models/user.dart';

// Globalny klient HTTP (adres z --dart-define=API_BASE)
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Bezpieczny storage na token
final secureStorageProvider =
Provider<SecureStorageService>((ref) => SecureStorageService());

// Realny serwis autoryzacji (HTTP)
final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthService(api.dio, storage);
});

// Mock repo (lokalny cache dla UI)
final mockRepoProvider = Provider<MockRepository>((ref) => MockRepository());

// Repozytorium API dla zgłoszeń
final zgloszeniaApiRepositoryProvider =
Provider<ZgloszeniaApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return ZgloszeniaApiRepository(api.dio, storage);
});

// Stan/logika autoryzacji w aplikacji
final authStateProvider = StateNotifierProvider<AuthController, User?>(
      (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<User?> {
  final Ref _ref;
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