import 'package:dio/dio.dart';
import '../models/raport.dart';
import '../models/maszyna.dart';
import '../models/osoba.dart';
import '../services/secure_storage_service.dart';

class RaportyApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;
  RaportyApiRepository(this._dio, this._storage);

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

  Future<Raport> create({
    required int maszynaId,
    String? typNaprawy,
    String? opis,
    int? osobaId,
    required DateTime data,
    required DateTime czasOd,
    required DateTime czasDo,
  }) async {
    final token = await _token();
    String fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final body = {
      'maszynaId': maszynaId,
      if (typNaprawy != null) 'typNaprawy': typNaprawy,
      if (opis != null) 'opis': opis,
      if (osobaId != null) 'osobaId': osobaId,
      'dataNaprawy': fmtDate(data),
      'czasOd': fmtTime(czasOd),
      'czasDo': fmtTime(czasDo),
    };
    final resp = await _dio.post(
      '/api/raporty',
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
    Maszyna? maszyna;
    if (j['maszyna'] is Map) {
      final m = (j['maszyna'] as Map).cast<String, dynamic>();
      maszyna = Maszyna(id: (m['id'] as num?)?.toInt() ?? 0, nazwa: (m['nazwa'] ?? '').toString());
    }
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
      partUsages: const [],
    );
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}

