import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Check animado que, ao terminar, permanece fixo (para antes do fade-out
/// que existe no final do JSON).
class StickyCheck extends StatefulWidget {
  final double size;

  const StickyCheck({super.key, this.size = 30});

  @override
  State<StickyCheck> createState() => _StickyCheckState();
}

class _StickyCheckState extends State<StickyCheck>
    with SingleTickerProviderStateMixin {
  // check.json: 63 frames, fade-out entre 50 e 62.
  static const double _frames = 63;
  static const double _stopFrame = 50;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2625),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.animateTo(
        _stopFrame / _frames,
        duration: Duration(milliseconds: (_stopFrame / 24 * 1000).round()),
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        'assets/rotina/lottie/check.json',
        controller: _controller,
        fit: BoxFit.contain,
      ),
    );
  }
}
