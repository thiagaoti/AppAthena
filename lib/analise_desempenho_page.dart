import 'dart:convert';

import 'package:athenaapp/auth_session.dart';
import 'dart:io';
import 'package:athenaapp/comissaria_vencidos_page.dart';
import 'package:athenaapp/limites_cedente_page.dart';
import 'package:athenaapp/operacoes_estruturadas_page.dart';
import 'package:athenaapp/titulos_vencidos_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const _anaPrimary = Color(0xFF0E7490);
const _anaPrimaryDark = Color(0xFF0F766E);
const _anaPrimarySoft = Color(0xFF0EA5A4);
const _anaAccent = Color(0xFF22C55E);
const _anaDanger = Color(0xFFDC2626);
const _anaWarning = Color(0xFFF59E0B);
const _anaDarkSurfaceAlt = Color(0xFF1C1C1E);
const _anaBorderLight = Color(0xFFE2E8F0);
const _anaSurfaceAltLight = Color(0xFFF8FAFC);

class TelaAnaliseDesempenho extends StatefulWidget {
  final String? cnpjInicial;
  final String? nomeInicial;
  final AuthSession sessao;
  final List<Map<String, dynamic>> listaSugestoes;
  final Future<void> Function()? aoTrocarPerfil;
  final bool usarScaffold;

  const TelaAnaliseDesempenho({
    super.key,
    this.cnpjInicial,
    this.nomeInicial,
    required this.sessao,
    required this.listaSugestoes,
    this.aoTrocarPerfil,
    this.usarScaffold = true,
  });

  @override
  State<TelaAnaliseDesempenho> createState() => _TelaAnaliseDesempenhoState();
}

class _TelaAnaliseDesempenhoState extends State<TelaAnaliseDesempenho> {
  late final TextEditingController _searchController;
  TextEditingController? _autocompleteController;
  Map<String, dynamic>? dadosApi;
  bool _carregando = false;
  String? _nomeCedenteExibicao;
  String? _gerenteCedenteExibicao;

