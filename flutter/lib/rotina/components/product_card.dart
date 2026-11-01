import 'package:flutter/material.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

class ProductCard extends StatefulWidget {
  final Item item;
  final bool blocked;
  final void Function(Item) onEdit;
  final void Function(Item) onShowBadge;

  const ProductCard({
    super.key,
    required this.item,
    required this.blocked,
    required this.onEdit,
    required this.onShowBadge,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  int? _activeStat;
  late AnimationController _animController;
  late Animation<double> _rotationAnim;
  late Animation<double> _scaleAnim;
  bool _wasTreated = false;

  @override
  void initState() {
    super.initState();
    _wasTreated = widget.item.treated;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotationAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasTreated && widget.item.treated) {
      _wasTreated = true;
      _animController.forward(from: 0);
    } else if (widget.item.treated && !_animController.isAnimating && _animController.value == 0) {
      _wasTreated = true;
      _animController.forward(from: 0);
    } else {
      _wasTreated = widget.item.treated;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleCardPress() {
    if (widget.blocked) return;
    if (widget.item.treated) {
      widget.onShowBadge(widget.item);
      return;
    }
    widget.onEdit(widget.item);
  }

  void _handleStatusPress() {
    if (widget.blocked) return;
    if (widget.item.treated) {
      widget.onShowBadge(widget.item);
    } else {
      widget.onEdit(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    const stats = ['V.DIA', 'V.MÊS', 'ESTOQUE', 'GRADE'];
    final statsValues = [
      widget.item.saleQuantityDay.toString(),
      widget.item.saleQuantityMonth.toString(),
      widget.item.quantityStock.toString(),
      widget.item.grade,
    ];

    return GestureDetector(
      onTap: _handleCardPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBEBEBE)),
          boxShadow: const [
            BoxShadow(color: Color(0x1AC9C9C9), blurRadius: 10, offset: Offset(3, 3)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            Container(
              color: AppColors.metricsBg,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: List.generate(stats.length, (index) {
                  final active = _activeStat == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _activeStat = active ? null : index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: active ? AppColors.primary : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              stats[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Open Sans',
                                color: active
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              statsValues[index],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Open Sans',
                                color: active
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECECEC)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.description,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Open Sans',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.item.ean} | ${widget.item.sap}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontFamily: 'Open Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleStatusPress,
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final rotation = _rotationAnim.value;
                        final scale = _scaleAnim.value;
                        final showCheck = widget.item.treated;
                        return Container(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..scale(
                                  (1 - rotation * 2).abs(),
                                  1.0,
                                )
                                ..scale(scale),
                              child: Image.asset(
                                showCheck ? 'assets/rotina/ic_check.png' : 'assets/rotina/ic_lapis.png',
                                width: 20,
                                height: 20,
                                color: showCheck
                                    ? AppColors.success
                                    : (widget.blocked
                                        ? AppColors.danger
                                        : AppColors.primary),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
