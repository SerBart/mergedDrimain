import 'package:dio/dio.dart';
import '../models/instruction.dart';
import '../services/secure_storage_service.dart';

class InstructionsApiRepository {
  final Dio _dio; final SecureStorageService _storage;
  InstructionsApiRepository(this._dio, this._storage);

  Future<List<InstructionModel>> list({int? maszynaId}) async {
    final t = await _token();
    final resp = await _dio.get(
      '/api/instrukcje',
      queryParameters: { if (maszynaId != null) 'maszynaId': maszynaId },
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    final list = (resp.data as List).cast<Map<String, dynamic>>();
    return list.map(InstructionModel.fromJson).toList();
  }

  Future<InstructionModel> getById(int id) async {
    final t = await _token();
    final resp = await _dio.get(
      '/api/instrukcje/$id',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    return InstructionModel.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<InstructionModel> create({
    required String title,
    String? description,
    required int maszynaId,
    required List<Map<String, dynamic>> parts, // [{partId, ilosc}]
  }) async {
    final t = await _token();
    final body = {
      'title': title,
      if (description != null) 'description': description,
      'maszynaId': maszynaId,
      'parts': parts,
    };
    final resp = await _dio.post(
      '/api/instrukcje',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
    return InstructionModel.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  Future<void> uploadAttachments({required int instructionId, required List<MultipartFile> files}) async {
    if (files.isEmpty) return;
    final t = await _token();
    final form = FormData.fromMap({
      'files': files,
    });
    await _dio.post(
      '/api/instrukcje/$instructionId/attachments',
      data: form,
      options: Options(headers: {
        'Authorization': 'Bearer $t',
        // multipart
        'Content-Type': 'multipart/form-data',
      }),
    );
  }

  Future<void> deleteInstruction(int id) async {
    final t = await _token();
    await _dio.delete(
      '/api/instrukcje/$id',
      options: Options(headers: {'Authorization': 'Bearer $t'}),
    );
  }

  Future<String> _token() async {
    final t = await _storage.readToken();
    if (t == null || t.isEmpty) throw Exception('Brak tokenu – zaloguj się.');
    return t;
  }
}
