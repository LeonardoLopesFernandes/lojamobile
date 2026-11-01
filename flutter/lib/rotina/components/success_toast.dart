import 'package:flutter/material.dart';
import 'package:inventario/rotina/theme.dart';

class SuccessToast extends StatefulWidget {
  final VoidCallback onHide;

  const SuccessToast({super.key, required this.onHide});

  @override
  State<SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<SuccessToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slide;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _progress = Tween<double>(begin: 1, end: 0).animate(_progressController);
    _slideController.forward();
    _progressController.forward();
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onHide();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
                border: Border.all(color: const Color(0xFFC7C7C7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('✓',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Open Sans')),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Item tratado com sucesso!',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Open Sans')),
                  ),
                  GestureDetector(
                    onTap: widget.onHide,
                    child: const Text('×',
                        style: TextStyle(fontSize: 24, color: AppColors.textHint, fontFamily: 'Open Sans')),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _progress,
              builder: (context, child) => Transform.scale(
                scaleX: _progress.value,
                scaleY: 1.0,
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 4,
                  width: double.infinity,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
