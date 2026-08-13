import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_html.dart' as impl;

bool downloadBytesAsFile({
  required String fileName,
  required String mimeType,
  required List<int> bytes,
}) {
  return impl.downloadBytesAsFile(
    fileName: fileName,
    mimeType: mimeType,
    bytes: bytes,
  );
}

