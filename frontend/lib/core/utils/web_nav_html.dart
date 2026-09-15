import 'dart:html' as html;

void navigateToDashboardWeb() {
  try {
    // Use absolute path — causes full page reload to dashboard
    html.window.location.href = '/dashboard';
  } catch (_) {}
}

void reloadCurrentPage() {
  try {
    html.window.location.reload();
  } catch (_) {}
}

