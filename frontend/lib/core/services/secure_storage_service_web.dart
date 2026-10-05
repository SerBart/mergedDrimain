import 'package:web/web.dart' as web;

final Map<String, String> _memoryFallback = <String, String>{};

web.Storage? _storage() {
  try {
    return web.window.localStorage;
  } catch (_) {
    return null;
  }
}

Future<void> writeString(String key, String value) async {
  final storage = _storage();
  if (storage != null) {
    try {
      storage.setItem(key, value);
      return;
    } catch (_) {
      // ignore and fall back
    }
  }
  _memoryFallback[key] = value;
}

Future<String?> readString(String key) async {
  final storage = _storage();
  if (storage != null) {
    try {
      final value = storage.getItem(key);
      if (value != null) return value;
    } catch (_) {
      // ignore and fall back
    }
  }
  return _memoryFallback[key];
}

Future<void> deleteByKey(String key) async {
  final storage = _storage();
  if (storage != null) {
    try {
      storage.removeItem(key);
    } catch (_) {
      // ignore and fall back
    }
  }
  _memoryFallback.remove(key);
}

Future<void> clear() async {
  final storage = _storage();
  if (storage != null) {
    try {
      storage.clear();
    } catch (_) {
      // ignore and fall back
    }
  }
  _memoryFallback.clear();
}

