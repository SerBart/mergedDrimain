import 'platform_origin_stub.dart' if (dart.library.html) 'platform_origin_web.dart' as impl;

class PlatformOrigin {
  static String? origin() => impl.origin();
}

