// ignore_for_file: duplicate_import, unused_import

import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/componentes/layout_base.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:athenaapp/main.dart'; // Onde está o temaApp
import 'componentes/layout_base.dart'; // Importe o seu LayoutBase aqui

const _detPrimary = Color(0xFF0E7490);
const _detPrimaryDark = Color(0xFF0F766E);
const _detAccent = Color(0xFF22C55E);
const _detDanger = Color(0xFFDC2626);
const _detDarkSurfaceAlt = Color(0xFF1C1C1E);
const _detBorderLight = Color(0xFFE2E8F0);

class VisualizarDetalhesPage extends StatefulWidget {
  final Map<String, dynamic> operacao;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;

  const VisualizarDetalhesPage({
    super.key,
    required this.operacao,
    required this.sessao,
    this.aoTrocarPerfil,
  });

  @override
  State<VisualizarDetalhesPage> createState() => _VisualizarDetalhesPageState();
}

class _VisualizarDetalhesPageState extends State<VisualizarDetalhesPage> {
  List<dynamic> historicoApi = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarStatusBordero();
  }

  Future<void> _buscarStatusBordero() async {
    if (!mounted) return;
    setState(() => carregando = true);
    try {
      final bordero = widget.operacao['bordero'];
      final empresa = widget.operacao['empresa'];
      final url = Uri.parse("https://athenaapp.athenabanco.com.br/api/App/detalheBor?bordero=$bordero&empresa=$empresa");
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          if (decoded is Map && decoded.containsKey('dados')) {
            historicoApi = decoded['dados']['\$values'] ?? [];
          } else {
            historicoApi = decoded is List ? decoded : [];
          }
          carregando = false;
        });
      } else {
        setState(() => carregando = false);
      }
    } catch (e) {
      if (mounted) setState(() => carregando = false);
    }
  }

  // --- MÉTODOS DE CÁLCULO MANTIDOS ---
  String _formatarDuracao(Duration duration) {
    if (duration.isNegative) return "0m";
    int dias = duration.inDays;
    int horas = duration.inHours % 24;
    int minutos = duration.inMinutes % 60;
    if (dias > 0) return "${dias}d ${horas}h ${minutos}m";
    if (horas > 0) return "${horas}h ${minutos}m";
    return "${minutos}m";
  }

  String _getTempoTotalProcesso() {
    if (historicoApi.isEmpty) return "--";
    try {
      DateTime inicio = DateTime.parse(historicoApi.first['inicio']);
      DateTime fim = DateTime.parse(historicoApi.last['inicio']);
      return _formatarDuracao(fim.difference(inicio));
    } catch (e) { return "--"; }
  }

  Map<String, dynamic>? _getEtapa(String areaBusca) {
    if (historicoApi.isEmpty) return null;
    try {
      return historicoApi.firstWhere(
        (e) {
          final area = e['area']?.toString().trim().toUpperCase() ?? "";
          return area == areaBusca.toUpperCase() || (areaBusca == "INICIO" && area.contains("IMPORT"));
        },
        orElse: () => null,
      );
    } catch (_) { return null; }
  }

  String _calcularDiferenca(String areaDe, String areaPara) {
    final d1 = _getEtapa(areaDe);
    final d2 = _getEtapa(areaPara);
    if (d1 == null || d2 == null) return "";
    try {
      DateTime inicio = DateTime.parse(d1['inicio']);
      DateTime fim = DateTime.parse(d2['inicio']);
      return _formatarDuracao(fim.difference(inicio));
    } catch (e) { return ""; }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = largura > 600;

    return LayoutBase(
      titulo: "Detalhes da Operação",
      nomeUsuario: widget.sessao.saudacaoUsuario,
      perfilUsuario: widget.sessao.rotuloPerfilAtual,
      aoTrocarPerfil: widget.aoTrocarPerfil,
      indexSelecionado: 1, // Aba de Operações
      aoMudarAba: (index) => Navigator.pop(context), // Volta ao mudar de aba
      // BOTÃO VOLTAR ENVIADO PARA O LAYOUTBASE
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _detPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      conteudo: carregando 
        ? const Center(child: CircularProgressIndicator(color: _detPrimary))
        : RefreshIndicator(
            onRefresh: _buscarStatusBordero,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 20),
                  _buildSecaoTitulo("STATUS DO PROCESSO", isDark),
                  _buildTimelineHibrida(isDark, isTablet),
                  const SizedBox(height: 24),
                  _buildSecaoTitulo("RESUMO FINANCEIRO", isDark),
                  _buildFinanceGrid(isTablet, isDark),
                  const SizedBox(height: 24),
                  _buildSecaoTitulo("TARIFAS", isDark),
                  _buildTaxasGrid(isTablet, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }
  

  Widget _buildTimelineHibrida(bool isDark, bool isTablet) {
    final todasAsFases = [
      {'label': 'Início', 'code': 'INICIO', 'obrigatoria': true},
      {'label': 'Comercial', 'code': 'ASS', 'obrigatoria': false},
      {'label': 'Financeiro', 'code': 'TGE', 'obrigatoria': false},
      {'label': 'FIDC', 'code': 'FID', 'obrigatoria': false},
      {'label': 'Assin. Cedente', 'code': 'ASSCED', 'obrigatoria': true},
      {'label': 'Assin. Adm.', 'code': 'ASSADM', 'obrigatoria': true},
    ];

    final fasesParaExibir = todasAsFases.where((f) {
      return (f['obrigatoria'] as bool) || _getEtapa(f['code']!.toString()) != null;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _detDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : _detBorderLight,
        ),
      ),
      child: isTablet 
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(fasesParaExibir.length, (index) {
              return Expanded(
                child: _buildTimelineItem(
                  fasesParaExibir[index]['label']!.toString(),
                  fasesParaExibir[index]['code']!.toString(),
                  index < fasesParaExibir.length - 1 ? fasesParaExibir[index + 1]['code']!.toString() : null,
                  index == fasesParaExibir.length - 1,
                  isDark,
                  isTablet,
                ),
              );
            }),
          )
        : Column(
            children: List.generate(fasesParaExibir.length, (index) {
              return _buildTimelineItem(
                fasesParaExibir[index]['label']!.toString(),
                fasesParaExibir[index]['code']!.toString(),
                index < fasesParaExibir.length - 1 ? fasesParaExibir[index + 1]['code']!.toString() : null,
                index == fasesParaExibir.length - 1,
                isDark,
                isTablet,
              );
            }),
          ),
    );
  }

  Widget _buildTimelineItem(String label, String code, String? nextCode, bool isLast, bool isDark, bool isTablet) {
    final dados = _getEtapa(code);
    final bool concluido = dados != null;
    final String duracao = nextCode != null ? _calcularDiferenca(code, nextCode) : "";
    
    String hora = "--:--";
    String usuarioNome = "";
    if (concluido) {
      usuarioNome = dados['nome']?.toString() ?? "";
      try {
        DateTime dt = DateTime.parse(dados['inicio']);
        hora = DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }

    Widget visualNode = isTablet 
      ? Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: concluido ? _detAccent : (isDark ? Colors.white10 : Colors.grey[300]),
              ),
              child: Icon(concluido ? Icons.check : Icons.lock_outline, size: 12, color: concluido ? Colors.white : Colors.grey),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  height: 2,
                  color: concluido && _getEtapa(nextCode ?? "") != null ? _detAccent : (isDark ? Colors.white10 : Colors.grey[200]),
                ),
              ),
          ],
        )
      : Column(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: concluido ? _detAccent : (isDark ? Colors.white10 : Colors.grey[300]),
              ),
              child: Icon(concluido ? Icons.check : Icons.lock_outline, size: 12, color: concluido ? Colors.white : Colors.grey),
            ),
            if (!isLast)
              Container(
                width: 2, height: (usuarioNome.isNotEmpty || duracao.isNotEmpty) ? 55 : 40,
                color: concluido && _getEtapa(nextCode ?? "") != null ? _detAccent : (isDark ? Colors.white10 : Colors.grey[200]),
              ),
          ],
        );

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isTablet) const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: isTablet ? 11 : 13, fontWeight: concluido ? FontWeight.bold : FontWeight.normal, color: concluido ? (isDark ? Colors.white : Colors.black87) : Colors.grey)),
        Text(hora, style: TextStyle(fontSize: 10, color: concluido ? (isDark ? Colors.white70 : Colors.black54) : Colors.grey)),
        if (usuarioNome.isNotEmpty)
          Text(usuarioNome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: _detPrimary.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
        if (duracao.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text("⏱ $duracao", style: const TextStyle(fontSize: 8, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
      ],
    );

    return isTablet 
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [visualNode, content],
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [visualNode, const SizedBox(width: 12), Expanded(child: content)],
        );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2A43), const Color(0xFF184E77)]
              : [_detPrimaryDark, _detPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.operacao['cedente']?.toString().toUpperCase() ?? "CEDENTE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  _buildHeaderBadge("Bordero #${widget.operacao['bordero']} ( ${widget.operacao['tp']})"),
                  const SizedBox(width: 8),
                  _buildHeaderBadge("${widget.operacao['qtd']} Títulos"),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("PROCESSADO EM", style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.92), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled, size: 12, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_getTempoTotalProcesso(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), 
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSecaoTitulo(String titulo, bool isDark) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(titulo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.grey[600], letterSpacing: 1.1)));
  }

  Widget _buildFinanceGrid(bool isTablet, bool isDark) {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 4 : 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.3,
      children: [
        _buildFinanceCard("BRUTO", widget.operacao['vrBruto'], isDark ? Colors.white : Colors.black87, Icons.account_balance_wallet_outlined, isDark),
        _buildFinanceCard("DEDUÇÕES", widget.operacao['ded'], _detDanger, Icons.remove_circle_outline, isDark),
        _buildFinanceCard("LÍQUIDO", widget.operacao['vrLiquido'], _detPrimary, Icons.account_balance_outlined, isDark),
        _buildFinanceCard("LIBERADO", widget.operacao['vr_liberado'], _detAccent, Icons.check_circle_outline, isDark, destaque: true),
      ],
    );
  }

  Widget _buildTaxasGrid(bool isTablet, bool isDark) {
    double tac = double.tryParse(widget.operacao['tac']?.toString() ?? '0') ?? 0;
    double assinatura = double.tryParse(widget.operacao['assinatura_Titulo']?.toString() ?? '0') ?? 0;
    double registro = double.tryParse(widget.operacao['registro_titulo']?.toString() ?? '0') ?? 0;
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 4 : 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.3,
      children: [
        _buildTaxaItem("TAC", tac, isDark),
        _buildTaxaItem("ASSINATURA", assinatura, isDark),
        _buildTaxaItem("REGISTRO", registro, isDark),
        _buildTaxaItem("TOTAL TARIFAS", tac + assinatura + registro, isDark, destaque: true),
      ],
    );
  }

  Widget _buildFinanceCard(String title, dynamic valor, Color color, IconData icon, bool isDark, {bool destaque = false}) {
    final String val = NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor ?? 0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _detDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: destaque
              ? color.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : _detBorderLight),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [Icon(icon, size: 10, color: color), const SizedBox(width: 4), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 4),
        FittedBox(child: Text(val, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900))),
      ]),
    );
  }

  Widget _buildTaxaItem(String label, dynamic valor, bool isDark, {bool destaque = false}) {
    final String val = NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor ?? 0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: destaque
            ? (isDark ? _detAccent.withValues(alpha: 0.12) : const Color(0xFFECFDF5))
            : (isDark ? _detDarkSurfaceAlt : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: destaque
              ? _detAccent.withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : _detBorderLight),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        FittedBox(child: Text(val, style: TextStyle(color: destaque ? _detAccent : (isDark ? Colors.white : Colors.black87), fontSize: 14, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}
