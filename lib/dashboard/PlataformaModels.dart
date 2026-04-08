// ignore_for_file: file_names

class PlataformaModel {
  final String? cgc;
  final String? cedente;
  final String? plataforma;
  final int? plat;

  PlataformaModel({
    this.cgc,
    this.cedente,
    this.plataforma,
    this.plat,
  });

  factory PlataformaModel.fromJson(Map<String, dynamic> json) {
    return PlataformaModel(
      cgc: json["cgc"],
      cedente: json["cedente"],
      plataforma: json["plataforma"],
      plat: json["plat"],
    );
  }
}
