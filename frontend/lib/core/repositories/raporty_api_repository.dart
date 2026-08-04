import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../models/raport.dart';
import '../models/maszyna.dart';
import '../models/dzial.dart';
import '../models/sekcja.dart';
import '../models/osoba.dart';
import '../models/part.dart';
import '../models/part_usage.dart';
import '../services/secure_storage_service.dart';

class RaportyApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;
  late final String _baseUrl;
  late final String _apiRoot;

  RaportyApiRepository(this._dio, this._storage) {
    _baseUrl = _trimTrailingSlashes(_dio.options.baseUrl);
    _apiRoot = _normalizeApiRoot(_baseUrl);
  }

  Future<List<Raport>> fetchAll({int page = 0, int size = 200}) async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/raporty',
      queryParameters: {'page': page, 'size': size},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = resp.data;
    final List list = (data is Map && data['content'] is List) ? data['content'] as List : (data as List);
    return list.cast<Map>().map((j) => _fromDto(j.cast<String, dynamic>())).toList();
  }

  Future<Raport> fetchById(int id) async {
    final token = await _token();
    final resp = await _dio.get(
      '/api/raporty/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _fromDto((resp.data as Map).cast<String, dynamic>());
  }

  Future<Raport> create({
    required int maszynaId,
    String? typNaprawy,
    String? opis,
    int? osobaId,
    required String status,
    required DateTime data,
    required DateTime czasOd,
    required DateTime czasDo,
    List<PartUsage>? partUsages,
  }) async {
    final token = await _token();
    String fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final body = {
      'maszynaId': maszynaId,
      if (typNaprawy != null) 'typNaprawy': typNaprawy,
      if (opis != null) 'opis': opis,
      if (osobaId != null) 'osobaId': osobaId,
      'status': status,
      'dataNaprawy': fmtDate(data),
      'czasOd': fmtTime(czasOd),
      'czasDo': fmtTime(czasDo),
      if (partUsages != null && partUsages.isNotEmpty)
        'partUsages': partUsages
            .map((pu) => {
                  'partId': pu.part.id,
                  'ilosc': pu.ilosc,
                })
            .toList(),
    };
    final resp = await _dio.post(
      '/api/raporty',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _fromDto((resp.data as Map).cast<String, dynamic>());
  }

  Future<Raport> update({
    required int id,
    required int maszynaId,
    String? typNaprawy,
    String? opis,
    int? osobaId,
    required String status,
    required DateTime data,
    required DateTime czasOd,
    required DateTime czasDo,
    List<PartUsage>? partUsages,
  }) async {
    final token = await _token();
    String fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final body = {
      'maszynaId': maszynaId,
      if (typNaprawy != null) 'typNaprawy': typNaprawy,
      if (opis != null) 'opis': opis,
      if (osobaId != null) 'osobaId': osobaId,
      'status': status,
      'dataNaprawy': fmtDate(data),
      'czasOd': fmtTime(czasOd),
      'czasDo': fmtTime(czasDo),
      if (partUsages != null && partUsages.isNotEmpty)
        'partUsages': partUsages
            .map((pu) => {
                  'partId': pu.part.id,
                  'ilosc': pu.ilosc,
                })
            .toList(),
    };
    final resp = await _dio.put(
      '/api/raporty/$id',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _fromDto((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) async {
    final token = await _token();
    await _dio.delete(
      '/api/raporty/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Raport _fromDto(Map<String, dynamic> j) {
    // RaportDTO fields: id, maszyna:{id,nazwa}, osoba:{id,imieNazwisko}, typNaprawy, opis, status, dataNaprawy (yyyy-MM-dd), czasOd (HH:mm[:ss]), czasDo
    final id = (j['id'] as num?)?.toInt() ?? 0;
    final maszyna = _parseMaszyna(j);
    Osoba? osoba;
    if (j['osoba'] is Map) {
      final o = (j['osoba'] as Map).cast<String, dynamic>();
      osoba = Osoba(id: (o['id'] as num?)?.toInt() ?? 0, imieNazwisko: (o['imieNazwisko'] ?? '').toString());
    }
    final typNaprawy = (j['typNaprawy'] ?? '').toString();
    final opis = (j['opis'] ?? '').toString();
    final status = (j['status'] ?? '').toString();
    final dn = (j['dataNaprawy'] ?? '').toString();
    final co = (j['czasOd'] ?? '').toString();
    final cd = (j['czasDo'] ?? '').toString();
    final partUsagesJson = j['partUsages'];
    List<PartUsage> partUsages = [];
    if (partUsagesJson is List) {
      for (final raw in partUsagesJson) {
        if (raw is Map) {
          final r = raw.cast<String, dynamic>();
          final pid = (r['partId'] as num?)?.toInt() ?? 0;
          final ilosc = (r['ilosc'] as num?)?.toInt() ?? 0;
          partUsages.add(
            PartUsage(
              part: Part(
                id: pid,
                nazwa: 'ID:$pid',
                kod: '',
                iloscMagazyn: 0,
                minIlosc: 0,
                jednostka: '',
              ),
              ilosc: ilosc,
            ),
          );
        }
      }
    }

    DateTime parseDate(String s) {
      // yyyy-MM-dd
      final p = s.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    int _toInt(String t) => int.tryParse(t) ?? 0;
    DateTime combine(DateTime d, String time) {
      final parts = time.split(':');
      final h = parts.isNotEmpty ? _toInt(parts[0]) : 0;
      final m = parts.length > 1 ? _toInt(parts[1]) : 0;
      return DateTime(d.year, d.month, d.day, h, m);
    }

    final data = dn.isNotEmpty ? parseDate(dn) : DateTime.now();
    final czasOd = combine(data, co);
    final czasDo = combine(data, cd);

    // Parse zdjęcia – wspieramy pełne URL-e, ścieżki względne i same nazwy plików.
    List<String> zdjecia = [];
    final zdjecia_json = j['zdjecia'];
    if (zdjecia_json is List) {
      zdjecia = zdjecia_json
          .map((z) => _toPhotoUrl(id, z.toString()))
          .where((u) => u.isNotEmpty)
          .toList();
    }

    return Raport(
      id: id,
      maszyna: maszyna,
      typNaprawy: typNaprawy,
      opis: opis,
      osoba: osoba,
      status: status,
      dataNaprawy: data,
      czasOd: czasOd,
      czasDo: czasDo,
      partUsages: partUsages,
      zdjecia: zdjecia,
    );
  }

  Maszyna? _parseMaszyna(Map<String, dynamic> j) {
    final raw = j['maszyna'];
    int id = 0;
    String nazwa = '';
    Dzial? dzial;
    Sekcja? sekcja;

    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      id = (m['id'] as num?)?.toInt() ?? (m['maszynaId'] as num?)?.toInt() ?? 0;
      nazwa = (m['nazwa'] ?? m['name'] ?? m['maszynaNazwa'] ?? '').toString();

      final rawDzial = m['dzial'];
      if (rawDzial is Map) {
        final d = rawDzial.cast<String, dynamic>();
        dzial = Dzial(
          id: (d['id'] as num?)?.toInt() ?? 0,
          nazwa: (d['nazwa'] ?? d['name'] ?? '').toString(),
        );
      } else if (rawDzial is String && rawDzial.trim().isNotEmpty) {
        dzial = Dzial(id: 0, nazwa: rawDzial.trim());
      }

      final rawSekcja = m['sekcja'];
      if (rawSekcja is Map) {
        final s = rawSekcja.cast<String, dynamic>();
        sekcja = Sekcja(
          id: (s['id'] as num?)?.toInt() ?? 0,
          nazwa: (s['nazwa'] ?? s['name'] ?? '').toString(),
          dzial: dzial,
        );
      } else if (rawSekcja is String && rawSekcja.trim().isNotEmpty) {
        sekcja = Sekcja(id: 0, nazwa: rawSekcja.trim(), dzial: dzial);
      }
    }

    // Fallback for flat DTOs (legacy/inconsistent payloads).
    if (id == 0) {
      id = (j['maszynaId'] as num?)?.toInt() ?? (j['machineId'] as num?)?.toInt() ?? 0;
    }
    if (nazwa.trim().isEmpty) {
      nazwa = (j['maszynaNazwa'] ?? j['machineName'] ?? '').toString();
    }
    if (dzial == null) {
      final dzialNazwa = (j['maszynaDzialNazwa'] ?? j['dzialNazwa'] ?? '').toString().trim();
      final dzialId = (j['dzialId'] as num?)?.toInt() ?? 0;
      if (dzialNazwa.isNotEmpty || dzialId > 0) {
        dzial = Dzial(id: dzialId, nazwa: dzialNazwa);
      }
    }

    if (sekcja == null) {
      final sekcjaNazwa = (j['maszynaSekcjaNazwa'] ?? j['sekcjaNazwa'] ?? '').toString().trim();
      final sekcjaId = (j['maszynaSekcjaId'] as num?)?.toInt() ?? (j['sekcjaId'] as num?)?.toInt() ?? 0;
      if (sekcjaNazwa.isNotEmpty || sekcjaId > 0) {
        sekcja = Sekcja(id: sekcjaId, nazwa: sekcjaNazwa, dzial: dzial);
      }
    }

    if (id <= 0 && nazwa.trim().isEmpty) return null;
    return Maszyna(id: id, nazwa: nazwa, dzial: dzial, sekcja: sekcja);
  }

  /// Wgrywa zdjęcia do raportu. Zwraca listę nowych pełnych URL-i.
  Future<List<String>> uploadZdjecia(int id, List<XFile> files) async {
    final token = await _token();
    final formData = FormData();
    for (final file in files) {
      final bytes = await file.readAsBytes();
      formData.files.add(MapEntry(
        'zdjecia',
        MultipartFile.fromBytes(bytes, filename: file.name),
      ));
    }
    final resp = await _dio.post(
      '/api/raporty/$id/zdjecia',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final List raw = resp.data as List;
    return raw
        .map((filename) => _normalizePhotoUrl(id, filename.toString()))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  /// Usuwa pojedyncze zdjęcie z raportu.
  Future<void> deleteZdjecie(int id, String photoUrl) async {
    final token = await _token();
    // Wyodrębnij samą nazwę pliku z URL-a lub ścieżki
    final normalized = photoUrl.replaceAll('\\', '/');
    final uri = Uri.tryParse(normalized);
    final lastSegment = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : normalized.split('/').last;
    final filename = Uri.decodeComponent(lastSegment);
    await _dio.delete(
      '/api/raporty/$id/zdjecia/$filename',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  String _toPhotoUrl(int raportId, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    // New backend format for persistent storage metadata.
    if (value.startsWith('inline:')) {
      final first = value.indexOf(':');
      final second = value.indexOf(':', first + 1);
      if (second > first + 1) {
        final filename = value.substring(first + 1, second);
        final encoded = Uri.encodeComponent(filename);
        return '$_apiRoot/api/raporty/$raportId/zdjecia/$encoded';
      }
      return '';
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/api/')) {
      return '$_apiRoot$value';
    }

    // Obsługa danych historycznych typu "dir/file.jpg" i "dir\\file.jpg".
    final normalized = value.replaceAll('\\', '/');
    final bare = normalized.split('/').last;
    final encoded = Uri.encodeComponent(bare);
    return '$_apiRoot/api/raporty/$raportId/zdjecia/$encoded';
  }

  String _normalizePhotoUrl(int raportId, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/api/')) {
      return '$_apiRoot$value';
    }
    if (value.contains('/api/raporty/')) {
      final idx = value.indexOf('/api/');
      if (idx >= 0) return '$_apiRoot${value.substring(idx)}';
    }
    return _toPhotoUrl(raportId, value);
  }

  String _normalizeApiRoot(String rawBaseUrl) {
    final base = _trimTrailingSlashes(rawBaseUrl);
    final uri = Uri.tryParse(base);
    if (uri == null) return base;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      final trimmed = segments.sublist(0, segments.length - 1);
      final path = trimmed.isEmpty ? '' : '/${trimmed.join('/')}';
      return _trimTrailingSlashes(uri.replace(path: path).toString());
    }
    return base;
  }

  String _trimTrailingSlashes(String input) =>
      input.replaceFirst(RegExp(r'/+$'), '');

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}
