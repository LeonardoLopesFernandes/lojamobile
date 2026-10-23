import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:inventario/network/session_manager.dart';
import 'package:inventario/widgets/auth_loader.dart';
import 'package:inventario/widgets/auth_logo_animado.dart';
import 'package:inventario/utils/log_helper.dart';
import '../network/troca_session.dart';

const String _trocaPath1 =
    'M1561 3225 c-35 -8 -222 -78 -415 -156 -193 -78 -462 -187 -597 -241 -270 -108 -310 -133 -351 -216 l-23 -47 0 -785 0 -785 28 -58 c16 -31 43 -69 62 -82 31 -24 198 -94 875 -367 407 -164 392 -159 504 -165 109 -6 106 -9 56 57 -15 19 -41 61 -59 93 -19 32 -43 62 -55 67 -281 109 -1185 476 -1193 484 -10 9 -5 1498 4 1507 5 5 160 70 344 145 183 74 447 181 584 237 234 94 255 101 332 105 l82 4 323 -130 c178 -72 447 -180 598 -241 151 -61 281 -119 288 -128 9 -13 12 -101 12 -360 l0 -342 58 -37 c31 -20 76 -52 99 -70 23 -19 44 -34 47 -34 3 0 6 197 6 438 0 418 -1 439 -21 482 -23 52 -71 105 -114 127 -26 14 -267 112 -1065 434 -195 78 -280 91 -409 64z';
const String _trocaPath2 =
    'M844 2441 c-36 -16 -64 -60 -64 -102 0 -71 26 -87 310 -193 140 -52 302 -113 360 -135 l105 -40 3 -352 2 -353 54 110 c30 60 80 140 110 178 l56 70 0 172 0 172 63 24 c34 14 199 76 365 139 193 72 313 123 328 138 31 31 40 80 20 118 -19 38 -75 66 -113 57 -15 -4 -192 -70 -393 -146 -200 -76 -370 -138 -378 -138 -7 0 -180 63 -384 140 -204 78 -382 143 -397 145 -14 3 -36 0 -47 -4z';
const String _trocaPath3 =
    'M2380 1763 c-113 -19 -261 -79 -355 -143 -140 -96 -259 -266 -316 -450 -20 -64 -23 -97 -24 -220 0 -125 3 -155 24 -220 43 -138 113 -257 208 -353 187 -190 456 -277 713 -233 319 56 573 283 662 591 19 67 23 102 22 220 0 123 -4 151 -28 230 -107 351 -431 589 -794 584 -48 -1 -98 -4 -112 -6z m286 -307 c27 -8 81 -36 120 -61 38 -24 72 -45 77 -45 4 0 7 18 7 40 0 78 83 119 137 68 22 -21 23 -26 23 -199 0 -98 -3 -185 -6 -194 -14 -37 -56 -45 -232 -45 -156 0 -171 2 -196 21 -20 16 -26 29 -26 59 0 59 33 80 126 80 90 0 96 14 27 65 -156 114 -354 95 -495 -47 -55 -56 -68 -62 -113 -59 -27 3 -65 47 -65 75 0 44 82 135 170 191 22 14 72 36 112 50 65 23 85 25 178 21 58 -2 128 -11 156 -20z m-268 -596 c27 -17 32 -25 32 -58 0 -61 -25 -76 -126 -81 -46 -1 -84 -7 -84 -11 0 -16 85 -77 140 -100 115 -49 277 -24 371 58 91 79 128 90 167 50 50 -55 32 -106 -65 -180 -76 -59 -109 -75 -200 -99 -163 -41 -321 -11 -454 87 l-49 36 0 -47 c0 -37 -5 -51 -26 -70 -33 -30 -73 -32 -108 -4 l-26 20 0 185 c0 248 -13 234 222 234 155 0 176 -2 206 -20z';

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
                logo: AuthLogoAnimado(
                  size: 140,
                  paths: [_trocaPath1, _trocaPath2, _trocaPath3],
                  translateY: 342,
                ),
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
