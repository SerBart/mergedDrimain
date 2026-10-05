import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Stream<Map<String, dynamic>> connectEnergySse({
  required String baseUrl,
  required String token,
  required Map<String, dynamic> queryParameters,
}) {
  late final StreamController<Map<String, dynamic>> controller;
  final uri = _buildUri(
    baseUrl: baseUrl,
    token: token,
    queryParameters: queryParameters,
  );
  final eventSource = html.EventSource(uri.toString());
  final listeners = <MapEntry<String, html.EventListener>>[];
  var closed = false;

  void emitPayload(dynamic rawData) {
    if (rawData == null) return;

    try {
      if (rawData is Map) {
        controller.add(rawData.cast<String, dynamic>());
        return;
      }

      if (rawData is String && rawData.trim().isNotEmpty) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) {
          controller.add(decoded.cast<String, dynamic>());
        }
      }
    } catch (_) {
      // Ignore malformed payloads and keep the stream alive.
    }
  }

  void addListener(String eventName, void Function(html.MessageEvent event) handler) {
    final listener = (html.Event event) {
      if (event is html.MessageEvent) {
        handler(event);
      }
    };
    listeners.add(MapEntry(eventName, listener));
    eventSource.addEventListener(eventName, listener);
  }

  void closeConnection() {
    if (closed) return;
    closed = true;

    for (final listener in listeners) {
      eventSource.removeEventListener(listener.key, listener.value);
    }

    eventSource.close();

    if (!controller.isClosed) {
      controller.close();
    }
  }

  controller = StreamController<Map<String, dynamic>>(
    onCancel: closeConnection,
  );

  addListener('INIT', (event) {
    emitPayload(event.data);
  });

  addListener('ENERGY_UPDATE', (event) {
    emitPayload(event.data);
  });

  addListener('HEARTBEAT', (_) {
    // Backend keep-alive ping; no payload to emit.
  });

  addListener('error', (_) {
    if (!controller.isClosed) {
      controller.addError(StateError('SSE connection error/closed'));
    }
    closeConnection();
  });

  return controller.stream;
}

Uri _buildUri({
  required String baseUrl,
  required String token,
  required Map<String, dynamic> queryParameters,
}) {
  final uri = Uri.parse(baseUrl).resolve('/api/energia/stream');
  final qp = <String, String>{
    'token': token,
    for (final entry in queryParameters.entries)
      if (entry.value != null) entry.key: entry.value.toString(),
  };
  return uri.replace(queryParameters: qp);
}
