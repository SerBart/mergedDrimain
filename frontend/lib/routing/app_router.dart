import 'package:drimain_mobile/features/zgloszenia/zgloszenia_screen_modern.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/app_providers.dart';
import '../features/czesci/czesci_list_screen.dart';

// IMPORTY EKRANÓW – UPEWNIJ SIĘ, ŻE PLIKI ISTNIEJĄ w tych ścieżkach
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/raporty/raport_list_screen.dart';
import '../features/zgloszenia/zgloszenia_list_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/raporty/raport_form_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Obserwujemy zalogowanego użytkownika
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    // redirect = decyduje czy zmienić ścieżkę automatycznie
    redirect: (context, state) {
      final loggedIn = auth != null;
      final atLogin = state.fullPath == '/login';

      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/dashboard';
      return null; // brak zmiany
    },
    routes: [
      GoRoute(
        path: '/czesci',
         builder: (c, s) => const CzesciListScreen()),

      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/raporty',
        builder: (context, state) => const RaportyListScreen(),
      ),
      GoRoute(
        path: '/raport/nowy',
        builder: (context, state) => const RaportFormScreen(),
      ),
      GoRoute(
        path: '/raport/edytuj/:id',
        builder: (context, state) {
          final idString = state.pathParameters['id'];
            // jeśli idString == null -> formularz nowy
          final raportId = int.tryParse(idString ?? '');
          return RaportFormScreen(raportId: raportId);
        },
      ),
      GoRoute(
        path: '/zgloszenia',
         builder: (c, s) => const ZgloszeniaScreenModern(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
  );
});