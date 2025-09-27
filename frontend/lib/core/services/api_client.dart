import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../util/platform_origin.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient({String? baseUrl}) {
    // Prefer explicit param, then build-time define, then web origin, finally localhost
    final defineBase = const String.fromEnvironment('API_BASE', defaultValue: '');

    String resolvedBaseUrl = baseUrl ?? defineBase;

    if (resolvedBaseUrl.isEmpty) {
      final origin = kIsWeb ? PlatformOrigin.origin() : null;
      resolvedBaseUrl = origin ?? 'http://localhost:8080';
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: resolvedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    return ApiClient._(dio);
  }

  Dio get dio => _dio;
}