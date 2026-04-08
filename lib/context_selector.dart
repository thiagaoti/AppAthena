import 'package:athenaapp/auth_session.dart';
import 'package:flutter/material.dart';

Future<AuthSession?> showContextSelector(
  BuildContext context,
  AuthSession sessao,
) {
  return showModalBottomSheet<AuthSession>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SeletorContextoSheet(sessao: sessao),
  );
}

class _SeletorContextoSheet extends StatelessWidget {
  final AuthSession sessao;

  const _SeletorContextoSheet({required this.sessao});

  @override
  Widget build(BuildContext context) {
    final contextoAtual = sessao.contextoSelecionado;
    final outrosContextos = sessao.outrosContextos;

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessao.saudacaoUsuario,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Escolha o perfil que deseja utilizar neste momento.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (contextoAtual != null) ...[
                    const _SecaoTitulo(
                      titulo: 'Perfil atual',
                      destaque: true,
                    ),
                    const SizedBox(height: 10),
                    _CardPerfilContexto(
                      titulo: contextoAtual.rotuloPerfil,
                      subtitulo: contextoAtual.resumoPlataformas,
                      atual: true,
                      onTap: () {
                        Navigator.pop(
                          context,
                          sessao.comContextoSelecionado(contextoAtual),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (outrosContextos.isNotEmpty) ...[
                    const _SecaoTitulo(titulo: 'Trocar perfil'),
                    const SizedBox(height: 10),
                    ...outrosContextos.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CardPerfilContexto(
                          titulo: item.rotuloPerfil,
                          subtitulo: item.resumoPlataformas,
                          atual: false,
                          onTap: () {
                            Navigator.pop(
                              context,
                              sessao.comContextoSelecionado(item),
                            );
                          },
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
    );
  }
}

class _SecaoTitulo extends StatelessWidget {
  final String titulo;
  final bool destaque;

  const _SecaoTitulo({
    required this.titulo,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: destaque ? const Color(0xFF0E7490) : const Color(0xFF64748B),
      ),
    );
  }
}

class _CardPerfilContexto extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final bool atual;
  final VoidCallback? onTap;

  const _CardPerfilContexto({
    required this.titulo,
    required this.subtitulo,
    required this.atual,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: atual ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: atual ? const Color(0xFF7DD3FC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (atual)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E7490).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Atual',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E7490),
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitulo,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
