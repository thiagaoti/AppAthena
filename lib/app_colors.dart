import 'package:flutter/material.dart';

class AppColors {
  // Fundo e Estrutura
  static const Color background = Color(0xFFF8F9FA); // Cinza muito claro
  static const Color cardBackground = Color(0xFF4A5568); // Cinza azulado (Cards de destaque)
  static const Color surface = Colors.white; // Brancos para cards comuns
  
  // Texto
  static const Color text = Colors.white; // Texto Brancos
  static const Color textPrimary = Color(0xFF2563eb); // Azul ardósia escuro (Sofisticado)
  static const Color textSecondary = Color(0xFF718096); // Cinza médio para legendas
  
  // Status e Ações (Semântica Financeira)
  static const Color success = Color(0xFF48BB78); // Verde Esmeralda (Lucro/Oficializado)
  static const Color warning = Color(0xFFECC94B); // Âmbar/Dourado (Simulado/Atenção)
  static const Color primary = Color.fromARGB(255, 72, 153, 230); // Azul Royal (Botões e Links)
  static const Color error = Color(0xFFE53E3E); // Vermelho (Prejuízo/Deduções)
}