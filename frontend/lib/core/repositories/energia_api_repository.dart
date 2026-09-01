import 'package:dio/dio.dart';
import 'dart:convert';

import '../models/energia.dart';
import '../services/secure_storage_service.dart';

class EnergiaApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  EnergiaApiRepository(this._dio, this._storage);

  Future<EnergyOverview> fetchOverview({
    EnergyScope scope = EnergyScope.total,
    int days = 1,
    int? dzialId,
    int? maszynaId,
  }) async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/energia/overview',
      queryParameters: {
        'scope': scope.apiValue,
        'days': days,
        if (dzialId != null) 'dzialId': dzialId,
        if (maszynaId != null) 'maszynaId': maszynaId,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return EnergyOverview.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  // SSE stream dla real-time updates
  Stream<EnergyOverview> streamOverview({
    EnergyScope scope = EnergyScope.total,
    int? dzialId,
    int? maszynaId,
  }) async* {
    try {
      final token = await _readToken();
      final resp = await _dio.get<ResponseBody>(
        '/api/energia/stream',
        queryParameters: {
          'scope': scope.apiValue,
          if (dzialId != null) 'dzialId': dzialId,
          if (maszynaId != null) 'maszynaId': maszynaId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.stream,
        ),
      );

      final stream = resp.data!.stream.transform<String>(
        const Utf8Decoder().fuse(const LineSplitter()),
      );

      await for (final line in stream) {
        if (line.isEmpty || line == ':') continue;

        // Parse SSE format: "data: {json}"
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield EnergyOverview.fromJson(json);
          } catch (e) {
            // Ignore parse errors, continue streaming
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EnergyHistoryPoint>> fetchHistory({
    EnergyScope scope = EnergyScope.total,
    int days = 7,
    int bucketMinutes = 15,
    int? dzialId,
    int? maszynaId,
  }) async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/energia/history',
      queryParameters: {
        'scope': scope.apiValue,
        'days': days,
        'bucketMinutes': bucketMinutes,
        if (dzialId != null) 'dzialId': dzialId,
        if (maszynaId != null) 'maszynaId': maszynaId,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(EnergyHistoryPoint.fromJson).toList();
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}
