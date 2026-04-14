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

const _comPrimary = Color(0xFF0E7490);
const _comPrimaryDark = Color(0xFF0F766E);
const _comAccent = Color(0xFF22C55E);
const _comDarkSurface = Color(0xFF17181C);
const _comDarkSurfaceAlt = Color(0xFF1C1C1E);
const _comBorderLight = Color(0xFFE2E8F0);
const _comSurfaceAltLight = Color(0xFFF8FAFC);

enum _FiltroComissaria { total, vencido, aVencer }

class TelaComissariaVencidos extends StatefulWidget {
  final String cnpjCedente;
  final String nomeCedente;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;

  const TelaComissariaVencidos({
    super.key,
    required this.cnpjCedente,
    required this.nomeCedente,
    required this.sessao,
    this.aoTrocarPerfil,
  });

  @override
  State<TelaComissariaVencidos> createState() => _TelaComissariaVencidosState();
}

class _TelaComissariaVencidosState extends State<TelaComissariaVencidos> {
  bool _carregando = true;
  int _limiteTitulos = 10;
  List<Map<String, dynamic>> _titulos = const [];
  _FiltroComissaria _filtroSelecionado = _FiltroComissaria.total;
  bool _exportandoPdf = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://athenaapp.athenabanco.com.br/api/App/comVenc?cnpj=${widget.cnpjCedente}',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Erro ao carregar comissÃ¡ria vencida');
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> valores = json['dados']?['\$values'] ?? const [];

