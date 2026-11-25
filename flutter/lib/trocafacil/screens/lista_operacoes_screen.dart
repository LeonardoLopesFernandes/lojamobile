import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import '../models/avaliacao.dart';
import '../network/troca_api.dart';
import '../network/troca_session.dart';
import 'operacao_troca_screen.dart';

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
    Map<String, dynamic>? det;
    try {
      det = await _api.getOperacao(op.tradeId);
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperacaoTrocaScreen(
          operacao: op,
          detalhe: det,
          api: _api,
        ),
      ),
    );
    if (!mounted) return;
    _carregar();
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
