import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:inventario/network/session_manager.dart';
import 'package:inventario/widgets/auth_loader.dart';
import 'package:inventario/utils/log_helper.dart';
import '../network/troca_session.dart';

/// Login Microsoft da Troca Fácil. Carrega o portal de autorização e captura
/// o token no callback `https://trocafacil.americanas.io/callback?token=...`.
class TrocaLoginWebViewScreen extends StatefulWidget {
  const TrocaLoginWebViewScreen({super.key});

  @override
  State<TrocaLoginWebViewScreen> createState() =>
      _TrocaLoginWebViewScreenState();
}

class _TrocaLoginWebViewScreenState extends State<TrocaLoginWebViewScreen> {
  static const String _loginUrl =
      'https://sl-authorization.americanas.io/troca-facil/login';

  late final WebViewController _controller;
  bool _carregando = true;
  bool _pronto = false;
  bool _concluido = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/149.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => _capturar(url),
          onPageFinished: (url) {
            if (!mounted || _concluido) return;
            if (_carregando) setState(() => _carregando = false);
            _capturar(url);
          },
          onNavigationRequest: (req) {
            _capturar(req.url);
            return NavigationDecision.navigate;
          },
        ),
      );
    await _controller.loadRequest(Uri.parse(_loginUrl));
    if (!mounted) return;
    setState(() => _pronto = true);
  }

  void _capturar(String url) {
    if (_concluido) return;
    final m = RegExp(r'[?&]token=([^&]+)').firstMatch(url);
    if (m == null) return;
    final token = Uri.decodeComponent(m.group(1)!);
    if (token.length > 50) _salvar(token);
  }

  Future<void> _salvar(String token) async {
    _concluido = true;

    int? exp;
    Map<String, dynamic>? claims;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        var p = parts[1];
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final j = jsonDecode(utf8.decode(base64Url.decode(p)));
        if (j is Map) claims = Map<String, dynamic>.from(j);
        if (claims?['exp'] is int) exp = claims!['exp'] as int;
      }
    } catch (_) {}

    final troca = await TrocaSession.create();
    troca.saveToken(token, expiryEpochSeconds: exp);

    // Aproveita para atualizar dados do usuário na sessão principal.
    try {
      final user = claims?['user'] is Map
          ? Map<String, dynamic>.from(claims!['user'])
          : null;
      final nome = user?['nome']?.toString();
      final email = user?['email']?.toString();
      final stores = user?['stores'];
      final loja = (stores is List && stores.isNotEmpty)
          ? stores.first.toString()
          : null;
      if (nome != null || email != null) {
        final session = await SessionManager.create();
        session.saveUserInfo(email ?? '', nome ?? '',
            loja ?? session.getUserStore());
      }
    } catch (e) {
      LogHelper.e('TrocaLogin: erro ao salvar usuário', e);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFD32F2F),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFD32F2F),
        body: Stack(
          children: [
            if (_pronto && !_carregando)
              WebViewWidget(controller: _controller)
            else
              const SizedBox.shrink(),
            if (_carregando)
              Container(
                color: const Color(0xFFD32F2F),
              child: const AuthLoader(
                titulo: 'Troca Fácil',
                subtitulo: 'Autenticando...',
              ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Garante que há um token válido; se não, abre o login WebView.
/// Retorna true se logado.
Future<bool> ensureTrocaLogin(BuildContext context) async {
  final troca = await TrocaSession.create();
  if (troca.isLoggedIn()) return true;
  if (!context.mounted) return false;
  final ok = await Navigator.of(context).pushNamed('/troca_login');
  return ok == true;
}
