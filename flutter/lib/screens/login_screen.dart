import 'package:flutter/material.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/app_version.dart';
import '../widgets/auth_logo_animado.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _salvarCredenciais = false;

  @override
  void initState() {
    super.initState();
    _preencherCredenciais();
  }

  Future<void> _preencherCredenciais() async {
    final session = await SessionManager.create();
    _emailController.text = session.getUserEmail() ?? '';
    _senhaController.text = session.getSavedPassword() ?? '';
    _salvarCredenciais = session.hasSavedCredentials();
    if (mounted) setState(() {});
  }

  Future<void> _entrar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final session = await SessionManager.create();
    if (_salvarCredenciais && email.isNotEmpty) {
      session.saveCredentials(email, senha);
    } else if (!_salvarCredenciais) {
      session.clearCredentials();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      '/login_webview',
      arguments: {
        'autoLogin': true,
        'email': email,
        'senha': senha,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(Constants.primaryRed),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    const AuthLogoAnimado(size: 150),
                    const SizedBox(height: 6),
                    const Text(
                      'Loja Mobile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Para ter acesso ao app, vamos manter os '
                      'fluxos de autenticação segura.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('E-mail',
                              style: TextStyle(
                                  color: Color(0xFF49454F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Email Microsoft',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Senha',
                              style: TextStyle(
                                  color: Color(0xFF49454F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _senhaController,
                            obscureText: !_senhaVisivel,
                            decoration: InputDecoration(
                              hintText: 'Senha',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF9CA3AF)),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              suffixIcon: IconButton(
                                icon: Icon(_senhaVisivel
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(
                                    () => _senhaVisivel = !_senhaVisivel),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _entrar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(Constants.primaryRed),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _MicrosoftLogo(size: 20),
                                SizedBox(width: 10),
                                Text('Login Microsoft'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setState(
                          () => _salvarCredenciais = !_salvarCredenciais),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _salvarCredenciais
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Salvar credenciais e ativar login automático',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Text(
                  'Versão $appVersion',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo 2x2 da Microsoft (4 quadrados coloridos).
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    final c = size / 2 - 1;
    final tiles = [
      Container(color: const Color(0xFFF25022)),
      Container(color: const Color(0xFF7FBA00)),
      Container(color: const Color(0xFF00A4EF)),
      Container(color: const Color(0xFFFFBA08)),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[0]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[1]),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[2]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[3]),
          ]),
        ],
      ),
    );
  }
}
