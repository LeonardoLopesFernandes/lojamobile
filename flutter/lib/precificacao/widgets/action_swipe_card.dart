import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'animated_trash_icon.dart';

/// Item que pode ser arrastado (para a esquerda OU direita) para remover,
/// revelando a lixeira branca animada no lado correspondente.
class SwipeToTrashItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;

  const SwipeToTrashItem({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  @override
  State<SwipeToTrashItem> createState() => _SwipeToTrashItemState();
}

class _SwipeToTrashItemState extends State<SwipeToTrashItem>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isDeleting = false;
  bool _isRemoved = false;

  late AnimationController _controller;
  late Animation<double> _animProgress;

  final double _threshold = 100.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animProgress =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isRemoved = true);
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isDeleting) return;
    setState(() => _dragOffset += details.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isDeleting) return;
    if (_dragOffset.abs() > _threshold) {
      setState(() => _isDeleting = true);
      _controller.forward();
    } else {
      setState(() => _dragOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRemoved) return const SizedBox.shrink();

    final bool paraDireita = _dragOffset >= 0;
    final bool isTrashOpen = _dragOffset.abs() > (_threshold / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            alignment:
                paraDireita ? Alignment.centerLeft : Alignment.centerRight,
            padding: EdgeInsets.only(
                left: paraDireita ? 20 : 0, right: paraDireita ? 0 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedScale(
              scale: isTrashOpen ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedTrashIcon(animate: isTrashOpen || _isDeleting),
            ),
          ),
        ),
          AnimatedBuilder(
            animation: _animProgress,
            builder: (context, _) {
              final progress = _animProgress.value;
              if (!_isDeleting) {
                return Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    child: widget.child,
                  ),
                );
              }
              final dir = _dragOffset >= 0 ? 1.0 : -1.0;
              double scaleFactor = 1.0;
              double opacity = 1.0;
              double translateX = _dragOffset;
              double translateY = 0.0;
              if (progress <= 0.4) {
                final p = progress / 0.4;
                scaleFactor = 1.0 - (p * 0.3);
              } else {
                final p = (progress - 0.4) / 0.6;
                scaleFactor = 0.7 * (1.0 - p * 0.5);
                opacity = (1.0 - p).clamp(0.0, 1.0);
                translateX = _dragOffset + (p * (dir * 140 - _dragOffset));
                translateY = -math.sin(p * math.pi) * 30;
              }
              return Opacity(
                opacity: opacity,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(translateX, translateY)
                    ..scale(scaleFactor),
                  alignment: Alignment.center,
                  child: widget.child,
                ),
              );
            },
          ),
      ],
    );
  }
}

class ActionSwipeCard extends SwipeToTrashItem {
  const ActionSwipeCard({
    super.key,
    required super.child,
    required super.onDismissed,
  });
}
