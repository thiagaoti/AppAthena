import 'dart:convert';
import 'dart:typed_data';

import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/componentes/layout_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const _titPrimary = Color(0xFF0E7490);
const _titDanger = Color(0xFFDC2626);
const _titWarning = Color(0xFFF59E0B);
const _titDarkSurface = Color(0xFF17181C);
const _titDarkSurfaceAlt = Color(0xFF1C1C1E);
const _titBorderLight = Color(0xFFE2E8F0);
const _titSurfaceAltLight = Color(0xFFF8FAFC);

enum _OrdenacaoTitulosVencidos { valor, atraso }

class TelaTitulosVencidos extends StatefulWidget {
  final String cnpjCedente;
  final String nomeCedente;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;

  const TelaTitulosVencidos({
    super.key,
    required this.cnpjCedente,
    required this.nomeCedente,
    required this.sessao,
    this.aoTrocarPerfil,
  });

  @override
  State<TelaTitulosVencidos> createState() => _TelaTitulosVencidosState();
}

class _TelaTitulosVencidosState extends State<TelaTitulosVencidos> {
  bool _carregando = true;
  int _limiteGrupos = 10;
  List<Map<String, dynamic>> _titulos = const [];
  final Set<String> _sacadosExpandidos = <String>{};
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';
  _OrdenacaoTitulosVencidos _ordenacao =
      _OrdenacaoTitulosVencidos.valor;
  String? _grupoExportandoId;
  bool _exportandoResumo = false;

  @override
  void initState() {
    super.initState();
    _carregarTitulos();
  }

