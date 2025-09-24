import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/app_providers.dart';

// Ekrany
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/raporty/raport_list_screen.dart';
import '../features/raporty/raport_form_screen.dart';
import '../features/czesci/czesci_list_screen.dart';
import '../features/zgloszenia/zgloszenia_screen_modern.dart';
import '../features/harmonogramy/harmonogramy_screen.dart';

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
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/raporty', builder: (_, __) => const RaportyListScreen()),
      GoRoute(path: '/raport/nowy', builder: (_, __) => const RaportFormScreen()),
      GoRoute(path: '/czesci', builder: (_, __) => const CzesciListScreen()),
      GoRoute(path: '/zgloszenia', builder: (_, __) => const ZgloszeniaScreenModern()),
      GoRoute(path: '/harmonogramy', builder: (_, __) => const HarmonogramyScreen()),
    ],
  );
});