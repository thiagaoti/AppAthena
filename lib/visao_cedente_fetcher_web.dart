import 'dart:convert';

import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> fetchVisaoCedente(Uri uri) async {
  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  final body = response.body.trim();
  if (body.isEmpty) {
    throw const FormatException('Resposta vazia');
  }
  return Map<String, dynamic>.from(jsonDecode(body));
}
