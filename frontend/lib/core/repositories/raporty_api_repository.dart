import 'package:dio/dio.dart';
import '../models/raport.dart';
import '../models/maszyna.dart';
import '../models/osoba.dart';
import '../models/part.dart';
import '../models/part_usage.dart';
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
    );
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}
