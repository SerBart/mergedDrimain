import 'web_visibility_observer.dart';

class _NoopWebVisibilityObserver implements WebVisibilityObserver {
  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  void dispose() {}
}

WebVisibilityObserver createWebVisibilityObserver() => _NoopWebVisibilityObserver();

