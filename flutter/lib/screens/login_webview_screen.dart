import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/auth_loader.dart';
import '../network/session_manager.dart';
import '../network/inventario_service.dart';
import '../utils/constants.dart';
import '../utils/log_helper.dart';
import '../auth/hub_tokens.dart';

/// URL de login SAML do minhaloja (fiel ao LoginWebViewActivity.carregarLogin).
/// prompt=select_account mostra a tela "Escolher uma conta" com as contas
/// salvas, evitando reautenticar silenciosamente a conta anterior.
const String _loginUrl =
    "https://login.microsoftonline.com/e316d1ac-42c8-4d30-817c-12c7a71f8ab2/saml2?SAMLRequest=nVPLjhoxEPyVke%2Beh4fdYS1gRUBRkDYJApJDLlGPp2dx4gdxezYkXx8xQMIhy4Gru1RVXdUePe6tSV4wkPZuzIo0Z4%2BTEYE1Oznt4tat8EeHFJO9NY5kPxizLjjpgTRJBxZJRiXX0%2FdPUqS53AUfvfKGJYv5mH29K%2B%2BwflDQVrlohVICy5Yln8%2BCIs1ZsiDqcOEogotjJnJxz%2FN7LgYbUcqikqJMi7z4wpLlifqNdo12z9d91EcQyXebzZIvP643LJkjRe0g9tLbGHcks8z4Z%2B1Sq1Xw5NvondEOU%2BVthmVx3xSg%2BECoIR80Zc6HRaV4IVQFVdEOoRbZIRLBkikRhgPxzDvqLIY1hhet8NPq6Z8UGQ5d3Pqgf%2FcmUrAYtAIHlGqfWe22wI3%2FBpkCY2pQ39mxDNlHFC5auL48nN2wCcKwaaui4YhNyQfDhwEHqEtegWhzUau6yttRdiFyrv8DWFzMl95o9euW%2Bt%2F6YCG%2Bji7Son%2FRDW97qEQL2kybJiARS6bG%2BJ%2BzgBBxzGLokGVna6ejxKY%2F0Zl3Efc3nejM2x0ETYd7wD2oeM77knhmgGiF7S3pX4UpqQ7USLJztEOlW43NqYv%2FGZgcZ6%2Fs%2F3d6%2BW8nfwA%3D&sso_reload=true&prompt=select_account";

