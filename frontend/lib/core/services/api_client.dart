import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/browser.dart';
import '../util/platform_origin.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient({String? baseUrl, void Function(String token)? onTokenRefreshed, Future<String?> Function()? refreshTokenCallback}) {
    // Prefer explicit param, then runtime config, then build-time define, then web-aware fallback, finally localhost
    final runtimeBase = kIsWeb ? PlatformOrigin.runtimeApiBase() : null;
    final defineBase = const String.fromEnvironment('API_BASE', defaultValue: '');

    String resolvedBaseUrl = baseUrl ?? runtimeBase ?? defineBase;

    if (kIsWeb) {
      final origin = PlatformOrigin.origin();
      if (_isLocalOrigin(origin)) {
        // For local web development always use same-origin API to avoid CORS.
        resolvedBaseUrl = origin!;
      } else if (resolvedBaseUrl.isEmpty) {
        resolvedBaseUrl = _defaultWebApiBase(origin);
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

    // Dodaję Interceptor do obsługi 401 i odświeżania tokenu
    if (refreshTokenCallback != null) {
      dio.interceptors.add(
        _AuthInterceptor(refreshTokenCallback, onTokenRefreshed),
      );
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

  static String _defaultWebApiBase(String? origin) {
    final uri = origin != null ? Uri.tryParse(origin) : null;
    final host = uri?.host.toLowerCase();

    if (host == null || host.isEmpty) {
      return 'https://app.drimain.com';
    }

    if (host == 'app.drimain.com' || host == 'mergeddrimain-production.up.railway.app') {
      return origin!;
    }

    if (host.endsWith('.up.railway.app') || host.startsWith('site-')) {
      return 'https://app.drimain.com';
    }

    return origin!;
  }
}

/// Interceptor obsługujący wygaśnięte tokeny JWT (401 błędy)
class _AuthInterceptor extends Interceptor {
  final Future<String?> Function() _refreshTokenCallback;
  final void Function(String token)? _onTokenRefreshed;

  _AuthInterceptor(this._refreshTokenCallback, this._onTokenRefreshed);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Jeśli jest 401, spróbuj odświeżyć token
    if (err.response?.statusCode == 401) {
      try {
        final newToken = await _refreshTokenCallback();
        if (newToken != null && newToken.isNotEmpty) {
          _onTokenRefreshed?.call(newToken);

          // Powtórz oryginalny request z nowym tokenem
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';

          final response = await err.requestOptions.dio.request<dynamic>(
            opts.path,
            data: opts.data,
            queryParameters: opts.queryParameters,
            options: Options(
              method: opts.method,
              sendTimeout: opts.sendTimeout,
              receiveTimeout: opts.receiveTimeout,
              extra: opts.extra,
              headers: opts.headers,
              responseType: opts.responseType,
              contentType: opts.contentType,
              validateStatus: opts.validateStatus,
              receiveDataWhenStatusError: opts.receiveDataWhenStatusError,
              followRedirects: opts.followRedirects,
              maxRedirects: opts.maxRedirects,
              persistentConnection: opts.persistentConnection,
            ),
          );
          return handler.resolve(response);
        }
      } catch (e) {
        // Jeśli refresh zawiódł, pass na kolejny handler
      }
    }
    return handler.next(err);
  }
}
