import 'package:flutter_test/flutter_test.dart';
import 'package:drimain_mobile/core/models/notification.dart';
import 'package:drimain_mobile/core/utils/notification_router.dart';

void main() {
  test('returns full path when link is absolute path for zgłoszenia', () {
    final n = NotificationModel(id: 1, link: '/zgloszenia/123');
    final r = routeFromNotificationModel(n);
    expect(r, '/zgloszenia/123');
  });

  test('parses URL and returns path for zgłoszenia', () {
    final n = NotificationModel(id: 2, link: 'https://example.com/zgloszenia/5');
    final r = routeFromNotificationModel(n);
    expect(r, '/zgloszenia/5');
  });

  test('heuristic detects zglos in title', () {
    final n = NotificationModel(id: 3, title: 'Nowe zgłoszenie utworzone');
    final r = routeFromNotificationModel(n);
    expect(r, '/zgloszenia');
  });

  test('heuristic detects harmonogram in message', () {
    final n = NotificationModel(id: 4, message: 'Nowy harmonogram dostępny');
    final r = routeFromNotificationModel(n);
    expect(r, '/harmonogramy');
  });

  test('heuristic detects przegl in type', () {
    final n = NotificationModel(id: 5, type: 'przeglad');
    final r = routeFromNotificationModel(n);
    expect(r, '/przeglady');
  });

  test('unknown returns notifications', () {
    final n = NotificationModel(id: 6, title: 'Something else');
    final r = routeFromNotificationModel(n);
    expect(r, '/notifications');
  });
}

