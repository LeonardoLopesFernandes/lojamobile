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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bloqueio ${op.id}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Loja ${op.store} • ${TrocaApi.fmtIsoDate(op.createdAt)}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              for (final it in op.itemsBlocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.description,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        'Etiqueta: ${it.tags.join(', ')} • Motivo: ${it.reasonBlocking} • ${it.quantity}x',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _reimprimir(op);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('REIMPRIMIR',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reimprimir(BloqueioOperacao op) async {
    if (op.itemsBlocked.isEmpty) return;
    final it = op.itemsBlocked.first;
    try {
      final uri = await BloqueioEtiquetaPdf.salvarNoDownloads(
        numeroOperacao: op.id,
        loja: op.store,
        dataBloqueio: TrocaApi.fmtIsoDate(op.createdAt),
        numeroEtiqueta: it.tags.isNotEmpty ? it.tags.first : '',
        motivo: it.reasonBlocking,
        descricao: it.description,
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
