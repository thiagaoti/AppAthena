import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/operacoes_do_dia_service.dart';
import 'package:athenaapp/visualizar_detalhes_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _opsBgLight = Color(0xFFF4F7F5);
const _opsSurfaceLight = Colors.white;
const _opsSurfaceAltLight = Color(0xFFF8FAFC);
const _opsBorderLight = Color(0xFFE2E8F0);
const _opsPrimary = Color(0xFF0E7490);
const _opsPrimarySoft = Color(0xFF0EA5A4);
const _opsAccent = Color(0xFF22C55E);
const _opsDanger = Color(0xFFDC2626);
const _opsDarkSurfaceAlt = Color(0xFF1C1C1E);

String fMoeda(double valor) {
  return NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor);
}

class TelaRelatorio extends StatefulWidget {
  final String nome;
  final AuthSession sessao;
  final Future<void> Function()? aoTrocarPerfil;
  final Function(String cnpj, String nome) aoSelecionarCedente;

  const TelaRelatorio({
    super.key,
    required this.nome,
    required this.sessao,
    this.aoTrocarPerfil,
    required this.aoSelecionarCedente,
  });

  @override
  State<TelaRelatorio> createState() => _TelaRelatorioState();
}

class _TelaRelatorioState extends State<TelaRelatorio> {
  final ScrollController _scrollController = ScrollController();
  bool _mostrarBotaoTopo = false;

  String filtroNome = '';
  List<dynamic> dadosOriginais = [];
  bool carregando = false;
  DateTime dataSelecionada = DateTime.now();
  int filtroStatusSelecionado = 0;

