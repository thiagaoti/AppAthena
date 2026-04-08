// ignore_for_file: file_names

class RamoModel {
  final String? ramo;
  final double riscoTotal;

  RamoModel({
    this.ramo,
    required this.riscoTotal,
  });

  factory RamoModel.fromJson(Map<String, dynamic> json) {
    return RamoModel(
      ramo: json["ramo"],
      riscoTotal: (json["riscO_TOTAL"] ?? 0).toDouble(),
    );
  }
}
