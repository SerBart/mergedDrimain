import 'package:dio/dio.dart';
import '../models/notification.dart';
import '../services/secure_storage_service.dart';

class NotificationsApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  NotificationsApiRepository(this._dio, this._storage);

  Future<List<NotificationModel>> fetchAll() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/notifications',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map((m) => NotificationModel.fromJson(m)).toList();
  }

  Future<List<NotificationModel>> markAllRead() async {
    final token = await _readToken();
    final resp = await _dio.post(
      '/api/notifications/mark-all-read',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map((m) => NotificationModel.fromJson(m)).toList();
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu — zaloguj się ponownie.');
    }
    return token;
  }
}
