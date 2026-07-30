import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/browser.dart';
import '../util/platform_origin.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient({String? baseUrl}) {
    // Prefer explicit param, then build-time define, then web origin, finally localhost
    final defineBase = const String.fromEnvironment('API_BASE', defaultValue: '');

    String resolvedBaseUrl = baseUrl ?? defineBase;

    if (kIsWeb) {
      final origin = PlatformOrigin.origin();
      if (_isLocalOrigin(origin)) {
        // For local web development always use same-origin API to avoid CORS.
        resolvedBaseUrl = origin!;
      }
    }

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

    if (kIsWeb) {
      final adapter = BrowserHttpClientAdapter()..withCredentials = true;
      dio.httpClientAdapter = adapter;
    }

    return ApiClient._(dio);
  }

  Dio get dio => _dio;

  static bool _isLocalOrigin(String? origin) {
    if (origin == null || origin.isEmpty) return false;
    final uri = Uri.tryParse(origin);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1';
  }
}