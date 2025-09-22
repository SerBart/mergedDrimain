import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient() {
    // Czytamy bazowy URL API z --dart-define=API_BASE (np. http://localhost:8080)
    // Gdy brak, domyślnie używamy same-origin "/api" (Flutter SPA serwowane przez Spring Boot).
    const apiBaseEnv = String.fromEnvironment('API_BASE', defaultValue: '');
    String baseUrl;
    if (apiBaseEnv.isNotEmpty) {
      baseUrl = apiBaseEnv.endsWith('/api') ? apiBaseEnv : '$apiBaseEnv/api';
    } else {
      baseUrl = '/api';
    }

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    return ApiClient._(dio);
  }

  // Ustawianie / czyszczenie nagłówka Authorization
  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Dio get dio => _dio;
}