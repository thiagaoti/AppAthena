import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> fetchVisaoCedente(Uri uri) async {
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = response.body.trim();
    if (body.isEmpty) {
      throw const HttpException('Resposta vazia');
    }
    return Map<String, dynamic>.from(jsonDecode(body));
  } catch (_) {
    final socket = await Socket.connect(
      uri.host,
      uri.port,
      timeout: const Duration(seconds: 15),
    );

    try {
      socket.write(
        'GET ${uri.path} HTTP/1.1\r\n'
        'Host: ${uri.host}:${uri.port}\r\n'
        'Accept: application/json\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      await socket.flush();

      final respostaBruta = await utf8.decoder.bind(socket).join();
      final partes = respostaBruta.split('\r\n\r\n');
      if (partes.length < 2) {
        throw const HttpException('Resposta invalida');
      }

      final cabecalhos = partes.first.toLowerCase();
      var corpo = partes.sublist(1).join('\r\n\r\n');
      if (cabecalhos.contains('transfer-encoding: chunked')) {
        corpo = _decodificarChunked(corpo);
      }

      corpo = corpo.trim();
      if (corpo.isEmpty) {
        throw const HttpException('Resposta vazia');
      }

      return Map<String, dynamic>.from(jsonDecode(corpo));
    } finally {
      await socket.close();
    }
  }
}

String _decodificarChunked(String corpo) {
  final buffer = StringBuffer();
  var restante = corpo;

  while (restante.isNotEmpty) {
    final fimCabecalho = restante.indexOf('\r\n');
    if (fimCabecalho < 0) {
      break;
    }

    final tamanhoHex = restante.substring(0, fimCabecalho).trim();
    final tamanho = int.tryParse(tamanhoHex, radix: 16);
    if (tamanho == null) {
      return corpo;
    }

    if (tamanho == 0) {
      break;
    }

    final inicioChunk = fimCabecalho + 2;
    final fimChunk = inicioChunk + tamanho;
    if (fimChunk > restante.length) {
      return corpo;
    }

    buffer.write(restante.substring(inicioChunk, fimChunk));
    restante =
        fimChunk + 2 <= restante.length ? restante.substring(fimChunk + 2) : '';
  }

  return buffer.toString();
}
