import 'package:flutter/material.dart';
import '../models/recebimento.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import 'ean_text.dart';

class ItemRow extends StatelessWidget {
  final RecebimentoItem item;

  const ItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final sap = int.tryParse(item.idSap)?.toString() ?? item.idSap;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: const Color(0xFFF8F9FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.guiaOuRoll != null && item.guiaOuRoll!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(item.guiaOuRoll!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(Constants.primaryRed))),
            ),
          Text(item.descricao,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              Text("Qtd: ${CurrencyFormatter.formatarInteiro(item.quantidade)}",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
              Text("DEP: ${item.departamento}",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
              Text("SAP: $sap",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
              EanText(sap: item.idSap, eanInicial: item.idEan),
            ],
          ),
        ],
      ),
    );
  }
}
