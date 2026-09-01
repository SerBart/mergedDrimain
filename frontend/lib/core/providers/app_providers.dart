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
import '../repositories/notifications_api_repository.dart';
import '../repositories/energia_api_repository.dart';
import '../models/notification.dart';

// Bezpieczny storage na token
final secureStorageProvider =
Provider<SecureStorageService>((ref) => SecureStorageService());

// Klient bez interceptora auth (używany m.in. do login/refresh, aby uniknąć pętli)
final authApiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class _RefreshCoordinator {
  _RefreshCoordinator(this._authService);

  final AuthService _authService;
  Future<String?>? _inFlight;

  Future<String?> refreshOnce() {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _authService.refresh().whenComplete(() => _inFlight = null);
    return _inFlight!;
  }
}

final refreshCoordinatorProvider = Provider<_RefreshCoordinator>((ref) {
  final auth = ref.watch(authServiceProvider);
  return _RefreshCoordinator(auth);
});

// Globalny klient HTTP do API biznesowego, z bezpiecznym auto-refresh
final apiClientProvider = Provider<ApiClient>((ref) {
  final refresh = ref.watch(refreshCoordinatorProvider);
  return ApiClient(refreshTokenCallback: refresh.refreshOnce);
});

// Realny serwis autoryzacji (HTTP)
final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(authApiClientProvider);
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
  final auth = ref.watch(authServiceProvider);
  return ZgloszeniaApiRepository(api.dio, storage, auth);
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

// Repozytorium API dla energii
final energiaApiRepositoryProvider = Provider<EnergiaApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return EnergiaApiRepository(api.dio, storage);
});

// Notifications repository + provider
final notificationsApiRepositoryProvider = Provider<NotificationsApiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return NotificationsApiRepository(api.dio, storage);
});

// Provider zwracający listę powiadomień (Future) — odświeża się po zmianie stanu auth
final notificationsListProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  // Odśwież, kiedy zmienia się stan autoryzacji
  final auth = ref.watch(authStateProvider);
  if (auth == null) return <NotificationModel>[];

  final repo = ref.watch(notificationsApiRepositoryProvider);
  try {
    return await repo.fetchAll();
  } catch (e) {
    return <NotificationModel>[];
  }
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
    String? token = await storage.readToken();
    bool refreshed = false;
    Map<String, dynamic>? me;

    if (token == null || token.isEmpty) {
      token = await auth.refresh();
      refreshed = true;
    }

    if (token != null && token.isNotEmpty) {
      me = await auth.me(token);
    }

    if (me == null && !refreshed) {
      final refreshedToken = await auth.refresh();
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        token = refreshedToken;
        me = await auth.me(refreshedToken);
      }
    }

    if (me != null && token != null) {
      final roles = (me['roles'] as List<dynamic>? ?? const []).cast<String>();
      final role = roles.contains('ROLE_ADMIN') ? 'ADMIN' : 'USER';
      final merged = <String, dynamic>{...me, 'token': token, 'role': role};
      state = User.fromJson(merged);
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

  Future<void> refreshSessionSilently() async {
    final auth = _ref.read(authServiceProvider);
    final refreshedToken = await auth.refresh();
    if (refreshedToken == null || refreshedToken.isEmpty) return;

    final me = await auth.me(refreshedToken);
    if (me == null) return;

    final roles = (me['roles'] as List<dynamic>? ?? const []).cast<String>();
    final role = roles.contains('ROLE_ADMIN') ? 'ADMIN' : 'USER';
    final merged = <String, dynamic>{...me, 'token': refreshedToken, 'role': role};
    state = User.fromJson(merged);
  }

  bool get isAdmin => state?.role == 'ADMIN';
  bool get isLoggedIn => state != null;
}