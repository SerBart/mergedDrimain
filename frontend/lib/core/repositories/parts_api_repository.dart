import 'package:dio/dio.dart';
import '../services/secure_storage_service.dart';
import '../models/part.dart';

class PartRefModel {
  final int id; final String nazwa; final String kod; final String? jednostka;
  PartRefModel({required this.id, required this.nazwa, required this.kod, this.jednostka});
  factory PartRefModel.fromJson(Map<String, dynamic> j) => PartRefModel(
    id: (j['id'] as num).toInt(),
    nazwa: (j['nazwa'] ?? '').toString(),
    kod: (j['kod'] ?? '').toString(),
    jednostka: (j['jednostka'] as String?),
  );
}

class PartsApiRepository {
  final Dio _dio; final SecureStorageService _storage;
  PartsApiRepository(this._dio, this._storage);

  // Lekki model do pickerów
  Future<List<PartRefModel>> listAll() async {
    final t = await _token();
    final resp = await _dio.get(
      '/api/czesci',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(PartRefModel.fromJson).toList();
  }

  // Pełna lista do widoku tabeli
  Future<List<Part>> listFull() async {
    final t = await _token();
    final resp = await _dio.get(
      '/api/czesci',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(_dtoToPart).toList();
  }

  Part _dtoToPart(Map<String, dynamic> j) {
    return Part(
      id: (j['id'] as num).toInt(),
      nazwa: (j['nazwa'] ?? '').toString(),
      kod: (j['kod'] ?? '').toString(),
      iloscMagazyn: (j['ilosc'] as num?)?.toInt() ?? 0,
      minIlosc: (j['minIlosc'] as num?)?.toInt() ?? 0,
      jednostka: (j['jednostka'] ?? 'szt').toString(),
      kategoria: (j['kategoria'] as String?),
      maszynaId: (j['maszynaId'] as num?)?.toInt(),
      maszynaNazwa: (j['maszynaNazwa'] as String?),
    );
  }

  Future<void> adjustQuantity({required int partId, required int delta}) async {
    final t = await _token();
    await _dio.patch(
      '/api/czesci/$partId/ilosc',
      data: { 'delta': delta },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<void> createPart({
    required String nazwa,
    required String kod,
    required int ilosc,
    required int minIlosc,
    required String jednostka,
    String? kategoria,
  }) async {
    final t = await _token();
    await _dio.post(
      '/api/czesci',
      data: {
        'nazwa': nazwa,
        'kod': kod,
        'ilosc': ilosc,
        'minIlosc': minIlosc,
        'jednostka': jednostka,
        if (kategoria != null) 'kategoria': kategoria,
      },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<void> updatePart({
    required int id,
    String? nazwa,
    String? kod,
    String? kategoria,
    int? minIlosc,
    String? jednostka,
  }) async {
    final t = await _token();
    await _dio.put(
      '/api/czesci/$id',
      data: {
        if (nazwa != null) 'nazwa': nazwa,
        if (kod != null) 'kod': kod,
        if (kategoria != null) 'kategoria': kategoria,
        if (minIlosc != null) 'minIlosc': minIlosc,
        if (jednostka != null) 'jednostka': jednostka,
      },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<void> assignToMaszyna({required int partId, int? maszynaId}) async {
    final t = await _token();
    await _dio.put(
      '/api/czesci/$partId',
      data: {
        'maszynaId': maszynaId ?? 0, // 0 => grupa "Inne"
      },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}
