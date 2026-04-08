import 'package:athenaapp/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'DashboardController.dart';

const _dashBgLight = Color(0xFFF4F7F5);
const _dashSurfaceLight = Colors.white;
const _dashSurfaceAltLight = Color(0xFFF8FAFC);
const _dashBorderLight = Color(0xFFE2E8F0);
const _dashPrimary = Color(0xFF0E7490);
const _dashPrimarySoft = Color(0xFF0EA5A4);
const _dashDanger = Color(0xFFDC2626);
const _dashDarkSurface = Color(0xFF17181C);
const _dashDarkSurfaceAlt = Color(0xFF1C1C1E);

DateTime? _parseDashDate(dynamic value) {
  if (value == null) return null;
  final texto = value.toString().trim();
  if (texto.isEmpty) return null;
  return DateTime.tryParse(texto)?.toLocal();
}

int? _diasParaLimite(dynamic value) {
  final data = _parseDashDate(value);
  if (data == null) return null;
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final alvo = DateTime(data.year, data.month, data.day);
  return alvo.difference(hoje).inDays;
}

String _textoCurtoLimite(dynamic value) {
  final data = _parseDashDate(value);
  final dias = _diasParaLimite(value);
  if (data == null || dias == null) return 'Sem data de limite';
  final dataFmt = DateFormat('dd/MM/yy').format(data);
  if (dias < 0) return 'Limite venceu em $dataFmt';
  if (dias == 0) return 'Limite vence hoje $dataFmt';
  if (dias == 1) return 'Limite vence em 1 dia';
  return 'Limite vence em $dias dias';
}

String _textoBadgeLimite(dynamic value) {
  final data = _parseDashDate(value);
  if (data == null) return 'Sem vencimento';
  return 'Data do Limite ${DateFormat('dd/MM/yy').format(data)}';
}

class DashboardPage extends StatefulWidget {
  final Function(String cnpj, String nome)? aoSelecionarCedente;
  final AuthSession sessao;

