import 'dart:convert';
import 'package:web/web.dart' as web;

bool downloadBytesAsFile({
  required String fileName,
  required String mimeType,
  required List<int> bytes,
}) {
  try {
    if (bytes.isEmpty) return false;
    final data = base64Encode(bytes);
    final href = 'data:$mimeType;base64,$data';
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = href
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}

