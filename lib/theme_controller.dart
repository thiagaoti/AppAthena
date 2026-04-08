import 'package:flutter/material.dart';

// Este é o "controle remoto" do tema
class TemaGerenciador extends ChangeNotifier {
  ThemeMode _temaAtual = ThemeMode.system;

  ThemeMode get temaAtual => _temaAtual;

  void alternarTema(bool isDark) {
    _temaAtual = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners(); // Isso avisa o app para redesenhar
  }
}

// Crie uma instância global simples para teste (ou use Provider se já tiver)
final temaGerenciador = TemaGerenciador();