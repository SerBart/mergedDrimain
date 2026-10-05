import 'platform_origin_stub.dart'
    if (dart.library.js_interop) 'platform_origin_web.dart' as impl;

class PlatformOrigin {
  static String? origin() => impl.origin();

  static String? runtimeApiBase() => impl.runtimeApiBase();

}
