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
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth != null;
      final atLogin = state.fullPath == '/login';
      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/czesci',    builder: (c, s) => const CzesciListScreen()),
      GoRoute(path: '/login',     builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/raporty',   builder: (c, s) => const RaportyListScreen()),
      GoRoute(path: '/raport/nowy', builder: (c, s) => const RaportFormScreen()),
      GoRoute(
        path: '/raport/edytuj/:id',
        builder: (c, s) => RaportFormScreen(
          raportId: int.tryParse(s.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(path: '/zgloszenia', builder: (c, s) => const ZgloszeniaScreenModern()),
      GoRoute(path: '/admin',      builder: (c, s) => const AdminScreen()),
    ],
  );
});