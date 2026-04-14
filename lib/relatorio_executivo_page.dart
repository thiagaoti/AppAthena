import 'package:athenaapp/analise_desempenho_page.dart';
import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/operacoes_do_dia_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _execBgLight = Color(0xFFF4F7F5);
const _execBorderLight = Color(0xFFE2E8F0);
const _execPrimary = Color(0xFF0E7490);

String _fMoeda(double valor) {
  return NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor);
}

class RelatorioExecutivoPage extends StatefulWidget {
  final ValueNotifier<DateTime> dataSelecionadaNotifier;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;

  const RelatorioExecutivoPage({
    super.key,
    required this.dataSelecionadaNotifier,
    required this.sessao,
    this.aoTrocarPerfil,
  });

  @override
  State<RelatorioExecutivoPage> createState() => _RelatorioExecutivoPageState();
}

class _RelatorioExecutivoPageState extends State<RelatorioExecutivoPage> {
  List<Map<String, dynamic>> _dados = const [];
  bool _carregando = false;

  DateTime get _dataSelecionada => widget.dataSelecionadaNotifier.value;

  @override
  void initState() {
    super.initState();
    widget.dataSelecionadaNotifier.addListener(_sincronizarDataCompartilhada);
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarDados());
  }

  void _sincronizarDataCompartilhada() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.dataSelecionadaNotifier.removeListener(_sincronizarDataCompartilhada);
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      final dados = await OperacoesDoDiaService.buscar(
        _dataSelecionada,
        sessao: widget.sessao,
      );
      if (!mounted) return;
      setState(() => _dados = dados);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel carregar o relatorio executivo.')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (data == null) return;
    widget.dataSelecionadaNotifier.value = data;
    await _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resumo = _ResumoExecutivo.from(_dados);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : _execBgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Visão Diária'),
        actions: [
          IconButton(
            tooltip: 'Selecionar data',
            onPressed: _selecionarData,
            icon: const Icon(Icons.calendar_month_outlined, size: 22),
          ),
          IconButton(
            onPressed: _carregando ? null : _carregarDados,
            icon: _carregando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            padding: EdgeInsets.zero,
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: _execPrimary.withValues(alpha: 0.1),
              child: const Icon(
                Icons.person,
                color: _execPrimary,
                size: 18,
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ola, ${widget.sessao.saudacaoUsuario}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.sessao.rotuloPerfilAtual,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.aoTrocarPerfil != null) const PopupMenuDivider(),
              if (widget.aoTrocarPerfil != null)
                const PopupMenuItem<String>(
                  value: 'trocar_perfil',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Trocar perfil'),
                    ],
                  ),
                ),
            ],
            onSelected: (value) {
              if (value == 'trocar_perfil') {
                widget.aoTrocarPerfil?.call();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _carregando && _dados.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _execPrimary))
          : _dados.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma operacao encontrada para ${DateFormat('dd/MM/yyyy').format(_dataSelecionada)}.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: _buildHeroResumo(resumo, isDark),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(child: _buildPanoramaTopo(resumo, isDark)),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
    );
  }

  Widget _buildHeroResumo(_ResumoExecutivo resumo, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0F2A43), Color(0xFF12324B), Color(0xFF184E77)]
              : const [Color(0xFF0F766E), Color(0xFF0E7490), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Visao geral das operacoes do dia', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.3)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_fMoeda(resumo.volumeTotal), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${resumo.quantidadeBorderos} borderos',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  'Data: ${DateFormat('dd/MM/yyyy').format(_dataSelecionada)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.white12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                    child: _buildHeroTotalSimples(
                      'OFICIALIZADO',
                      resumo.volumeOficializado,
                      '${resumo.percentualOficializado.toStringAsFixed(1)}%',
                      const Color(0xFF22C55E),
                      Icons.check_circle_outline,
                    ),
                  ),
                ),
                const VerticalDivider(color: Colors.white24, thickness: 1, indent: 10, endIndent: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                    child: _buildHeroTotalSimples(
                      'SIMULADO',
                      resumo.volumeSimulado,
                      '${resumo.percentualSimulado.toStringAsFixed(1)}%',
                      const Color(0xFFF59E0B),
                      Icons.query_stats_rounded,
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

  Widget _buildHeroTotalSimples(
    String label,
    double valor,
    String percentual,
    Color cor,
    IconData icone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _fMoeda(valor),
            style: TextStyle(color: cor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          percentual,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildPanoramaTopo(_ResumoExecutivo resumo, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.maxWidth;
        final colunas = largura > 1100 ? 3 : (largura > 720 ? 2 : 1);
        final itemWidth = (largura - ((colunas - 1) * 12)) / colunas;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildTopListCard(
                titulo: 'Top 5 Plataformas',
                itens: resumo.rankingPlataformas.take(5).toList(growable: false),
                volumeTotal: resumo.volumeTotal,
                icone: Icons.apartment_rounded,
                isDark: isDark,
                onTapItem: (item) => _mostrarDetalhesAgrupados(
                  titulo: item.nome,
                  subtitulo: 'Operacoes da plataforma',
                  operacoes: _filtrarOperacoesPorCampo('plataforma', item.nome),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildTopListCard(
                titulo: 'Top 5 Gerentes',
                itens: resumo.rankingGerentes.take(5).toList(growable: false),
                volumeTotal: resumo.volumeTotal,
                icone: Icons.emoji_events_outlined,
                isDark: isDark,
                onTapItem: (item) => _mostrarDetalhesAgrupados(
                  titulo: item.nome,
                  subtitulo: 'Operacoes do gerente',
                  operacoes: _filtrarOperacoesPorCampo('gerente', item.nome),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildTopListCard(
                titulo: 'Top 5 Cedentes',
                itens: resumo.rankingCedentes.take(5).toList(growable: false),
                volumeTotal: resumo.volumeTotal,
                icone: Icons.business_center_outlined,
                isDark: isDark,
                exibirValor: false,
                onTapItem: _abrirAnaliseCedente,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopListCard({
    required String titulo,
    required List<_RankingItem> itens,
    required double volumeTotal,
    required IconData icone,
    required bool isDark,
    bool exibirValor = true,
    bool habilitarClique = true,
    void Function(_RankingItem item)? onTapItem,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151518) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : _execBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _execPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: _execPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (itens.isEmpty)
            Text(
              'Sem dados disponiveis.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            )
          else
            ...itens.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTopListItem(
                  entry.key + 1,
                  entry.value,
                  volumeTotal,
                  isDark,
                  exibirValor: exibirValor,
                  onTap: !habilitarClique
                      ? null
                      : (onTapItem == null
                          ? () => _mostrarValorTop(entry.value)
                          : () => onTapItem(entry.value)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopListItem(
    int posicao,
    _RankingItem item,
    double volumeTotal,
    bool isDark,
    {bool exibirValor = true, VoidCallback? onTap}
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap == null ? null : () => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _execPrimary.withValues(alpha: posicao == 1 ? 1 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$posicao',
                style: TextStyle(
                  color: posicao == 1 ? Colors.white : _execPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${item.quantidade} operacoes',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            if (exibirValor) ...[
              const SizedBox(width: 8),
              Text(
                _fMoeda(item.valor),
                style: const TextStyle(
                  color: _execPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _abrirAnaliseCedente(_RankingItem item) {
    if ((item.cnpj ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel localizar o CNPJ do cedente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF000000)
                  : _execBgLight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Análise de Desempenho'),
          ),
          body: SafeArea(
            top: false,
            child: TelaAnaliseDesempenho(
              cnpjInicial: item.cnpj,
              nomeInicial: item.nome,
              sessao: widget.sessao,
              listaSugestoes: const [],
              usarScaffold: false,
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarValorTop(_RankingItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Volume: ${_fMoeda(item.valor)}'),
            const SizedBox(height: 6),
            Text('Operacoes: ${item.quantidade}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filtrarOperacoesPorCampo(
    String campo,
    String valor,
  ) {
    return _dados.where((item) {
      final valorItem = (item[campo] ?? '').toString().trim().toUpperCase();
      return valorItem == valor.trim().toUpperCase();
    }).toList(growable: false);
  }

  void _mostrarDetalhesAgrupados({
    required String titulo,
    required String subtitulo,
    required List<Map<String, dynamic>> operacoes,
  }) {
    final listaOrdenada = List<Map<String, dynamic>>.from(operacoes)
      ..sort((a, b) {
        final valorB = _ResumoExecutivo._lerNumero(
          b,
          const ['vrBruto', 'vr_bruto', 'valor', 'vlrBruto'],
        );
        final valorA = _ResumoExecutivo._lerNumero(
          a,
          const ['vrBruto', 'vr_bruto', 'valor', 'vlrBruto'],
        );
        return valorB.compareTo(valorA);
      });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151518) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$subtitulo • ${listaOrdenada.length} operacoes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: listaOrdenada.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma operacao encontrada.',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: listaOrdenada.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = listaOrdenada[index];
                              final bordero = _ResumoExecutivo._lerTexto(
                                item,
                                const ['bordero', 'bordero_garantia'],
                                fallback: '--',
                              );
                              final tipo = _ResumoExecutivo._lerTexto(
                                item,
                                const ['tp'],
                                fallback: '--',
                              );
                              final valorBruto = _ResumoExecutivo._lerNumero(
                                item,
                                const ['vrBruto', 'vr_bruto', 'valor', 'vlrBruto'],
                              );
                              final cedente = _ResumoExecutivo._lerTexto(
                                item,
                                const ['cedente', 'nome'],
                                fallback: 'Cedente nao informado',
                              );

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1C1C1E)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : _execBorderLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cedente,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Bordero: $bordero',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            'Tipo: $tipo',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _fMoeda(valorBruto),
                                      style: const TextStyle(
                                        color: _execPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

}

class _ResumoExecutivo {
  final double volumeTotal;
  final double volumeOficializado;
  final double volumeSimulado;
  final double receitaTotal;
  final double valorLiberadoTotal;
  final double ticketMedio;
  final double taxaMedia;
  final double prazoMedio;
  final double percentualOficializado;
  final double percentualSimulado;
  final double conversaoReceita;
  final double concentracaoTop3Plataformas;
  final int quantidadeOperacoes;
  final int quantidadeBorderos;
  final int quantidadeEmpresas;
  final int pendentesAssinatura;
  final _RankingItem? plataformaLider;
  final _RankingItem? maiorPlataformaPorQuantidade;
  final _RankingItem? gerenteLider;
  final _RankingItem? cedenteLider;
  final _MaiorOperacao? maiorOperacao;
  final List<_RankingItem> rankingGerentes;
  final List<_RankingItem> rankingPlataformas;
  final List<_RankingItem> rankingCedentes;

  const _ResumoExecutivo({
    required this.volumeTotal,
    required this.volumeOficializado,
    required this.volumeSimulado,
    required this.receitaTotal,
    required this.valorLiberadoTotal,
    required this.ticketMedio,
    required this.taxaMedia,
    required this.prazoMedio,
    required this.percentualOficializado,
    required this.percentualSimulado,
    required this.conversaoReceita,
    required this.concentracaoTop3Plataformas,
    required this.quantidadeOperacoes,
    required this.quantidadeBorderos,
    required this.quantidadeEmpresas,
    required this.pendentesAssinatura,
    required this.plataformaLider,
    required this.maiorPlataformaPorQuantidade,
    required this.gerenteLider,
    required this.cedenteLider,
    required this.maiorOperacao,
    required this.rankingGerentes,
    required this.rankingPlataformas,
    required this.rankingCedentes,
  });

  factory _ResumoExecutivo.from(List<Map<String, dynamic>> dados) {
    double volumeTotal = 0;
    double volumeOficializado = 0;
    double volumeSimulado = 0;
    double receitaTotal = 0;
    double valorLiberadoTotal = 0;
    double somaTaxaPonderada = 0;
    double somaPrazoPonderado = 0;
    int pendentesAssinatura = 0;
    final borderos = <String>{};
    final empresas = <String>{};
    final plataformas = <String, _Acumulador>{};
    final gerentes = <String, _Acumulador>{};
    final cedentes = <String, _Acumulador>{};
    _MaiorOperacao? maiorOperacao;

    for (final item in dados) {
      final bruto = _lerNumero(item, ['vrBruto', 'vr_bruto', 'valor', 'vlrBruto']);
      final receita = _lerNumero(item, ['receita', 'receitA_LIQUIDA']);
      final liberado = _lerNumero(item, ['vr_liberado', 'vrLiberado', 'valorLiberado']);
      final taxa = _lerNumero(item, ['tx', 'taxa']);
      final prazo = _lerNumero(item, ['prz', 'prazo']);
      final bordero = _lerTexto(item, ['bordero', 'bordero_garantia'], fallback: 'Sem bordero');
      final empresa = _lerTexto(item, ['empresa'], fallback: 'Sem empresa');
      final plataforma = _lerTexto(item, ['plataforma', 'plat'], fallback: 'Sem plataforma');
      final gerente = _lerTexto(item, ['gerente', 'nome_gerente'], fallback: 'Sem gerente');
      final cedente = _lerTexto(item, ['cedente', 'nome'], fallback: 'Sem cedente');
      final cnpjCedente = _lerTexto(item, ['cnpj', 'cgc']);
      final tipo = _lerTexto(item, ['tp'], fallback: '--');
      final oficializado = _isOficializado(item);
      final assinaturaPendente = oficializado && !tipo.startsWith('CS') && ((_lerTexto(item, ['asS_CEDENTE']) != 'S') || (_lerTexto(item, ['asS_ADMINISTRADORA']) != 'S'));

      volumeTotal += bruto;
      receitaTotal += receita;
      valorLiberadoTotal += liberado;
      somaTaxaPonderada += taxa * bruto;
      somaPrazoPonderado += prazo * bruto;
      borderos.add(bordero);
      empresas.add(empresa);
      if (oficializado) {
        volumeOficializado += bruto;
      } else {
        volumeSimulado += bruto;
      }
      if (assinaturaPendente) pendentesAssinatura += 1;
      plataformas.putIfAbsent(plataforma, () => _Acumulador()).adicionar(bruto);
      gerentes.putIfAbsent(gerente, () => _Acumulador()).adicionar(bruto);
      cedentes.putIfAbsent(cedente, () => _Acumulador()).adicionar(bruto, cnpj: cnpjCedente);
      if (maiorOperacao == null || bruto > maiorOperacao.valor) {
        maiorOperacao = _MaiorOperacao(titulo: cedente, valor: bruto, descricao: 'Bordero $bordero | $plataforma | $tipo');
      }
    }

    final rankingPlataformas = _ordenarRanking(plataformas);
    final rankingGerentes = _ordenarRanking(gerentes);
    final rankingCedentes = _ordenarRanking(cedentes);
    final quantidadeOperacoes = dados.length;
    final double ticketMedio = quantidadeOperacoes == 0 ? 0.0 : volumeTotal / quantidadeOperacoes;
    final double taxaMedia = volumeTotal == 0 ? 0.0 : somaTaxaPonderada / volumeTotal;
    final double prazoMedio = volumeTotal == 0 ? 0.0 : somaPrazoPonderado / volumeTotal;
    final double percentualOficializado = volumeTotal == 0 ? 0.0 : (volumeOficializado / volumeTotal) * 100;
    final double percentualSimulado = volumeTotal == 0 ? 0.0 : (volumeSimulado / volumeTotal) * 100;
    final double conversaoReceita = volumeTotal == 0 ? 0.0 : (receitaTotal / volumeTotal) * 100;
    final top3Volume = rankingPlataformas.take(3).fold<double>(0, (soma, item) => soma + item.valor);
    final double concentracaoTop3 = volumeTotal == 0 ? 0.0 : (top3Volume / volumeTotal) * 100;

    _RankingItem? maiorPlataformaPorQuantidade;
    if (rankingPlataformas.isNotEmpty) {
      final copia = List<_RankingItem>.from(rankingPlataformas)
        ..sort((a, b) {
          final quantidadeCompare = b.quantidade.compareTo(a.quantidade);
          if (quantidadeCompare != 0) return quantidadeCompare;
          return b.valor.compareTo(a.valor);
        });
      maiorPlataformaPorQuantidade = copia.first;
    }

    return _ResumoExecutivo(
      volumeTotal: volumeTotal,
      volumeOficializado: volumeOficializado,
      volumeSimulado: volumeSimulado,
      receitaTotal: receitaTotal,
      valorLiberadoTotal: valorLiberadoTotal,
      ticketMedio: ticketMedio,
      taxaMedia: taxaMedia,
      prazoMedio: prazoMedio,
      percentualOficializado: percentualOficializado,
      percentualSimulado: percentualSimulado,
      conversaoReceita: conversaoReceita,
      concentracaoTop3Plataformas: concentracaoTop3,
      quantidadeOperacoes: quantidadeOperacoes,
      quantidadeBorderos: borderos.length,
      quantidadeEmpresas: empresas.length,
      pendentesAssinatura: pendentesAssinatura,
      plataformaLider: rankingPlataformas.isEmpty ? null : rankingPlataformas.first,
      maiorPlataformaPorQuantidade: maiorPlataformaPorQuantidade,
      gerenteLider: rankingGerentes.isEmpty ? null : rankingGerentes.first,
      cedenteLider: rankingCedentes.isEmpty ? null : rankingCedentes.first,
      maiorOperacao: maiorOperacao,
      rankingGerentes: rankingGerentes,
      rankingPlataformas: rankingPlataformas,
      rankingCedentes: rankingCedentes,
    );
  }

  static List<_RankingItem> _ordenarRanking(Map<String, _Acumulador> origem) {
    final lista = origem.entries
        .map(
          (entry) => _RankingItem(
            nome: entry.key,
            valor: entry.value.valor,
            quantidade: entry.value.quantidade,
            cnpj: entry.value.cnpj,
          ),
        )
        .toList(growable: false);
    lista.sort((a, b) => b.valor.compareTo(a.valor));
    return lista;
  }

  static double _lerNumero(Map<String, dynamic> item, List<String> chaves) {
    for (final chave in chaves) {
      final valor = item[chave];
      if (valor is num) return valor.toDouble();
      if (valor is String) {
        final normalizado = valor.replaceAll('.', '').replaceAll(',', '.').trim();
        final convertido = double.tryParse(normalizado);
        if (convertido != null) return convertido;
      }
    }
    return 0;
  }

  static String _lerTexto(Map<String, dynamic> item, List<String> chaves, {String fallback = ''}) {
    for (final chave in chaves) {
      final valor = item[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return fallback;
  }

  static bool _isOficializado(Map<String, dynamic> item) {
    final ofc = _lerTexto(item, ['ofc']).toUpperCase();
    return !ofc.contains('SIMULADO');
  }
}

class _Acumulador {
  double valor = 0;
  int quantidade = 0;
  String? cnpj;

  void adicionar(double novoValor, {String? cnpj}) {
    valor += novoValor;
    quantidade += 1;
    this.cnpj ??= (cnpj == null || cnpj.isEmpty) ? null : cnpj;
  }
}

class _RankingItem {
  final String nome;
  final double valor;
  final int quantidade;
  final String? cnpj;

  const _RankingItem({
    required this.nome,
    required this.valor,
    required this.quantidade,
    this.cnpj,
  });
}

class _MaiorOperacao {
  final String titulo;
  final double valor;
  final String descricao;

  const _MaiorOperacao({required this.titulo, required this.valor, required this.descricao});
}
