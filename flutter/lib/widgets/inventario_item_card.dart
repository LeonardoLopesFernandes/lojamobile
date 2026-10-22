import 'package:flutter/material.dart';
import '../models/inventario.dart';

/// Card de item do inventário (layout do resumo): descrição, chips EAN/SAP e
/// as métricas ESPERADO / CONTADO / DIF.
class InventarioItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;

  const InventarioItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final dif = item.diferenca;
    return Padding(
      padding: margin,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.description,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      height: 1.3)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _codigoChip('EAN: ${item.ean}'),
                  _codigoChip('SAP: ${item.sapCode}'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metricTile('ESPERADO',
                        '${item.expectedQuantity}',
                        const Color(0xFFF9FAFB),
                        const Color(0xFFE5E7EB),
                        const Color(0xFF374151)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile('CONTADO',
                        '${item.countedQuantity}',
                        const Color(0xFFF9FAFB),
                        const Color(0xFFE5E7EB),
                        const Color(0xFF111827)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile('DIF.', dif > 0 ? '+$dif' : '$dif',
                        const Color(0xFFFFFBEB),
                        const Color(0xFFFDE68A),
                        const Color(0xFF78350F),
                        highlight: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(
    String label,
    String value,
    Color bgColor,
    Color borderColor,
    Color textColor, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color:
                      highlight ? const Color(0xFFB45309) : Colors.grey.shade500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.bold,
                  fontFamily: 'monospace',
                  color: textColor)),
        ],
      ),
    );
  }

  Widget _codigoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500)),
    );
  }
}
