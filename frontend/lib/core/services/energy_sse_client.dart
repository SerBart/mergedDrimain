import 'energy_sse_client_stub.dart'
    if (dart.library.html) 'energy_sse_client_web.dart' as impl;

Stream<Map<String, dynamic>> connectEnergySse({
  required String baseUrl,
  required String token,
  required Map<String, dynamic> queryParameters,
}) => impl.connectEnergySse(
  baseUrl: baseUrl,
  token: token,
  queryParameters: queryParameters,
);

