// ignore_for_file: file_names

class AnaliticoModel {
  final String? cnpj;
  final double duplicata;
  final double riscoTotalTodosBancos;

  AnaliticoModel({
    this.cnpj,
    required this.duplicata,
    required this.riscoTotalTodosBancos,
  });

  factory AnaliticoModel.fromJson(Map<String, dynamic> json) {
    return AnaliticoModel(
      cnpj: json["cnpj"],
      duplicata: (json["duplicata"] ?? 0).toDouble(),
      riscoTotalTodosBancos:
          (json["riscO_TOTAL_TODOS_BANCOS"] ?? 0).toDouble(),
    );
  }
}
