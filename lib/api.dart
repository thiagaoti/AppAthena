import 'dart:convert';
import 'package:athenaapp/dashboard/AnaliticoModels.dart';
import 'package:athenaapp/dashboard/PlataformaModels.dart';
import 'package:athenaapp/dashboard/RamoModels.dart';
import 'package:athenaapp/dashboard/TotaisModels.dart';
import 'package:http/http.dart' as http;

class Api {
  static const String baseUrl = "http://177.69.57.196:8083/api/Dash";

  // 🔥 helper pra tratar JSON do .NET
  static dynamic _extractData(dynamic json) {
    if (json is Map && json.containsKey("dados")) {
      final dados = json["dados"];

      if (dados is Map && dados.containsKey("\$values")) {
        return dados["\$values"];
      }

      return dados;
    }
    return json;
  }

  // ================================
  // 📊 TOTAIS GERAIS
  // ================================
  static Future<TotaisModel> getTotais() async {
    final response = await http.get(Uri.parse("$baseUrl/TotaisGerais"));

    final json = jsonDecode(response.body);
    final data = _extractData(json);

    return TotaisModel.fromJson(data);
  }

  // ================================
  // 🟡 PLATAFORMAS (lista cedentes)
  // ================================
  static Future<List<PlataformaModel>> getPlataformas() async {
    final response = await http.get(Uri.parse("$baseUrl/ListaCedentes"));

    final json = jsonDecode(response.body);
    final data = _extractData(json);

    return List.from(data)
        .map((e) => PlataformaModel.fromJson(e))
        .toList();
  }

  // ================================
  // 📋 ANALITICO PAGINADO
  // ================================
  static Future<List<AnaliticoModel>> getAnalitico(int pagina) async {
    final url =
        "$baseUrl/AnaliticoPaginado?pagina=$pagina&tamanho=20";

    final response = await http.get(Uri.parse(url));

    final json = jsonDecode(response.body);
    final data = _extractData(json);

    return List.from(data)
        .map((e) => AnaliticoModel.fromJson(e))
        .toList();
  }

  // ================================
  // 📊 POR RAMO
  // ================================
  static Future<List<RamoModel>> getRamos() async {
    final response = await http.get(Uri.parse("$baseUrl/ResumoPorRamo"));

    final json = jsonDecode(response.body);
    final data = _extractData(json);

    return List.from(data)
        .map((e) => RamoModel.fromJson(e))
        .toList();
  }
}