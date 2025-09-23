import 'package:dio/dio.dart';
import '../models/zgloszenie.dart';
import '../services/secure_storage_service.dart';

class ZgloszeniaApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  ZgloszeniaApiRepository(this._dio, this._storage);

  Future<List<Zgloszenie>> fetchAll() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }

    final resp = await _dio.get(
      '/api/zgloszenia',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(_fromDto).toList();
  }

  Zgloszenie _fromDto(Map<String, dynamic> j) {
    final String statusEnum = (j['status'] ?? '').toString();
    final String status = _mapStatus(statusEnum);

    final String imie = (j['imie'] ?? '').toString();
    final String nazwisko = (j['nazwisko'] ?? '').toString();
    final String typRaw = (j['typ'] ?? '').toString();
    final String typ = _mapTyp(typRaw);

    final String opis = (j['opis'] ?? '').toString();
    final String? dt = j['dataGodzina'] as String?;
    final DateTime dataGodzina =
    dt != null && dt.isNotEmpty ? DateTime.parse(dt) : DateTime.now();

    return Zgloszenie(
      id: (j['id'] is int) ? j['id'] as int : ((j['id'] as num?)?.toInt() ?? 0),
      imie: imie,
      nazwisko: nazwisko,
      typ: typ,
      dataGodzina: dataGodzina,
      opis: opis,
      status: status,
    );
  }

  String _mapStatus(String s) {
    switch (s.toUpperCase()) {
      case 'OPEN':
        return 'NOWE';
      case 'IN_PROGRESS':
        return 'W TOKU';
      case 'ON_HOLD':
        return 'WERYFIKACJA';
      case 'DONE':
      case 'REJECTED':
        return 'ZAMKNIĘTE';
      default:
        return 'NOWE';
    }
  }

  String _mapTyp(String t) {
    final v = t.toUpperCase();
    if (v == 'AWARIA') return 'Awaria';
    if (v == 'SERWIS') return 'Serwis';
    if (v == 'PRZEZBROJENIE' || v == 'PRZEZBROJENIA') return 'Przezbrojenie';
    return t;
  }
}