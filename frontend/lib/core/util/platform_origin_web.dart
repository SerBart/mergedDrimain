import 'dart:html' as html;
import 'dart:js_util' as js_util;

String? origin() {
  try {
    return html.window.location.origin;
  } catch (_) {
    return null;
  }
}

String? runtimeApiBase() {
  try {
    final config = js_util.getProperty<Object?>(html.window, '__DRIMAIN_CONFIG__');
    if (config == null) return null;
    final apiBase = js_util.getProperty<Object?>(config, 'API_BASE');
    if (apiBase is String && apiBase.trim().isNotEmpty) {
      return apiBase.trim();
    }
  } catch (_) {
    // ignore and fall back to other strategies
  }
  return null;
}

