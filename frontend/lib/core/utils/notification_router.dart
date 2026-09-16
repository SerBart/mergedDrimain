import '../models/notification.dart';

String routeFromNotificationModel(NotificationModel n) {
  final direct = (n.link ?? '').trim();

  // Backward compatibility: old notifications used /raporty/{id},
  // but app routes use /raport/edytuj/{id}.
  final raportLegacy = RegExp(r'^/raporty/(\d+)$').firstMatch(direct);
  if (raportLegacy != null) {
    return '/raport/edytuj/${raportLegacy.group(1)}';
  }

  if (direct.startsWith('/')) {
    return direct;
  }

  final raw = [n.module, n.type, n.title, n.message]
      .whereType<String>()
      .join(' ')
      .toLowerCase();
  final normalized = _normalize(raw);

  if (raw.contains('message') || raw.contains('wiadom') || normalized.contains('wiadom')) {
    return '/messages';
  }
  if (raw.contains('announc') || raw.contains('oglosz') || normalized.contains('oglosz')) {
    return '/announcements';
  }
  if (raw.contains('zglosz') || normalized.contains('zglosz')) {
    return '/zgloszenia';
  }
  if (raw.contains('raport')) {
    return '/raporty';
  }
  if (raw.contains('harmonogram')) {
    return '/harmonogramy';
  }
  if (raw.contains('przegl')) {
    return '/przeglady';
  }

  return '/notifications';
}

String _normalize(String input) {
  return input
      .replaceAll('ą', 'a')
      .replaceAll('ć', 'c')
      .replaceAll('ę', 'e')
      .replaceAll('ł', 'l')
      .replaceAll('ń', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ś', 's')
      .replaceAll('ż', 'z')
      .replaceAll('ź', 'z');
}
