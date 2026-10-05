import 'package:web/web.dart' as web;

void navigateToDashboardWeb() {
  try {
    // Use absolute path — causes full page reload to dashboard
    web.window.location.href = '/dashboard';
  } catch (_) {}
}

void reloadCurrentPage() {
  try {
    web.window.location.reload();
  } catch (_) {}
}

