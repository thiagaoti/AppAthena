import 'dart:convert';

import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/componentes/layout_base.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const _estrPrimary = Color(0xFF0E7490);
const _estrPrimaryDark = Color(0xFF0F766E);
const _estrAccent = Color(0xFF22C55E);
const _estrDanger = Color(0xFFDC2626);
const _estrDarkSurface = Color(0xFF17181C);
const _estrDarkSurfaceAlt = Color(0xFF1C1C1E);
const _estrBorderLight = Color(0xFFE2E8F0);
const _estrSurfaceAltLight = Color(0xFFF8FAFC);

class TelaOperacoesEstruturadas extends StatefulWidget {
  final String cnpj;
  final String nomeCedente;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;

  const TelaOperacoesEstruturadas({
    super.key,
    required this.cnpj,
    required this.nomeCedente,
    required this.sessao,
    this.aoTrocarPerfil,
  });

  @override
  State<TelaOperacoesEstruturadas> createState() =>
      _TelaOperacoesEstruturadasState();
}

class _TelaOperacoesEstruturadasState extends State<TelaOperacoesEstruturadas> {
  bool _carregando = true;
  List<Map<String, dynamic>> _operacoes = const [];
  final Set<String> _operacoesExpandidas = <String>{};

  @override
  void initState() {
    super.initState();
    _carregarOperacoes();
  }

