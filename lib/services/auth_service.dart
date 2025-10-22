// lib/services/auth_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _keyLoggedIn = 'logged_in';
  static const _keyUsername = 'username';

  // Lokálna identita (bez servera)
  static const _localUsername = 'Brana';

  /// Sem vlož svoj SHA-256 hash hesla vo formáte: 'sha256:<64-hex-znakov>'.
  /// Napr. 'sha256:ab12...'
  static const _passwordHash = 'sha256:02de54173d906730bff41ddf3bfe8d1203eb7bf7f071289796f3e28fb0ad8c54';

  bool _loggedIn = false;
  String? _username;

  bool get isLoggedIn => _loggedIn;
  String? get username => _username;

  /// Načíta uložený stav (volaj ešte pred runApp)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    _username = prefs.getString(_keyUsername);
    notifyListeners();
  }

  /// Lokálne prihlásenie – overí meno a hash hesla
  Future<bool> login(String username, String password) async {
    final okUser = username.trim() == _localUsername;
    final okPass = _verify(password);
    if (!(okUser && okPass)) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUsername, _localUsername);

    _loggedIn = true;
    _username = _localUsername;
    notifyListeners();
    return true;
  }

  /// Odhlásenie – zmaže uložený stav
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyUsername);
    _loggedIn = false;
    _username = null;
    notifyListeners();
  }

  // -- Helpers --

  bool _verify(String password) {
    if (!_passwordHash.startsWith('sha256:')) return false;
    final target = _passwordHash.substring('sha256:'.length);
    final digest = sha256.convert(utf8.encode(password)).toString();
    return _timeSafeEquals(digest, target);
  }

  // Odolné porovnanie (bez timing-leak)
  bool _timeSafeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var res = 0;
    for (var i = 0; i < a.length; i++) {
      res |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return res == 0;
  }
}
