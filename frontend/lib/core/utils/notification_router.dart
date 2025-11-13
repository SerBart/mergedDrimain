import 'package:characters/characters.dart';
import '../models/notification.dart';

String _normalize(String input) {
  final map = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ż': 'z',
    'ź': 'z',
    'Ą': 'A',
    'Ć': 'C',
    'Ę': 'E',
    'Ł': 'L',
    'Ń': 'N',
    'Ó': 'O',
    'Ś': 'S',
    'Ż': 'Z',
    'Ź': 'Z',
  };
  final sb = StringBuffer();
  for (final ch in input.characters) {
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

/// Mapuje `NotificationModel` (jego pola module/type/title/message/link)
/// na ścieżkę w aplikacji.
/// Zwraca domyślnie '/notifications' gdy nie rozpoznano celu.
String routeFromNotificationModel(NotificationModel n) {
  final raw = (n.link ?? '').trim();
  String path = '';
  if (raw.isNotEmpty) {
    try {
      final uri = Uri.parse(raw);
      if (uri.hasScheme)
        path = uri.path;
      else
        path = raw;
    } catch (_) {
      path = raw;
    }
  }

  final combined = ('${n.module ?? ''} ${n.type ?? ''} ${n.title ?? ''} ${n.message ?? ''} ${path}').toLowerCase();
  final normalized = _normalize(combined);

  // prefer explicit path when present
  if (path.isNotEmpty) {
    if (path.contains('/zglos')) {
      return path.contains('/zgloszenia/') ? path : '/zgloszenia';
    }
    if (path.contains('/harmonogram')) {
      return path.contains('/harmonogramy/') ? path : '/harmonogramy';
    }
    if (path.contains('/przegl')) {
      return (path.contains('/przeglady/') || path.contains('/przeglad/')) ? path : '/przeglady';
    }
    if (path.startsWith('/')) return path;
  }

  // heuristic fallback by content (normalized diacritics)
  if (normalized.contains('zglos')) return '/zgloszenia';
  if (normalized.contains('harmonogram')) return '/harmonogramy';
  if (normalized.contains('przegl')) return '/przeglady';

  return '/notifications';
}