  const DashboardPage({
    super.key,
    required this.sessao,
    this.aoSelecionarCedente,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _plataformaSelecionada = 'TODOS';
  String _gerenteSelecionado = 'TODOS';
  List<Map<String, dynamic>>? _ultimaBaseProcessada;
  String? _ultimaPlataformaProcessada;
  String? _ultimoGerenteProcessado;
  _DashboardViewData _dadosVisao = const _DashboardViewData();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardController>().inicializar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ocultarFiltrosGerente = widget.sessao.perfilNormalizado == 'GERENTE';
    final base =
        context.select<DashboardController, List<Map<String, dynamic>>>(
      (v) => v.baseCedentesCompleta,
    );
    final filtroEfetivo = _resolverFiltrosAtuais(base);
    final plataformaAtual = filtroEfetivo.plataforma;
    final gerenteAtual = filtroEfetivo.gerente;
    final dadosVisao = _obterDadosVisao(
      base,
      plataformaSelecionada: plataformaAtual,
      gerenteSelecionado: gerenteAtual,
    );
    final plataformas = dadosVisao.plataformas;
    final gerentes = dadosVisao.gerentes;
    final gerentesParaFiltro = plataformaAtual == 'TODOS'
        ? dadosVisao.gerentesConsolidadosOrdenadosPorRisco
        : gerentes;
    final baseFiltradaFinal = dadosVisao.baseFiltradaFinal;

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : _dashBgLight,
      body: RefreshIndicator(
        displacement: 80,
        color: _dashPrimary,
        onRefresh: () =>
            context.read<DashboardController>().carregarDadosCompletos(),
        child: CustomScrollView(
          cacheExtent: 1000,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            if (!ocultarFiltrosGerente)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _PlataformaSelectorWidget(
                    isDark: isDark,
                    plataformas: plataformas,
                    valorSelecionado: plataformaAtual,
                    onChanged: (valor) {
                      setState(() {
                        _plataformaSelecionada = valor ?? 'TODOS';
                        _gerenteSelecionado = 'TODOS';
                      });
                    },
                  ),
                ),
              ),
            if (!ocultarFiltrosGerente &&
                (plataformaAtual != 'TODOS' || gerenteAtual != 'TODOS') &&
                gerentesParaFiltro.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _GerenteSelectorWidget(
                    isDark: isDark,
                    gerentes: gerentesParaFiltro,
                    valorSelecionado: gerenteAtual,
                    onChanged: (valor) {
                      setState(() {
                        _gerenteSelecionado = valor ?? 'TODOS';
                      });
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: _HeaderWidget(
                  isDark: isDark,
                  baseFiltrada: baseFiltradaFinal,
                  exibirPercentualVencidos:
                      plataformaAtual != 'TODOS' || gerenteAtual != 'TODOS',
                  tituloVisao: _tituloVisaoSelecionada(
                    plataformas,
                    plataformaAtual,
                    gerenteAtual,
                  ),
                ),
              ),
            ),
            if (plataformaAtual == 'TODOS' && gerenteAtual == 'TODOS')
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _RiscoPorPlataformaWidget(
                    isDark: isDark,
                    plataformas: dadosVisao.plataformasOrdenadasPorRisco,
                    plataformaSelecionada: plataformaAtual,
                    onSelecionarPlataforma: (valor) {
                      setState(() {
                        _plataformaSelecionada = valor;
                        _gerenteSelecionado = 'TODOS';
                      });
                    },
                  ),
                ),
              ),
            if (plataformaAtual == 'TODOS' &&
                gerenteAtual == 'TODOS' &&
                dadosVisao.gerentesConsolidadosOrdenadosPorRisco.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _RankingGerentesWidget(
                    isDark: isDark,
                    gerentes: dadosVisao.gerentesConsolidadosOrdenadosPorRisco,
                    onSelecionarGerente: (valor) {
                      setState(() {
                        _plataformaSelecionada = 'TODOS';
                        _gerenteSelecionado = valor;
                      });
                    },
                  ),
                ),
              ),
            if (plataformaAtual != 'TODOS' &&
                gerenteAtual == 'TODOS' &&
                gerentes.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _RiscoPorGerenteWidget(
                    isDark: isDark,
                    gerentes: dadosVisao.gerentesOrdenadosPorRisco,
                    gerenteSelecionado: gerenteAtual,
                    onSelecionarGerente: (valor) {
                      setState(() {
                        _gerenteSelecionado = valor;
                      });
                    },
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _DrilldownCarteiraWidget(
                  isDark: isDark,
                  aoSelecionarCedente: widget.aoSelecionarCedente,
                  cedentesOrdenados: dadosVisao.cedentesOrdenados,
                  nomeGerente: gerenteAtual,
                  nomePlataforma: plataformaAtual,
                ),
              ),
            ),
            if (plataformaAtual == 'TODOS' && gerenteAtual == 'TODOS')
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _TopCedentesWidget(
                      isDark: isDark,
                      itensOrdenados: dadosVisao.cedentesOrdenados,
                      aoSelecionarCedente: widget.aoSelecionarCedente,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  ({String plataforma, String gerente}) _resolverFiltrosAtuais(
    List<Map<String, dynamic>> base,
  ) {
    if (widget.sessao.perfilNormalizado != 'GERENTE' || base.isEmpty) {
      return (
        plataforma: _plataformaSelecionada,
        gerente: _gerenteSelecionado,
      );
    }

    if (_plataformaSelecionada != 'TODOS' || _gerenteSelecionado != 'TODOS') {
      return (
        plataforma: _plataformaSelecionada,
        gerente: _gerenteSelecionado,
      );
    }

    final contextoSelecionado = widget.sessao.contextoSelecionado;
    final String plataformaDoContexto = contextoSelecionado == null
        ? ''
        : contextoSelecionado.plataformas
            .map((item) => item.plataforma.trim())
            .where((item) => item.isNotEmpty)
            .firstWhere((_) => true, orElse: () => '');

    final plataformaInicial = plataformaDoContexto.isNotEmpty
        ? plataformaDoContexto
        : _plataformaSelecionada;

    final baseDaPlataforma = plataformaInicial == 'TODOS'
        ? base
        : base
            .where((item) => _valorCampo(item, 'plat') == plataformaInicial)
            .toList(growable: false);

    final gerentes = _listarGerentes(baseDaPlataforma);
    final gerenteEncontrado = _encontrarGerenteDoContexto(baseDaPlataforma, gerentes);
    return (
      plataforma: plataformaInicial,
      gerente: gerenteEncontrado ?? _gerenteSelecionado,
    );
  }

  String? _encontrarGerenteDoContexto(
    List<Map<String, dynamic>> baseDaPlataforma,
    List<_GrupoCarteira> gerentes,
  ) {
    if (gerentes.isEmpty) return null;

    final codigoErpGerente = AuthSession.normalizarValor(
      widget.sessao.codigoErpPrincipal,
    );
    if (codigoErpGerente.isNotEmpty) {
      for (final item in baseDaPlataforma) {
        final codigoBase = AuthSession.normalizarValor(item['codGerente']);
        if (codigoBase == codigoErpGerente) {
          final gerente = item['codGerente']?.toString().trim();
          if (gerente != null && gerente.isNotEmpty) {
            return gerente;
          }
        }
      }
    }

    final nomesBase = <String>[
      widget.sessao.usuario,
      widget.sessao.contextoSelecionado?.usuNome ?? '',
    ]
        .map(_normalizarTexto)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    for (final gerente in gerentes) {
      final gerenteNormalizado = _normalizarTexto(gerente.nome);
      final gerenteLabelNormalizado = _normalizarTexto(gerente.label);
      for (final nome in nomesBase) {
        if (gerenteLabelNormalizado.contains(nome) ||
            nome.contains(gerenteLabelNormalizado) ||
            gerenteNormalizado.contains(nome) ||
            nome.contains(gerenteNormalizado)) {
          return gerente.nome;
        }
      }
    }

    if (gerentes.length == 1) {
      return gerentes.first.nome;
    }

    return null;
  }

  String _normalizarTexto(String valor) {
    return AuthSession.normalizarValor(valor).replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
  }

  List<_GrupoCarteira> _listarGerentes(List<Map<String, dynamic>> base) {
    final mapa = <String, _GrupoCarteira>{};
    for (final item in base) {
      final chave = _valorCampo(item, 'codGerente');
      final label = _valorCampo(item, 'gerente');
      final risco = ((item['risco'] ?? 0) as num).toDouble();
      final vencido = ((item['vencido'] ?? 0) as num).toDouble();
      final grupo = mapa.putIfAbsent(
        chave,
        () => _GrupoCarteira(nome: chave, label: label),
      );
      grupo.risco += risco;
      grupo.vencido = (grupo.vencido ?? 0) + vencido;
      grupo.quantidade += 1;
    }

    final itens = mapa.values.toList()
      ..sort((a, b) => b.risco.compareTo(a.risco));
    return itens;
  }

  List<_GrupoCarteira> _listarPlataformas(List<Map<String, dynamic>> base) {
    final mapa = <String, _GrupoCarteira>{};
    for (final item in base) {
      final chave = _valorCampo(item, 'plat');
      final label = _valorCampo(item, 'plataforma');
      final risco = ((item['risco'] ?? 0) as num).toDouble();
      final vencido = ((item['vencido'] ?? 0) as num).toDouble();
      final grupo = mapa.putIfAbsent(
        chave,
        () => _GrupoCarteira(nome: chave, label: label),
      );
      grupo.risco += risco;
      grupo.vencido = (grupo.vencido ?? 0) + vencido;
      grupo.quantidade += 1;
    }

    final itens = mapa.values.toList()
      ..sort((a, b) => _compararPlat(a.nome, b.nome));
    return itens;
  }

  int _compararPlat(String a, String b) {
    final numeroA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
    final numeroB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));

