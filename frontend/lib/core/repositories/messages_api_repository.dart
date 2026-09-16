import 'package:dio/dio.dart';

import '../models/direct_message.dart';
import '../models/message_contact.dart';
import '../services/secure_storage_service.dart';

class MessagesApiRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  MessagesApiRepository(this._dio, this._storage);

  Future<List<MessageContact>> fetchContacts() async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/messages/contacts',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(MessageContact.fromJson).toList();
  }

  Future<List<DirectMessage>> fetchThread(int userId, {int limit = 100}) async {
    final token = await _readToken();
    final resp = await _dio.get(
      '/api/messages/thread/$userId',
      queryParameters: {'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(DirectMessage.fromJson).toList();
  }

  Future<DirectMessage> sendMessage({required int recipientUserId, required String content}) async {
    final token = await _readToken();
    final resp = await _dio.post(
      '/api/messages',
      data: {
        'recipientUserId': recipientUserId,
        'content': content,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return DirectMessage.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<int> markThreadRead(int userId) async {
    final token = await _readToken();
    final resp = await _dio.post(
      '/api/messages/thread/$userId/read',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = (resp.data as Map).cast<String, dynamic>();
    return (data['marked'] as num?)?.toInt() ?? 0;
  }

  Future<String> _readToken() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Brak tokenu - zaloguj się ponownie.');
    }
    return token;
  }
}

