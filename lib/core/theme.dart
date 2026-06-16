import 'package:flutter/material.dart';

/// Tema do app. Cores escolhidas para contraste >= 4.5:1 (WCAG AA).
class AppTheme {
  static const seed = Color(0xFF00695C); // teal escuro, bom contraste

  // Verde/vermelho usados para receita/despesa — tons escuros o suficiente
  // para texto branco e legíveis no modo claro.
  static const income = Color(0xFF2E7D32);
  static const expense = Color(0xFFC62828);

  static ThemeData light([Color seedColor = seed]) =>
      _base(Brightness.light, seedColor);
  static ThemeData dark([Color seedColor = seed]) =>
      _base(Brightness.dark, seedColor);

  static ThemeData _base(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Alvos de toque confortáveis (>= 48dp) por padrão.
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
      ),
    );
  }
}
