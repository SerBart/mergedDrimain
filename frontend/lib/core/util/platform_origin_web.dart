import 'dart:js_util' as js_util;

String? origin() {
  try {
    final uri = Uri.base;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri.origin;
    }
  } catch (_) {
    // ignore and fall through to null
  }
  return null;
}

String? runtimeApiBase() {
  try {
    final config = js_util.getProperty<Object?>(js_util.globalThis, '__DRIMAIN_CONFIG__');
    if (config == null) {
      return null;
    }

    final value = js_util.getProperty<Object?>(config, 'API_BASE');
    final apiBase = value?.toString().trim();
    if (apiBase == null || apiBase.isEmpty) {
      return null;
    }
    return apiBase;
  } catch (_) {
    return null;
  }

}
