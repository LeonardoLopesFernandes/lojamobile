import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import '../models/bloqueio.dart';
import '../network/troca_api.dart';
import '../network/troca_session.dart';
import '../services/bloqueio_pdf.dart';

/// Lista de itens bloqueados (Troca Fácil).
class ListaBloqueiosScreen extends StatefulWidget {
  const ListaBloqueiosScreen({super.key});

  @override
  State<ListaBloqueiosScreen> createState() => _ListaBloqueiosScreenState();
}

class _ListaBloqueiosScreenState extends State<ListaBloqueiosScreen> {
  final TrocaApi _api = TrocaApi();
  List<BloqueioOperacao> _lista = [];
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final page = await _api.listarBloqueios(page: 1, size: 50);
      if (!mounted) return;
      setState(() {
        _lista = page.results;
        _loading = false;
      });
    } on TrocaApiException catch (e) {
      if (e.statusCode == 401) {
        final t = await TrocaSession.create();
        t.clear();
        if (!mounted) return;
        setState(() => _loading = false);
        ToastUtils.showError(context, 'Sessão expirada. Faça login novamente.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erro = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erro = 'Erro ao carregar bloqueios';
      });
    }
  }

  String _brl(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final grouped = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $grouped,${parts[1]}';
  }

  Future<void> _abrir(BloqueioOperacao op) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detalhes do Bloqueio',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.grey[100], shape: BoxShape.circle),
                          child: Icon(Icons.close,
                              size: 18, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Loja ${op.store}',
                          style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${TrocaApi.fmtIsoDate(op.createdAt)}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final it in op.itemsBlocked) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9ECEF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.description,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212529)),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFDEE2E6)),
                          const SizedBox(height: 12),
                          _buildDetailRow('Etiqueta:', _etiqueta(it)),
                          const SizedBox(height: 8),
                          _buildDetailRow('Motivo:', it.reasonBlocking),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                              'Quantidade:', '${it.quantity}x'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Valor:',
                              it.precovigente.isEmpty ? '-' : it.precovigente,
                              isHighlight: true),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text(
                        'REIMPRIMIR',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _reimprimir(op);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _etiqueta(ItemBloqueado it) {
    if (it.tags.isNotEmpty) return it.tags.join(', ');
    return it.ean.isEmpty ? '-' : it.ean;
  }

  Future<void> _reimprimir(BloqueioOperacao op) async {
    if (op.itemsBlocked.isEmpty) return;
    final itens = <BloqueioEtiquetaItem>[];
    for (final it in op.itemsBlocked) {
      if (it.tags.isEmpty) {
        itens.add(BloqueioEtiquetaItem(
          descricao: it.description,
          motivo: it.reasonBlocking,
          etiqueta: '',
        ));
      } else {
        for (final tag in it.tags) {
          itens.add(BloqueioEtiquetaItem(
            descricao: it.description,
            motivo: it.reasonBlocking,
            etiqueta: tag,
          ));
        }
      }
    }
    if (itens.isEmpty) return;
    try {
      final uri = await BloqueioEtiquetaPdf.salvarNoDownloads(
        numeroOperacao: op.id,
        loja: op.store,
        dataBloqueio: TrocaApi.fmtIsoDate(op.createdAt),
        itens: itens,
      );
      if (!mounted) return;
      if (uri != null && uri.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Etiqueta salva em Download/Troca'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () => _abrirPdf(uri),
          ),
        ));
      } else {
        ToastUtils.showError(context, 'Não foi possível salvar a etiqueta');
      }
    } catch (_) {
      if (mounted) {
        ToastUtils.showError(context, 'Erro ao gerar a etiqueta');
      }
    }
  }

  Future<void> _abrirPdf(String uri) async {
    try {
      const channel = MethodChannel('com.ir/media');
      await channel.invokeMethod('openUri',
          {'uri': uri, 'mime': 'application/pdf'});
    } catch (_) {
      if (mounted) {
        ToastUtils.showError(context, 'Não foi possível abrir o PDF');
      }
    }
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
        title: const Text('Itens bloqueados',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: _corpo(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Bloquear item'),
        onPressed: () async {
          await Navigator.of(context).pushNamed('/troca_bloquear_item');
          _carregar();
        },
      ),
    );
  }

  Widget _corpo() {
    if (_erro != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
              child: Text(_erro!,
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 15))),
          const SizedBox(height: 12),
          Center(
              child: OutlinedButton(
                  onPressed: _carregar, child: const Text('Tentar novamente'))),
        ],
      );
    }
    if (_lista.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(
              child: Text('Nenhum item bloqueado',
                  style: TextStyle(color: Colors.black54, fontSize: 15))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final op = _lista[i];
        final motivo =
            op.itemsBlocked.isNotEmpty ? op.itemsBlocked.first.reasonBlocking : '';
        return GestureDetector(
          onTap: () => _abrir(op),
          child: Container(
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
                const Text('Nº da operação',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(op.id,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${op.itemsBlocked.length} item(ns) • ${_brl(op.totalPrecoVigente)}\nMotivo: $motivo',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text('Loja ${op.store} • ${TrocaApi.fmtIsoDate(op.createdAt)}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildDetailRow(String label, String value,
    {bool isHighlight = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value.isEmpty ? '-' : value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
            color: isHighlight
                ? const Color(0xFFD32F2F)
                : const Color(0xFF343A40),
          ),
        ),
      ),
    ],
  );
}