    if (numeroA != null && numeroB != null) {
      final comparacaoNumerica = numeroA.compareTo(numeroB);
      if (comparacaoNumerica != 0) return comparacaoNumerica;
    }

    return a.compareTo(b);
  }

  String _nomePlataformaSelecionada(
    List<_GrupoCarteira> plataformas,
    String selecionada,
  ) {
    if (selecionada == 'TODOS') return 'TODOS';
    final match = plataformas.where((item) => item.nome == selecionada);
    if (match.isEmpty) return selecionada;
    return match.first.label;
  }

  String _tituloVisaoSelecionada(
    List<_GrupoCarteira> plataformas,
    String plataformaSelecionada,
    String gerenteSelecionado,
  ) {
    if (gerenteSelecionado != 'TODOS') {
      return _nomeGerenteSelecionado(
        _dadosVisao.gerentesConsolidadosOrdenadosPorRisco,
        gerenteSelecionado,
      );
    }

    return _nomePlataformaSelecionada(plataformas, plataformaSelecionada);
  }

  String _nomeGerenteSelecionado(
    List<_GrupoCarteira> gerentes,
    String selecionado,
  ) {
    if (selecionado == 'TODOS') return 'TODOS';
    final match = gerentes.where((item) => item.nome == selecionado);
    if (match.isEmpty) return selecionado;
    return match.first.label;
  }

  String _valorCampo(Map<String, dynamic> item, String campo) {
    final valor = (item[campo] ?? '').toString().trim();
    return valor.isEmpty ? 'NAO INFORMADO' : valor;
  }

  _DashboardViewData _obterDadosVisao(
    List<Map<String, dynamic>> base, {
    required String plataformaSelecionada,
    required String gerenteSelecionado,
  }) {
    if (identical(_ultimaBaseProcessada, base) &&
        _ultimaPlataformaProcessada == plataformaSelecionada &&
        _ultimoGerenteProcessado == gerenteSelecionado) {
      return _dadosVisao;
    }

    final plataformas = _listarPlataformas(base);
    final plataformasOrdenadasPorRisco = List<_GrupoCarteira>.from(plataformas)
      ..sort((a, b) => b.risco.compareTo(a.risco));

    final baseFiltrada = plataformaSelecionada == 'TODOS'
        ? base
        : base
            .where(
              (item) => _valorCampo(item, 'plat') == plataformaSelecionada,
            )
            .toList(growable: false);

    final gerentes = _listarGerentes(baseFiltrada);
    final gerentesConsolidadosOrdenadosPorRisco = _listarGerentes(base);
    final baseFiltradaFinal = gerenteSelecionado == 'TODOS'
        ? baseFiltrada
        : baseFiltrada
            .where(
              (item) =>
                  _valorCampo(item, 'codGerente') == gerenteSelecionado,
            )
            .toList(growable: false);

    final cedentesOrdenados = List<Map<String, dynamic>>.from(baseFiltradaFinal)
      ..sort(
        (a, b) => (((b['risco'] ?? 0) as num).toDouble()).compareTo(
          ((a['risco'] ?? 0) as num).toDouble(),
        ),
      );

    _ultimaBaseProcessada = base;
    _ultimaPlataformaProcessada = plataformaSelecionada;
    _ultimoGerenteProcessado = gerenteSelecionado;
    _dadosVisao = _DashboardViewData(
      plataformas: plataformas,
      plataformasOrdenadasPorRisco: plataformasOrdenadasPorRisco,
      gerentes: gerentes,
      gerentesOrdenadosPorRisco: gerentes,
      gerentesConsolidadosOrdenadosPorRisco:
          gerentesConsolidadosOrdenadosPorRisco,
      baseFiltradaFinal: baseFiltradaFinal,
      cedentesOrdenados: cedentesOrdenados,
    );
    return _dadosVisao;
  }
}

