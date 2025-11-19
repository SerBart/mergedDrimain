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
import '../features/przeglady/przeglady_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/instrukcje/instrukcje_list_screen.dart' as instrukcje_list;
import '../features/instrukcje/instrukcja_form_screen.dart' as instrukcja_form;
import '../features/notifications/notifications_page.dart';

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
      GoRoute(name: 'dashboard', path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/raporty', builder: (_, __) => const RaportyListScreen()),
      GoRoute(path: '/raport/nowy', builder: (_, __) => const RaportFormScreen()),
      GoRoute(
        path: '/raport/edytuj/:id',
        builder: (_, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr);
          return RaportFormScreen(raportId: id);
        },
      ),
      GoRoute(path: '/czesci', builder: (_, __) => const CzesciListScreen()),
      GoRoute(path: '/zgloszenia', builder: (_, __) => const ZgloszeniaScreenModern()),
      GoRoute(path: '/harmonogramy', builder: (_, __) => const HarmonogramyScreen()),
      GoRoute(path: '/przeglady', builder: (_, __) => const PrzegladyScreen()),
      GoRoute(path: '/instrukcje', builder: (_, __) => const instrukcje_list.InstrukcjeListScreen()),
      GoRoute(path: '/instrukcje/nowa', builder: (_, __) => const instrukcja_form.InstrukcjaFormScreen()),
      // Notifications page
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
      // Panel Admina
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
});