class LoginWebViewScreen extends StatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  late final WebViewController _controller;
  late final SessionManager _session;

  bool _loginConcluido = false;
  bool _tokenEncontrado = false;
  bool _autoLogin = false;
  bool _carregando = true;
  bool _pronto = false;
  String _email = '';
  String _senha = '';
  bool _argsLidos = false;
  bool _sincronizando = false;
  String _syncMensagem = '';
  Completer<void>? _pageCompleter;
  bool _trocaTokenCapturado = false;
  bool _rotinaTokenCapturado = false;
  String _syncUrl = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLidos) {
      _argsLidos = true;
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      _autoLogin = args?['autoLogin'] == true;
      _email = args?['email'] ?? '';
      _senha = args?['senha'] ?? '';
      _initAsync();
    }
  }

  Future<void> _initAsync() async {
    _session = await SessionManager.create();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (url != null) _syncUrl = url;
            if (url != null && _sincronizando) _capturarTokenDaUrl(url);
            if (url != null) _verificarTokenNaUrl(url);
            if (url != null) _verificarTokenViaCookies();
          },
          onPageFinished: (url) async {
            if (url != null) _syncUrl = url;
            if (_sincronizando) {
              if (url != null) _capturarTokenDaUrl(url);
              _pageCompleter?.complete();
              _pageCompleter = null;
              return;
            }
            // Antes de capturar o token, esconde o carregamento para o
            // usuário ver/preencher o login SAML. Depois do token, mantém a
            // tela de carregamento (logo centralizado).
            if (!_loginConcluido && !_tokenEncontrado) {
              setState(() => _carregando = false);
              _verificarTokenViaJavaScript();
              _verificarTokenViaCookies();
              if (_autoLogin) _preencherLoginAutomatico();
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (_sincronizando) _capturarTokenDaUrl(url);
            if (!_loginConcluido) _verificarTokenNaUrl(url);
            return NavigationDecision.navigate;
          },
        ),
      );

    await _controller.loadRequest(Uri.parse(_loginUrl));
    _pronto = true;
    if (mounted) setState(() {});
  }

  void _verificarTokenNaUrl(String url) {
    if (_loginConcluido || _tokenEncontrado) return;
    for (final pattern in [r'[?&]newToken=([^&]+)', r'[?&]token=([^&]+)']) {
      final m = RegExp(pattern).firstMatch(url);
      if (m != null) {
        final token = m.group(1)!;
        if (token.length > 50) {
          _salvarToken(token);
          return;
        }
      }
    }
  }

  Future<void> _verificarTokenViaJavaScript() async {
    if (_tokenEncontrado || _loginConcluido) return;
    const script =
        "(function(){return localStorage.getItem('newToken')||"
        "localStorage.getItem('token')||"
        "sessionStorage.getItem('newToken')||"
        "sessionStorage.getItem('token')||window.newToken||window.token;"
        "})();";
    try {
      final result = await _controller.runJavaScriptReturningResult(script);
      String? token;
      if (result is String) {
        token = result.replaceAll('"', '').trim();
      }
      if (token != null && token != 'null' && token.length > 50) {
        _salvarToken(token);
      }
    } catch (e) {
      LogHelper.e("verificarTokenViaJavaScript", e);
    }
  }

  /// Espelha o verificarCookies() do Kotlin LoginWebViewActivity: o portal
  /// minhaloja pode entregar o token em cookie (newToken/token) em vez de
  /// localStorage, e sem esta checagem o app ficava preso na WebView.
  Future<void> _verificarTokenViaCookies() async {
    if (_tokenEncontrado || _loginConcluido) return;
    try {
      final cookies = await _controller.runJavaScriptReturningResult(
          "(function(){return document.cookie||'';})()");
      if (cookies is String) {
        final all = cookies.replaceAll('"', '').trim();
        for (final name in ['newToken', 'token']) {
          final m = RegExp('(?:^|;\\s*)$name=([^;]+)').firstMatch(all);
          if (m != null) {
            final token = m.group(1)!.trim();
            if (token.isNotEmpty && token.length > 50) {
              _salvarToken(token);
              return;
            }
          }
        }
      }
    } catch (e) {
      LogHelper.e("verificarTokenViaCookies", e);
    }
  }

  /// Fluxo minha-loja: valida o token no BFF e vai direto para a home.
  Future<void> _salvarToken(String token) async {
    if (_loginConcluido) return;
    _loginConcluido = true;
    _tokenEncontrado = true;
    if (mounted) setState(() => _carregando = true);

    // Decodifica claims do JWT
    Map<String, dynamic>? claims;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        var p = parts[1];
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final j = jsonDecode(utf8.decode(base64Url.decode(p)));
        if (j is Map) claims = Map<String, dynamic>.from(j);
      }
    } catch (_) {}

    // Salva token com expiry do JWT (exp)
    _session.saveTokenWithExpiry(token,
        expiryEpochSeconds: claims?['exp'] is int ? claims!['exp'] as int : null);

    // Suporta JWT com claims aninhados em "user" (minhaloja/trocafacil)
    // e flat (Microsoft OAuth padrão).
    final user = claims?['user'] is Map
        ? Map<String, dynamic>.from(claims!['user'])
        : null;

    String email = (user?['email'] ??
            claims?['email'] ??
            claims?['preferred_username'] ??
            claims?['upn'])
        ?.toString() ??
        (_email.isNotEmpty ? _email : '');

    String nome = (user?['nome'] ??
            user?['name'] ??
            claims?['name'] ??
            claims?['given_name'])
        ?.toString() ??
        '';

    final stores = user?['stores'] ?? claims?['stores'];
    final loja = user?['loja']?.toString() ??
        claims?['loja']?.toString() ??
        (stores is List && stores.isNotEmpty ? stores.first.toString() : null);

    if (email.isEmpty) email = 'usuario@americanas.io';
    if (nome.isEmpty) {
      nome = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
      nome = nome
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' ');
    }

    _session.saveUserInfo(email, nome, loja ?? _session.getUserStore() ?? 'L291');

    try {
      final store = _session.getUserStore() ?? 'L291';
      final inventario = InventarioService.forSession(_session);
      await inventario.getCycleCounts(storeId: store, limit: 1);
      await _sincronizarHubs(
          token, claims?['exp'] is int ? claims!['exp'] as int : null);
      _irParaHome();
    } catch (e) {
      LogHelper.e("token rejeitado pelo BFF", e);
      _loginConcluido = false;
      _tokenEncontrado = false;
      _session.clearToken();
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token rejeitado. Tente novamente.')),
        );
      }
    }
  }

  // ---- Sincronização dos tokens próprios dos hubs ----

  /// Roda depois do token principal: o mesmo WebView (mesma sessão Microsoft)
  /// passa pelas autorizações da Rotina e do Troca Fácil e captura os tokens.
  Future<void> _sincronizarHubs(String mainToken, int? exp) async {
    try {
      await HubTokens.copiarPrincipalParaRecebimento(mainToken, exp: exp);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _sincronizando = true;
      _carregando = false;
      _syncMensagem = 'Sincronizando Rotina Comercial...';
    });
    try {
      await _capturarRotina();
      if (mounted) {
        setState(() => _syncMensagem = 'Sincronizando Troca Fácil...');
      }
      await _capturarTroca();
    } catch (e) {
      LogHelper.e('HubSync: erro ao sincronizar tokens', e);
    }
    if (mounted) {
      setState(() {
        _sincronizando = false;
        _syncMensagem = '';
      });
    }
  }

  Future<void> _capturarRotina() async {
    _rotinaTokenCapturado = false;
    await _carregarUrl(
        'https://sl-authorization.americanas.io/rotina-comercial');
    for (var i = 0; i < 8 && !_rotinaTokenCapturado; i++) {
      final token = await _lerCookie('rc-newToken');
      if (token != null) {
        _rotinaTokenCapturado = true;
        await HubTokens.salvarRotina(token);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<void> _capturarTroca() async {
    _trocaTokenCapturado = false;
    await _carregarUrl(
        'https://sl-authorization.americanas.io/troca-facil/login');
    for (var i = 0; i < 16 && !_trocaTokenCapturado; i++) {
      if (_syncUrl.contains('trocafacil.americanas.io')) {
        final token = await _lerCookie('token');
        if (token != null) {
          _trocaTokenCapturado = true;
          await HubTokens.salvarTroca(token);
          return;
        }
      }
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<void> _carregarUrl(String url) async {
    final c = Completer<void>();
    _pageCompleter = c;
    try {
      await _controller
          .loadRequest(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
    try {
      await c.future.timeout(const Duration(seconds: 20));
    } catch (_) {}
    _pageCompleter = null;
  }

  void _capturarTokenDaUrl(String url) {
    if (!_sincronizando) return;
    _syncUrl = url;
    final m = RegExp(r'[?&]token=([^&]+)').firstMatch(url);
    if (m == null) return;
    final token = Uri.decodeComponent(m.group(1)!);
    if (token.length <= 50) return;
    if (url.contains('trocafacil.americanas.io')) {
      _trocaTokenCapturado = true;
      HubTokens.salvarTroca(token);
    } else if (url.contains('rotina-comercial.americanas.io')) {
      _rotinaTokenCapturado = true;
      HubTokens.salvarRotina(token);
    }
  }

  Future<String?> _lerCookie(String nome) async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
          "(function(){try{var c=document.cookie?document.cookie.split('; '):[];"
          "for(var i=0;i<c.length;i++){var kv=c[i].split('=');"
          "if(kv[0]==='$nome')return kv.slice(1).join('=');}"
          "if(window.localStorage){var v=localStorage.getItem('$nome');if(v)return v;}"
          "if(window.sessionStorage){var v=sessionStorage.getItem('$nome');if(v)return v;}"
          "return '';}catch(e){return '';}})()");
      final s = result.toString().replaceAll('"', '').trim();
      return s.length > 50 ? s : null;
    } catch (_) {
      return null;
    }
  }

  void _irParaHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _preencherLoginAutomatico() async {
    final url = await _controller.currentUrl();
    if (url == null || !url.contains("login.microsoftonline.com")) return;
    if (_email.isEmpty || _senha.isEmpty) return;
    final script = _montarScriptPreenchimento(_email, _senha);
    await _controller.runJavaScript(script);
  }

  String _montarScriptPreenchimento(String email, String senha) {
    final e = _jsString(email);
    final s = _jsString(senha);
    return "(function(){"
        "var setV=function(el,v){var d=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');"
        "if(d&&d.set){d.set.call(el,v);}else{el.value=v;}"
        "el.dispatchEvent(new Event('input',{bubbles:true}));"
        "el.dispatchEvent(new Event('change',{bubbles:true}));};"
        "var btn=document.getElementById('idSIButton9');"
        "var em=document.getElementById('i0116');"
        "if(em){setV(em,$e);if(btn){btn.click();return 'email-clicked';}return 'email-no-btn';}"
        "var pw=document.getElementById('i0118');"
        "if(pw){setV(pw,$s);if(btn){btn.click();return 'pwd-clicked';}return 'pwd-no-btn';}"
        "return 'no-field';"
        "})()";
  }

  String _jsString(String s) =>
      '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(Constants.primaryRed),
      appBar: _carregando
          ? null
          : AppBar(
              backgroundColor: const Color(Constants.primaryRed),
              title: const Text('Login'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: Stack(
        children: [
          if (_pronto)
            WebViewWidget(controller: _controller)
          else
            const SizedBox.shrink(),
          if (_carregando) const _CarregamentoWidget(),
          if (_sincronizando)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: const Color(Constants.primaryRed),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _syncMensagem,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tela de carregamento: fundo vermelho, logo do caminhão centralizado com
/// animação de pulso e texto "Autenticando...". Exibida enquanto o token é
/// validado no BFF; ao concluir, navega para o home.
class _CarregamentoWidget extends StatelessWidget {
  const _CarregamentoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(Constants.primaryRed),
      child: const AuthLoader(),
    );
  }
}
