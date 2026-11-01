import 'package:flutter/material.dart';

/// Logo atual do app sendo "desenhado" (revelado da esquerda para a direita)
/// e o nome surgindo abaixo, no estilo da animação do ml Flutter.
class AnimatedLogoTitle extends StatefulWidget {
  final double logoSize;
  final String title;
  final Color titleColor;
  final String logoAsset;
  final Duration duration;

  const AnimatedLogoTitle({
    super.key,
    this.logoSize = 120,
    this.title = 'Rotina Comercial',
    this.titleColor = const Color(0xFFE60014),
    this.logoAsset = 'assets/rotina/logo_rotina.png',
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<AnimatedLogoTitle> createState() => _AnimatedLogoTitleState();
}

class _AnimatedLogoTitleState extends State<AnimatedLogoTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final draw = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
        final name = Curves.easeOutCubic
            .transform(((t - 0.55) / 0.30).clamp(0.0, 1.0));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.logoSize,
              height: widget.logoSize,
              child: ClipRect(
                clipper: _WipeClipper(draw),
                child: Image.asset(
                  widget.logoAsset,
                  width: widget.logoSize,
                  height: widget.logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: name,
              child: Transform.translate(
                offset: Offset(0, (1 - name) * 14),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: widget.titleColor,
                    fontFamily: 'Open Sans',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  final double progress;

  _WipeClipper(this.progress);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(covariant _WipeClipper oldClipper) =>
      oldClipper.progress != progress;
}
