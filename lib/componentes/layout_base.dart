import 'package:athenaapp/main.dart';
import 'package:flutter/material.dart';

class LayoutBase extends StatefulWidget {
  final Widget conteudo;
  final Widget? leading;
  final String? nomeUsuario;
  final String? perfilUsuario;
  final String titulo;
  final int indexSelecionado;
  final Function(int) aoMudarAba;
  final Future<void> Function()? aoTrocarPerfil;

  const LayoutBase({
    super.key,
    required this.conteudo,
    this.leading,
    this.nomeUsuario,
    this.perfilUsuario,
    required this.titulo,
    required this.indexSelecionado,
    required this.aoMudarAba,
    this.aoTrocarPerfil,
  });

  @override
  State<LayoutBase> createState() => _LayoutBaseState();
}

class _LayoutBaseState extends State<LayoutBase> {
  void _irParaHomeETopo() {
    widget.aoMudarAba(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final scrollController = PrimaryScrollController.maybeOf(context);
      if (scrollController == null || !scrollController.hasClients) return;

      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFF4F7F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 48,
                    child: widget.leading ?? const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isDark
                                ? Icons.wb_sunny_rounded
                                : Icons.nights_stay_rounded,
                            color: isDark
                                ? Colors.amber
                                : const Color(0xFF0E7490),
                            size: 20,
                          ),
                          onPressed: () {
                            temaApp.value =
                                isDark ? ThemeMode.light : ThemeMode.dark;
                          },
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          offset: const Offset(0, 45),
                          padding: EdgeInsets.zero,
                          icon: CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                const Color(0xFF0E7490).withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF0E7490),
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
                                    'Ola, ${widget.nomeUsuario ?? 'Usuario'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if ((widget.perfilUsuario ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        widget.perfilUsuario!,
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
                            if (widget.aoTrocarPerfil != null)
                              const PopupMenuDivider(),
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
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'sair',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red, size: 20),
                                  SizedBox(width: 10),
                                  Text('Sair'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'trocar_perfil') {
                              widget.aoTrocarPerfil?.call();
                              return;
                            }

                            if (value == 'sair') {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MyApp(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: widget.conteudo),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'layout-base-home-fab',
        onPressed: _irParaHomeETopo,
        backgroundColor: const Color(0xFF0E7490),
        shape: const CircleBorder(),
        child: const Icon(Icons.home_filled, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.bar_chart_rounded, 'Desempenho', 2),
              const SizedBox(width: 40),
              _buildNavItem(Icons.receipt_long_outlined, 'Operacoes', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final selecionado = widget.indexSelecionado == index;
    return InkWell(
      onTap: () => widget.aoMudarAba(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selecionado ? const Color(0xFF0E7490) : Colors.grey,
            size: 24,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selecionado ? const Color(0xFF0E7490) : Colors.grey,
              fontWeight:
                  selecionado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
