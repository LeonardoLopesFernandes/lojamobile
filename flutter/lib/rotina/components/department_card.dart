import 'package:flutter/material.dart';
import 'package:inventario/rotina/components/product_card.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

class DepartmentCard extends StatelessWidget {
  final Department department;
  final bool blocked;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(Department) onViewAll;
  final void Function(Item) onEditItem;
  final void Function(Item) onShowBadge;

  const DepartmentCard({
    super.key,
    required this.department,
    required this.blocked,
    required this.expanded,
    required this.onToggle,
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
    const navy = Color(0xFF1B2559);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${department.department.code} - ${department.department.name}',
                      style: const TextStyle(
                        fontSize: 17,
                        color: navy,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Open Sans',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (allTreated)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF20B26B), width: 2),
                      ),
                      child: const Icon(Icons.check,
                          size: 21, color: Color(0xFF20B26B)),
                    )
                  else if (blocked)
                    Image.asset('assets/rotina/ic_block.png',
                        width: 22, height: 22),
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: navy, size: 28),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, color: Color(0xFFE5E7EF)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
                        child: Row(
                          children: [
                            Text(
                              '$total ${total == 1 ? 'item' : 'itens'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontFamily: 'Open Sans',
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => onViewAll(department),
                              child: const Text('VER TUDO',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Open Sans')),
                            ),
                          ],
                        ),
                      ),
                      ...allItems.map((item) => ProductCard(
                            key: ValueKey('${item.id}-${item.ean}'),
                            item: item,
                            blocked: blocked,
                            onEdit: onEditItem,
                            onShowBadge: onShowBadge,
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EF)),
        ],
      ),
    );
  }
}
