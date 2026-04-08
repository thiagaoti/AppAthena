// ignore_for_file: file_names

class TotaisModel {
  final double riscoTotal;
  final double duplicata;
  final double fom;

  TotaisModel({
    required this.riscoTotal,
    required this.duplicata,
    required this.fom,
  });

  factory TotaisModel.fromJson(Map<String, dynamic> json) {
    return TotaisModel(
      riscoTotal: (json["riscO_TOTAL"] ?? 0).toDouble(),
      duplicata: (json["duplicata"] ?? 0).toDouble(),
      fom: (json["fom"] ?? 0).toDouble(),
    );
  }
}
