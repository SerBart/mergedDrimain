import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Stream<Map<String, dynamic>> connectEnergySse({
  required String baseUrl,
  required String token,
  required Map<String, dynamic> queryParameters,
}) {
  final controller = StreamController<Map<String, dynamic>>();
  final uri = _buildUri(
    baseUrl: baseUrl,
    token: token,
    queryParameters: queryParameters,
  );

  final eventSource = html.EventSource(
    uri.toString(),
    withCredentials: true,
  );

  final subscriptions = <StreamSubscription<dynamic>>[];

  void emitPayload(dynamic rawData) {
    if (rawData == null) return;
    try {
      if (rawData is Map) {
        controller.add(rawData.cast<String, dynamic>());
        return;
      }
      if (rawData is String && rawData.trim().isNotEmpty) {
        controller.add((jsonDecode(rawData) as Map).cast<String, dynamic>());
      }
    } catch (_) {
      // Ignore malformed payload and keep the stream alive.
    }
  }

  subscriptions.add(eventSource.onMessage.listen((event) {
    emitPayload(event.data);
  }));

  for (final eventName in const ['INIT', 'ENERGY_UPDATE']) {
    final provider = html.EventStreamProvider<html.MessageEvent>(eventName);
    subscriptions.add(provider.forTarget(eventSource).listen((event) {
      emitPayload(event.data);
    }));
  }

  final heartbeatProvider = html.EventStreamProvider<html.MessageEvent>('HEARTBEAT');
  subscriptions.add(heartbeatProvider.forTarget(eventSource).listen((_) {
    // Keep-alive event; nothing to do.
  }));

  subscriptions.add(eventSource.onError.listen((_) {
    if (eventSource.readyState == html.EventSource.CLOSED && !controller.isClosed) {
      controller.addError(StateError('SSE connection closed'));
    }
  }));

  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    eventSource.close();
  };

  return controller.stream;
}

Uri _buildUri({
  required String baseUrl,
  required String token,
  required Map<String, dynamic> queryParameters,
}) {
  final baseUri = Uri.parse(baseUrl);
  var path = baseUri.path;
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.endsWith('/api')) {
    path = '$path/energia/stream';
  } else {
    path = '$path/api/energia/stream';
  }
  if (path.isEmpty) {
    path = '/api/energia/stream';
  }

  final qp = <String, String>{
    ...baseUri.queryParameters,
    for (final entry in queryParameters.entries)
      if (entry.value != null) entry.key: '${entry.value}',
    if (token.trim().isNotEmpty) 'token': token.trim(),
  };

  return baseUri.replace(
    path: path,
    queryParameters: qp.isEmpty ? null : qp,
  );
}

