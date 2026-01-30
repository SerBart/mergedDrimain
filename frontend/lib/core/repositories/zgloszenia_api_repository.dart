import 'package:dio/dio.dart';
import '../models/zgloszenie.dart';
import '../services/secure_storage_service.dart';

class ZgloszeniaApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  ZgloszeniaApiRepository(this._dio, this._storage);

  Future<List<Zgloszenie>> fetchAll() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/zgloszenia',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(_fromDto).toList();
  }

  Future<Zgloszenie> create({
    required String imie,
    required String nazwisko,
    required String typUi,
    required String temat,
    required String opis,
    required String statusUi,
    DateTime? dataGodzina,
    int? dzialId,
    int? maszynaId,
  }) async {
    final token = await _readToken();
    final dto = {
      'typ': _uiTypToDto(typUi),
      'imie': imie,
      'nazwisko': nazwisko,
      'tytul': temat,  // Backend oczekuje 'tytul' nie 'temat'
      'status': _uiStatusToEnum(statusUi),
      'priorytet': 'NORMALNY', // zgodnie z DTO backendu
      'opis': opis,
      'dataGodzina': (dataGodzina ?? DateTime.now()).toIso8601String(),
      if (dzialId != null) 'dzialId': dzialId,
      if (maszynaId != null) 'maszynaId': maszynaId,
    };

    final resp = await _dio.post(
      '/api/zgloszenia',
      data: dto,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _fromDto((resp.data as Map).cast<String, dynamic>());
  }

  Future<Zgloszenie> update(Zgloszenie z) async {
    final token = await _readToken();
    final dto = {
      'id': z.id,
      'typ': _uiTypToDto(z.typ),
      'imie': z.imie,
      'nazwisko': z.nazwisko,
      'tytul': z.temat, // Wysyłaj jako 'tytul' bo tak backend oczekuje
      'status': _uiStatusToEnum(z.status),
      'opis': z.opis,
      'dataGodzina': z.dataGodzina.toIso8601String(),
    };

    final resp = await _dio.put(
      '/api/zgloszenia/${z.id}',
      data: dto,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _fromDto((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) async {
    final token = await _readToken();
    await _dio.delete(
      '/api/zgloszenia/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  // ---- Mapowania ----

  Zgloszenie _fromDto(Map<String, dynamic> j) {
    final String statusEnum = (j['status'] ?? '').toString();
    final String status = _enumStatusToUi(statusEnum);

    final String imie = (j['imie'] ?? '').toString();
    final String nazwisko = (j['nazwisko'] ?? '').toString();
    final String typRaw = (j['typ'] ?? '').toString();
    final String typ = _dtoTypToUi(typRaw);
    // Backend zwraca pole 'tytul' zamiast 'temat' - czytaj z tego pola
    final String temat = (j['tytul'] ?? j['temat'] ?? j['subject'] ?? j['topic'] ?? '').toString();

    final String opis = (j['opis'] ?? '').toString();
    final String? dt = j['dataGodzina'] as String?;
    final DateTime dataGodzina =
    dt != null && dt.isNotEmpty ? DateTime.parse(dt) : DateTime.now();

    return Zgloszenie(
      id: (j['id'] is int) ? j['id'] as int : ((j['id'] as num?)?.toInt() ?? 0),
      imie: imie,
      nazwisko: nazwisko,
      typ: typ,
      temat: temat,
      dataGodzina: dataGodzina,
      opis: opis,
      status: status,
    );
  }

  String _enumStatusToUi(String s) {
    switch (s.toUpperCase()) {
      case 'OPEN':
        return 'NOWE';
      case 'IN_PROGRESS':
        return 'W TOKU';
      case 'ON_HOLD':
        return 'PRZERWANE';
      case 'DONE':
      case 'REJECTED':
        return 'ZAMKNIĘTE';
      default:
        return 'NOWE';
    }
  }

  String _uiStatusToEnum(String s) {
    switch (s.toUpperCase()) {
      case 'NOWE':
        return 'OPEN';
      case 'W TOKU':
        return 'IN_PROGRESS';
      case 'PRZERWANE':
        return 'ON_HOLD';
      case 'WERYFIKACJA':
        return 'ON_HOLD';
      case 'ZAMKNIĘTE':
        return 'DONE';
      default:
        return 'OPEN';
    }
  }

  String _dtoTypToUi(String t) {
    final v = t.toUpperCase();
    if (v == 'AWARIA') return 'Awaria';
    if (v == 'SERWIS') return 'Serwis';
    if (v == 'PRZEZBROJENIE' || v == 'PRZEZBROJENIA') return 'Przezbrojenie';
    if (v == 'USTERKA') return 'Usterka';
    if (v == 'MODERNIZACJA') return 'Modernizacja';
    return t;
  }

  String _uiTypToDto(String t) {
    final v = t.toUpperCase();
    if (v == 'AWARIA') return 'AWARIA';
    if (v == 'SERWIS') return 'SERWIS';
    if (v == 'PRZEZBROJENIE' || v == 'PRZEZBROJENIA') return 'PRZEZBROJENIE';
    if (v == 'USTERKA') return 'USTERKA';
    if (v == 'MODERNIZACJA') return 'MODERNIZACJA';
    return v; // fallback
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}