  @override
  void initState() {
    super.initState();

    if (dadosOriginais.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => buscarDados());
    }

    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.offset > 400) {
        if (!_mostrarBotaoTopo) setState(() => _mostrarBotaoTopo = true);
      } else {
        if (_mostrarBotaoTopo) setState(() => _mostrarBotaoTopo = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _irParaOTopo() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? colhida = await showDatePicker(
      context: context,
      initialDate: dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (colhida != null) {
      setState(() {
        dataSelecionada = colhida;
        carregando = true;
      });
      await buscarDados();
    }
  }

  Future<void> buscarDados() async {
    if (!mounted) return;
    setState(() => carregando = true);

    try {
      final dados = await OperacoesDoDiaService.buscar(
        dataSelecionada,
        sessao: widget.sessao,
      );
      if (!mounted) return;
      setState(() => dadosOriginais = dados);
    } catch (e) {
      _msg('Erro ao conectar com servidor.');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final double larguraTela = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<dynamic> listaParaExibir = dadosOriginais.where((item) {
      final valorOFC = (item['ofc'] ?? '').toString().toUpperCase().trim();
      final bateNome = (item['cedente'] ?? '').toString().toLowerCase().contains(filtroNome.toLowerCase());
      if (filtroStatusSelecionado == 0) return bateNome && valorOFC.contains('SIMULADO');
      return bateNome && valorOFC.contains('OFICIALIZADO');
    }).toList();

    listaParaExibir.sort((a, b) {
      if (filtroStatusSelecionado == 0) {
        final bordA = int.tryParse(a['bordero'].toString()) ?? 0;
        final bordB = int.tryParse(b['bordero'].toString()) ?? 0;
        return bordA.compareTo(bordB);
      } else {
        int prioridade(dynamic item) {
          final tp = (item['tp'] ?? '').toString();
          if (tp.startsWith('CS')) return 3;
          if (item['asS_CEDENTE'] == 'S' && item['asS_ADMINISTRADORA'] == 'S') return 2;
          return 1;
        }

        final pA = prioridade(a);
        final pB = prioridade(b);
        if (pA != pB) return pA.compareTo(pB);
        return (int.tryParse(b['bordero'].toString()) ?? 0)
            .compareTo(int.tryParse(a['bordero'].toString()) ?? 0);
      }
    });

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : _opsBgLight,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  _buildSeletorData(isDark),
                  const Spacer(),
                  _buildTabFiltro(isDark),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildResumoConsolidado(isDark)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _buildCampoBusca(isDark),
            ),
          ),
          if (carregando && dadosOriginais.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _opsPrimary)),
            )
          else if (listaParaExibir.isEmpty && !carregando)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Nenhuma operacao encontrada.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: larguraTela > 900 ? 3 : (larguraTela > 600 ? 2 : 1),
                  mainAxisExtent: 195,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCardOperacao(listaParaExibir[index], isDark),
                  childCount: listaParaExibir.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: _mostrarBotaoTopo
          ? Padding(
              padding: const EdgeInsets.only(bottom: 70.0),
              child: FloatingActionButton(
                heroTag: 'relatorio-topo-fab',
                onPressed: _irParaOTopo,
                backgroundColor: _opsPrimary,
                mini: true,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildSeletorData(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _selecionarData(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : _opsSurfaceAltLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: _opsPrimary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(dataSelecionada),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: carregando ? null : buscarDados,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : _opsSurfaceAltLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: carregando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_opsPrimary),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18, color: _opsPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildResumoConsolidado(bool isDark) {
    if (dadosOriginais.isEmpty) return const SizedBox.shrink();

    double totalOfc = 0;
    double totalSim = 0;
    final Map<String, Map<String, double>> agrupado = {};

    for (final item in dadosOriginais) {
      final bruto = (item['vrBruto'] ?? 0).toDouble();
      if ((item['ofc'] ?? '').toString().toUpperCase().contains('SIMULADO')) {
        totalSim += bruto;
      } else {
        totalOfc += bruto;
      }

      final emp = item['empresa'] ?? 'N/A';
      agrupado.putIfAbsent(
        emp,
        () => {'vrBruto': 0.0, 'receita': 0.0, 'vr_liberado': 0.0},
      );
      agrupado[emp]!['vrBruto'] = agrupado[emp]!['vrBruto']! + bruto;
      agrupado[emp]!['receita'] = agrupado[emp]!['receita']! + (item['receita'] ?? 0).toDouble();
      agrupado[emp]!['vr_liberado'] =
          agrupado[emp]!['vr_liberado']! + (item['vr_liberado'] ?? 0).toDouble();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0F2A43), Color(0xFF184E77)]
              : const [Color(0xFF0F766E), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                    child: _buildTotalSimples(
                      'OFICIALIZADO',
                      totalOfc,
                      _opsAccent,
                      Icons.check_circle_outline,
                    ),
                  ),
                ),
                const VerticalDivider(color: Colors.white24, thickness: 1, indent: 10, endIndent: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                    child: _buildTotalSimples(
                      'SIMULADO',
                      totalSim,
                      const Color(0xFFF59E0B),
                      Icons.query_stats_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.white12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text(
                'PERFORMANCE POR EMPRESA',
                style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 0.5),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white54,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      _buildHeaderTabela(),
                      ...agrupado.entries.toList().asMap().entries.map(
                            (entry) => _buildLinhaEmpresa(entry.value, entry.key % 2 == 0),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardOperacao(Map<String, dynamic> item, bool isDark) {
    final cedente = (item['cedente'] ?? '').toString().trim().toUpperCase();
    final tp = (item['tp'] ?? '').toString();
    final isSimulado = (item['ofc'] ?? '').toString().toUpperCase().contains('SIMULADO');
    final txtAss = tp.startsWith('CS')
        ? 'N/A'
        : (item['asS_CEDENTE'] == 'S' && item['asS_ADMINISTRADORA'] == 'S')
            ? 'ASSINADO'
            : 'PENDENTE';
    final colAss = tp.startsWith('CS')
        ? Colors.grey
        : (txtAss == 'ASSINADO')
            ? Colors.green
            : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _opsDarkSurfaceAlt : _opsSurfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (txtAss == 'PENDENTE' && !isSimulado)
              ? Colors.orange.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : _opsBorderLight),
          width: (txtAss == 'PENDENTE' && !isSimulado) ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.aoSelecionarCedente(item['cnpj'].toString(), cedente),
                        child: Text(
                          cedente,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _opsPrimary,
                          ),
                        ),
                      ),
                    ),
                    _buildChipStatus(txtAss, colAss),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.business_center_outlined, size: 14, color: isSimulado ? _opsDanger : _opsAccent),
                    const SizedBox(width: 4),
                    Text(
                      item['empresa'] ?? '',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                    _buildMiniBadge(item['bordero'].toString(), isDark),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VALOR BRUTO',
                          style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey),
                        ),
                        Text(
                          fMoeda((item['vrBruto'] ?? 0).toDouble()),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                    _buildMiniBadge(tp, isDark),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoLegenda('RECEITA', fMoeda((item['receita'] ?? 0).toDouble()), isDark, _opsAccent),
                    _buildInfoLegenda('DEDUCOES', fMoeda((item['ded'] ?? 0).toDouble()), isDark, _opsDanger),
                    _buildInfoLegenda('PRAZO', '${(item['prz'] ?? 0).toDouble().round()}d', isDark, null),
                    _buildInfoLegenda('TAXA', '${item['tx']}%', isDark, null),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildBotaoDetalhes(item, isDark),
        ],
      ),
    );
  }

  Widget _buildTotalSimples(String label, double valor, Color cor, IconData icone) {
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
        Text(fMoeda(valor), style: TextStyle(color: cor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeaderTabela() {
    const style = TextStyle(color: Colors.white, fontSize: 9);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('EMPRESA', style: style)),
          Expanded(flex: 3, child: Text('BRUTO', textAlign: TextAlign.right, style: style)),
          Expanded(flex: 3, child: Text('RECEITA', textAlign: TextAlign.right, style: style)),
          Expanded(flex: 3, child: Text('LIBERADO', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }

  Widget _buildLinhaEmpresa(MapEntry<String, Map<String, double>> entry, bool isEven) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fMoeda(entry.value['vrBruto']!).replaceAll('R\$', ''),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fMoeda(entry.value['receita']!).replaceAll('R\$', ''),
              textAlign: TextAlign.right,
              style: const TextStyle(color: _opsAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fMoeda(entry.value['vr_liberado']!).replaceAll('R\$', ''),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipStatus(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  Widget _buildMiniBadge(String label, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : _opsSurfaceAltLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDark ? Colors.transparent : _opsBorderLight),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _buildInfoLegenda(String label, String value, bool isDark, Color? valColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valColor ?? (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      );

  Widget _buildBotaoDetalhes(Map<String, dynamic> item, bool isDark) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisualizarDetalhesPage(
              operacao: item,
              sessao: widget.sessao,
              aoTrocarPerfil: widget.aoTrocarPerfil,
            ),
          ),
        ),
        child: Container(
          height: 35,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : _opsSurfaceAltLight,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: const Center(
            child: Text(
              'VER DETALHES',
              style: TextStyle(color: _opsPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      );

  Widget _buildTabFiltro(bool isDark) => Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : _opsSurfaceAltLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [_buildTabButton('Simulados', 0, isDark), _buildTabButton('Oficializados', 1, isDark)]),
      );

  Widget _buildTabButton(String label, int index, bool isDark) {
    final sel = filtroStatusSelecionado == index;
    return GestureDetector(
      onTap: () => setState(() => filtroStatusSelecionado = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: sel ? (isDark ? const Color(0xFF0F2A43) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? _opsPrimarySoft : Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: sel ? (isDark ? Colors.white : _opsPrimary) : Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCampoBusca(bool isDark) => TextField(
        onChanged: (v) => setState(() => filtroNome = v),
        decoration: InputDecoration(
          hintText: 'Buscar cedente...',
          prefixIcon: const Icon(Icons.search, size: 20, color: _opsPrimary),
          filled: true,
          fillColor: isDark ? Colors.white10 : _opsSurfaceAltLight,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}
