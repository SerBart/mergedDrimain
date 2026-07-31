import 'package:flutter/material.dart';
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

CustomTransitionPage<void> _smoothPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final overlayOpacity = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 0.94)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 34,
        ),
        TweenSequenceItem(tween: ConstantTween<double>(0.94), weight: 26),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.94, end: 0)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 40,
        ),
      ]).animate(animation);
      final nextFade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
      );
      final loaderOpacity = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 40,
        ),
        TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 0)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 40,
        ),
      ]).animate(animation);
      final gearSpin = Tween<double>(begin: 0, end: 1.2).animate(
        CurvedAnimation(parent: animation, curve: Curves.linear),
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: nextFade.value, child: child),
          if (overlayOpacity.value > 0.01 || loaderOpacity.value > 0.01)
            ColoredBox(
              color: Theme.of(context)
                  .colorScheme
                  .surface
                  .withOpacity(overlayOpacity.value.clamp(0.0, 0.96).toDouble()),
              child: Center(
                child: Opacity(
                  opacity: loaderOpacity.value,
                  child: RotationTransition(
                    turns: gearSpin,
                    child: Icon(
                      Icons.settings_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

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
        path: '/admin',
        pageBuilder: (_, state) => _smoothPage(state: state, child: const AdminScreen()),
      ),
    ],
  );
});