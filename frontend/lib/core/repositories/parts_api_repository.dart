import 'package:dio/dio.dart';
import '../services/secure_storage_service.dart';
import '../models/part.dart';

class PartRefModel {
  final int id;
  final String nazwa;
  final String kod;
  final String? jednostka;

  PartRefModel({required this.id, required this.nazwa, required this.kod, this.jednostka});

  factory PartRefModel.fromJson(Map<String, dynamic> j) => PartRefModel(
    id: (j['id'] as num).toInt(),
    nazwa: (j['nazwa'] ?? '').toString(),
    kod: (j['kod'] ?? '').toString(),
    jednostka: (j['jednostka'] as String?),
  );
}

class PartsApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  PartsApiRepository(this._dio, this._storage);

  Future<List<PartRefModel>> listAll() async {
    final t = await _token();
    final resp = await _dio.get(
      '/api/czesci',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(PartRefModel.fromJson).toList();
  }

  Future<List<Part>> listFull() async {
    final t = await _token();
    final resp = await _dio.get(
      '/api/czesci',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Part.fromJson).toList();
  }

  Future<void> adjustQuantity({required int partId, required int delta}) async {
    final t = await _token();
    await _dio.patch(
      '/api/czesci/$partId/ilosc',
      data: {'delta': delta},
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
    DateTime? dataZakupu,
    DateTime? dataRealizacji,
    double? cena,
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
        if (dataZakupu != null) 'dataZakupu': Part.isoDate(dataZakupu),
        if (dataRealizacji != null) 'dataRealizacji': Part.isoDate(dataRealizacji),
        if (cena != null) 'cena': cena,
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
    DateTime? dataZakupu,
    DateTime? dataRealizacji,
    double? cena,
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
        'dataZakupu': Part.isoDate(dataZakupu),
        'dataRealizacji': Part.isoDate(dataRealizacji),
        'cena': cena,
      },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<void> assignToMaszyna({required int partId, int? maszynaId}) async {
    final t = await _token();
    await _dio.patch(
      '/api/czesci/$partId/maszyna',
      data: {'maszynaId': maszynaId ?? 0},
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<void> deletePart(int id) async {
    final t = await _token();
    await _dio.delete(
      '/api/czesci/$id',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<Map<String, dynamic>> importExcel({
    required List<int> bytes,
    required String fileName,
  }) async {
    final t = await _token();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final resp = await _dio.post(
      '/api/czesci/import',
      data: form,
      options: Options(headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'multipart/form-data',
      }),
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<List<int>> exportExcel() async {
    final t = await _token();
    final resp = await _dio.get<List<int>>(
      '/api/czesci/export',
      options: Options(
        headers: {'Authorization': 'Bearer $t'},
        responseType: ResponseType.bytes,
      ),
    );
    return resp.data ?? const <int>[];
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu - zaloguj sie.');
    return t;
  }
}
