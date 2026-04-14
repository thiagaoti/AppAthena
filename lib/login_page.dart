// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:athenaapp/auth_session.dart';
import 'package:athenaapp/context_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

class TelaLogin extends StatefulWidget {
  final Function(AuthSession) aoEntrar;

  const TelaLogin({super.key, required this.aoEntrar});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  static const _chaveEmail = 'email_athena';
  static const _chaveSenha = 'senha_athena';
  static const _chaveBiometriaAtiva = 'biometria_athena_ativa';
  static const _chaveBiometriaConfigurada = 'biometria_athena_configurada';

  final _email = TextEditingController();
  final _senha = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  bool _temBiometriaSalva = false;
  bool _mostrarSenha = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSePodeUsarBiometria();
    });
  }

  Future<void> _verificarSePodeUsarBiometria() async {
    final biometriaAtiva =
        await _storage.read(key: _chaveBiometriaAtiva) == 'true';
    final emailSalvo = await _storage.read(key: _chaveEmail);
    final senhaSalva = await _storage.read(key: _chaveSenha);

    if (biometriaAtiva && emailSalvo != null && senhaSalva != null) {
      if (mounted) setState(() => _temBiometriaSalva = true);
      _loginComDigital();
    }
  }

  Future<void> _loginComDigital() async {
    try {
      final podeAutenticar =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!podeAutenticar) return;

      final autenticado = await _auth.authenticate(
        localizedReason: 'Autentique-se para entrar no AthenaApp',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      if (!autenticado) return;

      final email = await _storage.read(key: _chaveEmail);
      final senha = await _storage.read(key: _chaveSenha);
      if (email != null && senha != null) {
        _email.text = email;
        _senha.text = senha;
        await _login();
      }
    } catch (e) {
      debugPrint('Erro biometria: $e');
    }
  }

  Future<void> _login() async {
    if (mounted) setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('https://athenaapp.athenabanco.com.br/api/Usuario/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _email.text.trim(),
          'senha': _senha.text,
        }),
      );

      if (response.statusCode != 200) {
        final corpo = jsonDecode(response.body);
        _msg(
          (corpo['mensagem'] ?? 'Erro: usuario ou senha invalidos.')
              .toString(),
        );
        return;
      }

      final corpo = jsonDecode(response.body) as Map<String, dynamic>;
      if (!_usuarioTemAcessoAoApp(corpo)) {
        _msg('Acesso nao permitido para este usuario.');
        return;
      }

      final sessao = AuthSession.fromJson(corpo);
      if (!sessao.sucesso) {
        _msg(
          sessao.mensagem.isEmpty
              ? 'Nao foi possivel realizar o login.'
              : sessao.mensagem,
        );
        return;
      }

      final biometriaConfigurada =
          await _storage.read(key: _chaveBiometriaConfigurada) == 'true';
      if (!biometriaConfigurada) {
        _perguntarSobreBiometria(_email.text.trim(), _senha.text, sessao);
        return;
      }

      await _concluirLogin(sessao);
    } catch (e) {
      _msg('Erro de conexao: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _usuarioTemAcessoAoApp(Map<String, dynamic> corpo) {
    final sistemas = corpo['sistemas'];
    if (sistemas is! Map<String, dynamic>) return false;

    final valores = sistemas['\$values'];
    if (valores is! List) return false;

    for (final item in valores) {
      if (item is! Map) continue;
      final nome = (item['nome'] ?? '').toString().trim().toUpperCase();
      if (nome == 'APPATHENA') {
        return true;
      }
    }

    return false;
  }

  Future<void> _abrirEsqueciSenha() async {
    final emailController = TextEditingController(text: _email.text.trim());
    bool loadingEsqueciSenha = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> enviarRecuperacao() async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                _msg('Informe o email para recuperar a senha.');
                return;
              }

              setStateDialog(() => loadingEsqueciSenha = true);
              try {
                final response = await http.post(
                  Uri.parse(
                    'https://athenaapp.athenabanco.com.br/api/Usuario/esqueci-minha-senha',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email}),
                );

                Map<String, dynamic> corpo = const {};
                if (response.body.isNotEmpty) {
                  try {
                    final decodificado = jsonDecode(response.body);
                    if (decodificado is Map<String, dynamic>) {
                      corpo = decodificado;
                    }
                  } catch (_) {
                    corpo = {'mensagem': response.body};
                  }
                }

                if (!mounted) return;

                final mensagem =
                    (corpo['mensagem'] ?? 'Solicitacao enviada com sucesso.')
                        .toString();
                final sucesso =
                    response.statusCode == 200 &&
                    (corpo.isEmpty || corpo['sucesso'] != false);

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mensagem),
                    backgroundColor: sucesso ? Colors.green : Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                _msg('Nao foi possivel enviar a recuperacao de senha.');
              } finally {
                if (ctx.mounted) {
                  setStateDialog(() => loadingEsqueciSenha = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Esqueci minha senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Informe seu email para receber as instrucoes de recuperacao.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.send,
                    autofillHints: const [AutofillHints.email],
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loadingEsqueciSenha
                      ? null
                      : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: loadingEsqueciSenha ? null : enviarRecuperacao,
                  child: loadingEsqueciSenha
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _perguntarSobreBiometria(
    String email,
    String senha,
    AuthSession sessao,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar Digital?'),
        content: const Text('Deseja usar a biometria nos proximos acessos?'),
        actions: [
          TextButton(
            onPressed: () {
              _storage.write(key: _chaveBiometriaConfigurada, value: 'true');
              _storage.write(key: _chaveBiometriaAtiva, value: 'false');
              if (mounted) setState(() => _temBiometriaSalva = false);
              Navigator.pop(ctx);
              _concluirLogin(sessao);
            },
            child: const Text('NAO'),
          ),
          TextButton(
            onPressed: () async {
              await _storage.write(key: _chaveEmail, value: email);
              await _storage.write(key: _chaveSenha, value: senha);
              await _storage.write(key: _chaveBiometriaConfigurada, value: 'true');
              await _storage.write(key: _chaveBiometriaAtiva, value: 'true');
              if (mounted) setState(() => _temBiometriaSalva = true);
              Navigator.pop(ctx);
              await _concluirLogin(sessao);
            },
            child: const Text('SIM'),
          ),
        ],
      ),
    );
  }

  void _msg(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _concluirLogin(AuthSession sessao) async {
    final sessaoFinal = await _selecionarContextoSeNecessario(sessao);
    if (sessaoFinal == null) return;
    widget.aoEntrar(sessaoFinal);
  }

  Future<AuthSession?> _selecionarContextoSeNecessario(AuthSession sessao) async {
    if (!sessao.requerSelecaoContexto && !sessao.possuiMultiplosContextos) {
      return sessao;
    }

    if (sessao.contextosOperacionais.isEmpty) {
      _msg('Nenhum contexto operacional disponivel para este usuario.');
      return null;
    }

    if (sessao.contextosOperacionais.length == 1) {
      return sessao.comContextoSelecionado(sessao.contextosOperacionais.first);
    }

    return showContextSelector(context, sessao);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Image.asset('lib/assets/icon.png', width: 120),
              const SizedBox(height: 20),
              const Text(
                'ATHENA APP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D40),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _senha,
                obscureText: !_mostrarSenha,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _mostrarSenha = !_mostrarSenha;
                      });
                    },
                    icon: Icon(
                      _mostrarSenha
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _abrirEsqueciSenha,
                  child: const Text(
                    'Esqueci minha senha',
                    style: TextStyle(
                      color: Color(0xFF004D40),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENTRAR',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              if (_temBiometriaSalva) ...[
                const SizedBox(height: 20),
                IconButton(
                  icon: const Icon(
                    Icons.fingerprint,
                    size: 50,
                    color: Color(0xFF004D40),
                  ),
                  onPressed: _loginComDigital,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
