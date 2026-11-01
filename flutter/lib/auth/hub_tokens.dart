import 'dart:convert';

import '../recebimento/network/session_manager.dart' as receb;
import '../rotina/storage/session.dart' as rotina;
import '../trocafacil/network/troca_session.dart';

/// Guarda os tokens dos hubs que têm sessão própria.
///
/// O login principal (minhaloja) é a porta de entrada; depois dele o mesmo
/// WebView passa pelas autorizações da Rotina e do Troca Fácil e os tokens
/// capturados são salvos aqui. O Recebimento usa o token principal.
class HubTokens {
  static Future<void> salvarRotina(String token) async {
    try {
      await rotina.Session.saveToken(token);
    } catch (_) {}
  }

  static Future<void> salvarTroca(String token) async {
    try {
      int? exp;
      final parts = token.split('.');
      if (parts.length == 3) {
        var p = parts[1];
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final j = jsonDecode(utf8.decode(base64Url.decode(p)));
        if (j is Map && j['exp'] is int) exp = j['exp'] as int;
      }
      final t = await TrocaSession.create();
      t.saveToken(token, expiryEpochSeconds: exp);
    } catch (_) {}
  }

  /// Recebimento Centralizado não tem token próprio na entrada: usa o token
  /// principal do app (o OAuth do BRLog é só para sincronizar as viagens).
  static Future<void> copiarPrincipalParaRecebimento(String token,
      {int? exp}) async {
    try {
      final s = await receb.SessionManager.create();
      s.saveTokenWithExpiry(token, expiryEpochSeconds: exp);
    } catch (_) {}
  }

  static Future<bool> rotinaValida() async {
    try {
      return (await rotina.Session.getToken()) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> trocaValida() async {
    try {
      final t = await TrocaSession.create();
      return t.isLoggedIn();
    } catch (_) {
      return false;
    }
  }
}
