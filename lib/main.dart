import 'dart:convert';

import 'package:athenaapp/DashboardController.dart';
import 'package:athenaapp/analise_desempenho_page.dart';
import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/componentes/layout_base.dart';
import 'package:athenaapp/context_selector.dart';
import 'package:athenaapp/dashboard_page.dart';
import 'package:athenaapp/login_page.dart';
import 'package:athenaapp/relatorio_executivo_page.dart';
import 'package:athenaapp/relatorio_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

final ValueNotifier<ThemeMode> temaApp = ValueNotifier(ThemeMode.light);

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DashboardController(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaApp,
      builder: (context, modoAtual, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: modoAtual,
          theme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF000000),
            cardColor: const Color(0xFF1C1C1E),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),
          home: Builder(
            builder: (context) => TelaLogin(
              aoEntrar: (sessao) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainPage(sessao: sessao),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  final AuthSession sessao;

  const MainPage({super.key, required this.sessao});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ValueNotifier<DateTime> _dataOperacoesDoDiaSelecionada =
      ValueNotifier(DateTime.now());
  late AuthSession _sessaoAtual;
  int _selectedIndex = 0;
  int _indiceAnteriorAntesDaAnalise = 0;
  String? cnpjSelecionado;
  String? nomeCedenteSelecionado;
  bool _mostrarBotaoVoltar = false;

  List<Map<String, dynamic>> _listaCedentesGlobal = [];
  List<Map<String, dynamic>> _listaSugestoesCedentes = [];
  bool _carregandoBase = false;
  DateTime? _ultimoToqueVoltar;
  @override
  void initState() {
    super.initState();
    _sessaoAtual = widget.sessao;
    _carregarDados();
  }

  @override
  void dispose() {
    _dataOperacoesDoDiaSelecionada.dispose();
    super.dispose();
  }

  String _normalizarCnpj(dynamic valor) {
    return (valor ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _carregarDados() async {
    if (_carregandoBase) return;
    setState(() => _carregandoBase = true);

    try {
      final responses = await Future.wait([
        http
            .get(
              Uri.parse(
                'https://athenaapp.athenabanco.com.br/api/Dash/AnaliticoPaginado?pagina=1&tamanho=1000',
              ),
            )
            .timeout(const Duration(seconds: 15)),
        http
            .get(
              Uri.parse('https://athenaapp.athenabanco.com.br/api/Dash/ListaCedentes'),
            )
            .timeout(const Duration(seconds: 15)),
      ]);

      final analiticoResp = responses[0];
      final listaCedentesResp = responses[1];

      final List analitico = analiticoResp.statusCode == 200
          ? (json.decode(analiticoResp.body)['dados']?['\$values'] ?? [])
          : const [];
      final List listaCedentes = listaCedentesResp.statusCode == 200
          ? (json.decode(listaCedentesResp.body)['dados']?['\$values'] ?? [])
          : const [];

      final mapaListaCedentes = <String, Map<String, dynamic>>{};
      for (final item in listaCedentes) {
        if (item is! Map) continue;
        final mapa = Map<String, dynamic>.from(item);
        final cnpj = _normalizarCnpj(mapa['cgc'] ?? mapa['cnpj']);
        if (cnpj.isNotEmpty) {
          mapaListaCedentes[cnpj] = mapa;
        }
      }

      final base = analitico.map<Map<String, dynamic>>((e) {
        final cnpj = _normalizarCnpj(e['cnpj']);
        final cadastroCedente = mapaListaCedentes[cnpj];
        final riscoOperacional = ((e['riscoOperacional'] ??
                    e['risco_operacional'] ??
                    e['riscO_OPERACIONAL']) ??
                e['riscoTotalTodosBancos'] ??
                e['riscO_TOTAL_TODOS_BANCOS'] ??
                0)
            as num;

        return {
          'nome': e['cedente'] ?? e['cnpj'],
          'cedente': e['cedente'] ?? e['cnpj'],
          'cgc': e['cnpj'],
          'cnpj': e['cnpj'],
          'empresa':
              e['empresa'] ??
              e['codigoErp'] ??
              e['codigoERP'] ??
              cadastroCedente?['empresa'] ??
              cadastroCedente?['codigoErp'] ??
              cadastroCedente?['CodigoERP'] ??
              '',
          'codigoErp':
              e['codigoErp'] ??
              e['codigoERP'] ??
              cadastroCedente?['codigoErp'] ??
              cadastroCedente?['CodigoERP'] ??
              cadastroCedente?['empresa'] ??
              '',
          'plat':
              cadastroCedente?['codPlataforma'] ??
              e['codPlataforma'] ??
              e['plat'] ??
              '',
          'plataforma':
              cadastroCedente?['plataforma'] ??
              e['plataforma'] ??
              'SEM PLATAFORMA',
          'codGerente': e['codGerente'] ?? cadastroCedente?['codGerente'] ?? '',
          'uf': e['uf'] ?? '',
          'ramo': _extrairRamo(e),
          'risco': riscoOperacional.toDouble(),
          'limite': ((e['limite'] ?? 0) as num).toDouble(),
          'dtLimite':
              cadastroCedente?['DtLimite'] ??
              cadastroCedente?['dtLimite'] ??
              cadastroCedente?['dataLimite'],
          'vencido': ((e['vencidos'] ?? 0) as num).toDouble(),
          'gerente': e['gerente'] ?? 'SEM GERENTE',
        };
      }).toList(growable: false);

      final sugestoes = listaCedentes.map<Map<String, dynamic>>((e) {
        return {
          'cedente': e['cedente'] ?? '',
          'cgc': e['cgc'] ?? '',
          'empresa':
              e['empresa'] ??
              e['codigoErp'] ??
              e['CodigoERP'] ??
              '',
          'codigoErp':
              e['codigoErp'] ??
              e['CodigoERP'] ??
              e['empresa'] ??
              '',
          'codGerente': e['codGerente'] ?? '',
          'gerente': e['gerente'] ?? '',
          'plat': e['plat'] ?? e['codPlataforma'] ?? '',
          'codPlataforma': e['codPlataforma'] ?? '',
          'plataforma': e['plataforma'] ?? '',
        };
      }).toList(growable: false);

      final baseFiltrada = _sessaoAtual.filtrarRegistros(base);
      final sugestoesFiltradas = _sessaoAtual.filtrarRegistros(sugestoes);

      if (!mounted) return;

      setState(() {
        _listaCedentesGlobal = baseFiltrada;
        _listaSugestoesCedentes = sugestoesFiltradas;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<DashboardController>().setBase(baseFiltrada);
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    } finally {
      if (mounted) {
        setState(() => _carregandoBase = false);
      }
    }
  }

  String _getTitulo() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Operações do Dia';
      case 2:
        return 'Análise de Desempenho';
      default:
        return 'Athena App';
    }
  }

  void _irParaAnalise(String cnpj, String nomeCedente) {
    setState(() {
      _indiceAnteriorAntesDaAnalise = _selectedIndex;
      cnpjSelecionado = cnpj;
      nomeCedenteSelecionado = nomeCedente;
      _mostrarBotaoVoltar = true;
      _selectedIndex = 2;
    });
  }

  void _voltarParaTelaAnterior() {
    setState(() {
      _selectedIndex = _indiceAnteriorAntesDaAnalise;
      _mostrarBotaoVoltar = false;
    });
  }

  void _abrirRelatorioExecutivo() {
    if (!_sessaoAtual.podeVerRelatorioExecutivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil sem acesso ao relatorio executivo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelatorioExecutivoPage(
          dataSelecionadaNotifier: _dataOperacoesDoDiaSelecionada,
          sessao: _sessaoAtual,
          aoTrocarPerfil:
              _sessaoAtual.possuiMultiplosContextos ? _abrirTrocaPerfil : null,
        ),
      ),
    );
  }

  Future<void> _trocarPerfilPorId(String idPerfil) async {
    final contexto = _sessaoAtual.contextosOperacionais.where(
      (item) => item.identificador == idPerfil,
    );
    if (contexto.isEmpty) return;

    final novaSessao = _sessaoAtual.comContextoSelecionado(contexto.first);
    if (novaSessao.contextoSelecionadoId == _sessaoAtual.contextoSelecionadoId) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _sessaoAtual = novaSessao;
      _selectedIndex = 0;
      _indiceAnteriorAntesDaAnalise = 0;
      _mostrarBotaoVoltar = false;
      cnpjSelecionado = null;
      nomeCedenteSelecionado = null;
      _listaCedentesGlobal = [];
      _listaSugestoesCedentes = [];
    });

    await _carregarDados();
  }

  Future<void> _abrirTrocaPerfil() async {
    if (!_sessaoAtual.possuiMultiplosContextos) return;

    final novaSessao = await showContextSelector(context, _sessaoAtual);
    if (novaSessao == null) return;

    await _trocarPerfilPorId(novaSessao.contextoSelecionadoId ?? '');
  }

  Future<void> _aoVoltarSistema() async {
    if (_mostrarBotaoVoltar) {
      _voltarParaTelaAnterior();
      return;
    }

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _mostrarBotaoVoltar = false;
        cnpjSelecionado = null;
        nomeCedenteSelecionado = null;
      });
      return;
    }

    final agora = DateTime.now();
    if (_ultimoToqueVoltar != null &&
        agora.difference(_ultimoToqueVoltar!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }

    _ultimoToqueVoltar = agora;
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pressione voltar novamente para sair'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      DashboardPage(
        key: ValueKey('dashboard-${_sessaoAtual.contextoSelecionadoId ?? 'padrao'}'),
        sessao: _sessaoAtual,
        aoSelecionarCedente: _irParaAnalise,
      ),
      TelaRelatorio(
        key: ValueKey('relatorio-${_sessaoAtual.contextoSelecionadoId ?? 'padrao'}'),
        nome: _sessaoAtual.nomeContextoSelecionado,
        sessao: _sessaoAtual,
        dataSelecionadaNotifier: _dataOperacoesDoDiaSelecionada,
        aoTrocarPerfil:
            _sessaoAtual.possuiMultiplosContextos ? _abrirTrocaPerfil : null,
        aoSelecionarCedente: _irParaAnalise,
      ),
      TelaAnaliseDesempenho(
        key: ValueKey('analise-${_sessaoAtual.contextoSelecionadoId ?? 'padrao'}'),
        cnpjInicial: cnpjSelecionado,
        nomeInicial: nomeCedenteSelecionado,
        sessao: _sessaoAtual,
        listaSugestoes: _listaSugestoesCedentes,
        aoTrocarPerfil:
            _sessaoAtual.possuiMultiplosContextos ? _abrirTrocaPerfil : null,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _aoVoltarSistema();
      },
      child: LayoutBase(
        titulo: _getTitulo(),
        nomeUsuario: _sessaoAtual.saudacaoUsuario,
        perfilUsuario: _sessaoAtual.rotuloPerfilAtual,
        aoTrocarPerfil:
            _sessaoAtual.possuiMultiplosContextos ? _abrirTrocaPerfil : null,
        indexSelecionado: _selectedIndex,
        leading: _mostrarBotaoVoltar
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: _voltarParaTelaAnterior,
              )
            : _selectedIndex == 1 && _sessaoAtual.podeVerRelatorioExecutivo
                ? IconButton(
                    tooltip: 'Visão executiva',
                    icon: const Icon(Icons.insights_rounded, size: 22),
                    onPressed: _abrirRelatorioExecutivo,
                  )
                : null,
        aoMudarAba: (index) {
          setState(() {
            _selectedIndex = index;
            _mostrarBotaoVoltar = false;
            cnpjSelecionado = null;
            nomeCedenteSelecionado = null;
          });
        },
        conteudo: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: paginas,
            ),
            if (_carregandoBase && _listaCedentesGlobal.isEmpty)
              const Positioned(
                top: 16,
                right: 16,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _extrairRamo(dynamic item) {
    if (item is! Map) return '';

    const chaves = [
      'ramo',
      'Ramo',
      'ramO',
      'ramoAtividade',
      'RamoAtividade',
      'descricaoRamo',
      'DescricaoRamo',
    ];

    for (final chave in chaves) {
      final valor = item[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }

    return '';
  }
}
