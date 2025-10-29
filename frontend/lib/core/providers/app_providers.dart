import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_service.dart';
import '../repositories/zgloszenia_api_repository.dart';
import '../repositories/mock_repository.dart';
import '../models/user.dart';
import '../repositories/harmonogramy_api_repository.dart';
import '../repositories/meta_api_repository.dart';
import '../repositories/admin_api_repository.dart';
import '../repositories/instructions_api_repository.dart';
import '../repositories/parts_api_repository.dart';
import '../repositories/raporty_api_repository.dart';

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

// Repozytorium API dla harmonogramów
final harmonogramyApiRepositoryProvider =
Provider<HarmonogramyApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return HarmonogramyApiRepository(api.dio, storage);
});

// Repozytorium meta (maszyny, osoby)
final metaApiRepositoryProvider = Provider<MetaApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return MetaApiRepository(api.dio, storage);
});

// Repozytorium admin (działy, maszyny, osoby, użytkownicy, modules)
final adminApiRepositoryProvider = Provider<AdminApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  final auth = ref.watch(authServiceProvider);
  return AdminApiRepository(api.dio, storage, auth);
});

// Repozytorium API dla instrukcji napraw
final instructionsApiRepositoryProvider = Provider<InstructionsApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return InstructionsApiRepository(api.dio, storage);
});

// Repozytorium API dla części (pobieranie z backendu)
final partsApiRepositoryProvider = Provider<PartsApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return PartsApiRepository(api.dio, storage);
});

// Repozytorium API dla raportów (pobieranie/zapisywanie do backendu)
final raportyApiRepositoryProvider = Provider<RaportyApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return RaportyApiRepository(api.dio, storage);
});

// Stan/logika autoryzacji w aplikacji
final authStateProvider = StateNotifierProvider<AuthController, User?>(
      (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<User?> {
  final Ref _ref;
  AuthController(this._ref) : super(null) {
    // Spróbuj przywrócić sesję na starcie
    _restore();
  }

  Future<void> _restore() async {
    final storage = _ref.read(secureStorageProvider);
    final auth = _ref.read(authServiceProvider);
    final remember = await storage.readRememberMe();
    if (!remember) return;

    String? token = await storage.readToken();
    Map<String, dynamic>? me;

    if (token != null && token.isNotEmpty) {
      me = await auth.me(token);
    }
    if (me == null) {
      token = await auth.refresh();
      if (token != null) {
        me = await auth.me(token);
      }
    }
    if (me != null && token != null) {
      final roles = (me['roles'] as List<dynamic>? ?? const []).cast<String>();
      final role = roles.contains('ROLE_ADMIN') ? 'ADMIN' : 'USER';
      final modules = ((me['modules'] as List<dynamic>? ?? const [])).map((e) => e.toString()).toSet();
      state = User(
        id: 0,
        username: (me['username'] as String?) ?? '',
        role: role,
        token: token,
        modules: modules,
      );
    }
  }

  Future<void> login(String username, String password, {bool rememberMe = false}) async {
    final user = await _ref.read(authServiceProvider).login(username, password, rememberMe: rememberMe);
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