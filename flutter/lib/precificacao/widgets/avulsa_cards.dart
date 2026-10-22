import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/precificacao/core/constants.dart';
import 'package:inventario/precificacao/models/models.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import 'package:inventario/network/inventario_service.dart';
import 'package:inventario/network/session_manager.dart';
import 'compose_avulsa.dart';

String _brl(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final grouped = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return 'R\$ $grouped,${parts[1]}';
}

String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

const Color _greenBadgeDark = Color(0xFF2E7D32);
const Color _orangeBadge = Color(0xFFFF9800);
const Color _greyBadge = Color(0xFF9E9E9E);

/// Campo de quantidade: 28dp, branco, borda vermelha, até 3 dígitos.
Widget _qtyBox(TextEditingController c, ValueChanged<int> onChange) {
  return SizedBox(
    width: 28,
    height: 28,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: avulsaRed, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 3,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
        onChanged: (v) {
          if (v.isEmpty) return;
          final n = int.tryParse(v);
          if (n != null) onChange(n.clamp(1, 999));
        },
      ),
    ),
  );
}

Widget _eanLinha(BuildContext context, String texto, String ean,
    {double? saldo}) {
  return GestureDetector(
    onTap: () async {
      await Clipboard.setData(ClipboardData(text: ean));
      if (context.mounted) ToastUtils.show(context, 'EAN copiado: $ean');
    },
    child: Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
        children: [
          TextSpan(text: texto),
          if (saldo != null)
            TextSpan(
              text: ' | SALDO: ${saldo.toInt()}',
              style: TextStyle(
                color: saldo < 0
                    ? const Color(0xFFD81B3A)
                    : const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// Container verde + badge branco anexado à direita (fiel ao Compose).
Widget _greenBadge(String valor, String tipo, Color cor, {bool parcelado = false}) {
  return Container(
    height: 28,
    constraints: const BoxConstraints(minHeight: 28),
    decoration: BoxDecoration(
      color: avulsaGreen,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.only(left: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              valor,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: parcelado ? 12 : 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: avulsaGreen),
              bottom: BorderSide(color: avulsaGreen),
              right: BorderSide(color: avulsaGreen),
              left: BorderSide(color: avulsaGreen),
            ),
            borderRadius:
                BorderRadius.horizontal(right: Radius.circular(12)),
          ),
          alignment: Alignment.center,
          child: Text(
            tipo,
            style: TextStyle(
                color: cor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class AvulsaEtiquetaCard extends StatefulWidget {
  final PriceTag tag;
  final ValueChanged<int> onImprimir;
  final ValueChanged<int> onChangedQuantity;
  const AvulsaEtiquetaCard({
    super.key,
    required this.tag,
    required this.onImprimir,
    required this.onChangedQuantity,
  });

  @override
  State<AvulsaEtiquetaCard> createState() => _AvulsaEtiquetaCardState();
}

class _AvulsaEtiquetaCardState extends State<AvulsaEtiquetaCard> {
  late TextEditingController _qty;
  int _lastQty = 0;
  double? _saldo;

  @override
  void initState() {
    super.initState();
    _lastQty = widget.tag.quantity;
    _qty = TextEditingController(text: widget.tag.quantity.toString());
    _carregarSaldo();
  }

  Future<void> _carregarSaldo() async {
    try {
      final session = await SessionManager.create();
      final store = session.getUserStore() ?? Constants.defaultStore;
      final p = await InventarioService.forSession(session).getProductStore(
        storeId: store,
        ean: widget.tag.ean,
        sapCode: widget.tag.sap,
      );
      if (mounted) setState(() => _saldo = p.stock);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AvulsaEtiquetaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tag.quantity != _lastQty) {
      _lastQty = widget.tag.quantity;
      _qty.text = widget.tag.quantity.toString();
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String? leve, String valor, String tipo, Color cor}) _calc() {
    final pd = widget.tag.printingData;
    final precoNormal = pd?.price?.value ?? 0.0;
    final precoPromo = pd?.promotionalPrice?.value;
    final take = pd?.takeAndWin;
    final inst = pd?.installments;

    final valorParcCalc = (inst != null && inst.installmentValue > 0)
        ? inst.installmentValue
        : (pd != null && pd.displayPrice > 0)
            ? pd.displayPrice
            : (pd != null && pd.unitValue > 0)
                ? pd.unitValue
                : (precoPromo != null && precoPromo > 0 ? precoPromo : precoNormal);

    final ehDeporParcelado = inst != null &&
        inst.installmentQuantity > 0 &&
        precoPromo != null &&
        precoPromo > 0 &&
        (precoNormal <= 0 || precoPromo < precoNormal);

    if (take != null && take.qty > 0 && take.totalValue > 0) {
      final totalLeve =
          (pd?.template == Constants.signTemplateLeveGanheCada &&
                  precoPromo != null &&
                  precoPromo > 0)
              ? precoPromo
              : take.totalValue;
      return (
        leve: 'Leve ${take.qty} por R\$ ${_num(totalLeve)}',
        valor: _brl(precoNormal),
        tipo: 'leve e ganhe',
        cor: _greenBadgeDark,
      );
    }
    if (ehDeporParcelado) {
      return (
        leve: null,
        valor:
            'Por R\$${_num(precoNormal)}|Por R\$${_num(precoPromo)}|${inst.installmentQuantity}x de R\$${_num(valorParcCalc)}',
        tipo: 'parcelado',
        cor: _orangeBadge,
      );
    }
    if (inst != null && inst.installmentQuantity > 0) {
      final qtdParc = inst.installmentQuantity;
      return (
        leve: null,
        valor: (precoPromo != null && precoPromo > 0)
            ? 'R\$${_num(precoPromo)} | ${qtdParc}x de R\$${_num(valorParcCalc)}'
            : '${_brl(precoNormal)} | ${qtdParc}x de R\$${_num(valorParcCalc)}',
        tipo: 'parcelado',
        cor: _orangeBadge,
      );
    }
    if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leve: null,
        valor: 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}',
        tipo: 'de por',
        cor: _orangeBadge,
      );
    }
    return (
      leve: null,
      valor: precoNormal > 0 ? _brl(precoNormal) : widget.tag.price,
      tipo: 'normal',
      cor: _greyBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _calc();
    final deptNum = widget.tag.department.split(' -').first.trim();
    final item = widget.tag;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Row(
              children: [
                _qtyBox(_qty, widget.onChangedQuantity),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121)),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      widget.onImprimir(int.tryParse(_qty.text) ?? 1),
                  icon: const Icon(Icons.print,
                      color: avulsaGreen, size: 20),
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(maxWidth: 28, maxHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eanLinha(context,
                          'DEP: $deptNum | EAN: ${item.ean} / SAP: ${item.sap}',
                          item.ean,
                          saldo: _saldo),
                      const SizedBox(height: 2),
                      if (p.leve != null)
                        _greenBadgeComLeve(p)
                      else
                        _greenBadge(p.valor, p.tipo, p.cor,
                            parcelado: p.tipo == 'parcelado'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _greenBadgeComLeve(({String? leve, String valor, String tipo, Color cor}) p) {
    return Container(
      height: 28,
      constraints: const BoxConstraints(minHeight: 28),
      decoration: BoxDecoration(
        color: avulsaGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                p.leve!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('|',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                p.valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _whiteTypeBadge(p.tipo, p.cor),
        ],
      ),
    );
  }

  Widget _whiteTypeBadge(String tipo, Color cor) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: avulsaGreen),
          bottom: BorderSide(color: avulsaGreen),
          right: BorderSide(color: avulsaGreen),
          left: BorderSide(color: avulsaGreen),
        ),
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
      ),
      alignment: Alignment.center,
      child: Text(
        tipo,
        style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class AvulsaPapeletaCard extends StatefulWidget {
  final PriceSign item;
  final ValueChanged<int> onImprimir;
  final ValueChanged<int> onChangedQuantity;
  const AvulsaPapeletaCard({
    super.key,
    required this.item,
    required this.onImprimir,
    required this.onChangedQuantity,
  });

  @override
  State<AvulsaPapeletaCard> createState() => _AvulsaPapeletaCardState();
}

class _AvulsaPapeletaCardState extends State<AvulsaPapeletaCard> {
  late TextEditingController _qty;
  int _lastQty = 0;
  double? _saldo;

  @override
  void initState() {
    super.initState();
    _lastQty = widget.item.quantity;
    _qty = TextEditingController(text: widget.item.quantity.toString());
    _carregarSaldo();
  }

  Future<void> _carregarSaldo() async {
    try {
      final session = await SessionManager.create();
      final store = session.getUserStore() ?? Constants.defaultStore;
      final p = await InventarioService.forSession(session).getProductStore(
        storeId: store,
        ean: widget.item.ean,
        sapCode: widget.item.sap,
      );
      if (mounted) setState(() => _saldo = p.stock);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AvulsaPapeletaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.quantity != _lastQty) {
      _lastQty = widget.item.quantity;
      _qty.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String? leve, String valor, String tipo, Color cor}) _calc() {
    final pd = widget.item.printingData;
    final precoNormal = pd?.price ?? 0.0;
    final precoPromo = pd?.promotionPrice;
    final takeQty = pd?.takeAndWinQuantity;
    final takePrice = pd?.takeAndWinPrice;

    final qtdParc = pd?.installmentQuantity ?? 0;
    final valorParc = (pd?.installmentPrice != null && pd!.installmentPrice! > 0)
        ? pd.installmentPrice!
        : (precoPromo != null && precoPromo > 0 ? precoPromo : precoNormal);
    final ehDeporParcelado = qtdParc > 0 &&
        precoPromo != null &&
        precoPromo > 0 &&
        (precoNormal <= 0 || precoPromo < precoNormal);

    if (takeQty != null && takeQty > 0 && takePrice != null && takePrice > 0) {
      final totalLeve = Constants.totalLeveGanhePorTemplate(
          pd?.template, precoPromo, takePrice, takeQty);
      return (
        leve: 'Leve $takeQty por ${_brl(totalLeve)}',
        valor: _brl(precoNormal),
        tipo: 'leve e ganhe',
        cor: _greenBadgeDark,
      );
    }
    if (ehDeporParcelado) {
      return (
        leve: null,
        valor:
            'De R\$${_num(precoNormal)} | Por R\$${_num(precoPromo)} | ${qtdParc}x de R\$${_num(valorParc)}',
        tipo: 'parcelado',
        cor: _orangeBadge,
      );
    }
    if (qtdParc > 0) {
      final por = (precoPromo != null && precoPromo > 0) ? precoPromo : null;
      return (
        leve: null,
        valor: (por != null && valorParc > 0)
            ? 'R\$${_num(por)} | ${qtdParc}x de R\$${_num(valorParc)}'
            : '${_brl(precoNormal)} | ${qtdParc}x de R\$${_num(valorParc)}',
        tipo: 'parcelado',
        cor: _orangeBadge,
      );
    }
    if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leve: null,
        valor: 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}',
        tipo: 'de por',
        cor: _orangeBadge,
      );
    }
    return (
      leve: null,
      valor: precoNormal > 0 ? _brl(precoNormal) : widget.item.price,
      tipo: 'normal',
      cor: _greyBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _calc();
    final deptNum = widget.item.department.split(' -').first.trim();
    final item = widget.item;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Row(
              children: [
                _qtyBox(_qty, widget.onChangedQuantity),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121)),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      widget.onImprimir(int.tryParse(_qty.text) ?? 1),
                  icon: const Icon(Icons.print,
                      color: avulsaGreen, size: 20),
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(maxWidth: 28, maxHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eanLinha(context,
                          'DEP: $deptNum | EAN: ${item.ean} / SAP: ${item.sap}',
                          item.ean,
                          saldo: _saldo),
                      const SizedBox(height: 2),
                      if (p.leve != null)
                        _greenBadgeComLeve(p)
                      else
                        _greenBadge(p.valor, p.tipo, p.cor,
                            parcelado: p.tipo == 'parcelado'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _greenBadgeComLeve(({String? leve, String valor, String tipo, Color cor}) p) {
    return Container(
      height: 28,
      constraints: const BoxConstraints(minHeight: 28),
      decoration: BoxDecoration(
        color: avulsaGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                p.leve!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('|',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                p.valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _whiteTypeBadge(p.tipo, p.cor),
        ],
      ),
    );
  }

  Widget _whiteTypeBadge(String tipo, Color cor) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: avulsaGreen),
          bottom: BorderSide(color: avulsaGreen),
          right: BorderSide(color: avulsaGreen),
          left: BorderSide(color: avulsaGreen),
        ),
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
      ),
      alignment: Alignment.center,
      child: Text(
        tipo,
        style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
