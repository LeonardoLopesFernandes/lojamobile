import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:inventario/rotina/api/client.dart';
import 'package:inventario/rotina/storage/session.dart';

enum AuthState { loading, authenticated, unauthenticated }

/// Decodifica o payload de um JWT (parte central) sem validar assinatura.
Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    return jsonDecode(utf8.decode(base64.decode(payload)))
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Extrai o nome do usuário do token (user.nome / user.name / nome / name).
String _extractUserNameFromToken(String token) {
  final map = _decodeJwtPayload(token);
  if (map == null) return '';
  final user = map['user'];
  if (user is Map) {
    final n = user['nome'] ?? user['name'];
    if (n is String && n.isNotEmpty) return n;
  }
  for (final key in ['nome', 'name']) {
    final v = map[key];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}

class AuthProvider with ChangeNotifier {
  AuthState _state = AuthState.loading;
  String? _token;
  String _userName = '';
  bool _autoLogin = false;

  AuthState get state => _state;
  String? get token => _token;
  String get userName => _userName;
  bool get autoLogin => _autoLogin;

  AuthProvider() {
    setOnSessionExpired(_requestReauth);
    initialize();
  }

  Future<void> initialize() async {
    // Usa somente o token próprio da Rotina. O token principal do LojaMobile
    // é de outro serviço e é rejeitado (401) pela BFF da Rotina.
    final savedToken = await Session.getToken();
    if (savedToken != null) {
      setAuthToken(savedToken);
      _token = savedToken;
      // Nome do usuário: tenta pelo token; se não, usa o salvo.
      _userName = _extractUserNameFromToken(savedToken);
      if (_userName.isEmpty) {
        _userName = await Session.getUserName();
      } else {
        await Session.saveUserName(_userName);
      }
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> setAuthenticated(String newToken) async {
    // O token recém-capturado no login é sempre o mais confiável. Um
    // `Set-Cookie` antigo ainda em memória (de requisição em voo) não pode
    // sobrescrevê-lo, senão o app volta a autenticar com token expirado.
    final tokenToUse = newToken;
    await Session.saveToken(tokenToUse);
    setAuthToken(tokenToUse);
    _token = tokenToUse;
    // Extrai o nome do usuário diretamente do token (fonte confiável).
    final tokenName = _extractUserNameFromToken(tokenToUse);
    if (tokenName.isNotEmpty) {
      _userName = tokenName;
      await Session.saveUserName(tokenName);
    }
    _autoLogin = false;
    _state = AuthState.authenticated;
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await Session.saveUserName(name);
    notifyListeners();
  }

  Future<void> logout() async {
    await Session.clearToken();
    clearToken();
    _token = null;
    _userName = '';
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> _requestReauth() async {
    final hasCreds = await Session.hasSavedCredentials();
    _autoLogin = hasCreds;
    _token = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }
}
