Stream<Map<String, dynamic>> connectEnergySse({
  required String baseUrl,
  required String token,
  required Map<String, dynamic> queryParameters,
}) {
  throw UnsupportedError('Browser SSE client is only available on web.');
}

