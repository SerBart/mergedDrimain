class PlatformOrigin {
  static String? origin() {
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

  static String? runtimeApiBase() => null;
}

