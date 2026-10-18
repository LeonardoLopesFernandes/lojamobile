import 'package:flutter/material.dart';
import 'package:inventario/utils/app_version.dart';
import 'package:lottie/lottie.dart';
import 'auth_logo_animado.dart';

/// Tela/widget de autenticação: logo do app sendo desenhado (branco), título,
/// subtítulo e rodapé com a versão do app.
class AuthLoader extends StatelessWidget {
  final String titulo;
  final String? subtitulo;

  const AuthLoader({
    super.key,
    this.titulo = 'Loja Mobile',
    this.subtitulo = 'Autenticando...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Lottie.asset(
                    'assets/lottie/loader_ring.json',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                  const LogoMarcaBranca(size: 84),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              'Versão $appVersion',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
