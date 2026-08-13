import 'dart:convert';
import 'dart:html' as html;

bool downloadBytesAsFile({
  required String fileName,
  required String mimeType,
  required List<int> bytes,
}) {
  try {
    if (bytes.isEmpty) return false;
    final data = base64Encode(bytes);
    final href = 'data:$mimeType;base64,$data';
    final anchor = html.AnchorElement(href: href)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}

