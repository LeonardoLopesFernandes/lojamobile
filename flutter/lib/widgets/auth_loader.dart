import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:inventario/utils/app_version.dart';

/// Tela/widget de autenticação: animação Lottie da sacola (tab_shop), título,
/// subtítulo e rodapé com a versão do app.
class AuthLoader extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final String lottieAsset;

  const AuthLoader({
    super.key,
    this.titulo = 'Loja Mobile',
    this.subtitulo = 'Autenticando...',
    this.lottieAsset = 'assets/lottie/tab_shop.json',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              lottieAsset,
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              repeat: true,
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
