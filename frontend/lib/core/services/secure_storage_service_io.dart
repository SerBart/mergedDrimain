import 'dart:convert';
import 'dart:io';

final Map<String, String> _memoryFallback = <String, String>{};
Map<String, String>? _cache;

String _storageFilePath() =>
    '${Directory.systemTemp.path}${Platform.pathSeparator}drimain_secure_storage.json';

File _storageFile() => File(_storageFilePath());

Future<Map<String, String>> _loadStore() async {
  if (_cache != null) return _cache!;

  try {
    final file = _storageFile();
    if (!await file.exists()) {
      _cache = <String, String>{};
      return _cache!;
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      _cache = decoded.map((key, value) => MapEntry('$key', '$value'));
    } else {
      _cache = <String, String>{};
    }
  } catch (_) {
    _cache = Map<String, String>.from(_memoryFallback);
  }

  return _cache!;
}

Future<void> _persistStore(Map<String, String> store) async {
  _memoryFallback
    ..clear()
    ..addAll(store);

  try {
    final file = _storageFile();
    await file.writeAsString(jsonEncode(store), flush: true);
  } catch (_) {
    // Best-effort persistence only; keep the in-memory fallback.
  }
}

Future<void> writeString(String key, String value) async {
  final store = await _loadStore();
  store[key] = value;
  await _persistStore(store);
}

Future<String?> readString(String key) async {
  final store = await _loadStore();
  return store[key];
}

Future<void> deleteByKey(String key) async {
  final store = await _loadStore();
  if (store.remove(key) != null) {
    await _persistStore(store);
  }
}

Future<void> clear() async {
  _cache = <String, String>{};
  _memoryFallback.clear();
  try {
    final file = _storageFile();
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // ignore
  }
}

