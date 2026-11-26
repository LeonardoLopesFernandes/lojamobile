import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/network/session_manager.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';

import '../models/avaliacao.dart';
import '../network/troca_api.dart';
import '../services/etiqueta_pdf.dart';

const _vermelho = Color(0xFFE60023);
const _fundo = Color(0xFFF8F8F8);
const _texto = Color(0xFF424957);

class _ProdutoOperacao {
  final String descricao;
  final String ean;
  final double valorUnitario;
  final int quantidade;
  final List<String> etiquetas;

  const _ProdutoOperacao({
    required this.descricao,
    required this.ean,
    required this.valorUnitario,
    required this.quantidade,
    required this.etiquetas,
  });
}

class OperacaoTrocaScreen extends StatefulWidget {
  final Avaliacao operacao;
  final Map<String, dynamic>? detalhe;
  final TrocaApi api;
  final bool finalizada;
  final int initialStep;

  const OperacaoTrocaScreen({
    super.key,
    required this.operacao,
    required this.api,
    this.detalhe,
    this.finalizada = false,
    this.initialStep = 0,
  });

  @override
  State<OperacaoTrocaScreen> createState() => _OperacaoTrocaScreenState();
}

class _OperacaoTrocaScreenState extends State<OperacaoTrocaScreen> {
  late final List<_ProdutoOperacao> _produtos;
  late final Set<String> _selecionadas;
  int _step = 0;
  bool _abrindo = false;

