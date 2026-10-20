import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/network/session_manager.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import '../models/avaliacao.dart';
import '../network/troca_api.dart';
import '../network/troca_session.dart';
import '../services/etiqueta_pdf.dart';

/// Lista de operações/trocas finalizadas (Troca Fácil).
class ListaOperacoesScreen extends StatefulWidget {
  const ListaOperacoesScreen({super.key});

  @override
  State<ListaOperacoesScreen> createState() => _ListaOperacoesScreenState();
}

class _ListaOperacoesScreenState extends State<ListaOperacoesScreen> {
  final TrocaApi _api = TrocaApi();
  List<Avaliacao> _lista = [];
  bool _loading = true;
  String? _erro;
  int _page = 1;
  int _totalPages = 1;

  Map<String, String?> _filtros = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _carregar({bool reset = true}) async {
    setState(() {
      _loading = true;
      _erro = null;
      if (reset) _page = 1;
    });
    final hoje = DateTime.now();
    final inicio = hoje.subtract(const Duration(days: 180));
    try {
      final page = await _api.getAvaliacoes(
        startDate: _filtros['startDate'] ?? _yyyyMMdd(inicio),
        finalDate: _filtros['finalDate'] ?? _yyyyMMdd(hoje),
        page: _page,
        sort: int.tryParse(_filtros['sort'] ?? '-1') ?? -1,
        status: _filtros['status'],
        operation: _filtros['operation'],
        cause: _filtros['cause'],
        transactionDate: _filtros['transactionDate'],
        costumerName: _filtros['costumerName'],
        tradeId: _filtros['tradeId'],
        tag: _filtros['tag'],
      );
      if (!mounted) return;
      setState(() {
        _lista = page.results;
        _totalPages = page.totalPages;
        _loading = false;
      });
    } on TrocaApiException catch (e) {
      if (e.statusCode == 401) {
        final troca = await TrocaSession.create();
        troca.clear();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erro = 'Erro ao carregar operações';
      });
    }
  }

  String? _toCompact(String? ddMMyyyy) {
    if (ddMMyyyy == null || ddMMyyyy.length != 10) return null;
    final p = ddMMyyyy.split('/');
    if (p.length != 3) return null;
    return '${p[2]}${p[1]}${p[0]}';
  }

  Future<void> _abrirFiltro() async {
    final r = await Navigator.of(context).pushNamed('/troca_operacoes_filtro');
    if (r is Map) {
      final num = (r['numero'] as String?)?.trim();
      final etiqueta = (r['etiqueta'] as String?)?.trim();
      final cliente = (r['cliente'] as String?)?.trim();
      final dataAv = _toCompact(r['dataAvaliacao'] as String?);
      final dataCompra = _toCompact(r['dataCompra'] as String?);
      final operacao = r['operacao'] as String?;
      final motivo = r['motivo'] as String?;
      setState(() {
        _filtros = {
          'tradeId': (num != null && num.isNotEmpty) ? num : null,
          'tag': (etiqueta != null && etiqueta.isNotEmpty) ? etiqueta : null,
          'operation': operacao == 'Troca'
              ? 'TROCA'
              : operacao == 'Devolução'
                  ? 'DEVOLUCAO'
                  : null,
          'cause': motivo == 'Insatisfação'
              ? 'INSATISFACAO'
              : motivo == 'Defeito'
                  ? 'DEFEITO'
                  : null,
          'costumerName':
              (cliente != null && cliente.isNotEmpty) ? cliente : null,
          'transactionDate': dataCompra,
          'startDate': dataAv,
          'finalDate': dataAv,
          'sort': (r['ordenarOrdem'] == 'Crescente') ? '1' : '-1',
        };
      });
      _carregar();
    }
  }

  Future<void> _abrirAcoes(Avaliacao op) async {
    // Busca o detalhe completo da operação (cliente/etiquetas) no BFF.
    Map<String, dynamic>? det;
    try {
      det = await _api.getOperacao(op.tradeId);
    } catch (_) {}
    if (!mounted) return;

    final costumer = (det?['costumer'] as Map?) ?? const {};
    String s(dynamic v) => (v ?? '').toString();
    final nome = s(costumer['costumerName']).isNotEmpty
        ? s(costumer['costumerName'])
        : op.costumerName;
    final doc = s(costumer['costumerDocument']);
    final cidade = s(costumer['city']);
    final uf = s(costumer['uf']);
    final motivo = s(det?['reason']).isNotEmpty
        ? s(det?['reason'])
        : _motivoLabel(op.cause);

    final etiquetas = <String>[];
    final prods = (det?['products'] as List?) ?? const [];
    for (final p in prods.whereType<Map>()) {
      final ln = p['labelNumber'];
      if (ln is List) etiquetas.addAll(ln.map((e) => e.toString()));
    }
    if (etiquetas.isEmpty) {
      etiquetas.addAll(op.products.expand((p) => p.tags));
    }
    final produtosTxt = prods
        .whereType<Map>()
        .map((p) => s(p['productDescription']))
        .where((e) => e.isNotEmpty)
        .join(' | ');

    final selecionadas = <String>{...etiquetas};

    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operação ${op.tradeId}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _linha('Cliente', nome),
                if (doc.isNotEmpty) _linha('Documento', doc),
                if (cidade.isNotEmpty || uf.isNotEmpty)
                  _linha('Cidade', '$cidade${uf.isNotEmpty ? ' - $uf' : ''}'),
                _linha('Motivo', motivo),
                if (produtosTxt.isNotEmpty)
                  _linha('Produtos', produtosTxt),
                if (etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('Selecione as etiquetas para reimprimir:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final e in etiquetas)
                    InkWell(
                      onTap: () => setSheetState(() {
                        if (selecionadas.contains(e)) {
                          selecionadas.remove(e);
                        } else {
                          selecionadas.add(e);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                                selecionadas.contains(e)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: const Color(0xFFD32F2F),
                                size: 20),
                            const SizedBox(width: 8),
                            Text(e,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _badge(
                            'REIMPRIMIR',
                            op.cancelada
                                ? null
                                : () => Navigator.pop(ctx, 'reimprimir'),
                            icon: Icons.print)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _badge(
                            'CANCELAR',
                            op.cancelada
                                ? null
                                : () => Navigator.pop(ctx, 'cancelar'),
                            icon: Icons.close)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (acao == 'reimprimir') {
      final etqs = selecionadas.toList();
      if (etqs.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: etqs.join(', ')));
      final prod =
          prods.isNotEmpty ? Map<String, dynamic>.from(prods.first as Map) : <String, dynamic>{};
      final operationType = s(det?['operationType']).toUpperCase();
      final systemSource = s(det?['systemSource']).toUpperCase();
      final modalidade = operationType == 'DEVOLUCAO'
          ? 'Devolução'
          : (systemSource == 'FISICO' ? 'Físico' : '');
      try {
        final uri = await TrocaEtiquetaPdf.salvarNoDownloads(
          labelNumbers: etqs,
          tradeId: op.tradeId,
          loja: s(det?['storeNumber']),
          data: TrocaApi.fmtIsoDate(s(det?['operationDate'])),
          produto: s(prod['productDescription']),
          motivo: motivo,
          modalidade: modalidade,
          cause: op.cause.isNotEmpty ? op.cause : s(det?['cause']),
        );
        if (!mounted) return;
        if (uri != null && uri.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${etqs.length} etiqueta(s) salva(s) em Download/Troca'),
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
    } else if (acao == 'cancelar') {
      await _cancelar(op);
    }
  }

  Future<void> _abrirPdf(String uri) async {
    try {
      const channel = MethodChannel('com.ir/media');
      await channel.invokeMethod('openUri', {
        'uri': uri,
        'mime': 'application/pdf',
      });
    } catch (_) {
      if (mounted) {
        ToastUtils.showError(context, 'Não foi possível abrir o PDF');
      }
    }
  }

  Widget _linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(valor,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _badge(String label, VoidCallback? onTap, {IconData? icon}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _cancelar(Avaliacao op) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cancelar operação'),
        content: Text('Deseja cancelar a operação ${op.tradeId}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final session = await SessionManager.create();
      final email = session.getUserEmail() ?? '';
      final deletedBy = email.contains('@') ? email.split('@').first : email;
      final produtos = op.products;
      if (produtos.isEmpty) {
        await _api.cancelOperation(
          tradeId: op.tradeId,
          avaliation: '',
          tags: const [],
          deletedBy: deletedBy,
        );
      } else {
        for (final p in produtos) {
          await _api.cancelOperation(
            tradeId: op.tradeId,
            avaliation: p.avaliationId ?? '',
            tags: p.tags,
            deletedBy: deletedBy,
          );
        }
      }
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Operação cancelada');
      _carregar();
    } on TrocaApiException catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao cancelar operação');
    }
  }

  String _operacaoLabel(String op) {
    switch (op) {
      case 'TROCA':
        return 'Troca';
      case 'DEVOLUCAO':
        return 'Devolução';
      default:
        return op;
    }
  }

  String _motivoLabel(String cause) {
    switch (cause) {
      case 'INSATISFACAO':
        return 'Insatisfação';
      case 'DEFEITO':
        return 'Defeito';
      default:
        return cause;
    }
  }

  String _brl(double v) {
    final s = v.toStringAsFixed(2);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Operações',
          style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            onPressed: _abrirFiltro,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _carregar(),
        child: _corpo(),
      ),
    );
  }

  Widget _corpo() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(_erro!,
                style: const TextStyle(color: Colors.black54, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: _carregar,
              child: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }
    if (_lista.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(
            child: Text('Nenhuma operação encontrada',
                style: TextStyle(color: Colors.black54, fontSize: 15)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _abrirAcoes(_lista[i]),
        child: OperacaoCard(
          operacao: _lista[i],
          operacaoLabel: _operacaoLabel(_lista[i].operation),
          motivoLabel: _motivoLabel(_lista[i].cause),
          valorLabel: _brl(_lista[i].totalValue),
        ),
      ),
    );
  }
}

class OperacaoCard extends StatelessWidget {
  final Avaliacao operacao;
  final String operacaoLabel;
  final String motivoLabel;
  final String valorLabel;

  const OperacaoCard({
    super.key,
    required this.operacao,
    required this.operacaoLabel,
    required this.motivoLabel,
    required this.valorLabel,
  });

  void _copiar(BuildContext context, String valor) {
    Clipboard.setData(ClipboardData(text: valor));
    ToastUtils.show(context, 'Copiado: $valor');
  }

  @override
  Widget build(BuildContext context) {
    final etiquetas = operacao.products.expand((p) => p.tags).toList();
    return Stack(
      children: [
        Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Número de operação',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => _copiar(context, operacao.tradeId),
                        child: Text(
                          operacao.tradeId,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _copiar(context, operacao.tradeId),
                      child: const Icon(Icons.copy_outlined,
                          size: 16, color: Colors.black54),
                    ),
                  ],
                ),
                if (etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Etiqueta',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: () =>
                              _copiar(context, etiquetas.join(', ')),
                          child: Text(
                            etiquetas.join(', '),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () =>
                            _copiar(context, etiquetas.join(', ')),
                        child: const Icon(Icons.copy_outlined,
                            size: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Text('Cliente',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  operacao.costumerName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Text('Loja solicitante',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  operacao.store,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text('Data solicitação',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  TrocaApi.fmtIsoDate(operacao.avaliationDate),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operação',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  operacaoLabel,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text('Valor Operação',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  valorLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text('Motivo',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  motivoLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text('Data da compra',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  TrocaApi.fmtCompactDate(operacao.transactionDate),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
        if (operacao.cancelada)
          Positioned(
            top: 12,
            right: 12,
            child: Icon(Icons.close,
                color: const Color(0xFFD32F2F), size: 20),
          ),
      ],
    );
  }
}
