import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import '../models/bloqueio.dart';
import '../network/troca_api.dart';

/// Etapa inicial do bloqueio: monta a lista de itens que serão bloqueados.
/// Ainda não confirma o bloqueio (sem finalização).
class BloquearItemScreen extends StatefulWidget {
  const BloquearItemScreen({super.key});

  @override
  State<BloquearItemScreen> createState() => _BloquearItemScreenState();
}

class _LinhaBloqueio {
  final TextEditingController eanCtrl = TextEditingController();
  ProductInfo? produto;
  int quantidade = 1;
  String? motivo;
  bool buscando = false;
  String? erro;
  Timer? debounce;

  void dispose() {
    debounce?.cancel();
    eanCtrl.dispose();
  }
}

class _BloquearItemScreenState extends State<BloquearItemScreen> {
  final TrocaApi _api = TrocaApi();
  final List<_LinhaBloqueio> _linhas = [_LinhaBloqueio()];

  static const List<String> _motivos = [
    'Bateria',
    'Avariado (Arranhado, rasgado, furado)',
    'Tela com defeito',
    'Áudio com defeito',
    'Câmera com defeito',
    'Fora da validade',
    'Faltando peças',
    'Não está ligando',
    'Outros',
  ];

  @override
  void dispose() {
    for (final l in _linhas) {
      l.dispose();
    }
    super.dispose();
  }

  void _adicionarLinha() {
    setState(() => _linhas.add(_LinhaBloqueio()));
  }

  void _enviar() {
    ToastUtils.showInfo(context, 'Envio de bloqueio em implementação');
  }

  Future<void> _scan(_LinhaBloqueio linha) async {
    final r = await Navigator.of(context).pushNamed('/barcode');
    if (r is String && r.isNotEmpty) {
      linha.eanCtrl.text = r;
      _buscar(linha);
    }
  }

  void _onEanChanged(_LinhaBloqueio linha, String v) {
    linha.debounce?.cancel();
    if (v.trim().length < 8) {
      if (linha.produto != null) {
        setState(() {
          linha.produto = null;
          linha.erro = null;
        });
      }
      return;
    }
    linha.debounce = Timer(const Duration(milliseconds: 500), () {
      _buscar(linha);
    });
  }

  Future<void> _buscar(_LinhaBloqueio linha) async {
    final ean = linha.eanCtrl.text.trim();
    if (ean.isEmpty) return;
    linha.debounce?.cancel();
    setState(() {
      linha.buscando = true;
      linha.erro = null;
      linha.produto = null;
    });
    try {
      final produtos = await _api.infosProduct(ean: ean);
      if (!mounted) return;
      setState(() {
        linha.buscando = false;
        if (produtos.isEmpty) {
          linha.erro = 'Produto não encontrado para o EAN $ean';
        } else {
          linha.produto = produtos.first;
          linha.quantidade = 1;
          linha.motivo = null;
        }
      });
    } on TrocaApiException catch (e) {
      if (!mounted) return;
      setState(() {
        linha.buscando = false;
        linha.erro = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        linha.buscando = false;
        linha.erro = 'Erro ao buscar o produto';
      });
    }
  }

  String _brl(String v) {
    final valor = double.tryParse(v);
    if (valor == null) return 'R\$ $v';
    final s = valor.toStringAsFixed(2);
    final parts = s.split('.');
    final grouped = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $grouped,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Bloquear item',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.send),
        label: const Text('Enviar'),
        onPressed: _enviar,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          for (int i = 0; i < _linhas.length; i++) ...[
            _linhaCard(i, _linhas[i]),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _adicionarLinha,
            icon: const Icon(Icons.add, color: Color(0xFFD32F2F)),
            label: const Text('Nova linha',
                style: TextStyle(
                    color: Color(0xFFD32F2F), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFD32F2F)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Itens ainda não confirmados',
                style: TextStyle(fontSize: 11, color: Colors.black45)),
          ),
        ],
      ),
    );
  }

  Widget _linhaCard(int index, _LinhaBloqueio linha) {
    final p = linha.produto;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Item ${index + 1}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (_linhas.length > 1)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => setState(() {
                    _linhas.removeAt(index).dispose();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: linha.eanCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => _onEanChanged(linha, v),
            onSubmitted: (_) => _buscar(linha),
            decoration: InputDecoration(
              hintText: 'EAN do produto',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => _scan(linha),
                tooltip: 'Escanear',
              ),
            ),
          ),
          if (linha.buscando)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (linha.erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(linha.erro!,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54)),
            )
          else if (p != null) ...[
            const SizedBox(height: 12),
            Text(p.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (p.description.isNotEmpty)
              Text(p.description,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(_brl(p.precovigente),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F))),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dropdown<int>(
                    label: 'Quantidade',
                    value: linha.quantidade,
                    items: List<int>.generate(30, (i) => i + 1)
                        .map((q) => DropdownMenuItem(
                            value: q, child: Text('$q')))
                        .toList(),
                    onChanged: (v) => setState(
                        () => linha.quantidade = v ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _dropdown<String>(
                    label: 'Motivo',
                    value: linha.motivo,
                    hint: 'Selecione',
                    items: _motivos
                        .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setState(() => linha.motivo = v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
          hint: hint == null
              ? null
              : Text(hint, style: const TextStyle(fontSize: 12)),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
