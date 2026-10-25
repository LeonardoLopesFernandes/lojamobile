import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/constants.dart';

class DialogProtocoloSucesso extends StatefulWidget {
  final String protocolo;

  const DialogProtocoloSucesso({super.key, required this.protocolo});

  @override
  State<DialogProtocoloSucesso> createState() => _DialogProtocoloSucessoState();
}

class _DialogProtocoloSucessoState extends State<DialogProtocoloSucesso>
    with SingleTickerProviderStateMixin {
  // O check.json tem 63 frames e faz fade-out entre 50 e 62. Paramos no
  // frame 50 para o check permanecer fixo no dialog após animar.
  static const double _frames = 63;
  static const double _stopFrame = 50;

  late final AnimationController _check;

  @override
  void initState() {
    super.initState();
    _check = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2625),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _check.animateTo(
        _stopFrame / _frames,
        duration: Duration(milliseconds: (_stopFrame / 24 * 1000).round()),
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Lottie.asset(
                'assets/lottie/check.json',
                controller: _check,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Protocolo gerado com sucesso',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333))),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.protocolo,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(Constants.primaryRed))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(Constants.primaryRed),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK, ENTENDI',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
