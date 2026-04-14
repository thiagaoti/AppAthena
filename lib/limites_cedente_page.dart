import 'dart:convert';

import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/componentes/layout_base.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TelaLimitesCedente extends StatefulWidget {
  final String cnpj;
  final String nomeCedente;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;

  const TelaLimitesCedente({
    super.key,
    required this.cnpj,
    required this.nomeCedente,
    required this.sessao,
    this.aoTrocarPerfil,
  });

  @override
  State<TelaLimitesCedente> createState() => _TelaLimitesCedenteState();
}

class _TelaLimitesCedenteState extends State<TelaLimitesCedente> {
  bool _carregando = true;
  List<Map<String, dynamic>> _limites = const [];
  Set<String>? _operacoesExpandidas;

  @override
  void initState() {
    super.initState();
    _carregarLimites();
  }

  Future<void> _carregarLimites() async {
    setState(() => _carregando = true);

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://athenaapp.athenabanco.com.br/api/App/posicaoliquidado?cnpj=${widget.cnpj}',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar limites');
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> valores = json['dados']?['\$values'] ?? const [];
      if (!mounted) return;

      setState(() {
        _limites = valores
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar os limites do cedente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
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

  DateTime? _dataRevLimPrincipal() {
    final datas = _limites
        .map((item) => _parseData(item['DataRevLim'] ?? item['dataRevLim']))
        .whereType<DateTime>()
        .toList(growable: false);
    if (datas.isEmpty) return null;
    datas.sort();
    return datas.first;
  }

  int? _diasParaVencimento(DateTime? data) {
    if (data == null) return null;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final alvo = DateTime(data.year, data.month, data.day);
    return alvo.difference(hoje).inDays;
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '--';
    return DateFormat('dd/MM/yyyy').format(data);
  }

  String _textoTempoVencimento(DateTime? data) {
    final dias = _diasParaVencimento(data);
    if (dias == null) return 'Data de vencimento do limite indisponivel';
    if (dias < 0) {
      final atraso = dias.abs();
      return atraso == 1
          ? 'Limite vencido ha 1 dia'
          : 'Limite vencido ha $atraso dias';
    }
    if (dias == 0) return 'Limite vence hoje';
    if (dias == 1) return 'Falta 1 dia para vencer';
    return 'Faltam $dias dias para vencer';
  }

  bool _ehLimiteCompartilhado(String operacao) {
    final nome = operacao.toUpperCase();
    return nome.contains('CCB') ||
        nome.contains('NOTA COMERCIAL') ||
        nome == 'NC';
  }

  List<Map<String, dynamic>> _limitesValidosParaSoma() {
    return _limites
        .where((item) => _asDouble(item['limites']) > 0)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _limitesValidosParaUso() {
    return _limites
        .where((item) {
          final limite = _asDouble(item['limites']);
          final operacao = item['operacao']?.toString() ?? '';
          return limite > 0 || _ehLimiteCompartilhado(operacao);
        })
        .toList(growable: false);
  }

  double _riscoSacadoInformativo(List<Map<String, dynamic>> itens) {
    for (final item in itens) {
      final risco = _asDouble(item['riscoSacado']);
      if (risco > 0) return risco;
    }
    return 0;
  }

  double _limiteOperacoesEstruturadasResumo(
    List<Map<String, dynamic>> itens,
  ) {
    for (final item in itens) {
      if (item['compartilhado'] == true) {
        return _asDouble(item['limites']);
      }
    }
    return 0;
  }

  String _cardId(Map<String, dynamic> item) {
    return item['operacao']?.toString() ?? 'operacao';
  }

  void _alternarExpansao(String id) {
    final operacoesExpandidas = _operacoesExpandidas ??= <String>{};
    setState(() {
      if (operacoesExpandidas.contains(id)) {
        operacoesExpandidas.remove(id);
      } else {
        operacoesExpandidas.add(id);
      }
    });
  }

  List<Map<String, dynamic>> _montarLimitesExibicao() {
    final List<Map<String, dynamic>> ccbNcItens = [];
    final List<Map<String, dynamic>> demaisItens = [];
    Map<String, dynamic>? operacoesEstruturadas;

    for (final item in _limites) {
      final operacao = item['operacao']?.toString() ?? '';
      if (_ehLimiteCompartilhado(operacao)) {
        ccbNcItens.add(item);
      } else {
        demaisItens.add(item);
      }
    }

    final List<Map<String, dynamic>> exibicao = [];

    if (ccbNcItens.isNotEmpty) {
      final limiteCompartilhado = ccbNcItens.fold<double>(
        0,
        (atual, item) => atual > _asDouble(item['limites'])
            ? atual
            : _asDouble(item['limites']),
      );
      final totalEmAberto = ccbNcItens.fold<double>(
        0,
        (soma, item) => soma + _asDouble(item['totalemAberto']),
      );
      final aVencer = ccbNcItens.fold<double>(
        0,
        (soma, item) => soma + _asDouble(item['aVencerValor']),
      );
      final vencido = ccbNcItens.fold<double>(
        0,
        (soma, item) => soma + _asDouble(item['vencidoValor']),
      );
      final riscoSacado = ccbNcItens.fold<double>(
        0,
        (soma, item) => soma + _asDouble(item['riscoSacado']),
      );

      if (limiteCompartilhado > 0) {
        operacoesEstruturadas = {
          'operacao': 'Oper. Estruturadas',
          'limites': limiteCompartilhado,
          'totalemAberto': totalEmAberto,
          'riscoSacado': riscoSacado,
          'aVencerValor': aVencer,
          'vencidoValor': vencido,
          'saldodoLimite': limiteCompartilhado - totalEmAberto,
          'compartilhado': true,
          'detalhes': ccbNcItens
              .map(
                (item) => {
                  'operacao': item['operacao']?.toString() ?? 'Operacao',
                  'totalemAberto': _asDouble(item['totalemAberto']),
                },
              )
              .toList(growable: false),
        };
      }
    }

    exibicao.addAll(
      demaisItens.map(
        (item) => {
          ...item,
          'compartilhado': false,
          'detalhes': [
            {
              'operacao': item['operacao']?.toString() ?? 'Operacao',
              'totalemAberto': _asDouble(item['totalemAberto']),
            },
          ],
        },
      ),
    );

    if (operacoesEstruturadas != null) {
      exibicao.add(operacoesEstruturadas);
    }

    return exibicao
        .where((item) => _asDouble(item['limites']) > 0)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final limitesValidos = _limitesValidosParaSoma();
    final limitesValidosParaUso = _limitesValidosParaUso();
    final limitesExibicao = _montarLimitesExibicao();
    final dataRevLim = _dataRevLimPrincipal();
    final diasParaVencer = _diasParaVencimento(dataRevLim);
    final exibirAlertaVencimento =
        diasParaVencer != null && diasParaVencer <= 5;
    final totalLimite = limitesValidos.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['limites']),
    );
    final totalUsado = limitesValidosParaUso.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['totalemAberto']),
    );
    final riscoSacadoInformativo = _riscoSacadoInformativo(limitesValidos);
    final limiteOperacoesEstruturadas =
        _limiteOperacoesEstruturadasResumo(limitesExibicao);
    final totalSaldo = limitesValidos.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['saldodoLimite']),
    );
    final usoPercentual = totalLimite <= 0
        ? 0.0
        : (totalUsado / totalLimite).clamp(0.0, 1.0);

    return LayoutBase(
      titulo: 'Limites do Cedente',
      nomeUsuario: widget.sessao.saudacaoUsuario,
      perfilUsuario: widget.sessao.rotuloPerfilAtual,
      aoTrocarPerfil: widget.aoTrocarPerfil,
      indexSelecionado: 2,
      aoMudarAba: (_) => Navigator.pop(context),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Color(0xFF0E7490),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      conteudo: RefreshIndicator(
        onRefresh: _carregarLimites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeaderCard(isDark, dataRevLim),
            const SizedBox(height: 16),
            if (exibirAlertaVencimento && diasParaVencer != null) ...[
              _buildAlertaVencimento(isDark, dataRevLim, diasParaVencer),
              const SizedBox(height: 16),
            ],
            if (_carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (limitesExibicao.isEmpty)
              _buildEmptyState(isDark)
            else ...[
              _buildResumoCard(
                isDark: isDark,
                totalLimite: totalLimite,
                totalUsado: totalUsado,
                riscoSacadoInformativo: riscoSacadoInformativo,
                limiteOperacoesEstruturadas: limiteOperacoesEstruturadas,
                totalSaldo: totalSaldo,
                usoPercentual: usoPercentual,
              ),
              const SizedBox(height: 16),
              ...limitesExibicao.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOperacaoCard(item, isDark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark, DateTime? dataRevLim) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Visao de limite',
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
                const SizedBox(height: 2),
                Text(
                  'CNPJ ${widget.cnpj}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vencimento do limite',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatarData(dataRevLim),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _textoTempoVencimento(dataRevLim),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaVencimento(
    bool isDark,
    DateTime? dataRevLim,
    int diasParaVencer,
  ) {
    final vencido = diasParaVencer < 0;
    final cor = vencido ? Colors.redAccent : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            vencido ? Icons.warning_rounded : Icons.notifications_active_rounded,
            color: cor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vencido ? 'Limite vencido' : 'Alerta de vencimento do limite',
                  style: TextStyle(
                    color: cor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Data ${_formatarData(dataRevLim)}. ${_textoTempoVencimento(dataRevLim)}.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard({
    required bool isDark,
    required double totalLimite,
    required double totalUsado,
    required double riscoSacadoInformativo,
    required double limiteOperacoesEstruturadas,
    required double totalSaldo,
    required double usoPercentual,
  }) {
    final corSaldo = totalSaldo < 0 ? Colors.redAccent : Colors.green;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17181C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo geral',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),          
          _buildMetricLine(
            'Risco como sacado',
            _moeda(riscoSacadoInformativo),
            isDark,
            valueColor: const Color(0xFFEA580C),
          ),
          if (limiteOperacoesEstruturadas > 0) ...[
            const SizedBox(height: 10),
            _buildMetricLine(
              'Limite oper. estruturadas',
              _moeda(limiteOperacoesEstruturadas),
              isDark,
              valueColor: const Color(0xFF0284C7),
            ),
          ],
          const SizedBox(height: 10),
          _buildMetricLine(
            'Limite total',
            _moeda(totalLimite),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildMetricLine(
            'Ja utilizado',
            _moeda(totalUsado),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildMetricLine(
            'Saldo disponivel',
            _moeda(totalSaldo),
            isDark,
            valueColor: corSaldo,
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: usoPercentual,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                totalSaldo < 0 ? Colors.redAccent : const Color(0xFF0EA5A4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(usoPercentual * 100).toStringAsFixed(1)}% do limite consumido',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricLine(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildOperacaoCard(Map<String, dynamic> item, bool isDark) {
    final operacao = item['operacao']?.toString() ?? 'Operacao';
    final limite = _asDouble(item['limites']);
    final usado = _asDouble(item['totalemAberto']);
    final aVencer = _asDouble(item['aVencerValor']);
    final vencido = _asDouble(item['vencidoValor']);
    final saldo = _asDouble(item['saldodoLimite']);
    final compartilhado = item['compartilhado'] == true;
    final detalhes =
        List<Map<String, dynamic>>.from(item['detalhes'] ?? const []);
    final percentualUso = limite <= 0 ? 0.0 : (usado / limite).clamp(0.0, 1.0);
    final excedido = saldo < 0;
    final expandido =
        (_operacoesExpandidas ?? const <String>{}).contains(_cardId(item));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: excedido
              ? Colors.redAccent.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE5E7EB)),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _alternarExpansao(_cardId(item)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          operacao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          excedido ? 'Acima do limite' : 'Dentro do limite',
                          style: TextStyle(
                            color:
                                excedido ? Colors.redAccent : Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: _buildResumoLista(
                      'Limite',
                      _moeda(limite),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildResumoLista(
                      'Saldo',
                      _moeda(saldo),
                      isDark,
                      destaqueCor: excedido ? Colors.redAccent : Colors.green,
                    ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 14),
                  _buildMetricLine(
                    compartilhado
                        ? 'Limite compartilhado'
                        : 'Limite da operacao',
                    _moeda(limite),
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricLine(
                    compartilhado
                        ? 'Total em aberto do grupo'
                        : 'Total em aberto',
                    _moeda(usado),
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricLine(
                    'Saldo do limite',
                    _moeda(saldo),
                    isDark,
                    valueColor: excedido ? Colors.redAccent : Colors.green,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: percentualUso,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        excedido ? Colors.redAccent : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    compartilhado
                        ? '${(percentualUso * 100).toStringAsFixed(1)}% do limite compartilhado utilizado'
                        : '${(percentualUso * 100).toStringAsFixed(1)}% utilizado nesta operacao',
                    style: TextStyle(
                      color:
                          isDark ? Colors.white60 : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (compartilhado) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Total em aberto por operacao',
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF374151),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...detalhes.map(
                      (detalhe) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildDetalheOperacao(
                          detalhe['operacao']?.toString() ?? 'Operacao',
                          _moeda(_asDouble(detalhe['totalemAberto'])),
                          isDark,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          'A vencer',
                          _moeda(aVencer),
                          const Color(0xFF0EA5A4),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoChip(
                          'Vencido',
                          _moeda(vencido),
                          const Color(0xFFEF4444),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumoLista(
    String label,
    String valor,
    bool isDark, {
    Color? destaqueCor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                destaqueCor ?? (isDark ? Colors.white : const Color(0xFF111827)),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildDetalheOperacao(String label, String valor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF374151),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    String label,
    String valor,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 46,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma informacao de limite foi encontrada para este cedente.',
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