  Future<void> _carregarOperacoes() async {
    setState(() => _carregando = true);

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://athenaapp.athenabanco.com.br/api/App/ccbgarantia?cnpj=${widget.cnpj}',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Erro ao carregar operacoes estruturadas');
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> valores = json['dados']?['\$values'] ?? const [];

      if (!mounted) return;

      setState(() {
        _operacoes = _agruparOperacoes(
          valores.map((item) => Map<String, dynamic>.from(item)).toList(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel carregar as operacoes estruturadas.'),
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

  String _formatarData(dynamic value) {
    final data = _parseData(value);
    if (data == null) return '--';
    return DateFormat('dd/MM/yyyy').format(data);
  }

  dynamic _primeiroValorPreenchido(
    List<Map<String, dynamic>> itens,
    List<String> chaves,
  ) {
    for (final item in itens) {
      for (final chave in chaves) {
        final valor = item[chave];
        if (valor == null) continue;
        final texto = valor.toString().trim();
        if (texto.isNotEmpty) return valor;
      }
    }
    return null;
  }

  double _primeiroDoublePreenchido(
    List<Map<String, dynamic>> itens,
    List<String> chaves,
  ) {
    return _asDouble(_primeiroValorPreenchido(itens, chaves));
  }

  bool _textoTemValor(dynamic value) {
    if (value == null) return false;
    final texto = value.toString().trim();
    if (texto.isEmpty) return false;

    final normalizado = texto.toLowerCase();
    return normalizado != 'null' &&
        normalizado != '--' &&
        normalizado != '0' &&
        normalizado != '0,00' &&
        normalizado != '0.00';
  }

  String _percentual(dynamic value) {
    final numero = _asDouble(value);
    return '${numero.toStringAsFixed(numero % 1 == 0 ? 0 : 2)}%';
  }

  List<Map<String, dynamic>> _agruparOperacoes(List<Map<String, dynamic>> itens) {
    final mapa = <String, List<Map<String, dynamic>>>{};
    for (final item in itens) {
      final operacao = (item['operacao'] ?? 'Operacao').toString();
      mapa.putIfAbsent(operacao, () => []).add(item);
    }

    final grupos = mapa.entries.map((entry) {
      final garantias = List<Map<String, dynamic>>.from(entry.value);
      final base = garantias.first;
      final totalCarteira = _asDouble(
        _primeiroValorPreenchido(garantias, const ['total_Carteira']),
      );
      final vencidosMais15 = _asDouble(
        _primeiroValorPreenchido(garantias, const ['vencidosMais15']),
      );
      final cobrancaNAceita = _asDouble(
        _primeiroValorPreenchido(garantias, const ['cobrancaNAceita']),
      );
      final prazoSuperior = _asDouble(
        _primeiroValorPreenchido(garantias, const ['przSuperior']),
      );
      final carteiraValidaTotal =
          totalCarteira - vencidosMais15 - cobrancaNAceita - prazoSuperior;
      final saldoCaucao = _asDouble(
        _primeiroValorPreenchido(garantias, const ['saldoCaucao']),
      );
      final dtOperacao = _primeiroValorPreenchido(
        garantias,
        const ['dtOperacao'],
      );
      final dtGarantia = _primeiroValorPreenchido(
        garantias,
        const ['dtGarantia', 'maiorVencimentoOperacao'],
      );
      final percentualContratado = _asDouble(base['pContratada']);
      final garantiaNecessaria = percentualContratado == 100
          ? 0.0
          : _asDouble(base['garantia_necessaria'] ?? base['garantia_Necessaria']);

      return {
        'operacao': entry.key,
        'tipoOperacao': base['tipoOperacao'],
        'dtOperacao': dtOperacao,
        'dtGarantia': dtGarantia,
        'maiorVencimentoOperacao':
            _primeiroValorPreenchido(
              garantias,
              const ['maiorVencimentoOperacao', 'dtGarantia'],
            ),
        'pContratada': percentualContratado,
        'riscoAtual': _asDouble(base['riscoAtual']),
        'garantiaNecessaria': garantiaNecessaria,
        'garantiaCarteira': carteiraValidaTotal,
        'totalCarteira': totalCarteira,
        'saldoCaucao': saldoCaucao,
        'przSuperior': prazoSuperior,
        'vencidosMais15': vencidosMais15,
        'cobrancaNAceita': cobrancaNAceita,
        'faltaExcesso':
            (carteiraValidaTotal + saldoCaucao) - garantiaNecessaria,
        'vl_CCBVencidas': _asDouble(base['vl_CCBVencidas']),
        'garantias': garantias,
      };
    }).toList(growable: false);

    grupos.sort((a, b) {
      final dataB = _parseData(b['dtOperacao']);
      final dataA = _parseData(a['dtOperacao']);

      if (dataA != null && dataB != null) {
        return dataB.compareTo(dataA);
      }
      if (dataB != null) return 1;
      if (dataA != null) return -1;
      return _asDouble(b['riscoAtual']).compareTo(_asDouble(a['riscoAtual']));
    });

    return grupos;
  }

  List<Map<String, dynamic>> _garantiasGerais() {
    final vistos = <String>{};
    final garantias = <Map<String, dynamic>>[];

    for (final operacao in _operacoes) {
      final itens =
          List<Map<String, dynamic>>.from(operacao['garantias'] ?? const []);
      for (final item in itens) {
        final avaliacao = _asDouble(item['avaliacao']);
        final possuiGarantia =
            avaliacao > 0 ||
            _textoTemValor(item['bordero_garantia']) ||
            _textoTemValor(item['natureza_Garantia']) ||
            _textoTemValor(item['tipo_Garantia']) ||
            _textoTemValor(item['descricao_Garantia']);
        if (!possuiGarantia) continue;

        final chave = [
          (item['bordero_garantia'] ?? '').toString(),
          (item['natureza_Garantia'] ?? '').toString(),
          (item['tipo_Garantia'] ?? '').toString(),
          avaliacao.toStringAsFixed(2),
          (item['descricao_Garantia'] ?? '').toString(),
        ].join('|');
        if (vistos.add(chave)) {
          garantias.add(item);
        }
      }
    }

    return garantias;
  }

  void _alternarOperacao(String id) {
    setState(() {
      if (_operacoesExpandidas.contains(id)) {
        _operacoesExpandidas.remove(id);
      } else {
        _operacoesExpandidas.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalRisco = _operacoes.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['riscoAtual']),
    );
    final totalGarantiaNecessaria = _operacoes.fold<double>(
      0,
      (soma, item) => soma + _asDouble(item['garantiaNecessaria']),
    );
    final totalGarantiaCarteira = _primeiroDoublePreenchido(
      _operacoes,
      const ['garantiaCarteira'],
    );
    final totalSaldoCaucao = _primeiroDoublePreenchido(
      _operacoes,
      const ['saldoCaucao'],
    );
    final totalFaltaExcesso =
        (totalGarantiaCarteira + totalSaldoCaucao) - totalGarantiaNecessaria;
    final garantiasGerais = _garantiasGerais();

    return LayoutBase(
      titulo: 'Operações Estruturadas',
      nomeUsuario: widget.sessao.saudacaoUsuario,
      perfilUsuario: widget.sessao.rotuloPerfilAtual,
      aoTrocarPerfil: widget.aoTrocarPerfil,
      indexSelecionado: 2,
      aoMudarAba: (_) => Navigator.pop(context),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: _estrPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      conteudo: RefreshIndicator(
        onRefresh: _carregarOperacoes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeader(isDark, totalRisco),
            const SizedBox(height: 4),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: _estrPrimary),
                ),
              )
            else if (_operacoes.isEmpty)
              _buildEmptyState(isDark)
            else ...[
              _buildSectionTitle('Operações em aberto', isDark),
              const SizedBox(height: 4),
              _buildOperacoesLista(_operacoes, isDark),
              const SizedBox(height: 4),
              _buildSectionTitle('Resumo geral', isDark),
              const SizedBox(height: 4),
              _buildResumoGeral(
                isDark: isDark,
                garantiaNecessaria: totalGarantiaNecessaria,
                garantiaCarteira: totalGarantiaCarteira,
                faltaExcesso: totalFaltaExcesso,
                saldoCaucao: totalSaldoCaucao,
              ),
              if (garantiasGerais.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildSectionTitle('Garantia real', isDark),
                const SizedBox(height: 4),
                ...garantiasGerais.map(
                  (garantia) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildGarantiaCard(garantia, isDark),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, double totalRisco) {
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
          const SizedBox(height: 4),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMini('Operacoes', _operacoes.length.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderMini('Risco atual', _moeda(totalRisco)),
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

  Widget _buildOperacoesLista(List<Map<String, dynamic>> operacoes, bool isDark) {
    return Column(
      children: operacoes.map((operacao) {
        final operacaoId = operacao['operacao']?.toString() ?? '--';
        final expandido = _operacoesExpandidas.contains(operacaoId);
        final vencido = _asDouble(operacao['vl_CCBVencidas']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? _estrDarkSurfaceAlt : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: vencido > 0
                    ? _estrDanger.withValues(alpha: 0.28)
                    : (isDark ? Colors.white10 : _estrBorderLight),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _alternarOperacao(operacaoId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Operacao',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      operacaoId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _estrPrimary.withValues(alpha: isDark ? 0.18 : 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: _estrPrimary.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      '${operacao['tipoOperacao'] ?? '--'}',
                                      style: const TextStyle(
                                        color: _estrPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (vencido > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Existem operações estruturadas vencidas ${_moeda(vencido)}',
                                  style: const TextStyle(
                                    color: _estrDanger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Risco atual',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _moeda(_asDouble(operacao['riscoAtual'])),
                              style: const TextStyle(
                                color: _estrPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
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
                        Divider(
                          height: 12,
                          color: isDark ? Colors.white10 : _estrBorderLight,
                        ),
                        _buildMetricLine(
                          'Data operacao',
                          _formatarData(operacao['dtOperacao']),
                          isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildMetricLine(
                          'Data garantia',
                          _formatarData(operacao['dtGarantia']),
                          isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildMetricLine(
                          'Percentual contratado',
                          _percentual(operacao['pContratada']),
                          isDark,
                          valueColor: _estrPrimary,
                        ),
                        const SizedBox(height: 8),
                        _buildMetricLine(
                          'Risco atual',
                          _moeda(_asDouble(operacao['riscoAtual'])),
                          isDark,
                          valueColor: _estrPrimary,
                        ),
                        const SizedBox(height: 8),
                        _buildMetricLine(
                          'Garantia necessaria',
                          _moeda(_asDouble(operacao['garantiaNecessaria'])),
                          isDark,
                          valueColor: _estrPrimaryDark,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildResumoGeral({
    required bool isDark,
    required double garantiaNecessaria,
    required double garantiaCarteira,
    required double faltaExcesso,
    required double saldoCaucao,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.72,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildResumoMiniCard(
          'Garantia necessaria total',
          _moeda(garantiaNecessaria),
          isDark,
          icon: Icons.verified_user_outlined,
          valueColor: _estrPrimaryDark,
        ),
        _buildResumoMiniCard(
          'Carteira valida',
          _moeda(garantiaCarteira),
          isDark,
          icon: Icons.account_balance_wallet_outlined,
        ),
        _buildResumoMiniCard(
          'Saldo da conta caucao',
          _moeda(saldoCaucao),
          isDark,
          icon: Icons.savings_outlined,
          valueColor: _estrPrimary,
        ),
        _buildResumoMiniCard(
          faltaExcesso < 0 ? 'Total falta' : 'Total excesso',
          _moeda(faltaExcesso),
          isDark,
          icon: faltaExcesso < 0
              ? Icons.trending_down_rounded
              : Icons.trending_up_rounded,
          valueColor: faltaExcesso < 0 ? _estrDanger : _estrAccent,
          highlight: faltaExcesso < 0,
        ),
      ],
    );
  }

  Widget _buildResumoMiniCard(
    String label,
    String value,
    bool isDark, {
    required IconData icon,
    Color? valueColor,
    bool highlight = false,
  }) {
    final iconColor = valueColor ?? (isDark ? Colors.white70 : const Color(0xFF111827));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? _estrDanger.withValues(alpha: isDark ? 0.14 : 0.08)
            : (isDark ? _estrDarkSurfaceAlt : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? _estrDanger.withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : _estrBorderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF111827),
        fontSize: 16,
        fontWeight: FontWeight.w800,
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildGarantiaCard(Map<String, dynamic> garantia, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _estrDarkSurface : _estrSurfaceAltLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : _estrBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricLine(
            'Bordero',
            garantia['bordero_garantia']?.toString() ?? '--',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildMetricLine(
            'Natureza',
            garantia['natureza_Garantia']?.toString() ?? '--',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildMetricLine(
            'Tipo',
            garantia['tipo_Garantia']?.toString() ?? '--',
            isDark,
          ),
          const SizedBox(height: 8),
          _buildMetricLine(
            'Avaliacao',
            _moeda(_asDouble(garantia['avaliacao'])),
            isDark,
            valueColor: _estrPrimary,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Descricao',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  garantia['descricao_Garantia']?.toString() ?? '--',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? _estrDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : _estrBorderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 46,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma operacao estruturada encontrada para este cedente.',
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
