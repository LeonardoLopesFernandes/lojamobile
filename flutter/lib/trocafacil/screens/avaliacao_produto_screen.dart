import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/network/session_manager.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import '../models/cupom.dart';
import '../network/troca_api.dart';
import '../network/troca_session.dart';
import '../services/etiqueta_launcher.dart';
import '../services/etiqueta_pdf.dart';
import 'realizar_troca_itens_screen.dart' show ProdutoSelecionado;

/// Tela 2 — Avaliação do(s) produto(s) selecionado(s) (Sim/Não por questão).
class AvaliacaoProdutoScreen extends StatefulWidget {
  const AvaliacaoProdutoScreen({super.key});

  @override
  State<AvaliacaoProdutoScreen> createState() => _AvaliacaoProdutoScreenState();
}

class _AvaliacaoProdutoScreenState extends State<AvaliacaoProdutoScreen> {
  final TrocaApi _api = TrocaApi();

  late Cupom _cupom;
  List<ProdutoSelecionado> _selecionados = [];
  Map<String, dynamic> _cliente = {};
  String _cause = 'INSATISFACAO';
  String _reason = '';
  String _operationType = 'TROCA';
  bool _argsLidos = false;

  // Perguntas por produto (índice) e respostas por 'índice::id'.
  final List<List<Map<String, dynamic>>> _perguntas = [];
  final Map<String, bool> _respostas = {};
  bool _carregando = true;
  bool _enviando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLidos) return;
    _argsLidos = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _cupom = args['cupom'] as Cupom;
      _selecionados =
          (args['selecionados'] as List).cast<ProdutoSelecionado>();
      _cliente = Map<String, dynamic>.from(args['cliente'] ?? {});
      _cause = args['cause'] ?? 'INSATISFACAO';
      _reason = args['reason'] ?? '';
      _operationType = args['operationType'] ?? 'TROCA';
    }
    _carregarPerguntas();
  }

  Future<void> _carregarPerguntas() async {
    try {
      final todas = <List<Map<String, dynamic>>>[];
      for (final sel in _selecionados) {
        final p = sel.produto;
        final infos = '${p.departmentCode},${p.line};';
        final resp = await _api.getQuestions(cause: _cause, infosProduct: infos);
        final lista = <Map<String, dynamic>>[];
        for (final bloco in resp) {
          final qs = bloco['questionsProduct'];
          if (qs is List) {
            for (final q in qs.whereType<Map>()) {
              lista.add(Map<String, dynamic>.from(q));
            }
          }
        }
        lista.sort((a, b) => ((a['question_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['question_order'] as num?)?.toInt() ?? 0));
        todas.add(lista);
      }
      if (!mounted) return;
      setState(() {
        _perguntas
          ..clear()
          ..addAll(todas);
        _carregando = false;
      });
    } on TrocaApiException catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      if (e.statusCode == 401) {
        final t = await TrocaSession.create();
        t.clear();
        if (!mounted) return;
        ToastUtils.showError(context, 'Sessão expirada. Faça login novamente.');
      } else {
        ToastUtils.showError(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ToastUtils.showError(context, 'Erro ao carregar perguntas');
    }
  }

  String _id(Map<String, dynamic> q) =>
      (q['id_avaliation_questions'] ?? '').toString();
  String _desc(Map<String, dynamic> q) =>
      (q['description_question'] ?? '').toString();

  bool get _todasRespondidas =>
      _perguntas.isNotEmpty &&
      _perguntas.asMap().entries.every((e) =>
          e.value.every((q) => _respostas.containsKey('${e.key}::${_id(q)}')));

  String _brl(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final grouped = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $grouped,${parts[1]}';
  }

  Future<void> _continuar() async {
    if (!_todasRespondidas || _enviando) return;
    setState(() => _enviando = true);
    try {
      final session = await SessionManager.create();
      final email = session.getUserEmail() ?? '';
      final createdBy = email.contains('@') ? email.split('@').first : email;
      final hoje = DateTime.now();
      final operationDate = '${hoje.year.toString().padLeft(4, '0')}-'
          '${hoje.month.toString().padLeft(2, '0')}-'
          '${hoje.day.toString().padLeft(2, '0')}';

      final rua = (_cliente['rua'] ?? '').toString();
      final numero = (_cliente['numero'] ?? '').toString();
      final complemento = (_cliente['complemento'] ?? '').toString();
      final endereco = [rua, numero, complemento]
          .where((e) => e.trim().isNotEmpty)
          .join(', ');

      final produtosBody = <Map<String, dynamic>>[];
      for (var i = 0; i < _selecionados.length; i++) {
        final sel = _selecionados[i];
        final p = sel.produto;
        produtosBody.add({
          'EAN': p.ean,
          'SKU': p.sku,
          'productDescription':
              p.name.isNotEmpty ? p.name : p.description,
          'qtProduct': sel.quantidade,
          'nsu': p.nsu,
          'unitValue': p.unitValue,
          'imei': p.imeiCode,
          'avaliationResults': _perguntas[i]
              .map((q) => {
                    'id_avaliation_questions': _id(q),
                    'client_answer': _respostas['$i::${_id(q)}'] ?? false,
                  })
              .toList(),
          'excededTime': p.excededTime,
          'treatmentDesc': p.treatmentDescription,
          'treatmentCode': p.treatmentCode,
          'departamentCode': p.departmentCode,
          'catalog': p.catalog,
          'category': p.category,
          'currentPrice': p.currentPrice,
          'line': p.line,
        });
      }

      final body = {
        'products': produtosBody,
        'costumerData': {
          'costumerDocument': _cliente['cpfCnpj'] ?? '',
          'costumerName': _cliente['nome'] ?? '',
          'costumerPhone': _cliente['telefone'] ?? '',
          'neighborhood': _cliente['bairro'] ?? '',
          'uf': _cliente['uf'] ?? '',
          'address': endereco,
          'city': _cliente['cidade'] ?? '',
          'email': '',
        },
        'couponData': {
          'key_nfce': _cupom.keyNfce,
          'couponNumber': _cupom.couponNumber,
          'originStore': _cupom.couponStoreNumber,
          'originPDV': _cupom.couponPdvNumber,
          'transactionDate': _cupom.creationDate,
          'vl_total': _cupom.totalValue,
        },
        'createdBy': createdBy,
        'cause': _cause,
        'reason': _reason,
        'operationType': _operationType,
        'storeNumber': session.getUserStore(),
        'tipo': 'VENDA_FISICA',
        'tipoDoc': 'CUPOM_FISCAL',
        'systemSource': 'FISICO',
        'operationDate': operationDate,
      };

      final resultado = await _api.finishTrade(body);
      if (!mounted) return;
      _mostrarResultado(resultado, body, session);
    } on TrocaApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        final t = await TrocaSession.create();
        t.clear();
        ToastUtils.showError(context, 'Sessão expirada. Faça login novamente.');
      } else {
        ToastUtils.showError(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao finalizar troca');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarResultado(Map<String, dynamic> resultado,
      Map<String, dynamic> body, SessionManager session) {
    final status = (resultado['operationStatus'] ?? '').toString();
    final prods = resultado['products'];
    final autorizado = (prods is List && prods.isNotEmpty)
        ? (prods.first['tradeProductAuthorization'] ?? '').toString()
        : '';
    final aprovado = autorizado.toUpperCase() == 'APROVADO' ||
        status.toLowerCase() == 'aceita';
    final etiquetas = _extrairEtiquetas(resultado);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(aprovado ? 'Troca aprovada' : 'Troca recusada'),
        content: Text(aprovado
            ? 'A troca foi registrada. Deseja imprimir a etiqueta?'
            : 'Operação: $status${autorizado.isNotEmpty ? ' ($autorizado)' : ''}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Fechar'),
          ),
          if (aprovado)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _abrirEtiquetaFinalizada(
                  resultado: resultado,
                  body: body,
                  session: session,
                  etiquetas: etiquetas,
                );
              },
              child: const Text('Imprimir etiqueta'),
            ),
        ],
      ),
    );
  }

  List<String> _extrairEtiquetas(Map<String, dynamic> resultado) {
    final out = <String>{};
    void add(dynamic valor) {
      if (valor is List) {
        for (final e in valor) {
          add(e);
        }
      } else if (valor is Map) {
        for (final e in valor.values) {
          add(e);
        }
      } else if (valor != null) {
        final s = valor.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
    }

    add(resultado['etiqueta']);
    add(resultado['tag']);
    add(resultado['tags']);
    add(resultado['labelNumber']);
    final prods = resultado['products'];
    if (prods is List) {
      for (final p in prods.whereType<Map>()) {
        add(p['labelNumber']);
        add(p['tags']);
        add(p['etiqueta']);
        add(p['tag']);
      }
    }
    return out.toList();
  }

  String _tradeIdResultado(Map<String, dynamic> resultado) {
    for (final k in ['tradeId', 'trade_id', 'operationId', 'id', '_id']) {
      final v = (resultado[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Future<void> _abrirEtiquetaFinalizada({
    required Map<String, dynamic> resultado,
    required Map<String, dynamic> body,
    required SessionManager session,
    required List<String> etiquetas,
  }) async {
    var labels = etiquetas;
    final tradeId = _tradeIdResultado(resultado);
    if (labels.isEmpty && tradeId.isNotEmpty) {
      try {
        final detalhe = await _api.getOperacao(tradeId);
        labels = _extrairEtiquetas(detalhe);
      } catch (_) {}
    }
    if (labels.isEmpty) {
      // Fallback: mantém o comportamento antigo se a API não devolver a etiqueta.
      await abrirEtiquetaTroca();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    final produto = _selecionados
        .map((s) => s.produto.name.isNotEmpty
            ? s.produto.name
            : s.produto.description)
        .where((e) => e.trim().isNotEmpty)
        .join(' | ');
    final operationType =
        (body['operationType'] ?? 'TROCA').toString().toUpperCase();
    final modalidade = operationType == 'DEVOLUCAO' ? 'Devolução' : 'Físico';
    final loja = (body['storeNumber'] ?? session.getUserStore()).toString();
    final data = TrocaApi.fmtIsoDate((body['operationDate'] ?? '').toString());
    final cause = (body['cause'] ?? '').toString();
    final motivo = (body['reason'] ?? '').toString();

    try {
      final uri = await TrocaEtiquetaPdf.salvarNoDownloads(
        labelNumbers: labels,
        tradeId: tradeId.isNotEmpty ? tradeId : labels.first,
        loja: loja,
        data: data,
        produto: produto,
        motivo: motivo.isNotEmpty ? motivo : cause,
        modalidade: modalidade,
        cause: cause,
      );
      if (!mounted) return;
      if (uri != null && uri.isNotEmpty) {
        await const MethodChannel('com.ir/media')
            .invokeMethod('openUri', {'uri': uri, 'mime': 'application/pdf'});
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        ToastUtils.showError(context, 'Não foi possível gerar a etiqueta');
      }
    } catch (_) {
      if (mounted) {
        ToastUtils.showError(context, 'Erro ao gerar a etiqueta');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Detalhes do cupom',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Avalie o produto e responda as seguintes questões:',
                        style:
                            TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < _selecionados.length; i++) ...[
                        _cardProduto(_selecionados[i]),
                        const SizedBox(height: 16),
                        if (_perguntas.length > i && _perguntas[i].isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text('Nenhuma pergunta para este item',
                                style: TextStyle(color: Colors.black54)),
                          )
                        else if (_perguntas.length > i)
                          ..._perguntas[i].asMap().entries.map((e) =>
                              _pergunta(i, e.value)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: _enviando
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('‹ Voltar',
                      style: TextStyle(color: Colors.black87)),
                ),
                ElevatedButton(
                  onPressed: (_todasRespondidas && !_enviando)
                      ? _continuar
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Continuar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardProduto(ProdutoSelecionado sel) {
    final p = sel.produto;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD32F2F), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/drawables/logo_mloja.png',
                  width: 18, height: 18, color: const Color(0xFFD32F2F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name.isNotEmpty ? p.name : p.description,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _InfoCol('EAN', p.ean),
              _InfoCol('Valor', _brl(p.unitValue)),
              _InfoCol('Qtd cupom:', '${p.totalSaleQuantity}'),
              _InfoCol('Qtd disponível:', '${p.totalQuantityAvailable}'),
              _InfoCol('Qtd desejada:', '${sel.quantidade}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pergunta(int prod, Map<String, dynamic> q) {
    final id = _id(q);
    final resp = _respostas['$prod::$id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_desc(q),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Row(
            children: [
              _radio(prod, id, true, 'Sim', resp == true),
              const SizedBox(width: 32),
              _radio(prod, id, false, 'Não', resp == false),
            ],
          ),
          const Divider(color: Colors.grey, height: 1),
        ],
      ),
    );
  }

  Widget _radio(int prod, String id, bool valor, String label, bool selected) {
    return InkWell(
      onTap: () => setState(() => _respostas['$prod::$id'] = valor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(
            value: valor,
            groupValue: _respostas['$prod::$id'],
            activeColor: const Color(0xFFD32F2F),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => setState(() => _respostas['$prod::$id'] = v!),
          ),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _InfoCol extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCol(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ],
    );
  }
}
