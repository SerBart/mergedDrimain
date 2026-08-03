import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationOverlayControllerProvider =
    ChangeNotifierProvider<NavigationOverlayController>((ref) {
  final controller = NavigationOverlayController();
  ref.onDispose(controller.dispose);
  return controller;
});

class NavigationOverlayController extends ChangeNotifier {
  bool _visible = false;
  Timer? _timer;

  bool get visible => _visible;

  void pulse({Duration duration = const Duration(milliseconds: 220)}) {
    _timer?.cancel();
    _visible = true;
    notifyListeners();
    _timer = Timer(duration, () {
      _visible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class NavigationFlashObserver extends NavigatorObserver {
  final VoidCallback onRouteTransition;

  NavigationFlashObserver({required this.onRouteTransition});

  bool _isVisualPageRoute(Route<dynamic>? route) {
    if (route == null) return false;
    return route is PageRoute<dynamic>;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isVisualPageRoute(route)) {
      onRouteTransition();
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_isVisualPageRoute(newRoute)) {
      onRouteTransition();
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isVisualPageRoute(previousRoute)) {
      onRouteTransition();
    }
    super.didPop(route, previousRoute);
  }
}

class NavigationTransitionOverlay extends ConsumerWidget {
  final Widget child;

  const NavigationTransitionOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      navigationOverlayControllerProvider.select((c) => c.visible),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (visible)
          IgnorePointer(
            ignoring: true,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withOpacity(.96),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1.8),
                  duration: const Duration(milliseconds: 220),
                  builder: (context, turns, icon) {
                    return Transform.rotate(
                      angle: turns * 6.283185307179586,
                      child: icon,
                    );
                  },
                  child: Icon(
                    Icons.settings_rounded,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

