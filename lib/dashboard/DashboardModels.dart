// ignore_for_file: file_names

class DashboardModel {
  final double riscoTotal;
  final double limite;
  final double vencidos;
  final int qtdCedentes;

  final List<GraficoModel> grafico;
  final List<GerenteModel> gerentes;

  DashboardModel({
    required this.riscoTotal,
    required this.limite,
    required this.vencidos,
    required this.qtdCedentes,
    required this.grafico,
    required this.gerentes,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      riscoTotal: (json['riscoTotal'] ?? 0).toDouble(),
      limite: (json['limite'] ?? 0).toDouble(),
      vencidos: (json['vencidos'] ?? 0).toDouble(),
      qtdCedentes: json['qtdCedentes'] ?? 0,
      grafico: (json['grafico'] as List? ?? [])
          .map((e) => GraficoModel.fromJson(e))
          .toList(),
      gerentes: (json['gerentes'] as List? ?? [])
          .map((e) => GerenteModel.fromJson(e))
          .toList(),
    );
  }
}

class GraficoModel {
  final String ramo;
  final double valor;

  GraficoModel({required this.ramo, required this.valor});

  factory GraficoModel.fromJson(Map<String, dynamic> json) {
    return GraficoModel(
      ramo: json['ramo'],
      valor: (json['valor'] ?? 0).toDouble(),
    );
  }
}

class GerenteModel {
  final String nome;
  final List<EmpresaModel> empresas;

  GerenteModel({
    required this.nome,
    required this.empresas,
  });

  factory GerenteModel.fromJson(Map<String, dynamic> json) {
    return GerenteModel(
      nome: json['nome'],
      empresas: (json['empresas'] as List? ?? [])
          .map((e) => EmpresaModel.fromJson(e))
          .toList(),
    );
  }
}

class EmpresaModel {
  final String nome;
  final double risco;
  final double limite;
  final double vencido;

  EmpresaModel({
    required this.nome,
    required this.risco,
    required this.limite,
    required this.vencido,
  });

  factory EmpresaModel.fromJson(Map<String, dynamic> json) {
    return EmpresaModel(
      nome: json['nome'],
      risco: (json['risco'] ?? 0).toDouble(),
      limite: (json['limite'] ?? 0).toDouble(),
      vencido: (json['vencido'] ?? 0).toDouble(),
    );
  }
}
