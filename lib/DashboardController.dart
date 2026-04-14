// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardController extends ChangeNotifier {
  double riscoTotal = 0;
  double limite = 0;
  double vencidos = 0;
  int qtdCedentes = 0;
  List<Map<String, dynamic>> resumoRamo = [];
    
  List<Map<String, dynamic>> baseCedentesCompleta = [];
  
  // Lista processada para a UI de Plataformas
  List<Map<String, dynamic>> resumoPlataforma = [];
  
  bool carregando = false;

  // Chamado pela MainPage. Faz o merge e já prepara o agrupamento por Plataforma
  void setBase(List<Map<String, dynamic>> base) {
    baseCedentesCompleta = base;
    _gerarResumoPlataformas(); // Processa os dados assim que chegam
    notifyListeners(); 
  }

  // Agrupa os cedentes da base completa por Gerente/Plataforma
  void _gerarResumoPlataformas() {
    final Map<String, double> agrupado = {};
    
    for (var c in baseCedentesCompleta) {
      // Ajuste o nome da chave conforme vier da sua API (ex: 'plataforma' ou 'gerente')
      String plat = c['plataforma']?.toString().toUpperCase() ?? 'NÃO IDENTIFICADO';
      double risco = (c['risco'] ?? 0).toDouble();
      
      agrupado[plat] = (agrupado[plat] ?? 0) + risco;
    }

    resumoPlataforma = agrupado.entries.map((e) => {
      'plataforma': e.key,
      'riscO_TOTAL': e.value
    }).toList();

    // Ordena do maior risco para o menor
    resumoPlataforma.sort((a, b) => b['riscO_TOTAL'].compareTo(a['riscO_TOTAL']));
  }

  Future<void> inicializar() async {
    await _carregarCache();
    await carregarDadosCompletos();
  }

  Future<void> _carregarCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dadosSalvos = prefs.getString('cache_totais');
    final String? ramosSalvos = prefs.getString('cache_ramos');

    if (dadosSalvos != null) {
      _mapearTotais(jsonDecode(dadosSalvos));
    }
    if (ramosSalvos != null) {
      resumoRamo = List<Map<String, dynamic>>.from(jsonDecode(ramosSalvos));
    }
    notifyListeners();
  }

  Future<void> carregarDadosCompletos() async {
    if (riscoTotal == 0) {
      carregando = true;
      notifyListeners();
    }

    try {
      final resultados = await Future.wait([
        http.get(Uri.parse('https://athenaapp.athenabanco.com.br/api/Dash/TotaisGerais')),
        http.get(Uri.parse('https://athenaapp.athenabanco.com.br/api/Dash/ResumoPorRamo')),
      ]).timeout(const Duration(seconds: 10));

      final resTotais = resultados[0];
      final resRamos = resultados[1];
      final prefs = await SharedPreferences.getInstance();

      if (resTotais.statusCode == 200) {
        final d = jsonDecode(resTotais.body)['dados'];
        _mapearTotais(d);
        await prefs.setString('cache_totais', jsonEncode(d));
      }

      if (resRamos.statusCode == 200) {
        final dataRamos = jsonDecode(resRamos.body);
        // Tratamento para o formato $values comum em APIs .NET
        final lista = List<Map<String, dynamic>>.from(dataRamos['dados']['\$values'] ?? []);
        resumoRamo = lista;
        await prefs.setString('cache_ramos', jsonEncode(lista));
      }

    } catch (e) {
      debugPrint("Erro na atualização: $e");
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  void _mapearTotais(Map<String, dynamic> d) {
    riscoTotal = (d['riscO_TOTAL'] ?? 0).toDouble();
    limite = (d['totaL_LIMITE'] ?? 0).toDouble();
    vencidos = (d['foM_VENCIDO'] ?? 0).toDouble();
    qtdCedentes = d['qtD_CLIENTES'] ?? 0;
  }
}