  Avaliacao get _op => widget.operacao;
  Map<String, dynamic>? get _det => widget.detalhe;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 2);
    _produtos = _montarProdutos();
    _selecionadas = {
      ..._produtos.expand((p) => p.etiquetas),
    };
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
  }

  int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  String _data(String iso) {
    if (iso.isEmpty) return '—';
    return TrocaApi.fmtIsoDate(iso);
  }

  String _brl(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final grouped = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $grouped,${parts[1]}';
  }

  String get _tituloOperacao =>
      _op.operation.toUpperCase().contains('DEVOLUCAO') ? 'Devolução' : 'Troca';

  String get _modalidade => '$_tituloOperacao física';

  String get _loja =>
      _op.store.isNotEmpty ? _op.store : _s(_det?['storeNumber']);

  String get _motivoTipo {
    final c = _op.cause.toUpperCase();
    if (c.contains('DEFEITO')) return 'Defeito';
    if (c.contains('INSAT')) return 'Insatisfação';
    return _op.cause.isNotEmpty ? _op.cause : '—';
  }

  String get _motivoDescricao {
    final r = _s(_det?['reason']);
    return r.isNotEmpty ? r : _motivoTipo;
  }

  String get _dataSolicitacao => _data(_op.avaliationDate);

  String get _dataCompra => _data(_op.transactionDate);

  String get _dataRecebimento {
    final d = _s(_det?['operationDate']);
    return _data(d.isNotEmpty ? d : _op.avaliationDate);
  }

  bool get _cancelada => _op.cancelada;

  List<_ProdutoOperacao> _montarProdutos() {
    final detProds = ((_det?['products'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final out = <_ProdutoOperacao>[];

    if (_op.products.isNotEmpty) {
      for (var i = 0; i < _op.products.length; i++) {
        final ap = _op.products[i];
        final dp =
            i < detProds.length ? detProds[i] : const <String, dynamic>{};
        final rawLabels = dp['labelNumber'];
        final labels = rawLabels is List
            ? rawLabels
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
        final tags =
            ap.tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final descricaoDet = _s(dp['productDescription']);
        out.add(_ProdutoOperacao(
          descricao: descricaoDet.isNotEmpty ? descricaoDet : ap.productName,
          ean: ap.ean.isNotEmpty ? ap.ean : _s(dp['productEan']),
          valorUnitario: ap.unitValue > 0 ? ap.unitValue : _d(dp['unitValue']),
          quantidade: ap.quantity > 0 ? ap.quantity : _i(dp['quantity']),
          etiquetas: labels.isNotEmpty ? labels : tags,
        ));
      }
    } else {
      for (final dp in detProds) {
        final rawLabels = dp['labelNumber'];
        final labels = rawLabels is List
            ? rawLabels
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
        out.add(_ProdutoOperacao(
          descricao: _s(dp['productDescription']),
          ean: _s(dp['productEan']),
          valorUnitario: _d(dp['unitValue']),
          quantidade: _i(dp['quantity']),
          etiquetas: labels,
        ));
      }
    }
    return out;
  }

  void _voltar() {
    if (widget.finalizada) {
      Navigator.of(context).pop();
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  String get _titulo {
    switch (_step) {
      case 1:
        return 'Itens aprovados';
      case 2:
        return 'Cupom';
      default:
        return 'Operação';
    }
  }

  Future<void> _abrirEtiquetaNativa({List<String>? labels}) async {
    if (_abrindo) return;
    if (_cancelada) {
      ToastUtils.showError(context, 'Operação cancelada');
      return;
    }
    final selecionadas = labels ?? _selecionadas.toList();
    if (selecionadas.isEmpty) {
      ToastUtils.show(context, 'Selecione uma etiqueta');
      return;
    }
    if (_produtos.isEmpty) {
      ToastUtils.showError(context, 'Nenhum item encontrado');
      return;
    }
    final produto = _produtos.firstWhere(
      (p) => p.etiquetas.any(selecionadas.contains),
      orElse: () => _produtos.first,
    );
    setState(() => _abrindo = true);
    try {
      final uri = await TrocaEtiquetaPdf.salvarNoDownloads(
        labelNumbers: selecionadas,
        tradeId: _op.tradeId,
        loja: _loja,
        data: _dataRecebimento,
        produto: produto.descricao,
        motivo: _motivoDescricao,
        modalidade: _modalidade,
        cause: _op.cause.isNotEmpty ? _op.cause : _s(_det?['cause']),
      );
      if (!mounted) return;
      if (uri == null || uri.isEmpty) {
        ToastUtils.showError(context, 'Não foi possível salvar a etiqueta');
        return;
      }
      await const MethodChannel('com.ir/media').invokeMethod('openUri', {
        'uri': uri,
        'mime': 'application/pdf',
      });
    } catch (_) {
      if (mounted) {
        ToastUtils.showError(context, 'Erro ao abrir a etiqueta');
      }
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  Future<void> _cancelarOperacao() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cancelar operação'),
        content: Text('Deseja cancelar a operação ${_op.tradeId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final session = await SessionManager.create();
      final email = session.getUserEmail() ?? '';
      final deletedBy = email.contains('@') ? email.split('@').first : email;
      if (_op.products.isEmpty) {
        await widget.api.cancelOperation(
          tradeId: _op.tradeId,
          avaliation: '',
          tags: const [],
          deletedBy: deletedBy,
        );
      } else {
        for (final p in _op.products) {
          await widget.api.cancelOperation(
            tradeId: _op.tradeId,
            avaliation: p.avaliationId ?? '',
            tags: p.tags,
            deletedBy: deletedBy,
          );
        }
      }
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Operação cancelada');
      Navigator.of(context).pop();
    } on TrocaApiException catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao cancelar operação');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _texto),
          onPressed: _voltar,
        ),
        title: Text(
          _titulo,
          style: const TextStyle(
            fontSize: 20,
            color: _texto,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (!_cancelada || _selecionadas.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _texto),
              onSelected: (v) {
                if (v == 'cancelar') {
                  _cancelarOperacao();
                } else if (v == 'etiqueta') {
                  _abrirEtiquetaNativa();
                }
              },
              itemBuilder: (_) => [
                if (!widget.finalizada && !_cancelada)
                  const PopupMenuItem(
                    value: 'cancelar',
                    child: Text('Cancelar operação'),
                  ),
                if (_selecionadas.isNotEmpty)
                  const PopupMenuItem(
                    value: 'etiqueta',
                    child: Text('Abrir etiqueta'),
                  ),
              ],
            ),
        ],
      ),
      body: _step == 0
          ? _telaOperacao()
          : _step == 1
              ? _telaItens()
              : _telaCupom(),
    );
  }

  Widget _telaOperacao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('operação', style: TextStyle(color: _texto, fontSize: 14)),
          const SizedBox(height: 5),
          Text(
            _tituloOperacao,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: _texto,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _info('Cliente', _op.costumerName),
                    const SizedBox(height: 30),
                    _info('Loja solicitante', _loja),
                    const SizedBox(height: 30),
                    _info('Data solicitação', _dataSolicitacao),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _info('Valor da operação', _brl(_op.totalValue)),
                    const SizedBox(height: 30),
                    _info('Motivo', _motivoTipo),
                    const SizedBox(height: 30),
                    _info('Data da compra', _dataCompra),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 55),
          const Text(
            'Para imprimir o cupom de troca, acesse o item e escolha as etiquetas desejadas.',
            style: TextStyle(fontSize: 16, height: 1.5, color: _texto),
          ),
          const SizedBox(height: 25),
          ..._produtos.map(_cardItem),
          const SizedBox(height: 5),
          _botao(
            'Acessar itens',
            _produtos.isEmpty ? null : () => setState(() => _step = 1),
          ),
        ],
      ),
    );
  }

  Widget _telaItens() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final produto in _produtos) ...[
                const Text(
                  'Item',
                  style: TextStyle(
                    color: _texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  produto.descricao,
                  style: const TextStyle(fontSize: 16, color: _texto),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: _info('Quantidade', '${produto.quantidade}'),
                    ),
                    Expanded(
                      child: _info(
                        'Valor unitário',
                        _brl(produto.valorUnitario),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const Divider(),
                if (produto.etiquetas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma etiqueta encontrada',
                      style: TextStyle(color: _texto),
                    ),
                  )
                else
                  for (final etiqueta in produto.etiquetas)
                    _linhaEtiqueta(etiqueta),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
        _botao(
          'Continuar',
          _selecionadas.isEmpty ? null : () => setState(() => _step = 2),
        ),
      ],
    );
  }

  Widget _telaCupom() {
    final labels = _selecionadas.toList();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              for (final label in labels)
                _cupomCard(
                  label,
                  _produtos.firstWhere(
                    (p) => p.etiquetas.contains(label),
                    orElse: () => _produtos.isEmpty
                        ? const _ProdutoOperacao(
                            descricao: '—',
                            ean: '',
                            valorUnitario: 0,
                            quantidade: 0,
                            etiquetas: [],
                          )
                        : _produtos.first,
                  ),
                ),
            ],
          ),
        ),
        _botao(
          'Abrir etiqueta',
          _abrindo ? null : () => _abrirEtiquetaNativa(),
          icon: Icons.open_in_new,
        ),
      ],
    );
  }

  Widget _info(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _texto,
          ),
        ),
        const SizedBox(height: 7),
        Text(valor, style: const TextStyle(fontSize: 17, color: _texto)),
      ],
    );
  }

  Widget _cardItem(_ProdutoOperacao produto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Item',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: _cancelada
                      ? const Color(0xFFFFE5E5)
                      : const Color(0xFFDDF2ED),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _cancelada ? 'Cancelado' : 'Aprovado',
                  style: TextStyle(
                    color: _cancelada
                        ? const Color(0xFFC93636)
                        : const Color(0xFF278B76),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            produto.descricao,
            style: const TextStyle(fontSize: 18, color: _texto),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _info('EAN', produto.ean.isEmpty ? '—' : produto.ean),
                    const SizedBox(height: 16),
                    _info('Quantidade', '${produto.quantidade}'),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: _info('Valor unitário', _brl(produto.valorUnitario)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linhaEtiqueta(String etiqueta) {
    final selecionada = _selecionadas.contains(etiqueta);
    return InkWell(
      onTap: () => _abrirEtiquetaNativa(labels: [etiqueta]),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: selecionada,
              activeColor: _vermelho,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selecionadas.add(etiqueta);
                  } else {
                    _selecionadas.remove(etiqueta);
                  }
                });
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Etiqueta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    etiqueta,
                    style: const TextStyle(fontSize: 16, color: _texto),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Abrir etiqueta',
              icon: const Icon(Icons.open_in_new, size: 20, color: _texto),
              onPressed: () => _abrirEtiquetaNativa(labels: [etiqueta]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cupomCard(String label, _ProdutoOperacao produto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: CustomPaint(
        foregroundPainter: const _DashedBorderPainter(),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comprovante de troca',
                style: TextStyle(fontSize: 19, color: _texto),
              ),
              const SizedBox(height: 15),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: _vermelho,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  _modalidade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                produto.descricao,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.5,
                  color: _texto,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 35),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _info('Etiqueta', label)),
                  Expanded(
                      child: _info('Descrição do motivo', _motivoDescricao)),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _info('Loja de recebimento', _loja)),
                  Expanded(
                      child: _info('Data de recebimento', _dataRecebimento)),
                ],
              ),
              const SizedBox(height: 55),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _info('Valor da troca', _brl(_op.totalValue)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Nº da operação',
                          style: TextStyle(color: _texto),
                        ),
                        const SizedBox(height: 8),
                        const _BarcodeVisual(),
                        const SizedBox(height: 5),
                        Text(
                          _op.tradeId,
                          style: const TextStyle(
                            color: _texto,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  Widget _botao(String label, VoidCallback? onPressed, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _abrindo ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _vermelho,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(35),
            ),
            elevation: 0,
          ),
          child: _abrindo
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BarcodeVisual extends StatelessWidget {
  const _BarcodeVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 65,
      width: double.infinity,
      child: CustomPaint(painter: _BarcodePainter()),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _texto;
    const barras = [
      2,
      1,
      3,
      1,
      1,
      2,
      4,
      1,
      2,
      1,
      3,
      2,
      1,
      1,
      4,
      2,
      1,
      3,
      1,
      2,
      2,
      1,
      4,
      1,
      3,
      1,
      2,
      2,
      1,
      3,
      1,
      2,
      4,
      1,
      2,
      1,
      3,
      1,
      2,
      3,
    ];
    double x = 0;
    for (final largura in barras) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, largura.toDouble(), size.height),
        paint,
      );
      x += largura + 2;
      if (x > size.width) break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const radius = 25.0;
    const dash = 6.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = const Color(0xFFB9B1B1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