  Future<void> _carregarTitulos() async {
    setState(() => _carregando = true);
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://athenaapp.athenabanco.com.br/api/App/titulosvencidos?cnpj=${widget.cnpjCedente}',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Erro ao carregar titulos vencidos');
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> valores = json['dados']?['\$values'] ?? const [];

      if (!mounted) return;

      setState(() {
        _titulos = valores
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        _limiteGrupos = 10;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar os titulos vencidos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _moeda(double valor) {
    return NumberFormat.simpleCurrency(
      locale: 'pt_BR',
      decimalDigits: 2,
    ).format(valor);
  }

  DateTime? _parseData(dynamic value) {
    if (value == null) return null;
    final texto = value.toString().trim();
    if (texto.isEmpty) return null;
    return DateTime.tryParse(texto)?.toLocal();
  }

  String _formatarData(dynamic value) {
    final data = _parseData(value);
    if (data == null) return '--';
    return DateFormat('dd/MM/yyyy').format(data);
  }

  int? _diasEmAtraso(dynamic value) {
    final data = _parseData(value);
    if (data == null) return null;
    final hoje = DateTime.now();
    final base = DateTime(hoje.year, hoje.month, hoje.day);
    final alvo = DateTime(data.year, data.month, data.day);
    return base.difference(alvo).inDays;
  }

  bool _mesmaData(dynamic a, dynamic b) {
    final dataA = _parseData(a);
    final dataB = _parseData(b);
    if (dataA == null || dataB == null) return false;
    return dataA.year == dataB.year &&
        dataA.month == dataB.month &&
        dataA.day == dataB.day;
  }

  List<Map<String, dynamic>> _outrosTitulosMesmaRaiz(
    Map<String, dynamic> titulo,
    List<Map<String, dynamic>> todosTitulos,
  ) {
    final raiz = (titulo['raiz'] ?? '').toString().trim();
    if (raiz.isEmpty) return const [];

    final itens = todosTitulos.where((item) {
      final mesmaRaiz = (item['raiz'] ?? '').toString().trim() == raiz;
      final mesmoBordero = (item['bordero'] ?? '').toString() ==
          (titulo['bordero'] ?? '').toString();
      final mesmaDuplicata = (item['duplicatas'] ?? '').toString() ==
          (titulo['duplicatas'] ?? '').toString();
      final mesmaData = _mesmaData(item['vencimento'], titulo['vencimento']);

      return mesmaRaiz && !(mesmoBordero && mesmaDuplicata && mesmaData) && !mesmaData;
    }).map((item) => Map<String, dynamic>.from(item)).toList(growable: false);

    itens.sort((a, b) {
      final dataA = _parseData(a['vencimento']);
      final dataB = _parseData(b['vencimento']);
      if (dataA == null && dataB == null) {
        return _asDouble(b['valorTitulo']).compareTo(_asDouble(a['valorTitulo']));
      }
      if (dataA == null) return 1;
      if (dataB == null) return -1;
      final comparacaoData = dataA.compareTo(dataB);
      if (comparacaoData != 0) return comparacaoData;
      return _asDouble(b['valorTitulo']).compareTo(_asDouble(a['valorTitulo']));
    });

    return itens;
  }

  List<Map<String, dynamic>> _outrosTitulosDoGrupoPorRaiz(
    List<Map<String, dynamic>> titulosGrupo,
    List<Map<String, dynamic>> todosTitulos,
  ) {
    final raizes = titulosGrupo
        .map((item) => (item['raiz'] ?? '').toString().trim())
        .where((raiz) => raiz.isNotEmpty)
        .toSet();

    final chavesGrupo = titulosGrupo
        .map(
          (item) => [
            (item['raiz'] ?? '').toString().trim(),
            (item['bordero'] ?? '').toString(),
            (item['duplicatas'] ?? '').toString(),
            _formatarData(item['vencimento']),
            _asDouble(item['valorTitulo']).toStringAsFixed(2),
          ].join('|'),
        )
        .toSet();

    final vistos = <String>{};
    final outros = <Map<String, dynamic>>[];

    for (final item in todosTitulos) {
      final raiz = (item['raiz'] ?? '').toString().trim();
      if (!raizes.contains(raiz)) continue;

      final chave = [
        raiz,
        (item['bordero'] ?? '').toString(),
        (item['duplicatas'] ?? '').toString(),
        _formatarData(item['vencimento']),
        _asDouble(item['valorTitulo']).toStringAsFixed(2),
      ].join('|');

      if (chavesGrupo.contains(chave) || !vistos.add(chave)) continue;
      outros.add(Map<String, dynamic>.from(item));
    }

    outros.sort((a, b) {
      final dataA = _parseData(a['vencimento']);
      final dataB = _parseData(b['vencimento']);
      if (dataA == null && dataB == null) {
        return _asDouble(b['valorTitulo']).compareTo(_asDouble(a['valorTitulo']));
      }
      if (dataA == null) return 1;
      if (dataB == null) return -1;
      final comparacaoData = dataA.compareTo(dataB);
      if (comparacaoData != 0) return comparacaoData;
      return _asDouble(b['valorTitulo']).compareTo(_asDouble(a['valorTitulo']));
    });

    return outros;
  }

  List<Map<String, dynamic>> _agruparPorSacado(List<Map<String, dynamic>> fonte) {
    final mapa = <String, List<Map<String, dynamic>>>{};
    for (final titulo in fonte) {
      final sacado = (titulo['sacado'] ?? 'SEM SACADO').toString().trim();
      mapa.putIfAbsent(sacado, () => []).add(titulo);
    }

    final grupos = mapa.entries.map((entry) {
      final itens = List<Map<String, dynamic>>.from(entry.value)
        ..sort((a, b) => _asDouble(b['valorTitulo']).compareTo(_asDouble(a['valorTitulo'])));
      return {
        'sacado': entry.key,
        'quantidade': itens.length,
        'valorTotal': itens.fold<double>(
          0,
          (soma, item) => soma + _asDouble(item['valorTitulo']),
        ),
        'menorVencimento': itens
            .map((item) => _parseData(item['vencimento']))
            .whereType<DateTime>()
            .fold<DateTime?>(null, (anterior, atual) {
          if (anterior == null) return atual;
          return atual.isBefore(anterior) ? atual : anterior;
        }),
        'maiorAtraso': itens.fold<int>(
          0,
          (maior, item) {
            final dias = _diasEmAtraso(item['vencimento']) ?? 0;
            return dias > maior ? dias : maior;
          },
        ),
        'titulos': itens,
      };
    }).toList(growable: false);

    grupos.sort((a, b) {
      if (_ordenacao == _OrdenacaoTitulosVencidos.atraso) {
        final comparacaoAtraso =
            ((b['maiorAtraso'] ?? 0) as int).compareTo((a['maiorAtraso'] ?? 0) as int);
        if (comparacaoAtraso != 0) return comparacaoAtraso;
      }
      return _asDouble(b['valorTotal']).compareTo(_asDouble(a['valorTotal']));
    });

    return grupos;
  }

  List<Map<String, dynamic>> _gruposPorSacado() => _agruparPorSacado(_titulos);

  void _alternarSacado(String grupoId) {
    setState(() {
      if (_sacadosExpandidos.contains(grupoId)) {
        _sacadosExpandidos.remove(grupoId);
      } else {
        _sacadosExpandidos.add(grupoId);
      }
    });
  }

  String _sanitizarArquivo(String texto) {
    final base = texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return base.isEmpty ? 'sacado' : base;
  }

  Future<Uint8List> _gerarPdfGrupo({
    required String sacado,
    required List<Map<String, dynamic>> titulos,
    required double valorTotal,
    required List<Map<String, dynamic>> outrosTitulosRaiz,
  }) async {
    final pdf = pw.Document();
    final hoje = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fonteRegular = await PdfGoogleFonts.notoSansRegular();
    final fonteBold = await PdfGoogleFonts.notoSansBold();
    final logoBytes = await rootBundle.load('lib/assets/icon.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: fonteRegular,
          bold: fonteBold,
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: pw.Image(
                  logo,
                  width: 34,
                  height: 34,
                  fit: pw.BoxFit.cover,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Titulos vencidos',
                      style: pw.TextStyle(
                        fontSize: 20,
                        font: fonteBold,
                        color: PdfColors.teal700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${widget.nomeCedente}  |  CNPJ ${widget.cnpjCedente}',
                      maxLines: 1,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Sacado: $sacado'),
          pw.Text('Gerado em: $hoje'),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Titulos: ${titulos.length}'),
                pw.Text('Valor total: ${_moeda(valorTotal)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Bordero', 'Vencimento', 'Duplicata', 'Valor'],
            headerStyle: pw.TextStyle(
              font: fonteBold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.teal700,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 9,
            ),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(2),
            },
            data: titulos
                .map(
                  (item) => [
                    '${item['bordero'] ?? '--'}',
                    _formatarData(item['vencimento']),
                    '${item['duplicatas'] ?? '--'}',
                    _moeda(_asDouble(item['valorTitulo'])),
                  ],
                )
                .toList(growable: false),
          ),
          if (outrosTitulosRaiz.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              outrosTitulosRaiz.length == 1
                  ? 'Ha mais 1 titulo vencido na raiz desse CNPJ'
                  : 'Ha mais ${outrosTitulosRaiz.length} titulos vencidos na raiz desse CNPJ',
              style: pw.TextStyle(
                font: fonteBold,
                fontSize: 12,
                color: PdfColors.teal700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Valor total relacionado: ${_moeda(outrosTitulosRaiz.fold<double>(0, (soma, item) => soma + _asDouble(item['valorTitulo'])))}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: const ['Sacado', 'CNPJ', 'Duplicata', 'Vencimento', 'Valor'],
              headerStyle: pw.TextStyle(
                font: fonteBold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal700,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 9,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              data: outrosTitulosRaiz
                  .map(
                    (item) => [
                      '${item['sacado'] ?? '--'}',
                      '${item['cnpj'] ?? '--'}',
                      '${item['duplicatas'] ?? '--'}',
                      _formatarData(item['vencimento']),
                      _moeda(_asDouble(item['valorTitulo'])),
                    ],
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _compartilharPdfGrupo(
    String grupoId,
    String sacado,
    List<Map<String, dynamic>> titulos,
    double valorTotal,
    List<Map<String, dynamic>> outrosTitulosRaiz,
  ) async {
    setState(() => _grupoExportandoId = grupoId);
    try {
      final bytes = await _gerarPdfGrupo(
        sacado: sacado,
        titulos: titulos,
        valorTotal: valorTotal,
        outrosTitulosRaiz: outrosTitulosRaiz,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'titulos_vencidos_${_sanitizarArquivo(sacado)}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel gerar o PDF deste sacado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _grupoExportandoId = null);
      }
    }
  }

  Future<Uint8List> _gerarPdfResumoSacados({
    required List<Map<String, dynamic>> grupos,
    required double valorTotal,
  }) async {
    final pdf = pw.Document();
    final hoje = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fonteRegular = await PdfGoogleFonts.notoSansRegular();
    final fonteBold = await PdfGoogleFonts.notoSansBold();
    final logoBytes = await rootBundle.load('lib/assets/icon.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fonteRegular, bold: fonteBold),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: pw.Image(logo, width: 34, height: 34, fit: pw.BoxFit.cover),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Titulos vencidos por sacado',
                      style: pw.TextStyle(
                        fontSize: 20,
                        font: fonteBold,
                        color: PdfColors.teal700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${widget.nomeCedente}  |  CNPJ ${widget.cnpjCedente}',
                      maxLines: 1,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Gerado em: $hoje'),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Sacados: ${grupos.length}'),
                pw.Text('Valor total: ${_moeda(valorTotal)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Sacado', 'Titulos', 'Valor total'],
            headerStyle: pw.TextStyle(font: fonteBold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(6),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            data: grupos
                .map(
                  (grupo) => [
                    '${grupo['sacado'] ?? '--'}',
                    '${grupo['quantidade'] ?? 0}',
                    _moeda(_asDouble(grupo['valorTotal'])),
                  ],
                )
                .toList(growable: false),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _compartilharPdfResumoSacados(
    List<Map<String, dynamic>> grupos,
    double valorTotal,
  ) async {
    setState(() => _exportandoResumo = true);
    try {
      final bytes = await _gerarPdfResumoSacados(
        grupos: grupos,
        valorTotal: valorTotal,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'titulos_vencidos_resumo_${_sanitizarArquivo(widget.nomeCedente)}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel gerar o PDF resumido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportandoResumo = false);
      }
    }
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grupos = _gruposPorSacado()
        .where((grupo) {
          if (_termoBusca.trim().isEmpty) return true;
          final sacado = (grupo['sacado'] ?? '').toString().toLowerCase();
          return sacado.contains(_termoBusca.trim().toLowerCase());
        })
        .toList(growable: false);
    final gruposExibidos = grupos.take(_limiteGrupos).toList(growable: false);
    final valorTotal = _titulos.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['valorTitulo']),
    );

    return LayoutBase(
      titulo: 'Titulos Vencidos',
      nomeUsuario: widget.sessao.saudacaoUsuario,
      perfilUsuario: widget.sessao.rotuloPerfilAtual,
      aoTrocarPerfil: widget.aoTrocarPerfil,
      indexSelecionado: 2,
      aoMudarAba: (_) => Navigator.pop(context),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: _titPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      conteudo: RefreshIndicator(
        onRefresh: _carregarTitulos,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeader(isDark, valorTotal, grupos.length, grupos),
            const SizedBox(height: 16),
            _buildOrdenacao(isDark),
            const SizedBox(height: 16),
            _buildBuscaSacado(isDark),
            const SizedBox(height: 16),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: _titPrimary),
                ),
              )
            else if (_titulos.isEmpty)
              _buildEmptyState(isDark)
            else ...[
              ...gruposExibidos.map(
                (grupo) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildGrupoSacado(grupo, isDark),
                ),
              ),
              if (grupos.length > _limiteGrupos)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _limiteGrupos = (_limiteGrupos + 10).clamp(0, grupos.length);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _titPrimary,
                    side: const BorderSide(color: _titPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'CARREGAR MAIS 10',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBuscaSacado(bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? _titDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : _titBorderLight,
        ),
      ),
      child: TextField(
        controller: _buscaController,
        onChanged: (value) {
          setState(() {
            _termoBusca = value;
            _limiteGrupos = 10;
          });
        },
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF111827),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar sacado...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white38 : _titPrimary,
            size: 20,
          ),
          suffixIcon: _termoBusca.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _buscaController.clear();
                    setState(() {
                      _termoBusca = '';
                      _limiteGrupos = 10;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildOrdenacao(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? _titDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : _titBorderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBotaoOrdenacao(
              label: 'Maior valor',
              selecionado: _ordenacao == _OrdenacaoTitulosVencidos.valor,
              isDark: isDark,
              onTap: () {
                setState(() {
                  _ordenacao = _OrdenacaoTitulosVencidos.valor;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBotaoOrdenacao(
              label: 'Maior atraso',
              selecionado: _ordenacao == _OrdenacaoTitulosVencidos.atraso,
              isDark: isDark,
              onTap: () {
                setState(() {
                  _ordenacao = _OrdenacaoTitulosVencidos.atraso;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoOrdenacao({
    required String label,
    required bool selecionado,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selecionado
              ? _titPrimary.withValues(alpha: isDark ? 0.28 : 0.12)
              : (isDark ? _titDarkSurface : _titSurfaceAltLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado
                ? _titPrimary
                : (isDark ? Colors.white10 : _titBorderLight),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selecionado ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: selecionado
                  ? _titPrimary
                  : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selecionado
                    ? _titPrimary
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isDark,
    double valorTotal,
    int totalSacados,
    List<Map<String, dynamic>> grupos,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0F2A43), Color(0xFF184E77)]
              : const [Color(0xFF0F766E), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Visao executiva',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.nomeCedente,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'CNPJ ${widget.cnpjCedente}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _exportandoResumo
                  ? null
                  : () => _compartilharPdfResumoSacados(grupos, valorTotal),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: _exportandoResumo
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(
                _exportandoResumo ? 'Gerando...' : 'PDF Geral',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMini(
                  'Valor vencido',
                  _moeda(valorTotal),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderMini(
                  'Titulos',
                  _titulos.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderMini(
                  'Sacados',
                  totalSacados.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMini(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrupoSacado(Map<String, dynamic> grupo, bool isDark) {
    final sacado = grupo['sacado']?.toString() ?? 'Sacado';
    final grupoId = 'principal:$sacado';
    final quantidade = grupo['quantidade']?.toString() ?? '0';
    final valorTotal = _asDouble(grupo['valorTotal']);
    final titulos = List<Map<String, dynamic>>.from(grupo['titulos'] ?? const []);
    final outrosTitulosRaiz = _outrosTitulosDoGrupoPorRaiz(titulos, _titulos);
    final valorOutrosTitulosRaiz = outrosTitulosRaiz.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['valorTitulo']),
    );
    final outrosGruposSacado = _agruparPorSacado(outrosTitulosRaiz)
        .take(10)
        .toList(growable: false);
    final menorVencimento = grupo['menorVencimento'];
    final diasAtraso = _diasEmAtraso(menorVencimento);
    final expandido = _sacadosExpandidos.contains(grupoId);
    final corBadge = (diasAtraso ?? 0) >= 30 ? _titDanger : _titWarning;
    final exportando = _grupoExportandoId == grupoId;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _titDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : _titBorderLight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _alternarSacado(grupoId),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sacado,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$quantidade titulos vencidos',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _moeda(valorTotal),
                        style: const TextStyle(
                          color: _titPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: corBadge.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: corBadge.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          diasAtraso == null
                              ? 'Sem data'
                              : '$diasAtraso dias',
                          style: TextStyle(
                            color: corBadge,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (expandido)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: exportando
                          ? null
                          : () => _compartilharPdfGrupo(
                                grupoId,
                                sacado,
                                titulos,
                                valorTotal,
                                outrosTitulosRaiz,
                              ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _titPrimary,
                        side: BorderSide(
                          color: _titPrimary.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: exportando
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _titPrimary,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: Text(
                        exportando ? 'Gerando...' : 'PDF',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTabelaHeader(isDark),
                  const SizedBox(height: 8),
                  ...titulos.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildTituloRow(
                        entry.value,
                        isDark,
                        mostrarLinha: entry.key != titulos.length - 1,
                      ),
                    ),
                  ),
                  if (outrosTitulosRaiz.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        outrosTitulosRaiz.length == 1
                            ? 'Ha mais 1 titulo (${_moeda(valorOutrosTitulosRaiz)}) vencido na raiz desse CNPJ'
                            : 'Ha mais ${outrosTitulosRaiz.length} titulos (${_moeda(valorOutrosTitulosRaiz)}) vencidos na raiz desse CNPJ',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...outrosGruposSacado.map(
                      (grupoRelacionado) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildGrupoRelacionado(
                          grupoPrincipal: sacado,
                          grupo: grupoRelacionado,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrupoRelacionado({
    required String grupoPrincipal,
    required Map<String, dynamic> grupo,
    required bool isDark,
  }) {
    final sacado = grupo['sacado']?.toString() ?? 'Sacado';
    final grupoId = 'relacionado:$grupoPrincipal:$sacado';
    final quantidade = grupo['quantidade']?.toString() ?? '0';
    final valorTotal = _asDouble(grupo['valorTotal']);
    final titulos = List<Map<String, dynamic>>.from(grupo['titulos'] ?? const []);
    final menorVencimento = grupo['menorVencimento'];
    final diasAtraso = _diasEmAtraso(menorVencimento);
    final expandido = _sacadosExpandidos.contains(grupoId);
    final corBadge = (diasAtraso ?? 0) >= 30 ? _titDanger : _titWarning;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _titDarkSurface : _titSurfaceAltLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : _titBorderLight,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _alternarSacado(grupoId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sacado,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$quantidade titulos vencidos',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _moeda(valorTotal),
                        style: const TextStyle(
                          color: _titPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: corBadge.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: corBadge.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          diasAtraso == null ? 'Sem data' : '$diasAtraso dias',
                          style: TextStyle(
                            color: corBadge,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (expandido)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 12),
                  _buildTabelaHeader(isDark),
                  const SizedBox(height: 8),
                  ...titulos.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildTituloRow(
                        entry.value,
                        isDark,
                        mostrarLinha: entry.key != titulos.length - 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabelaHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildHeaderCell('DUPLICATA', isDark),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildHeaderCell('VENCIMENTO', isDark),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell('VALOR', isDark, alignEnd: true),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String texto, bool isDark, {bool alignEnd = false}) {
    return Text(
      texto,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTituloRow(
    Map<String, dynamic> item,
    bool isDark, {
    required bool mostrarLinha,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? _titDarkSurface : _titSurfaceAltLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  '${item['duplicatas'] ?? '--'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatarData(item['vencimento']),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _moeda(_asDouble(item['valorTitulo'])),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: _titPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (mostrarLinha) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              thickness: 0.7,
              color: isDark ? Colors.white10 : _titBorderLight,
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInfoChip(String texto, Color cor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? _titDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : _titBorderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.timer_off_outlined,
            size: 46,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum titulo vencido encontrado para este cedente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
