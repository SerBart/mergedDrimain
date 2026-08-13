import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../models/maszyna.dart';
import '../models/osoba.dart';
import '../models/dzial.dart';
import '../models/sekcja.dart';
import '../models/dashboard_kpi.dart';
import '../services/secure_storage_service.dart';

class MetaApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  MetaApiRepository(this._dio, this._storage);

  Future<List<Maszyna>> fetchMaszynySimple({int? dzialId, String? dzialNazwa}) async {
    final token = await _readToken();
    final qp = <String, dynamic>{};
    if (dzialId != null) qp['dzialId'] = dzialId;
    if (dzialNazwa != null && dzialNazwa.isNotEmpty) qp['dzialNazwa'] = dzialNazwa;
    final resp = await _dio.get(
      '/api/meta/maszyny-simple',
      queryParameters: qp.isEmpty ? null : qp,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Maszyna.fromJson).toList();
  }

  Future<List<Osoba>> fetchOsobySimple({int? dzialId, String? dzialNazwa}) async {
    final token = await _readToken();
    final qp = <String, dynamic>{};
    if (dzialId != null) qp['dzialId'] = dzialId;
    if (dzialNazwa != null && dzialNazwa.isNotEmpty) qp['dzialNazwa'] = dzialNazwa;
    final resp = await _dio.get(
      '/api/meta/osoby-simple',
      queryParameters: qp.isEmpty ? null : qp,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Osoba.fromJson).toList();
  }

  // New: fetch simple departments list for forms
  Future<List<Dzial>> fetchDzialySimple() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/meta/dzialy-simple',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Dzial.fromJson).toList();
  }

  Future<List<Sekcja>> fetchSekcjeSimple({int? dzialId}) async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/meta/sekcje-simple',
      queryParameters: dzialId != null ? {'dzialId': dzialId} : null,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(Sekcja.fromJson).toList();
  }

  Future<DashboardKpi> fetchDashboardKpi({int days = 7}) async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/meta/dashboard-kpi',
      queryParameters: {'days': days},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return DashboardKpi.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<String> fetchDashboardKpiCsv({int days = 7}) async {
    final token = await _readToken();
    final resp = await _dio.get<String>(
      '/api/meta/dashboard-kpi/export',
      queryParameters: {'days': days},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.plain,
      ),
    );
    return resp.data ?? '';
  }

  Future<Uint8List> fetchDashboardKpiPdf({int days = 7}) async {
    final token = await _readToken();
    final resp = await _dio.get<List<int>>(
      '/api/meta/dashboard-kpi/export.pdf',
      queryParameters: {'days': days},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(resp.data ?? const <int>[]);
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}
