import 'package:flutter/material.dart';
import 'package:inventario/rotina/components/product_card.dart';
import 'package:inventario/rotina/components/sticky_check.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

class DepartmentCard extends StatelessWidget {
  final Department department;
  final bool blocked;
  final void Function(Department) onViewAll;
  final void Function(Item) onEditItem;
  final void Function(Item) onShowBadge;

  const DepartmentCard({
    super.key,
    required this.department,
    required this.blocked,
    required this.onViewAll,
    required this.onEditItem,
    required this.onShowBadge,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = department.items
        .map((e) => e.copyWith(departmentCode: department.department.code))
        .toList();
    final total = allItems.length;
    final treatedCount = allItems.where((i) => i.treated).length;
    final allTreated = total > 0 && treatedCount == total;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${department.department.code} - ${department.department.name}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Open Sans',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (allTreated) ...[
                  const SizedBox(width: 6),
                  const StickyCheck(size: 30),
                ] else if (blocked) ...[
                  const SizedBox(width: 6),
                  Image.asset('assets/rotina/ic_block.png', width: 20, height: 20),
                ],
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => onViewAll(department),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x47000000),
                              blurRadius: 3.6,
                              offset: Offset(0, 1.6),
                            ),
                          ],
                        ),
                        child: const Text(
                          'VER TUDO',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Open Sans',
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 22, minHeight: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$total',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Open Sans',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: allItems
                .map((item) => ProductCard(
                      key: ValueKey('${item.id}-${item.ean}'),
                      item: item,
                      blocked: blocked,
                      onEdit: onEditItem,
                      onShowBadge: onShowBadge,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
