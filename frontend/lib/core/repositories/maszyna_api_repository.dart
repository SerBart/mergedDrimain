import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/maszyna.dart';

class MaszynaApiRepository {
  final String baseUrl;
  MaszynaApiRepository({required this.baseUrl});

  Future<List<Maszyna>> fetchMaszyny() async {
    final response = await http.get(Uri.parse('$baseUrl/api/meta/maszyny-simple'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Maszyna.fromJson(json)).toList();
    } else {
      throw Exception('Nie udało się pobrać maszyn: ${response.statusCode}');
    }
  }
}

