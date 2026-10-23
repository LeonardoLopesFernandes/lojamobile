import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/inventario.dart';
import '../network/inventario_service.dart';
import '../network/session_manager.dart';

class DetalheInventarioScreen extends StatefulWidget {
  final String inventoryId;
  final String? inventoryNumber;

  const DetalheInventarioScreen({
    super.key,
    required this.inventoryId,
    this.inventoryNumber,
  });

  @override
  State<DetalheInventarioScreen> createState() =>
      _DetalheInventarioScreenState();
}

class _DetalheInventarioScreenState extends State<DetalheInventarioScreen> {
  bool _carregando = true;
  InventoryDetail? _detalhe;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final session = await SessionManager.create();
      final service = InventarioService.forSession(session);
      final d = await service.getCycleCount(widget.inventoryId);
      if (!mounted) return;
      setState(() {
        _detalhe = d;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha ao carregar o inventário';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detalhe;
    final numero = (d != null && d.inventoryNumber.isNotEmpty)
        ? d.inventoryNumber
        : (widget.inventoryNumber ?? 'Inventário');
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(numero),
        previousPageTitle: '',
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.chevron_left,
            color: CupertinoColors.activeBlue,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _carregar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    final d = _detalhe!;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          if (d.finalizado)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _avisoFinalizado(),
            ),
          if (d.finalizado) const SizedBox(height: 16),
          CupertinoListSection.insetGrouped(
            header: const Text('INFORMAÇÕES'),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              CupertinoListTile(
                title: const Text('Referência'),
                trailing: Text(
                  d.reference,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
              ),
              CupertinoListTile(
                title: const Text('Status'),
                trailing: Text(
                  d.statusName,
                  style: TextStyle(
                    color: d.finalizado
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: Text('ITENS (${d.items.length})'),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            children: d.items.isEmpty
                ? [
                    const CupertinoListTile(
                        title: Text('Nenhum item neste inventário')),
                  ]
                : d.items.map((i) => _iosItemTile(i)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _avisoFinalizado() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: const [
          Icon(CupertinoIcons.info, color: Color(0xFFD97706), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Inventário finalizado. Os dados estão disponíveis apenas para consulta.',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iosItemTile(InventoryItem item) {
    final dif = item.diferenca;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'EAN: ${item.ean} • SAP: ${item.sapCode}',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _subMetric('ESP.', '${item.expectedQuantity}'),
                  Container(
                    height: 20,
                    width: 1,
                    color: CupertinoColors.separator,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  _subMetric('CONT.', '${item.countedQuantity}'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'DIFERENÇA',
                    style: TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.secondaryLabel,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dif > 0 ? '+$dif' : '$dif',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: dif < 0
                          ? CupertinoColors.destructiveRed
                          : CupertinoColors.activeOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            color: CupertinoColors.label,
          ),
        ),
      ],
    );
  }
}
