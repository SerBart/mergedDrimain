import 'web_visibility_observer_stub.dart'
    if (dart.library.html) 'web_visibility_observer_web.dart' as impl;

abstract class WebVisibilityObserver {
  Stream<bool> get changes;
  void dispose();
}

WebVisibilityObserver createWebVisibilityObserver() => impl.createWebVisibilityObserver();