class _DashboardViewData {
  final List<_GrupoCarteira> plataformas;
  final List<_GrupoCarteira> plataformasOrdenadasPorRisco;
  final List<_GrupoCarteira> gerentes;
  final List<_GrupoCarteira> gerentesOrdenadosPorRisco;
  final List<_GrupoCarteira> gerentesConsolidadosOrdenadosPorRisco;
  final List<Map<String, dynamic>> baseFiltradaFinal;
  final List<Map<String, dynamic>> cedentesOrdenados;

  const _DashboardViewData({
    this.plataformas = const [],
    this.plataformasOrdenadasPorRisco = const [],
    this.gerentes = const [],
    this.gerentesOrdenadosPorRisco = const [],
    this.gerentesConsolidadosOrdenadosPorRisco = const [],
    this.baseFiltradaFinal = const [],
    this.cedentesOrdenados = const [],
  });
}

class _HeaderWidget extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>> baseFiltrada;
  final String tituloVisao;
  final bool exibirPercentualVencidos;

  const _HeaderWidget({
    required this.isDark,
    required this.baseFiltrada,
    required this.tituloVisao,
    required this.exibirPercentualVencidos,
  });

  @override
  Widget build(BuildContext context) {
    final risco = baseFiltrada.fold<double>(
      0,
      (soma, item) => soma + ((item['risco'] ?? 0) as num).toDouble(),
    );
    final limite = baseFiltrada.fold<double>(
      0,
      (soma, item) => soma + ((item['limite'] ?? 0) as num).toDouble(),
    );
    final qtd = baseFiltrada.length;
    final vencidos = baseFiltrada.fold<double>(
      0,
      (soma, item) => soma + ((item['vencido'] ?? 0) as num).toDouble(),
    );
    final double percentual = limite > 0 ? (risco / limite) : 0;
    final fMoeda =
        NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
            tituloVisao == 'TODOS' ? 'VISAO CONSOLIDADA' : tituloVisao,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTextCol(
                'RISCO TOTAL ATUAL',
                fMoeda.format(risco),
                24,
                Colors.white,
              ),
              _buildTextCol(
                'CEDENTES',
                qtd.toString(),
                14,
                Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ProgressBar(p: percentual),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderTotalCard(
                  label: 'LIMITE',
                  value: fMoeda.format(limite),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderTotalCard(
                  label: 'VENCIDOS',
                  value: exibirPercentualVencidos
                      ? '${fMoeda.format(vencidos)} (${((risco > 0 ? (vencidos / risco) : 0) * 100).toStringAsFixed(1).replaceAll('.', ',')}%)'
                      : fMoeda.format(vencidos),
                  color: const Color.fromARGB(255, 255, 255, 255),
                  backgroundColor: const Color.fromARGB(255, 202, 61, 61),
                  borderColor: const Color.fromARGB(255, 170, 51, 51).withValues(alpha: 0.45),
                  labelColor: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextCol(String label, String value, double size, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PlataformaSelectorWidget extends StatelessWidget {
  final bool isDark;
  final List<_GrupoCarteira> plataformas;
  final String valorSelecionado;
  final ValueChanged<String?> onChanged;

  const _PlataformaSelectorWidget({
    required this.isDark,
    required this.plataformas,
    required this.valorSelecionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLATAFORMAS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: plataformas.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PlatformChip(
                    isDark: isDark,
                    titulo: 'TODOS',
                    selecionado: valorSelecionado == 'TODOS',
                    onTap: () => onChanged('TODOS'),
                  );
                }

                final item = plataformas[index - 1];
                return _PlatformChip(
                  isDark: isDark,
                  titulo: item.label,
                  selecionado: valorSelecionado == item.nome,
                  onTap: () => onChanged(item.nome),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GerenteSelectorWidget extends StatelessWidget {
  final bool isDark;
  final List<_GrupoCarteira> gerentes;
  final String valorSelecionado;
  final ValueChanged<String?> onChanged;

  const _GerenteSelectorWidget({
    required this.isDark,
    required this.gerentes,
    required this.valorSelecionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GERENTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: gerentes.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PlatformChip(
                    isDark: isDark,
                    titulo: 'TODOS',
                    selecionado: valorSelecionado == 'TODOS',
                    onTap: () => onChanged('TODOS'),
                  );
                }

                final item = gerentes[index - 1];
                return _PlatformChip(
                  isDark: isDark,
                  titulo: item.label,
                  selecionado: valorSelecionado == item.nome,
                  onTap: () => onChanged(item.nome),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final bool isDark;
  final String titulo;
  final bool selecionado;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.isDark,
    required this.titulo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? _dashPrimary
              : (isDark ? _dashDarkSurfaceAlt : _dashSurfaceAltLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado
                ? _dashPrimarySoft
                : (isDark ? Colors.white10 : _dashBorderLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selecionado ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selecionado
                  ? Colors.white
                  : (isDark ? Colors.white54 : _dashPrimary),
              size: 14,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selecionado
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderTotalCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? labelColor;

  const _HeaderTotalCard({
    required this.label,
    required this.value,
    required this.color,
    this.backgroundColor,
    this.borderColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? Colors.white60,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiscoPorPlataformaWidget extends StatefulWidget {
  final bool isDark;
  final List<_GrupoCarteira> plataformas;
  final String plataformaSelecionada;
  final ValueChanged<String> onSelecionarPlataforma;

  const _RiscoPorPlataformaWidget({
    required this.isDark,
    required this.plataformas,
    required this.plataformaSelecionada,
    required this.onSelecionarPlataforma,
  });

  @override
  State<_RiscoPorPlataformaWidget> createState() =>
      _RiscoPorPlataformaWidgetState();
}

class _RiscoPorPlataformaWidgetState extends State<_RiscoPorPlataformaWidget> {
  bool _mostrarTudo = false;

  @override
  void didUpdateWidget(covariant _RiscoPorPlataformaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.plataformas, widget.plataformas)) {
      _mostrarTudo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plataformas.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalRisco =
        widget.plataformas.fold<double>(0, (soma, item) => soma + item.risco);
    final plataformasFiltradas = widget.plataformas
        .where((item) {
          final percentual = totalRisco > 0 ? (item.risco / totalRisco) : 0.0;
          return percentual > 0;
        })
        .toList(growable: false);
    if (plataformasFiltradas.isEmpty) {
      return const SizedBox.shrink();
    }
    final itensExibidos = _mostrarTudo
        ? plataformasFiltradas
        : plataformasFiltradas.take(5).toList(growable: false);
    final fMoeda =
        NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? _dashDarkSurface : _dashSurfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : _dashBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RISCO POR PLATAFORMA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${plataformasFiltradas.length} plataformas',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color:
                      widget.isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...itensExibidos.map((item) {
            final selecionado = widget.plataformaSelecionada == item.nome;
            final percentual = totalRisco > 0 ? (item.risco / totalRisco) : 0.0;
            final vencido = item.vencido ?? 0;
            final percentualVencido = item.risco > 0
                ? (vencido / item.risco)
                : 0.0;
            final corPercentual = percentualVencido >= 0.5
                ? _dashDanger
                : _dashPrimary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => widget.onSelecionarPlataforma(item.nome),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? const Color(0xFFDFF7F3)
                        : (widget.isDark
                            ? _dashDarkSurfaceAlt
                            : _dashSurfaceAltLight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selecionado
                          ? _dashPrimarySoft
                          : (widget.isDark
                              ? Colors.white10
                              : _dashBorderLight),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            fMoeda.format(item.risco),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _dashPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(percentual * 100).toStringAsFixed(1)}% do volume total',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                          Text(
                            '${(percentualVencido * 100).toStringAsFixed(1)}% vencido',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: corPercentual,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fMoeda.format(vencido)} vencidos dentro de ${fMoeda.format(item.risco)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (plataformasFiltradas.length > 5) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _mostrarTudo = !_mostrarTudo;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dashPrimary,
                  side: const BorderSide(color: _dashPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _mostrarTudo ? 'VER MENOS' : 'VER MAIS',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiscoPorGerenteWidget extends StatefulWidget {
  final bool isDark;
  final List<_GrupoCarteira> gerentes;
  final String gerenteSelecionado;
  final ValueChanged<String> onSelecionarGerente;

  const _RiscoPorGerenteWidget({
    required this.isDark,
    required this.gerentes,
    required this.gerenteSelecionado,
    required this.onSelecionarGerente,
  });

  @override
  State<_RiscoPorGerenteWidget> createState() => _RiscoPorGerenteWidgetState();
}

class _RiscoPorGerenteWidgetState extends State<_RiscoPorGerenteWidget> {
  bool _mostrarTudo = false;

  @override
  void didUpdateWidget(covariant _RiscoPorGerenteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gerentes, widget.gerentes)) {
      _mostrarTudo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gerentes.isEmpty) {
      return const SizedBox.shrink();
    }

    final topItens = _mostrarTudo
        ? widget.gerentes
        : widget.gerentes.take(5).toList(growable: false);
    final totalRisco =
        widget.gerentes.fold<double>(0, (soma, item) => soma + item.risco);
    final fMoeda =
        NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? _dashDarkSurface : _dashSurfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : _dashBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RISCO POR GERENTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${widget.gerentes.length} gerentes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...topItens.map((item) {
            final selecionado = widget.gerenteSelecionado == item.nome;
            final percentual = totalRisco > 0 ? (item.risco / totalRisco) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => widget.onSelecionarGerente(item.nome),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? const Color(0xFFDFF7F3)
                        : (widget.isDark
                            ? _dashDarkSurfaceAlt
                            : _dashSurfaceAltLight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selecionado
                          ? _dashPrimarySoft
                          : (widget.isDark
                              ? Colors.white10
                              : _dashBorderLight),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            fMoeda.format(item.risco),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _dashPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percentual.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              widget.isDark
                                  ? Colors.white10
                                  : _dashBorderLight,
                          valueColor: const AlwaysStoppedAnimation(
                            _dashPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(percentual * 100).toStringAsFixed(1)}% do volume total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (widget.gerentes.length > 5) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _mostrarTudo = !_mostrarTudo;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dashPrimary,
                  side: const BorderSide(color: _dashPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _mostrarTudo ? 'VER MENOS' : 'VER MAIS',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingGerentesWidget extends StatefulWidget {
  final bool isDark;
  final List<_GrupoCarteira> gerentes;
  final ValueChanged<String> onSelecionarGerente;

  const _RankingGerentesWidget({
    required this.isDark,
    required this.gerentes,
    required this.onSelecionarGerente,
  });

  @override
  State<_RankingGerentesWidget> createState() => _RankingGerentesWidgetState();
}

class _RankingGerentesWidgetState extends State<_RankingGerentesWidget> {
  bool _mostrarTudo = false;

  @override
  void didUpdateWidget(covariant _RankingGerentesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gerentes, widget.gerentes)) {
      _mostrarTudo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gerentes.isEmpty) {
      return const SizedBox.shrink();
    }

    final topItens = _mostrarTudo
        ? widget.gerentes
        : widget.gerentes.take(5).toList(growable: false);
    final totalRisco =
        widget.gerentes.fold<double>(0, (soma, item) => soma + item.risco);
    final fMoeda =
        NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? _dashDarkSurface : _dashSurfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : _dashBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOP GERENTES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${widget.gerentes.length} gerentes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...topItens.asMap().entries.map((entry) {
            final item = entry.value;
            final percentual = totalRisco > 0 ? (item.risco / totalRisco) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => widget.onSelecionarGerente(item.nome),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? _dashDarkSurfaceAlt
                        : _dashSurfaceAltLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white10
                          : _dashBorderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _dashPrimary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: _dashPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            fMoeda.format(item.risco),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _dashPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percentual.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: widget.isDark
                              ? Colors.white10
                              : _dashBorderLight,
                          valueColor: const AlwaysStoppedAnimation(
                            _dashPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(percentual * 100).toStringAsFixed(1)}% do volume total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (widget.gerentes.length > 5) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _mostrarTudo = !_mostrarTudo;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dashPrimary,
                  side: const BorderSide(color: _dashPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _mostrarTudo ? 'VER MENOS' : 'VER MAIS',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopCedentesWidget extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> itensOrdenados;
  final Function(String cnpj, String nome)? aoSelecionarCedente;

  const _TopCedentesWidget({
    required this.isDark,
    required this.itensOrdenados,
    this.aoSelecionarCedente,
  });

  @override
  State<_TopCedentesWidget> createState() => _TopCedentesWidgetState();
}

class _TopCedentesWidgetState extends State<_TopCedentesWidget> {
  int _limiteExibicao = 5;
  _OrdenacaoCedentes _ordenacaoSelecionada = _OrdenacaoCedentes.risco;

  @override
  void didUpdateWidget(covariant _TopCedentesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itensOrdenados, widget.itensOrdenados)) {
      _limiteExibicao = 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final carregando =
        context.select<DashboardController, bool>((v) => v.carregando);
    final itens = widget.itensOrdenados;

    if (carregando && itens.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final itensOrdenados = List<Map<String, dynamic>>.from(itens)
      ..sort((a, b) {
        final valorA = _valorOrdenacao(a);
        final valorB = _valorOrdenacao(b);
        return valorB.compareTo(valorA);
      });

    final totalRisco = itensOrdenados.fold<double>(
      0,
      (s, e) => s + ((e['risco'] ?? 0) as num).toDouble(),
    );
    final exibidos =
        itensOrdenados.take(_limiteExibicao).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? _dashDarkSurface : _dashSurfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : _dashBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'MAIORES CEDENTES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildBotaoOrdenacao(
                      label: 'Risco',
                      ativo: _ordenacaoSelecionada == _OrdenacaoCedentes.risco,
                      onTap: () {
                        setState(() {
                          _ordenacaoSelecionada = _OrdenacaoCedentes.risco;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildBotaoOrdenacao(
                      label: '% Vencido',
                      ativo:
                          _ordenacaoSelecionada == _OrdenacaoCedentes.vencidos,
                      onTap: () {
                        setState(() {
                          _ordenacaoSelecionada = _OrdenacaoCedentes.vencidos;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Text(
                '${itens.length} empresas',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...exibidos.asMap().entries.map((entry) {
            final item = entry.value;
            final p = totalRisco > 0
                ? (((item['risco'] ?? 0) as num).toDouble() / totalRisco)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopCedenteRow(
                index: entry.key + 1,
                nome: (item['cedente'] ?? item['nome'] ?? 'CEDENTE').toString(),
                cnpj: (item['cnpj'] ?? '').toString(),
                gerente: (item['gerente'] ?? 'SEM GERENTE').toString(),
                dtLimite: item['dtLimite'],
                risco: ((item['risco'] ?? 0) as num).toDouble(),
                vencido: ((item['vencido'] ?? 0) as num).toDouble(),
                percentual: p,
                isDark: widget.isDark,
                onTap: widget.aoSelecionarCedente == null
                    ? null
                    : () => widget.aoSelecionarCedente!(
                          (item['cnpj'] ?? '').toString(),
                          (item['cedente'] ?? item['nome'] ?? '').toString(),
                        ),
              ),
            );
          }),
          if (_limiteExibicao < itens.length) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _limiteExibicao =
                        (_limiteExibicao + 10).clamp(0, itens.length);
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dashPrimary,
                  side: const BorderSide(color: _dashPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'MOSTRAR MAIS 10',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotaoOrdenacao({
    required String label,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ativo
              ? _dashPrimary
              : (widget.isDark
                  ? _dashDarkSurfaceAlt
                  : _dashSurfaceAltLight),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ativo
                ? _dashPrimary
                : (widget.isDark ? Colors.white10 : _dashBorderLight),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: ativo
                ? Colors.white
                : (widget.isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  double _valorOrdenacao(Map<String, dynamic> item) {
    switch (_ordenacaoSelecionada) {
      case _OrdenacaoCedentes.vencidos:
        final risco = ((item['risco'] ?? 0) as num).toDouble();
        final vencido = ((item['vencido'] ?? 0) as num).toDouble();
        return risco > 0 ? (vencido / risco) : 0;
      case _OrdenacaoCedentes.risco:
        return ((item['risco'] ?? 0) as num).toDouble();
    }
  }
}

class _TopCedenteRow extends StatelessWidget {
  final int index;
  final String nome;
  final String cnpj;
  final String gerente;
  final dynamic dtLimite;
  final double risco;
  final double vencido;
  final double percentual;
  final bool isDark;
  final VoidCallback? onTap;

  const _TopCedenteRow({
    required this.index,
    required this.nome,
    required this.cnpj,
    required this.gerente,
    required this.dtLimite,
    required this.risco,
    required this.vencido,
    required this.percentual,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fMoeda =
        NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);
    final percentualVencido = risco > 0 ? (vencido / risco) : 0.0;
    final corVencido = percentualVencido >= 0.5
        ? _dashDanger
        : _dashPrimary;
    final diasParaLimite = _diasParaLimite(dtLimite);
    final alertaLimite = diasParaLimite != null && diasParaLimite <= 7;
    final corLimite = diasParaLimite != null && diasParaLimite < 0
        ? _dashDanger
        : (alertaLimite ? _dashDanger : _dashPrimarySoft);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? _dashDarkSurfaceAlt : _dashSurfaceAltLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : _dashBorderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _dashPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: _dashPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cnpj,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gerente: $gerente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black54,
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
                      fMoeda.format(risco),
                      style: const TextStyle(
                        color: _dashPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: corLimite.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: corLimite.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        _textoBadgeLimite(dtLimite),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: corLimite,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vencido no risco',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  '${(percentualVencido * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: corVencido,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: percentualVencido.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor:
                    isDark ? Colors.white10 : _dashBorderLight,
                valueColor: AlwaysStoppedAnimation<Color>(corVencido),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              alertaLimite
                  ? ''
                  : '${fMoeda.format(vencido)} vencidos dentro de ${fMoeda.format(risco)}',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            if (alertaLimite || dtLimite != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (alertaLimite) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: _dashDanger,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        _textoCurtoLimite(dtLimite),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: alertaLimite ? FontWeight.w800 : FontWeight.w600,
                          color: alertaLimite
                              ? _dashDanger
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrilldownCarteiraWidget extends StatefulWidget {
  final bool isDark;
  final Function(String cnpj, String nome)? aoSelecionarCedente;
  final List<Map<String, dynamic>> cedentesOrdenados;
  final String nomeGerente;
  final String nomePlataforma;

  const _DrilldownCarteiraWidget({
    required this.isDark,
    this.aoSelecionarCedente,
    required this.cedentesOrdenados,
    required this.nomeGerente,
    required this.nomePlataforma,
  });

  @override
  State<_DrilldownCarteiraWidget> createState() =>
      _DrilldownCarteiraWidgetState();
}

class _DrilldownCarteiraWidgetState extends State<_DrilldownCarteiraWidget> {
  _OrdenacaoCedentes _ordenacaoSelecionada = _OrdenacaoCedentes.risco;

  @override
  Widget build(BuildContext context) {
    final bool exibirCedentes =
        widget.nomePlataforma != 'TODOS' || widget.nomeGerente != 'TODOS';
    final cedentes =
        exibirCedentes ? widget.cedentesOrdenados : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exibirCedentes) ...[
          const SizedBox(height: 16),
          _buildSecaoCedentes(cedentes),
        ],
      ],
    );
  }

  Widget _buildSecaoCedentes(List<Map<String, dynamic>> cedentes) {
    final cedentesOrdenados = List<Map<String, dynamic>>.from(cedentes)
      ..sort((a, b) {
        final valorA = _valorOrdenacao(a);
        final valorB = _valorOrdenacao(b);
        return valorB.compareTo(valorA);
      });

    return _buildContainerSecao(
      titulo: 'CEDENTES',
      subtitulo: '',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildBotaoOrdenacao(
            label: 'Risco',
            ativo: _ordenacaoSelecionada == _OrdenacaoCedentes.risco,
            onTap: () {
              setState(() {
                _ordenacaoSelecionada = _OrdenacaoCedentes.risco;
              });
            },
          ),
          _buildBotaoOrdenacao(
            label: '% Vencido',
            ativo: _ordenacaoSelecionada == _OrdenacaoCedentes.vencidos,
            onTap: () {
              setState(() {
                _ordenacaoSelecionada = _OrdenacaoCedentes.vencidos;
              });
            },
          ),
        ],
      ),
      child: Column(
        children: cedentesOrdenados.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CardCedente(
              nome: _valorCampo(item, 'cedente'),
              cnpj: _valorCampo(item, 'cnpj'),
              gerente: _valorCampo(item, 'gerente'),
              plataforma: _valorCampo(item, 'plataforma'),
              dtLimite: item['dtLimite'],
              risco: _fMoeda(((item['risco'] ?? 0) as num).toDouble()),
              vencido: ((item['vencido'] ?? 0) as num).toDouble(),
              riscoValor: ((item['risco'] ?? 0) as num).toDouble(),
              isDark: widget.isDark,
              onTap: widget.aoSelecionarCedente == null
                  ? null
                  : () => widget.aoSelecionarCedente!(
                        _valorCampo(item, 'cnpj'),
                        _valorCampo(item, 'cedente'),
                      ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBotaoOrdenacao({
    required String label,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ativo
              ? _dashPrimary
              : (widget.isDark ? _dashDarkSurfaceAlt : _dashSurfaceAltLight),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ativo
                ? _dashPrimary
                : (widget.isDark ? Colors.white10 : _dashBorderLight),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: ativo
                ? Colors.white
                : (widget.isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  double _valorOrdenacao(Map<String, dynamic> item) {
    switch (_ordenacaoSelecionada) {
      case _OrdenacaoCedentes.vencidos:
        final risco = ((item['risco'] ?? 0) as num).toDouble();
        final vencido = ((item['vencido'] ?? 0) as num).toDouble();
        return risco > 0 ? (vencido / risco) : 0;
      case _OrdenacaoCedentes.risco:
        return ((item['risco'] ?? 0) as num).toDouble();
    }
  }

  Widget _buildContainerSecao({
    required String titulo,
    required String subtitulo,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? _dashDarkSurface : _dashSurfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : _dashBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                    if (subtitulo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              widget.isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _valorCampo(Map<String, dynamic> item, String campo) {
    final valor = (item[campo] ?? '').toString().trim();
    if (valor.isEmpty) return 'NAO INFORMADO';
    return valor;
  }

  String _fMoeda(double valor) {
    return NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0)
        .format(valor);
  }
}

class _GrupoCarteira {
  final String nome;
  final String label;
  double risco;
  double? vencido;
  int quantidade;

  _GrupoCarteira({
    required this.nome,
    required this.label,
  })  : risco = 0,
        vencido = 0,
        quantidade = 0;
}

enum _OrdenacaoCedentes {
  risco,
  vencidos,
}

class _CardCedente extends StatelessWidget {
  final String nome;
  final String cnpj;
  final String gerente;
  final String plataforma;
  final dynamic dtLimite;
  final String risco;
  final double vencido;
  final double riscoValor;
  final bool isDark;
  final VoidCallback? onTap;

  const _CardCedente({
    required this.nome,
    required this.cnpj,
    required this.gerente,
    required this.plataforma,
    required this.dtLimite,
    required this.risco,
    required this.vencido,
    required this.riscoValor,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fMoeda =
        NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);
    final percentualVencido = riscoValor > 0 ? (vencido / riscoValor) : 0.0;
    final diasParaLimite = _diasParaLimite(dtLimite);
    final alertaLimite = diasParaLimite != null && diasParaLimite <= 7;
    final corLimite = diasParaLimite != null && diasParaLimite < 0
        ? _dashDanger
        : (alertaLimite ? _dashDanger : _dashPrimarySoft);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? _dashDarkSurfaceAlt : _dashSurfaceAltLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white10 : _dashBorderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      risco,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _dashPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: corLimite.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: corLimite.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        _textoBadgeLimite(dtLimite),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: corLimite,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'CNPJ: $cnpj',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gerente: $gerente',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Plataforma: $plataforma',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vencido no risco',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  '${(percentualVencido * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: percentualVencido >= 0.5
                        ? _dashDanger
                        : _dashPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: percentualVencido.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor:
                    isDark ? Colors.white10 : _dashBorderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentualVencido >= 0.5 ? _dashDanger : _dashPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${fMoeda.format(vencido)} vencidos dentro de $risco',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            if (alertaLimite || dtLimite != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (alertaLimite) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: _dashDanger,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        _textoCurtoLimite(dtLimite),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: alertaLimite ? FontWeight.w800 : FontWeight.w600,
                          color: alertaLimite
                              ? _dashDanger
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double p;

  const _ProgressBar({required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'USO DO LIMITE',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(p * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: p.clamp(0, 1),
          backgroundColor: Colors.white12,
          color: const Color(0xFF6EE7B7),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
