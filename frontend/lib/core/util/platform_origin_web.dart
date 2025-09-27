import 'dart:html' as html;

String? origin() {
  try {
    return html.window.location.origin;
  } catch (_) {
    return null;
  }
}

