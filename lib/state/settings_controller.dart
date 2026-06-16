import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatters.dart';

/// Preferências do usuário (tema, cor de destaque, privacidade), persistidas
/// localmente com shared_preferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);
  final SharedPreferences _prefs;

  static const _kThemeMode = 'themeMode';
  static const _kSeed = 'seedColor';
  static const _kHide = 'hideAmounts';
  static const _kPinHash = 'pinHash';

  static const int defaultSeed = 0xFF00695C;

  /// Paleta de cores de destaque disponíveis nas configurações.
  static const List<int> accentPalette = [
    0xFF00695C, // teal
    0xFF1565C0, // azul
    0xFF6A1B9A, // roxo
    0xFF2E7D32, // verde
    0xFFEF6C00, // laranja
    0xFFC2185B, // rosa
    0xFF455A64, // cinza-azulado
  ];

  ThemeMode _themeMode = ThemeMode.system;
  int _seedColor = defaultSeed;
  bool _hideAmounts = false;
  String? _pinHash;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => Color(_seedColor);
  int get seedValue => _seedColor;
  bool get hideAmounts => _hideAmounts;

  /// Bloqueio por PIN ativo?
  bool get lockEnabled => _pinHash != null && _pinHash!.isNotEmpty;

  void load() {
    _themeMode = switch (_prefs.getString(_kThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _seedColor = _prefs.getInt(_kSeed) ?? defaultSeed;
    _hideAmounts = _prefs.getBool(_kHide) ?? false;
    _pinHash = _prefs.getString(_kPinHash);
  }

  String _hash(String pin) => sha256.convert(utf8.encode('financas:$pin')).toString();

  bool verifyPin(String pin) => lockEnabled && _hash(pin) == _pinHash;

  Future<void> setPin(String pin) async {
    _pinHash = _hash(pin);
    notifyListeners();
    await _prefs.setString(_kPinHash, _pinHash!);
  }

  Future<void> disableLock() async {
    _pinHash = null;
    notifyListeners();
    await _prefs.remove(_kPinHash);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setSeed(int colorValue) async {
    _seedColor = colorValue;
    notifyListeners();
    await _prefs.setInt(_kSeed, colorValue);
  }

  Future<void> toggleHideAmounts() => setHideAmounts(!_hideAmounts);

  Future<void> setHideAmounts(bool value) async {
    _hideAmounts = value;
    notifyListeners();
    await _prefs.setBool(_kHide, value);
  }

  /// Formata um valor respeitando o modo "ocultar valores".
  String money(num value) => _hideAmounts ? r'R$ ••••••' : Fmt.money(value);
}
