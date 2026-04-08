class AuthSession {
  final bool sucesso;
  final String mensagem;
  final String token;
  final String usuario;
  final String email;
  final bool requerSelecaoContexto;
  final List<UsuarioContextoOperacional> contextosOperacionais;
  final String? contextoSelecionadoId;

  const AuthSession({
    required this.sucesso,
    required this.mensagem,
    required this.token,
    required this.usuario,
    required this.email,
    required this.requerSelecaoContexto,
    required this.contextosOperacionais,
    this.contextoSelecionadoId,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final contextos = _lerLista(json['contextosOperacionais'])
        .map(UsuarioContextoOperacional.fromJson)
        .where((item) => item.ativo)
        .toList(growable: false);

    return AuthSession(
      sucesso: json['sucesso'] == true,
      mensagem: (json['mensagem'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      usuario: (json['usuario'] ?? 'Usuario').toString(),
      email: (json['email'] ?? '').toString(),
      requerSelecaoContexto: json['requerSelecaoContexto'] == true,
      contextosOperacionais: contextos,
      contextoSelecionadoId:
          contextos.isEmpty ? null : contextos.first.identificador,
    );
  }

  AuthSession copyWith({
    bool? sucesso,
    String? mensagem,
    String? token,
    String? usuario,
    String? email,
    bool? requerSelecaoContexto,
    List<UsuarioContextoOperacional>? contextosOperacionais,
    String? contextoSelecionadoId,
  }) {
    return AuthSession(
      sucesso: sucesso ?? this.sucesso,
      mensagem: mensagem ?? this.mensagem,
      token: token ?? this.token,
      usuario: usuario ?? this.usuario,
      email: email ?? this.email,
      requerSelecaoContexto:
          requerSelecaoContexto ?? this.requerSelecaoContexto,
      contextosOperacionais:
          contextosOperacionais ?? this.contextosOperacionais,
      contextoSelecionadoId:
          contextoSelecionadoId ?? this.contextoSelecionadoId,
    );
  }

  AuthSession comContextoSelecionado(UsuarioContextoOperacional contexto) {
    return copyWith(contextoSelecionadoId: contexto.identificador);
  }

  bool get possuiMultiplosContextos => contextosOperacionais.length > 1;

  List<UsuarioContextoOperacional> get contextosOrdenados {
    final lista = List<UsuarioContextoOperacional>.from(contextosOperacionais);
    lista.sort((a, b) {
      final ordemPerfil = a.ordemHierarquia.compareTo(b.ordemHierarquia);
      if (ordemPerfil != 0) return ordemPerfil;
      return a.rotuloPerfil.compareTo(b.rotuloPerfil);
    });
    return lista;
  }

  UsuarioContextoOperacional? get contextoSelecionado {
    if (contextosOperacionais.isEmpty) return null;

    if (contextoSelecionadoId != null) {
      for (final contexto in contextosOperacionais) {
        if (contexto.identificador == contextoSelecionadoId) {
          return contexto;
        }
      }
    }

    return contextosOrdenados.first;
  }

  String get perfil => contextoSelecionado?.perfil ?? '';

  String get perfilNormalizado => normalizarValor(perfil);

  String get saudacaoUsuario {
    final nome = usuario.trim();
    return nome.isEmpty ? 'Usuario' : nome;
  }

  String formatarUsuarioComPerfil(String perfilContexto) {
    final nomeBase = saudacaoUsuario;
    final perfilBase = perfilContexto.trim();

    if (perfilBase.isEmpty) return nomeBase;
    return '$nomeBase ( $perfilBase )';
  }

  String get nomeContextoSelecionado => formatarUsuarioComPerfil(perfil);

  String get rotuloPerfilAtual => contextoSelecionado?.rotuloPerfil ?? 'Perfil';

  List<UsuarioContextoOperacional> get outrosContextos {
    final atualId = contextoSelecionado?.identificador;
    return contextosOrdenados
        .where((item) => item.identificador != atualId)
        .toList(growable: false);
  }

  String? get codigoErpPrincipal {
    final plataformas = contextoSelecionado?.plataformas ?? const [];
    for (final plataforma in plataformas) {
      final codigo = plataforma.codigoErp.trim();
      if (codigo.isNotEmpty) return codigo;
    }
    return null;
  }

  String? get plataformaPrincipal {
    final plataformas = contextoSelecionado?.plataformas ?? const [];
    for (final plataforma in plataformas) {
      final descricao = plataforma.nomeExibicao;
      if (descricao.isNotEmpty) return descricao;
    }
    return null;
  }

  Set<String> get codigosErpPermitidos {
    final codigos = <String>{};
    final plataformas = contextoSelecionado?.plataformas ?? const [];
    for (final plataforma in plataformas) {
      final codigo = normalizarValor(plataforma.codigoErp);
      if (codigo.isNotEmpty) codigos.add(codigo);
    }
    return codigos;
  }

  Set<String> get plataformasPermitidas {
    final plataformasPermitidas = <String>{};
    final plataformas = contextoSelecionado?.plataformas ?? const [];
    for (final plataforma in plataformas) {
      final plataformaNormalizada = normalizarValor(plataforma.plataforma);
      final descricaoNormalizada = normalizarValor(plataforma.descPlataforma);
      final nomeNormalizado = normalizarValor(plataforma.nomeExibicao);
      final codigoErpNormalizado = normalizarValor(plataforma.codigoErp);

      if (plataformaNormalizada.isNotEmpty) {
        plataformasPermitidas.add(plataformaNormalizada);
      }

      if (descricaoNormalizada.isNotEmpty) {
        plataformasPermitidas.add(descricaoNormalizada);
      }

      if (nomeNormalizado.isNotEmpty) {
        plataformasPermitidas.add(nomeNormalizado);
      }

      if (plataformaNormalizada.isEmpty && _pareceCodigoPlataforma(codigoErpNormalizado)) {
        plataformasPermitidas.add(codigoErpNormalizado);
      }
    }
    return plataformasPermitidas;
  }

  bool get isAdmin =>
      perfilNormalizado == 'ADMIN' || perfilNormalizado == 'PRESIDENCIA';

  bool get podeVerRelatorioExecutivo {
    const perfisPermitidos = {
      'SUPERITENDE',
      'SUPERINTENDENTE',
      'DIRETOR',
      'PRESIDENCIA',
      'ADMIN',
    };
    return perfisPermitidos.contains(perfilNormalizado);
  }

  bool get restringePorCodigoErp => perfilNormalizado == 'GERENTE';

  bool get restringePorPlataforma {
    const perfis = {
      'ASSISTENTE',
      'DIRETOR',
    };
    return perfis.contains(perfilNormalizado);
  }

  bool get restringeSuperintendente {
    const perfis = {
      'SUPERITENDE',
      'SUPERINTENDENTE',
    };
    return perfis.contains(perfilNormalizado);
  }

  List<Map<String, dynamic>> filtrarRegistros(
    List<Map<String, dynamic>> registros, {
    List<String> chavesCodigoErp = const [
      'codigoErp',
      'codigoERP',
      'codErp',
      'codGerente',
      'empresa',
    ],
    List<String> chavesPlataforma = const [
      'plataforma',
      'plat',
      'descPlataforma',
    ],
  }) {
    if (isAdmin) return List<Map<String, dynamic>>.from(registros);

    if (restringePorCodigoErp) {
      final codigos = codigosErpPermitidos;
      if (codigos.isEmpty) return <Map<String, dynamic>>[];
      return registros.where((registro) {
        return _registroPossuiAlgumValor(registro, chavesCodigoErp, codigos);
      }).toList(growable: false);
    }

    if (restringeSuperintendente) {
      final plataformas = plataformasPermitidas;
      if (plataformas.isEmpty) return <Map<String, dynamic>>[];
      return registros.where((registro) {
        return _registroPossuiAlgumValor(
          registro,
          chavesPlataforma,
          plataformas,
        );
      }).toList(growable: false);
    }

    if (restringePorPlataforma) {
      final plataformas = plataformasPermitidas;
      if (plataformas.isEmpty) return <Map<String, dynamic>>[];
      return registros.where((registro) {
        return _registroPossuiAlgumValor(
          registro,
          chavesPlataforma,
          plataformas,
        );
      }).toList(growable: false);
    }

    return List<Map<String, dynamic>>.from(registros);
  }

  static bool _registroPossuiAlgumValor(
    Map<String, dynamic> registro,
    List<String> chaves,
    Set<String> valoresPermitidos,
  ) {
    for (final chave in chaves) {
      final valor = normalizarValor(registro[chave]);
      if (valor.isEmpty) continue;

      for (final permitido in valoresPermitidos) {
        if (_valoresCompativeis(valor, permitido)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _valoresCompativeis(String valorRegistro, String valorPermitido) {
    if (valorRegistro == valorPermitido) return true;

    final registroCompacto = _compactarCodigo(valorRegistro);
    final permitidoCompacto = _compactarCodigo(valorPermitido);

    if (registroCompacto == permitidoCompacto) return true;

    if (_pareceCodigoCorporativo(registroCompacto) ||
        _pareceCodigoCorporativo(permitidoCompacto)) {
      return registroCompacto.startsWith(permitidoCompacto) ||
          permitidoCompacto.startsWith(registroCompacto);
    }

    return false;
  }

  static String _compactarCodigo(String valor) {
    return valor.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool _pareceCodigoPlataforma(String valor) {
    if (valor.isEmpty) return false;
    return RegExp(r'^\d{2}\.\d{2}\.$').hasMatch(valor);
  }

  static bool _pareceCodigoCorporativo(String valor) {
    if (valor.isEmpty) return false;
    return RegExp(r'^\d{4,}$').hasMatch(valor);
  }

  static List<Map<String, dynamic>> _lerLista(dynamic origem) {
    if (origem is List) {
      return origem.whereType<Map>().map(_toMap).toList(growable: false);
    }

    if (origem is Map) {
      final valores = origem[r'$values'];
      if (valores is List) {
        return valores.whereType<Map>().map(_toMap).toList(growable: false);
      }
    }

    return const [];
  }

  static Map<String, dynamic> _toMap(Map mapa) {
    return Map<String, dynamic>.from(mapa);
  }

  static String normalizarValor(dynamic valor) {
    final texto = (valor ?? '').toString().trim().toUpperCase();
    const mapa = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'Ç': 'C',
    };

    return texto.split('').map((char) => mapa[char] ?? char).join();
  }
}

class UsuarioContextoOperacional {
  final int? id;
  final String userId;
  final String codUsu;
  final String usuNome;
  final String perfil;
  final String roleId;
  final bool ativo;
  final List<PlataformaOperacional> plataformas;

  const UsuarioContextoOperacional({
    required this.id,
    required this.userId,
    required this.codUsu,
    required this.usuNome,
    required this.perfil,
    required this.roleId,
    required this.ativo,
    required this.plataformas,
  });

  factory UsuarioContextoOperacional.fromJson(Map<String, dynamic> json) {
    return UsuarioContextoOperacional(
      id: json['id'] as int?,
      userId: (json['userId'] ?? '').toString(),
      codUsu: (json['codUsu'] ?? '').toString(),
      usuNome: (json['usuNome'] ?? '').toString(),
      perfil: (json['perfil'] ?? '').toString(),
      roleId: (json['roleId'] ?? '').toString(),
      ativo: json['ativo'] != false,
      plataformas: AuthSession._lerLista(json['plataformas'])
          .map(PlataformaOperacional.fromJson)
          .toList(growable: false),
    );
  }

  String get identificador => '${id ?? codUsu}|$perfil|$usuNome';

  String get perfilNormalizado => AuthSession.normalizarValor(perfil);

  int get ordemHierarquia {
    switch (perfilNormalizado) {
      case 'ADMIN':
        return 0;
      case 'DIRETOR':
        return 1;
      case 'SUPERITENDE':
      case 'SUPERINTENDENTE':
        return 2;
      case 'GERENTE':
        return 3;
      case 'ASSISTENTE':
        return 4;
      default:
        return 99;
    }
  }

  String get rotuloPerfil {
    final perfilBase = perfil.trim();
    final codigoBase = codUsu.trim();
    if (perfilBase.isEmpty && codigoBase.isEmpty) return 'Perfil';
    if (codigoBase.isEmpty) return perfilBase;
    if (perfilBase.isEmpty) return '($codigoBase)';
    return '$perfilBase ($codigoBase)';
  }

  String get resumoPlataformas {
    if (plataformas.isEmpty) return 'Sem plataforma vinculada';
    return plataformas.map((item) => item.nomeExibicao).join(' | ');
  }
}

class PlataformaOperacional {
  final String codigoErp;
  final String plataforma;
  final String descPlataforma;

  const PlataformaOperacional({
    required this.codigoErp,
    required this.plataforma,
    required this.descPlataforma,
  });

  factory PlataformaOperacional.fromJson(Map<String, dynamic> json) {
    return PlataformaOperacional(
      codigoErp: (json['codigoErp'] ?? '').toString(),
      plataforma: (json['plataforma'] ?? '').toString(),
      descPlataforma: (json['descPlataforma'] ?? '').toString(),
    );
  }

  String get nomeExibicao {
    if (descPlataforma.trim().isNotEmpty) return descPlataforma.trim();
    return plataforma.trim();
  }
}
