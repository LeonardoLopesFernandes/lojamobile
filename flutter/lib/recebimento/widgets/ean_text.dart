import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/ean_resolver.dart';

class EanText extends StatefulWidget {
  final String sap;
  final String eanInicial;
  final TextStyle? style;
  final String prefixo;

  const EanText({
    super.key,
    required this.sap,
    this.eanInicial = '',
    this.style,
    this.prefixo = 'EAN: ',
  });

  @override
  State<EanText> createState() => _EanTextState();
}

class _EanTextState extends State<EanText> {
  String _ean = '';
  bool _buscando = false;

  String _eanValido(String valor) {
    final v = valor.trim();
    if (v == '-' || v == '--') return '';
    if (v.toLowerCase() == 'null') return '';
    return v;
  }

  @override
  void initState() {
    super.initState();
    _ean = _eanValido(widget.eanInicial);
    if (_ean.isEmpty) _buscar();
  }

  @override
  void didUpdateWidget(covariant EanText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sap != widget.sap ||
        oldWidget.eanInicial != widget.eanInicial) {
      _ean = _eanValido(widget.eanInicial);
      if (_ean.isEmpty) _buscar();
    }
  }

  Future<void> _buscar() async {
    if (_buscando) return;
    final sap = widget.sap.trim();
    if (sap.isEmpty) return;
    setState(() => _buscando = true);
    final ean = await EanResolver.bySap(sap);
    if (!mounted) return;
    setState(() {
      _ean = _eanValido(ean);
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valor = _ean.isNotEmpty ? _ean : (_buscando ? '...' : '-');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _ean.isEmpty
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: _ean));
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('EAN copiado: $_ean')),
              );
            },
      child: Text(
        '${widget.prefixo}$valor',
        style: widget.style ??
            const TextStyle(fontSize: 12, color: Color(0xFF666666)),
      ),
    );
  }
}