  List<Map<String, dynamic>> _cacheCedentes = [];
  bool _baixandoLista = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.nomeInicial ?? '');
    _nomeCedenteExibicao = widget.nomeInicial;

    _hidratarSugestoes(widget.listaSugestoes);
    if (_cacheCedentes.isEmpty) {
      _carregarCacheSincrono();
    }

    if (widget.cnpjInicial != null && widget.cnpjInicial!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consultarApi(widget.cnpjInicial!, widget.nomeInicial);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TelaAnaliseDesempenho oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listaSugestoes != oldWidget.listaSugestoes ||
        widget.sessao.contextoSelecionadoId != oldWidget.sessao.contextoSelecionadoId) {
      _hidratarSugestoes(widget.listaSugestoes);
    }
    if (widget.cnpjInicial != oldWidget.cnpjInicial &&
        widget.cnpjInicial != null &&
        widget.cnpjInicial!.isNotEmpty) {
      final novoTexto = widget.nomeInicial ?? _searchController.text;
      _searchController.text = novoTexto;
      _autocompleteController?.text = novoTexto;
      _consultarApi(widget.cnpjInicial!, widget.nomeInicial);
    } else if (widget.nomeInicial != oldWidget.nomeInicial &&
        widget.nomeInicial != null &&
        widget.nomeInicial!.isNotEmpty) {
      final novoTexto = widget.nomeInicial!;
      _searchController.text = novoTexto;
      _autocompleteController?.text = novoTexto;
      _nomeCedenteExibicao = novoTexto;
    }
  }

  void _hidratarSugestoes(List<Map<String, dynamic>> sugestoes) {
    if (sugestoes.isEmpty) return;

    _cacheCedentes = sugestoes
        .map(
          (item) => {
            'cedente': item['cedente'] ?? item['nome'] ?? '',
            'cgc': item['cgc'] ?? item['cnpj'] ?? '',
            'empresa': item['empresa'] ?? item['codigoErp'] ?? '',
            'codigoErp': item['codigoErp'] ?? item['empresa'] ?? '',
            'plat': item['plat'] ?? item['codPlataforma'] ?? '',
            'plataforma': item['plataforma'] ?? '',
            'gerente': item['gerente'] ?? 'SEM GERENTE',
          },
        )
        .where(
          (item) =>
              item['cedente'].toString().isNotEmpty &&
              item['cgc'].toString().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> _carregarCacheSincrono() async {
    if (_cacheCedentes.isNotEmpty || widget.listaSugestoes.isNotEmpty) return;

    setState(() => _baixandoLista = true);
    try {
      final response = await http
          .get(Uri.parse('http://177.69.57.196:8083/api/Dash/ListaCedentes'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> listaBruta = data['dados']['\$values'] ?? [];
        final lista = listaBruta.map((e) {
          final item = Map<String, dynamic>.from(e);
          return {
            ...item,
            'empresa':
                item['empresa'] ??
                item['codigoErp'] ??
                item['CodigoERP'] ??
                '',
            'codigoErp':
                item['codigoErp'] ??
                item['CodigoERP'] ??
                item['empresa'] ??
                '',
            'plat': item['plat'] ?? item['codPlataforma'] ?? '',
            'plataforma': item['plataforma'] ?? item['descPlataforma'] ?? '',
          };
        }).toList(growable: false);
        _cacheCedentes = widget.sessao.filtrarRegistros(lista);
      }
    } catch (e) {
      debugPrint('Erro ao baixar lista: $e');
    } finally {
      if (mounted) {
        setState(() => _baixandoLista = false);
      }
    }
  }

  Iterable<Map<String, dynamic>> _getSugestoesOtimizadas(String termo) {
    if (termo.isEmpty) return const Iterable.empty();

    final termoLower = termo.toLowerCase();
    return _cacheCedentes.where((item) {
      final nome = (item['cedente'] ?? '').toString().toLowerCase();
      final cnpj = (item['cgc'] ?? '').toString();
      return nome.contains(termoLower) || cnpj.contains(termo);
    }).take(15);
  }

  String fMoeda(double valor) =>
      NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor);

  String _normalizarCnpj(dynamic valor) {
    return (valor ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _consultarApi(String cnpj, String? nomeFallback) async {
    final cnpjNormalizado = _normalizarCnpj(cnpj);
    if (cnpjNormalizado.isEmpty) {
      _msg('CNPJ invalido para consulta.');
      return;
    }

    final sugestao = _cacheCedentes.cast<Map<String, dynamic>?>().firstWhere(
          (item) => _normalizarCnpj(item?['cgc']) == cnpjNormalizado,
          orElse: () => null,
        );

    setState(() {
      _carregando = true;
      if (nomeFallback != null) _nomeCedenteExibicao = nomeFallback;
      _gerenteCedenteExibicao = sugestao?['gerente']?.toString();
    });

    try {
      final decoded = await _buscarVisaoCedente(cnpjNormalizado);
      if (!mounted) return;

      setState(() {
        dadosApi = decoded['dados'];
        if (dadosApi != null &&
            (dadosApi!['nome'] != null || dadosApi!['cedente'] != null)) {
          _nomeCedenteExibicao = dadosApi!['nome'] ?? dadosApi!['cedente'];
        }
        _gerenteCedenteExibicao =
            dadosApi?['gerente']?.toString() ??
            dadosApi?['nomeGerente']?.toString() ??
            dadosApi?['nome_gerente']?.toString() ??
            _gerenteCedenteExibicao;
      });
    } catch (e) {
      _msg('Erro de conexao ao consultar o cedente.');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<Map<String, dynamic>> _buscarVisaoCedente(String cnpj) async {
    final uri = Uri.parse('http://177.69.57.196:8083/api/VisaoCedente/$cnpj');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.body.trim().isEmpty) {
        throw const HttpException('Resposta vazia');
      }
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      final socket = await Socket.connect(uri.host, uri.port, timeout: const Duration(seconds: 15));
      try {
        socket.write(
          'GET ${uri.path} HTTP/1.1\r\n'
          'Host: ${uri.host}:${uri.port}\r\n'
          'Accept: application/json\r\n'
          'Connection: close\r\n'
          '\r\n',
        );
        await socket.flush();

        final respostaBruta = await utf8.decoder.bind(socket).join();
        final partes = respostaBruta.split('\r\n\r\n');
        if (partes.length < 2) {
          throw const HttpException('Resposta invalida');
        }

        final cabecalhos = partes.first.toLowerCase();
        var corpo = partes.sublist(1).join('\r\n\r\n');
        if (cabecalhos.contains('transfer-encoding: chunked')) {
          corpo = _decodificarChunked(corpo);
        }
        corpo = corpo.trim();
        if (corpo.isEmpty) {
          throw const HttpException('Resposta vazia');
        }

        return Map<String, dynamic>.from(jsonDecode(corpo));
      } finally {
        await socket.close();
      }
    }
  }

  String _decodificarChunked(String corpo) {
    final buffer = StringBuffer();
    var restante = corpo;

    while (restante.isNotEmpty) {
      final fimCabecalho = restante.indexOf('\r\n');
      if (fimCabecalho < 0) break;

      final tamanhoHex = restante.substring(0, fimCabecalho).trim();
      final tamanho = int.tryParse(tamanhoHex, radix: 16);
      if (tamanho == null) {
        return corpo;
      }

      if (tamanho == 0) {
        break;
      }

      final inicioChunk = fimCabecalho + 2;
      final fimChunk = inicioChunk + tamanho;
      if (fimChunk > restante.length) {
        return corpo;
      }

      buffer.write(restante.substring(inicioChunk, fimChunk));
      restante = fimChunk + 2 <= restante.length
          ? restante.substring(fimChunk + 2)
          : '';
    }

    return buffer.toString();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _temValorPositivo(dynamic valor) {
    if (valor == null) return false;
    if (valor is num) return valor.toDouble() > 0;
    return (double.tryParse(valor.toString()) ?? 0) > 0;
  }

  Widget _buildCardInfo(
    String label,
    dynamic valor,
    IconData icone,
    Color cor,
    bool isDark,
    {bool mostrarAlerta = false,
    VoidCallback? onTap,
  }
  ) {
    double numValor = 0;
    if (valor != null) {
      numValor = (valor is int)
          ? valor.toDouble()
          : (double.tryParse(valor.toString()) ?? 0);
    }

    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? _anaDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mostrarAlerta
              ? _anaDanger.withValues(alpha: isDark ? 0.6 : 0.35)
              : (isDark ? Colors.white10 : _anaBorderLight),
          width: mostrarAlerta ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fMoeda(numValor),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF111827),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (mostrarAlerta) ...[
                              const SizedBox(width: 6),
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _anaDanger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(icone, color: cor.withValues(alpha: 0.3), size: 18),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildLiquidacaoImpactante(Map<String, dynamic> dados, bool isDark) {
    final double total = (dados['liquidados'] ?? 0).toDouble();
    final double p1 = total > 0 ? ((dados['pago_na_data'] ?? 0) / total) : 0;
    final double p2 = total > 0 ? ((dados['pago_sete_dias'] ?? 0) / total) : 0;
    final double p3 = total > 0 ? ((dados['pago_cartorio'] ?? 0) / total) : 0;
    final double p4 =
        total > 0 ? ((dados['pago_acima_sete_dias'] ?? 0) / total) : 0;
    final double p5 = total > 0 ? ((dados['recomprados'] ?? 0) / total) : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? _anaDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : _anaBorderLight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                )
              ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIQUIDEZ (180 DIAS)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : const Color(0xFF111827),
                ),
              ),
              Text(
                fMoeda(total),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (p1 > 0)
                    Expanded(
                      flex: (p1 * 100).toInt().clamp(1, 100),
                      child: Container(color: _anaAccent),
                    ),
                  if (p2 > 0)
                    Expanded(
                      flex: (p2 * 100).toInt().clamp(1, 100),
                      child: Container(color: _anaAccent),
                    ),
                  if (p4 > 0)
                    Expanded(
                      flex: (p4 * 100).toInt().clamp(1, 100),
                      child: Container(color: _anaWarning),
                    ),
                  if (p3 > 0)
                    Expanded(
                      flex: (p3 * 100).toInt().clamp(1, 100),
                      child: Container(color: _anaDanger),
                    ),
                  if (p5 > 0)
                    Expanded(
                      flex: (p5 * 100).toInt().clamp(1, 100),
                      child: Container(color: _anaDanger),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 15,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendaBI(
                'NO PRAZO',
                '${(p1 * 100).toStringAsFixed(1)}%',
                _anaAccent,
                isDark,
              ),
              _buildLegendaBI(
                'ATÉ 7 DIAS',
                '${(p2 * 100).toStringAsFixed(1)}%',
                _anaAccent,
                isDark,
              ),
              _buildLegendaBI(
                '+ 7 DIAS',
                '${(p4 * 100).toStringAsFixed(1)}%',
                _anaWarning,
                isDark,
              ),
              _buildLegendaBI(
                'CARTÓRIO',
                '${(p3 * 100).toStringAsFixed(1)}%',
                _anaDanger,
                isDark,
              ),
              _buildLegendaBI(
                'RECOMPRAS',
                '${(p5 * 100).toStringAsFixed(1)}%',
                _anaDanger,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendaBI(String label, String percent, Color cor, bool isDark) {
    return Column(
      children: [
        Text(
          percent,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: cor),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white30 : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildOperacoesEstruturadas(Map<String, dynamic> dados, bool isDark) {
    final double gNecessaria = (dados['garantia_necessaria'] ?? 0).toDouble();
    final double gCarteira = (dados['garantia_carteira'] ?? 0).toDouble();
    final double faltaExcesso = (dados['falta_excesso'] ?? 0).toDouble();
    final bool temFalta = faltaExcesso < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? _anaDarkSurfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : _anaBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPERAÇÕES ESTRUTURADAS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniBox(
                'RISCO ATUAL',
                fMoeda((dados['ccb_cce_nc'] ?? 0).toDouble()),
                isDark ? Colors.white54 : const Color(0xFF6B7280),
                isDark,
              ),
              const SizedBox(width: 8),
              _buildMiniBox(
                'GARANTIA NEC.',
                fMoeda(gNecessaria),
                _anaWarning,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMiniBox(
                'EM CARTEIRA',
                fMoeda(gCarteira),
                _anaPrimary,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildMiniBox(
                temFalta ? 'FALTA' : 'EXCESSO',
                fMoeda(faltaExcesso),
                temFalta ? _anaDanger : _anaAccent,
                isDark,
                destaque: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBox(
    String label,
    String valor,
    Color cor,
    bool isDark, {
    bool destaque = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: destaque
              ? cor.withValues(alpha: 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : _anaSurfaceAltLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: destaque
                    ? cor
                    : (isDark ? Colors.white38 : const Color(0xFF6B7280)),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: destaque
                      ? cor
                      : (isDark ? Colors.white70 : const Color(0xFF111827)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;
    final limiteDisponivel = _temValorPositivo(dadosApi?['limite']) ||
        _temValorPositivo(dadosApi?['risco_total_todos_bancos']);
    final vencidosDisponivel = _temValorPositivo(dadosApi?['vencidos']);
    final ccbDisponivel = _temValorPositivo(dadosApi?['ccb_cce_nc']);
    final comissariaDisponivel = _temValorPositivo(dadosApi?['comissaria']);

    final conteudo = Column(
      children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => option['cedente'] ?? '',
              optionsBuilder: (textValue) =>
                  _getSugestoesOtimizadas(textValue.text),
              onSelected: (selection) {
                final cnpj = _normalizarCnpj(selection['cgc']);
                final nome = selection['cedente'].toString();
                _searchController.text = nome;
                _autocompleteController?.text = nome;
                _autocompleteController?.selection = TextSelection.collapsed(
                  offset: nome.length,
                );
                _consultarApi(cnpj, nome);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                _autocompleteController = controller;
                if (controller.text != _searchController.text) {
                  controller.value = TextEditingValue(
                    text: _searchController.text,
                    selection: TextSelection.collapsed(
                      offset: _searchController.text.length,
                    ),
                  );
                }
                return Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : _anaSurfaceAltLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : _anaBorderLight,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onTap: () {
                      if (controller.text.isNotEmpty) {
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: controller.text.length,
                        );
                      }
                    },
                    onChanged: (value) {
                      _searchController.text = value;
                    },
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      hintText: _baixandoLista
                          ? 'Sincronizando...'
                          : 'Buscar Cedente...',
                      prefixIcon: _baixandoLista
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(_anaPrimary),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.search,
                              size: 18,
                              color: isDark ? Colors.white24 : _anaPrimary,
                            ),
                      suffixIcon: _carregando
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(_anaPrimary),
                                ),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_nomeCedenteExibicao != null || _carregando)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_nomeCedenteExibicao ?? '').toUpperCase(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'CNPJ: ${dadosApi?['cnpj'] ?? (widget.cnpjInicial ?? "...")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((_gerenteCedenteExibicao ?? '').trim().isNotEmpty)
                    Text(
                      'Gerente: $_gerenteCedenteExibicao',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Divider(height: 20, thickness: 0.5),
                ],
              ),
            ),
          if (dadosApi != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isTablet ? 4 : 2,
                      childAspectRatio: 3.2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildCardInfo(
                          'Limite',
                          dadosApi!['limite'],
                          Icons.account_balance_wallet,
                          _anaPrimary,
                          isDark,
                          onTap: limiteDisponivel ? () {
                            final cnpj = (dadosApi?['cnpj'] ?? widget.cnpjInicial)
                                ?.toString();
                            final nome = (_nomeCedenteExibicao ??
                                    dadosApi?['nome']?.toString() ??
                                    widget.nomeInicial ??
                                    'Cedente')
                                .toString();

                            if (cnpj == null || cnpj.isEmpty) {
                              _msg('CNPJ do cedente nao encontrado.');
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaLimitesCedente(
                                  cnpj: cnpj,
                                  nomeCedente: nome,
                                  sessao: widget.sessao,
                                  aoTrocarPerfil: widget.aoTrocarPerfil,
                                ),
                              ),
                            );
                          } : null,
                        ),
                        _buildCardInfo(
                          'Vencidos',
                          dadosApi!['vencidos'],
                          Icons.timer_off,
                          _anaDanger,
                          isDark,
                          onTap: vencidosDisponivel ? () {
                            final cnpj = (dadosApi?['cnpj'] ?? widget.cnpjInicial)
                                ?.toString();
                            final nome = (_nomeCedenteExibicao ??
                                    dadosApi?['nome']?.toString() ??
                                    widget.nomeInicial ??
                                    'Cedente')
                                .toString();

                            if (cnpj == null || cnpj.isEmpty) {
                              _msg('CNPJ do cedente nao encontrado.');
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaTitulosVencidos(
                                  cnpjCedente: cnpj,
                                  nomeCedente: nome,
                                  sessao: widget.sessao,
                                  aoTrocarPerfil: widget.aoTrocarPerfil,
                                ),
                              ),
                            );
                          } : null,
                        ),
                        _buildCardInfo(
                          'Risco Oper.',
                          dadosApi!['risco_operacional'],
                          Icons.warning_amber,
                          _anaWarning,
                          isDark,
                        ),
                        _buildCardInfo(
                          'Risco Total',
                          dadosApi!['risco_total_todos_bancos'],
                          Icons.assessment,
                          _anaPrimaryDark,
                          isDark,
                        ),
                        _buildCardInfo(
                          'Liquidados',
                          dadosApi!['liquidados'],
                          Icons.check_circle,
                          _anaAccent,
                          isDark,
                        ),
                        _buildCardInfo(
                          'Vencer',
                          dadosApi!['vencer'],
                          Icons.event_available,
                          _anaPrimarySoft,
                          isDark,
                        ),
                        _buildCardInfo(
                          'CCB/CCE/NC',
                          dadosApi!['ccb_cce_nc'],
                          Icons.description,
                          _anaPrimary,
                          isDark,
                          onTap: ccbDisponivel ? () {
                            final cnpj = (dadosApi?['cnpj'] ?? widget.cnpjInicial)
                                ?.toString();
                            final nome = (_nomeCedenteExibicao ??
                                    dadosApi?['nome']?.toString() ??
                                    widget.nomeInicial ??
                                    'Cedente')
                                .toString();

                            if (cnpj == null || cnpj.isEmpty) {
                              _msg('CNPJ do cedente nao encontrado.');
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaOperacoesEstruturadas(
                                  cnpj: cnpj,
                                  nomeCedente: nome,
                                  sessao: widget.sessao,
                                  aoTrocarPerfil: widget.aoTrocarPerfil,
                                ),
                              ),
                            );
                          } : null,
                        ),
                        _buildCardInfo(
                          'Comissária',
                          dadosApi!['comissaria'],
                          Icons.pie_chart,
                          _anaPrimaryDark,
                          isDark,
                          onTap: comissariaDisponivel ? () {
                            final cnpj = (dadosApi?['cnpj'] ?? widget.cnpjInicial)
                                ?.toString();
                            final nome = (_nomeCedenteExibicao ??
                                    dadosApi?['nome']?.toString() ??
                                    widget.nomeInicial ??
                                    'Cedente')
                                .toString();

                            if (cnpj == null || cnpj.isEmpty) {
                              _msg('CNPJ do cedente nao encontrado.');
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaComissariaVencidos(
                                  cnpjCedente: cnpj,
                                  nomeCedente: nome,
                                  sessao: widget.sessao,
                                  aoTrocarPerfil: widget.aoTrocarPerfil,
                                ),
                              ),
                            );
                          } : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLiquidacaoImpactante(dadosApi!, isDark),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            )
          else if (!_carregando)
            const Expanded(
              child: Center(
                child: Text('Selecione um cedente na busca acima'),
              ),
            ),
      ],
    );

    if (!widget.usarScaffold) {
      return conteudo;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: conteudo,
    );
  }
}

