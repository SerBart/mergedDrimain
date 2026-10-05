import 'dart:async';
import 'dart:html' as html;

import 'web_visibility_observer.dart';

class _BrowserVisibilityObserver implements WebVisibilityObserver {
  _BrowserVisibilityObserver() {
    _controller.add(_isVisible);
    _subscription = html.document.onVisibilityChange.listen((_) {
      _controller.add(_isVisible);
    });
  }

  final StreamController<bool> _controller = StreamController<bool>();
  final html.Document _document = html.document;
  StreamSubscription<html.Event>? _subscription;

  bool get _isVisible => _document.hidden != true;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

WebVisibilityObserver createWebVisibilityObserver() => _BrowserVisibilityObserver();