      if (!mounted) return;
      setState(() {
        _titulos = valores
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        _limiteTitulos = 10;
        _filtroSelecionado = _FiltroComissaria.total;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar a comissÃ¡ria vencida.'),
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

  String _formatarData(dynamic value) {
    if (value == null) return '--';
    final data = DateTime.tryParse(value.toString())?.toLocal();
    if (data == null) return '--';
    return DateFormat('dd/MM/yyyy').format(data);
  }

  DateTime _ajustarParaDiaUtil(DateTime data) {
    final base = DateTime(data.year, data.month, data.day);
    switch (base.weekday) {
      case DateTime.saturday:
        return base.add(const Duration(days: 2));
      case DateTime.sunday:
        return base.add(const Duration(days: 1));
      default:
        return base;
    }
  }

  int _diasExibicao(Map<String, dynamic> titulo) {
    final atraso = titulo['atraso'];
    if (atraso is num) return atraso.round();

    final atrasoDouble = double.tryParse(atraso?.toString() ?? '');
    if (atrasoDouble != null) return atrasoDouble.round();

    final data = DateTime.tryParse((titulo['vencimento'] ?? '').toString())?.toLocal();
    if (data == null) return 0;

    final hoje = DateTime.now();
    final baseHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final baseVencimento = _ajustarParaDiaUtil(data);

    if (baseVencimento.isBefore(baseHoje)) {
      return baseHoje.difference(baseVencimento).inDays;
    }

    return baseVencimento.difference(baseHoje).inDays;
  }

  bool _estaVencido(Map<String, dynamic> titulo) {
    final data = DateTime.tryParse((titulo['vencimento'] ?? '').toString())?.toLocal();
    if (data != null) {
      final hoje = DateTime.now();
      final baseHoje = DateTime(hoje.year, hoje.month, hoje.day);
      final baseVenc = _ajustarParaDiaUtil(data);
      return baseVenc.isBefore(baseHoje);
    }

    final atraso = titulo['atraso'];
    if (atraso is num) return atraso.toInt() > 0;
    final atrasoInt = int.tryParse(atraso?.toString() ?? '');
    if (atrasoInt != null) return atrasoInt > 0;
    return false;
  }

  List<Map<String, dynamic>> _agruparPorEspecie() {
    final base = _titulosFiltrados();
    final mapa = <String, List<Map<String, dynamic>>>{};
    for (final titulo in base) {
      final especie = (titulo['especie'] ?? 'Sem especie').toString().trim();
      mapa.putIfAbsent(especie, () => []).add(titulo);
    }

    final grupos = mapa.entries.map((entry) {
      final total = entry.value.fold<double>(
        0,
        (soma, item) => soma + _asDouble(item['valorTotal']),
      );
      return {
        'especie': entry.key,
        'quantidade': entry.value.length,
        'valorTotal': total,
      };
    }).toList(growable: false);

    grupos.sort(
      (a, b) => _asDouble(b['valorTotal']).compareTo(_asDouble(a['valorTotal'])),
    );
    return grupos;
  }

  List<Map<String, dynamic>> _titulosOrdenados() {
    final lista = List<Map<String, dynamic>>.from(_titulosFiltrados());
    lista.sort(
      (a, b) => _asDouble(b['valorTotal']).compareTo(_asDouble(a['valorTotal'])),
    );
    return lista;
  }

  List<Map<String, dynamic>> _titulosFiltrados() {
    switch (_filtroSelecionado) {
      case _FiltroComissaria.total:
        return _titulos;
      case _FiltroComissaria.vencido:
        return _titulos.where(_estaVencido).toList(growable: false);
      case _FiltroComissaria.aVencer:
        return _titulos.where((item) => !_estaVencido(item)).toList(growable: false);
    }

    return const [];
  }

  String _labelFiltroAtual() {
    switch (_filtroSelecionado) {
      case _FiltroComissaria.total:
        return 'total';
      case _FiltroComissaria.vencido:
        return 'vencido';
      case _FiltroComissaria.aVencer:
        return 'a vencer';
    }
  }

  double _valorDoFiltroAtual(double valorTotal, double valorVencido, double valorAVencer) {
    switch (_filtroSelecionado) {
      case _FiltroComissaria.total:
        return valorTotal;
      case _FiltroComissaria.vencido:
        return valorVencido;
      case _FiltroComissaria.aVencer:
        return valorAVencer;
    }
  }

  Future<Uint8List> _gerarPdfVencidos(List<Map<String, dynamic>> titulos) async {
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
                      'Comissária vencida',
                      style: pw.TextStyle(
                        fontSize: 20,
                        font: fonteBold,
                        color: PdfColors.teal700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('${widget.nomeCedente} | CNPJ ${widget.cnpjCedente}'),
                    pw.Text('Gerado em: $hoje'),
                  ],
                ),
              ),
            ],
          ),
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
                pw.Text('Titulos vencidos: ${titulos.length}'),
                pw.Text(
                  'Valor total: ${_moeda(titulos.fold<double>(0, (soma, item) => soma + _asDouble(item['valorTotal'])))}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Sacado', 'Titulo', 'Especie', 'Vencimento', 'Valor'],
            headerStyle: pw.TextStyle(
              font: fonteBold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellStyle: pw.TextStyle(
              font: fonteRegular,
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
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            data: titulos
                .map(
                  (item) => [
                    '${item['sacado'] ?? '--'}',
                    '${item['titulo'] ?? '--'}',
                    '${item['especie'] ?? '--'}',
                    _formatarData(item['vencimento']),
                    _moeda(_asDouble(item['valorTotal'])),
                  ],
                )
                .toList(growable: false),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _compartilharPdfVencidos(List<Map<String, dynamic>> titulos) async {
    setState(() => _exportandoPdf = true);
    try {
      final bytes = await _gerarPdfVencidos(titulos);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'comissaria_vencidos_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel gerar o PDF dos vencidos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valorTotal = _titulos.fold<double>(0, (soma, item) => soma + _asDouble(item['valorTotal']));
    final valorVencido = _titulos.fold<double>(
      0,
      (soma, item) => soma + (_estaVencido(item) ? _asDouble(item['valorTotal']) : 0),
    );
    final valorAVencer = valorTotal - valorVencido;
    final titulosFiltrados = _titulosFiltrados();
    final valorTotalFiltrado = titulosFiltrados.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['valorTotal']),
    );
    final porEspecie = _agruparPorEspecie();
    final titulosOrdenados = _titulosOrdenados();
    final titulosExibidos =
        titulosOrdenados.take(_limiteTitulos).toList(growable: false);

    return LayoutBase(
      titulo: 'Comissária',
      nomeUsuario: widget.sessao.saudacaoUsuario,
      perfilUsuario: widget.sessao.rotuloPerfilAtual,
      aoTrocarPerfil: widget.aoTrocarPerfil,
      indexSelecionado: 2,
      aoMudarAba: (_) => Navigator.pop(context),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _comPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      conteudo: RefreshIndicator(
        onRefresh: _carregarDados,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeader(
              isDark,
              valorTotal,
              valorVencido,
              valorAVencer,
              titulosFiltrados,
            ),
            const SizedBox(height: 16),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: _comPrimary),
                ),
              )
            else if (_titulos.isEmpty)
              _buildEmptyState(isDark)
            else ...[
              _buildSectionTitle('Por especie', 'Total e vencidos por especie'),
              const SizedBox(height: 10),
              _buildEspeciesChart(porEspecie, valorTotalFiltrado, isDark),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionTitle(
                      'Titulos',
                      '${titulosFiltrados.length} titulos no filtro ${_labelFiltroAtual()}',
                    ),
                  ),
                  if (_filtroSelecionado == _FiltroComissaria.vencido)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: OutlinedButton.icon(
                        onPressed: _exportandoPdf
                            ? null
                            : () => _compartilharPdfVencidos(titulosFiltrados),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _comPrimary,
                          side: const BorderSide(color: _comPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: _exportandoPdf
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _comPrimary,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: Text(
                          _exportandoPdf ? 'Gerando...' : 'PDF vencidos',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...titulosExibidos.map(
                (titulo) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildTituloCard(titulo, isDark),
                ),
              ),
              if (titulosOrdenados.length > _limiteTitulos)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _limiteTitulos =
                          (_limiteTitulos + 10).clamp(0, titulosOrdenados.length);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _comPrimary,
                    side: const BorderSide(color: _comPrimary),
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

  Widget _buildHeader(
    bool isDark,
    double valorTotal,
    double valorVencido,
    double valorAVencer,
    List<Map<String, dynamic>> titulosFiltrados,
  ) {
    final valorDestaque = _valorDoFiltroAtual(valorTotal, valorVencido, valorAVencer);

    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            widget.nomeCedente,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'CNPJ ${widget.cnpjCedente}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Text(
            'VALOR TOTAL',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _moeda(valorDestaque),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildResumoLinha('Vencido', _moeda(valorVencido))),
              const SizedBox(width: 10),
              Expanded(child: _buildResumoLinha('A vencer', _moeda(valorAVencer))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFiltroBotao(
                  'Total',
                  _FiltroComissaria.total,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFiltroBotao(
                  'Vencido',
                  _FiltroComissaria.vencido,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFiltroBotao(
                  'A vencer',
                  _FiltroComissaria.aVencer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoLinha(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroBotao(String label, _FiltroComissaria filtro) {
    final selecionado = _filtroSelecionado == filtro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _filtroSelecionado = filtro;
            _limiteTitulos = 10;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selecionado
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionado
                  ? Colors.white.withValues(alpha: 0.60)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: selecionado ? 0.95 : 0.72),
                  fontSize: 11,
                  fontWeight: selecionado ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String titulo, String subtitulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitulo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildEspeciesChart(
    List<Map<String, dynamic>> especies,
    double valorTotal,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _comDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : _comBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (especies.isEmpty)
            Text(
              'Sem dados por especie.',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                fontSize: 12,
              ),
            )
          else
            ...especies.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildEspecieBar(item, valorTotal, isDark),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEspecieBar(
    Map<String, dynamic> item,
    double valorTotal,
    bool isDark,
  ) {
    final valor = _asDouble(item['valorTotal']);
    final percentual = valorTotal == 0 ? 0.0 : valor / valorTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item['especie'] ?? 'Sem especie'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(percentual * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: _comPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentual.clamp(0, 1),
            minHeight: 11,
            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE7EEF3),
            valueColor: AlwaysStoppedAnimation(
              Color.lerp(_comAccent, _comPrimaryDark, percentual)!,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _moeda(valor),
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${item['quantidade'] ?? 0} titulos',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTituloCard(Map<String, dynamic> titulo, bool isDark) {
    final vencido = _estaVencido(titulo);
    final valor = _asDouble(titulo['valorTotal']);
    final prazoLabel = vencido ? 'ATRASO' : 'Prazo';
    final prazoCor = vencido
        ? Colors.redAccent
        : (isDark ? Colors.white70 : const Color(0xFF475569));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _comDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : _comBorderLight),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${titulo['sacado'] ?? 'Sem sacado'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'VALOR',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _moeda(valor),
                    style: const TextStyle(
                      color: _comPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: vencido
                    ? Colors.redAccent.withValues(alpha: 0.22)
                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoColuna(
                    'Titulo',
                    '${titulo['titulo'] ?? '--'}',
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildInfoColuna(
                    'Especie',
                    '${titulo['especie'] ?? 'Sem especie'}',
                    isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoColuna(
                    'Bordero',
                    '${titulo['bordero'] ?? '--'}',
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildInfoColuna(
                    'Vencimento',
                    _formatarData(titulo['vencimento']),
                    isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: vencido
                  ? Colors.redAccent.withValues(alpha: 0.10)
                  : _comPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  vencido ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                  size: 16,
                  color: prazoCor,
                ),
                const SizedBox(width: 8),
                Text(
                  '$prazoLabel: ${_diasExibicao(titulo)} dias',
                  style: TextStyle(
                    color: prazoCor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColuna(String label, String valor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? _comDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : _comBorderLight),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: isDark ? Colors.white38 : Colors.grey, size: 32),
          const SizedBox(height: 12),
          Text(
            'Nenhum titulo encontrado para a comissÃ¡ria.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

