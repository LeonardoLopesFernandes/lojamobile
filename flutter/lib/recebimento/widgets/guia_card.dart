import 'package:flutter/material.dart';
import '../models/recebimento.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import 'ean_text.dart';

class GuiaOuRoll {
  final String numero;
  final double valorTotal;
  final String detalheNotas;
  final List<RecebimentoItem> produtos;

  GuiaOuRoll({
    required this.numero,
    required this.valorTotal,
    required this.detalheNotas,
    required this.produtos,
  });
}

class GuiaCard extends StatefulWidget {
  final GuiaOuRoll guia;
  final VoidCallback? onVerTudo;

  const GuiaCard({super.key, required this.guia, this.onVerTudo});

  @override
  State<GuiaCard> createState() => _GuiaCardState();
}

class _GuiaCardState extends State<GuiaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final produtos = widget.guia.produtos
      ..sort((a, b) => a.departamento.compareTo(b.departamento));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.description,
                    size: 18, color: Color(Constants.primaryRed)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text("GUIA: ${widget.guia.numero}",
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDE000000))),
              ),
              Text(CurrencyFormatter.formatarMoedaComSimbolo(widget.guia.valorTotal),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(Constants.primaryRed))),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.guia.detalheNotas,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Container()),
              InkWell(
                onTap: widget.onVerTudo,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(Constants.primaryRed),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('VER TUDO',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0x12000000)),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2,
                      size: 20, color: Color(Constants.primaryRed)),
                  const SizedBox(width: 6),
                  Text(
                    _expanded
                        ? "Ocultar produtos (${produtos.length})"
                        : "Ver produtos (${produtos.length})",
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(Constants.primaryRed)),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Column(
              children: produtos
                  .map((p) => _ProdutoSimples(item: p))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ProdutoSimples extends StatelessWidget {
  final RecebimentoItem item;

  const _ProdutoSimples({required this.item});

  @override
  Widget build(BuildContext context) {
    final sap = int.tryParse(item.idSap)?.toString() ?? item.idSap;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: const Color(0xFFF8F9FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
