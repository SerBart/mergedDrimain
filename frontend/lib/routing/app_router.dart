import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/app_providers.dart';
import 'navigation_transition_overlay.dart';
import '../widgets/app_background.dart';

// Ekrany
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/raporty/raport_list_screen.dart';
import '../features/raporty/raport_form_screen.dart';
import '../features/czesci/czesci_list_screen.dart';
import '../features/zgloszenia/zgloszenia_screen_modern.dart';
import '../features/zgloszenia/moje_zgloszenia_screen.dart';
import '../features/harmonogramy/harmonogramy_screen.dart';
import '../features/przeglady/przeglady_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/instrukcje/instrukcje_list_screen.dart' as instrukcje_list;
import '../features/instrukcje/instrukcja_form_screen.dart' as instrukcja_form;
import '../features/notifications/notifications_page.dart';
import '../features/profile/profile_screen.dart';
import '../features/modules/modules_screen.dart';

class _RouteBackground extends StatelessWidget {
  final Widget child;

  const _RouteBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: AppBackground(child: child),
    );
  }
}

CustomTransitionPage<void> _smoothPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: _RouteBackground(child: child),
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authStateProvider.select((user) => user != null));
  final overlayController = ref.read(navigationOverlayControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    observers: [
      NavigationFlashObserver(onRouteTransition: () => overlayController.pulse()),
    ],
    redirect: (context, state) {
      final loggedIn = isLoggedIn;
      final atLogin = state.fullPath == '/login';
      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        name: 'dashboard',
        path: '/dashboard',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const DashboardScreen()),
      ),
      GoRoute(
        path: '/raporty',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const RaportyListScreen()),
      ),
      GoRoute(
        path: '/raport/nowy',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const RaportFormScreen()),
      ),
      GoRoute(
        path: '/raport/edytuj/:id',
        pageBuilder: (_, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr);
          return _smoothPage(state: state, child: RaportyListScreen(editRaportId: id));
        },
      ),
      GoRoute(
        path: '/czesci',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const CzesciListScreen()),
      ),
       GoRoute(
         path: '/zgloszenia',
         pageBuilder: (_, state) => _smoothPage(state: state, child: const ZgloszeniaScreenModern()),
       ),
       GoRoute(
         path: '/moje-zgloszenia',
         pageBuilder: (_, state) => _smoothPage(state: state, child: const MojeZgloszeniaScreen()),
       ),
       GoRoute(
         path: '/zgloszenia/:id',
        pageBuilder: (_, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final id = int.tryParse(idStr);
          return _smoothPage(state: state, child: ZgloszeniaScreenModern(selectedZgloszenieId: id));
        },
      ),
      GoRoute(
        path: '/harmonogramy',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const HarmonogramyScreen()),
      ),
      GoRoute(
        path: '/przeglady',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const PrzegladyScreen()),
      ),
      GoRoute(
        path: '/instrukcje',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const instrukcje_list.InstrukcjeListScreen()),
      ),
      GoRoute(
        path: '/instrukcje/nowa',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const instrukcja_form.InstrukcjaFormScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const NotificationsPage()),
      ),
      GoRoute(
        path: '/profil',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/moduly',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const ModulesScreen()),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const AdminScreen()),
      ),
    ],
  );
});