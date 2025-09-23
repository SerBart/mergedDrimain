import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef TokenProvider = Future<String?> Function();
typedef TokenRefresher = Future<bool> Function();

class ApiClient {
  late final Dio dio;
  final TokenProvider tokenProvider;
  final TokenRefresher tokenRefresher;

  ApiClient({
    required String baseUrl,
    required this.tokenProvider,
    required this.tokenRefresher,
  }) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final tok = await tokenProvider();
        if (tok != null && tok.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $tok';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 &&
            (e.requestOptions.extra['retried'] != true)) {
          final ok = await tokenRefresher();
          if (ok) {
            final clone = await _retry(e.requestOptions);
            return handler.resolve(clone);
          }
        }
        handler.next(e);
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: false,
        responseHeader: false,
        error: true,
      ));
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions ro) async {
    final opts = Options(
      method: ro.method,
      headers: ro.headers,
      contentType: ro.contentType,
      responseType: ro.responseType,
      extra: {...ro.extra, 'retried': true},
    );
    return dio.request(
      ro.path,
      data: ro.data,
      queryParameters: ro.queryParameters,
      options: opts,
    );
  }
}