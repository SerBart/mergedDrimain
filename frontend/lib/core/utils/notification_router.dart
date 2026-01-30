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
/// ZAWSZE kieruje do listy modułu (np. /zgloszenia, /raporty), nigdy do szczegółów
String routeFromNotificationModel(NotificationModel n) {
  final raw = (n.link ?? '').trim();

  final combined = ('${n.module ?? ''} ${n.type ?? ''} ${n.title ?? ''} ${n.message ?? ''} ${raw}').toLowerCase();
  final normalized = _normalize(combined);

  // Najpierw sprawdzaj moduł - zawsze kieruj do listy, ignoruj konkretne ID
  if (raw.isNotEmpty) {
    if (raw.contains('zglos')) return '/zgloszenia';
    if (raw.contains('raport')) return '/raporty';
    if (raw.contains('harmonogram')) return '/harmonogramy';
    if (raw.contains('przegl')) return '/przeglady';
  }

  // Heuristic fallback by content (normalized diacritics)
  if (normalized.contains('zglos')) return '/zgloszenia';
  if (normalized.contains('raport')) return '/raporty';
  if (normalized.contains('harmonogram')) return '/harmonogramy';
  if (normalized.contains('przegl')) return '/przeglady';

  return '/notifications';
}
