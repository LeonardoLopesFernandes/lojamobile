import 'package:flutter/material.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

class SpecialProductCard extends StatelessWidget {
  final SpecialItem item;
  final bool blocked;
  final void Function(SpecialItem) onUntreatedClick;
  final void Function(SpecialItem) onTreatedClick;

  const SpecialProductCard({
    super.key,
    required this.item,
    required this.blocked,
    required this.onUntreatedClick,
    required this.onTreatedClick,
  });

  String _brl(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }
    return 'R\$ ${buffer},${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final treated = item.isTreated;

    return GestureDetector(
      onTap: () {
        if (blocked) return;
        if (treated) {
          onTreatedClick(item);
        } else {
          onUntreatedClick(item);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: treated
                ? AppColors.success.withOpacity(0.3)
                : blocked
                    ? const Color(0xFFD32F2F).withOpacity(0.3)
                    : const Color(0xFFC7C7C7),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Open Sans',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.ean} | ${item.sap}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontFamily: 'Open Sans',
                    ),
                  ),
                  if (item.daysWithoutSelling != null)
                    Text(
                      'Sem venda há ${item.daysWithoutSelling} dias',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontFamily: 'Open Sans',
                      ),
                    ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'Open Sans',
                      ),
                      children: [
                        TextSpan(text: 'Estoque: ${item.stockQuantity}  '),
                        TextSpan(
                          text: _brl(item.stockValue),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: blocked
                  ? Image.asset('assets/rotina/ic_block.png', width: 20, height: 20)
                  : Container(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: Image.asset(
                          treated ? 'assets/rotina/ic_check.png' : 'assets/rotina/ic_lapis.png',
                          width: 20,
                          height: 20,
                          color: treated
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
