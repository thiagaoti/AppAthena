import 'dart:convert';

import 'package:athenaapp/auth_session.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class OperacoesDoDiaService {
  static String _formatarDataAPI(DateTime data) {
    return DateFormat('yyyy-MM-ddTHH:mm:ss').format(data);
  }

  static Future<List<Map<String, dynamic>>> buscar(
    DateTime data, {
    required AuthSession sessao,
  }) async {
    final urlOperacoes = Uri.parse(
      'https://athenaapp.athenabanco.com.br/api/App/operdia?data=${_formatarDataAPI(data)}',
    );
    final urlCedentes = Uri.parse(
      'https://athenaapp.athenabanco.com.br/api/Dash/ListaCedentes',
    );

    final respostas = await Future.wait([
      http.get(urlOperacoes).timeout(const Duration(seconds: 15)),
      http.get(urlCedentes).timeout(const Duration(seconds: 15)),
    ]);

    final response = respostas[0];
    final responseCedentes = respostas[1];

    if (response.statusCode != 200) {
      throw Exception('Erro ao carregar operacoes do dia');
    }

    final Map<String, dynamic> jsonCompleto = json.decode(response.body);
    final valores = jsonCompleto['dados']?['\$values'];
    if (valores is! List) {
      return const [];
    }

    final mapaCedentes = <String, Map<String, dynamic>>{};
    final mapaCedentesPorNome = <String, Map<String, dynamic>>{};
    if (responseCedentes.statusCode == 200) {
      final Map<String, dynamic> jsonCedentes = json.decode(responseCedentes.body);
      final valoresCedentes = jsonCedentes['dados']?['\$values'];
      if (valoresCedentes is List) {
        for (final item in valoresCedentes.whereType<Map>()) {
          final mapa = Map<String, dynamic>.from(item);
          final cnpj = _normalizarCnpj(mapa['cgc'] ?? mapa['cnpj']);
          final nome = _normalizarNome(mapa['cedente'] ?? mapa['nome']);
          if (cnpj.isNotEmpty) {
            mapaCedentes[cnpj] = mapa;
          }
          if (nome.isNotEmpty) {
            mapaCedentesPorNome[nome] = mapa;
          }
        }
      }
    }

    final registros = valores
        .whereType<Map>()
        .map((item) {
          final mapa = Map<String, dynamic>.from(item);
          final cnpj = _normalizarCnpj(
            mapa['cgc'] ??
                mapa['cnpj'] ??
                mapa['cpfCnpj'] ??
                mapa['documento'],
          );
          final nomeCedente = _normalizarNome(
            mapa['cedente'] ?? mapa['nome'] ?? mapa['sacado'],
          );
          final cadastroCedente =
              mapaCedentes[cnpj] ?? mapaCedentesPorNome[nomeCedente];
          return {
            ...mapa,
            'empresa':
                mapa['empresa'] ??
                mapa['codigoErp'] ??
                mapa['codigoERP'] ??
                cadastroCedente?['empresa'] ??
                cadastroCedente?['codigoErp'] ??
                cadastroCedente?['CodigoERP'] ??
                '',
            'codigoErp':
                mapa['codigoErp'] ??
                mapa['codigoERP'] ??
                cadastroCedente?['codigoErp'] ??
                cadastroCedente?['CodigoERP'] ??
                cadastroCedente?['empresa'] ??
                '',
            'codGerente':
                mapa['codGerente'] ?? cadastroCedente?['codGerente'] ?? '',
            'gerente': mapa['gerente'] ?? cadastroCedente?['gerente'] ?? '',
            'plat':
                cadastroCedente?['codPlataforma'] ??
                mapa['codPlataforma'] ??
                mapa['plat'] ??
                '',
            'codPlataforma':
                mapa['codPlataforma'] ?? cadastroCedente?['codPlataforma'] ?? '',
            'plataforma':
                cadastroCedente?['plataforma'] ??
                mapa['plataforma'] ??
                '',
          };
        })
        .toList(growable: false);

    return sessao.filtrarRegistros(registros);
  }

  static String _normalizarCnpj(dynamic valor) {
    return (valor ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String _normalizarNome(dynamic valor) {
    final texto = AuthSession.normalizarValor(valor);
    return texto.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
