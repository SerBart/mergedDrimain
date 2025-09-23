import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/raporty/list_screen.dart';
import 'features/raporty/detail_screen.dart';
import 'features/raporty/edit_screen.dart';
import 'features/harmonogramy/list_screen.dart';
import 'features/harmonogramy/edit_screen.dart';
import 'features/przeglady/list_screen.dart';
import 'features/przeglady/edit_screen.dart';

GoRouter createRouter(WidgetRef ref) {
  String? redirectLogic(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final loggingIn = state.matchedLocation == '/login';
    if (!auth.isAuthenticated && !loggingIn) {
      final from = Uri.encodeComponent(state.uri.toString());
      return '/login?from=$from';
    }
    if (auth.isAuthenticated && loggingIn) {
      return '/';
    }
    return null;
  }

  return GoRouter(
    refreshListenable: RouterNotifier(ref),
    redirect: (context, state) => redirectLogic(context, state),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          redirectTo: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/raporty',
        builder: (context, state) => const RaportyListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                RaportDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'new',
            builder: (context, state) => const RaportEditScreen(id: null),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                RaportEditScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/harmonogramy',
        builder: (context, state) => const HarmonogramyListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const HarmonogramEditScreen(id: null),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                HarmonogramEditScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/przeglady',
        builder: (context, state) => const PrzegladyListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const PrzegladEditScreen(id: null),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                PrzegladEditScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(WidgetRef ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}