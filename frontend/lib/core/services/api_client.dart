import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient({String? baseUrl}) {
    // Czytaj adres API z --dart-define=API_BASE, fallback na localhost
    final resolvedBaseUrl = baseUrl ??
        const String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080');

    final dio = Dio(BaseOptions(
      baseUrl: resolvedBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    return ApiClient._(dio);
  }

  Dio get dio => _dio;
}