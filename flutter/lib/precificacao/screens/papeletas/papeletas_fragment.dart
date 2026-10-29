import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario/precificacao/core/constants.dart';
import 'package:inventario/precificacao/core/session_manager.dart';
import 'package:inventario/precificacao/core/lista_store.dart';
import 'package:inventario/precificacao/models/models.dart';
import 'package:inventario/precificacao/network/api_client.dart';
import 'package:inventario/precificacao/network/api_service.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import 'package:inventario/precificacao/utils/log_helper.dart';
import 'package:inventario/precificacao/utils/session_expired_handler.dart';
import 'package:inventario/precificacao/utils/buscar_anim.dart';
import 'package:inventario/precificacao/utils/price_tag_mapper.dart';
import 'package:inventario/precificacao/widgets/avulsa_cards.dart';
import 'package:inventario/precificacao/widgets/compose_avulsa.dart';
import 'package:inventario/precificacao/widgets/action_swipe_card.dart';

enum _AcaoSucesso { nenhuma, limpar }

class PapeletasFragment extends StatefulWidget {
  const PapeletasFragment({super.key});

  @override
  State<PapeletasFragment> createState() => _PapeletasFragmentState();
}

class _PapeletasFragmentState extends State<PapeletasFragment>
    with BuscarAnimMixin {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager _session = SessionManager.instance!;

  late String _store;
  late String _startDate;

  bool _loading = false;
  bool _isGerando = false;
  List<PriceSign> _items = [];
  String? _deletingId;

  String _tipo = 'Promocional'; // Normal / Promocional
  // Misto / Promocional / Promocional Editável / Normal / Normal Editável /
  // Vencimentos (fiel ao Compose).
  String _modelo = 'Misto';
  String _buscaTipo = 'EAN'; // EAN / SAP / Descrição do item
  String _size = '4×1'; // 1×1 / 2×1 / 4×1 / 6×1

  final TextEditingController _eanController = TextEditingController();
  String _eanHint = 'Digite o EAN';
  TextInputType _eanKeyboardType = TextInputType.number;
  String _colagem = '';

  @override
  void initState() {
    super.initState();
    _store = _session.getUserStore();
    _startDate = _today();
    _loadSaved();
    _carregarColagem();
  }

  @override
  void dispose() {
    _eanController.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool get _buscaNumerica => _buscaTipo == 'EAN' || _buscaTipo == 'SAP';

  String get _baseHint {
    switch (_buscaTipo) {
      case 'EAN':
        return 'Digite o EAN';
      case 'SAP':
        return 'Digite o SAP';
      default:
        return 'Buscar Por Descrição';
    }
  }

  // ---- Modos (fiel ao Compose) ----
  bool get _usarMisto => _modelo == 'Misto';
  bool get _usarModeloEditavel =>
      _modelo == 'Promocional' || _modelo == 'Promocional Editável';
  bool get _usarComumEditavel => _modelo == 'Normal Editável';
  bool get _usarVencimentos => _modelo == 'Vencimentos';
  bool get _usarEletro => _modelo == 'Eletro da semana';
  bool get _isModoEditavel =>
      _modelo == 'Promocional Editável' ||
      _modelo == 'Normal Editável' ||
      _usarEletro;
  // Modelos que abrem preview; "Normal" envia direto pela API.
  bool get _abrePreview =>
      _usarMisto ||
      _usarModeloEditavel ||
      _usarComumEditavel ||
      _usarVencimentos ||
      _usarEletro;
  bool get _tipoNormal => _tipo == 'Normal';
  String get _tipoPapeleta {
    if (_modelo == 'Promocional Editável') return 'Promocional';
    if (_modelo == 'Normal Editável') return 'Normal';
    return _tipoNormal ? 'Normal' : 'Promocional';
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      _items = List<PriceSign>.from(await ListaStore.instance.getPapeletas());
    } catch (e) {
      LogHelper.e('Erro ao carregar papeletas', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.savePapeletas(_items);
  }

  void _delete(PriceSign item) {
    if (_deletingId != null) return;
    setState(() => _deletingId = item.id);
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
      _deletingId = null;
    });
    ListaStore.instance.removePapeleta(item);
  }

  static String _templatePorMovimento(String? movement) {
    final m = (movement ?? '').toLowerCase();
    if (m == 'de/por') return Constants.signTemplateDepor;
    if (m == 'parcelado') return Constants.signTemplateDeporParcelado;
    return Constants.signTemplateModeloEditavel;
  }

  PapeletaPrintingData _ajustarDadosLeveGanhe(PapeletaPrintingData d) =>
      ajustarDadosLeveGanhe(d);

  bool _isItemComum(PriceSign item) {
    final d = item.printingData;
    if (d == null) return true;
    if (d.template == 'por_de_parcelado' ||
        d.template == Constants.signTemplateDeporParcelado) {
      return true;
    }
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasPromo || hasTW) return false;
    return true;
  }

  bool _isComumElegivel(PriceSign item) {
    final d = item.printingData;
    if (d == null) return true;
    final hasInst =
        d.installmentQuantity != null && d.installmentQuantity! > 0;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasInst && !hasPromo && !hasTW) return (d.price) > 149.99;
    return true;
  }

  PapeletaPrintingData _eletroData(PapeletaPrintingData d) {
    final qtd = (d.installmentQuantity ?? 0) > 0
        ? d.installmentQuantity!
        : 10;
    return d.copyWith(
      template: Constants.signTemplateEletroSemana,
      quantity: 1,
      size: _size,
      installmentQuantity: qtd,
      installmentPrice: d.installmentPrice ?? 0.0,
    );
  }

  Future<void> _addStandalone() async {
    final c = _eanController.text.trim();
    if (c.isEmpty) {
      ToastUtils.show(context, _baseHint);
      return;
    }
    startBuscarAnim();
    try {
      final descricao = !_buscaNumerica ? c : null;
      final results = await Future.wait([
        _api.getPriceSignStandalone(_store, Constants.tipoComum,
            ean: _buscaTipo == 'EAN' ? c : null,
            sapId: _buscaTipo == 'SAP' ? c : null,
            description: descricao,
            startDate: _startDate),
        _api.getPriceSignStandalone(_store, Constants.tipoPromocional,
            ean: _buscaTipo == 'EAN' ? c : null,
            sapId: _buscaTipo == 'SAP' ? c : null,
            description: descricao,
            startDate: _startDate),
      ]);
      int added = 0;
      int incremented = 0;
      for (final r in results) {
        for (final it in r.items) {
          final idx = _items.indexWhere((e) => e.id == it.id);
          if (idx >= 0) {
            _items[idx].quantity += 1;
            incremented++;
          } else {
            _items.add(it);
            added++;
          }
        }
      }
      setState(() {});
      if (!mounted) return;
      if (added == 0 && incremented == 0) {
        ToastUtils.showInfo(context, 'Nenhum item encontrado');
      } else {
        final parts = <String>[];
        if (added > 0) parts.add('$added adicionado(s)');
        if (incremented > 0) parts.add('$incremented incrementado(s)');
        ToastUtils.showSuccess(context, parts.join(' | '));
      }
      await _persist();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('Erro ao buscar papeleta', e);
      ToastUtils.showError(context, 'Erro ao buscar papeleta');
    } finally {
      stopBuscarAnim();
    }
  }

  Future<void> _addByScan() async {
    final r = await Navigator.pushNamed(context, '/barcode');
    if (r is String && r.isNotEmpty) {
      _eanController.text = r;
      await _salvarColagem(r);
      await _addStandalone();
    }
  }

  Future<void> _carregarColagem() async {
    final code = await ListaStore.instance.getColagem();
    if (!mounted) return;
    setState(() => _colagem = code);
  }

  Future<void> _salvarColagem(String code) async {
    setState(() => _colagem = code);
    await ListaStore.instance.setColagem(code);
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (e) {
      LogHelper.e('PapeletasFragment: erro ao copiar para clipboard', e);
    }
  }

  Future<void> _usarColagem() async {
    final code = _colagem.trim();
    if (code.isEmpty) return;
    _eanController.text = code;
    await _addStandalone();
  }

  Widget _buildColagem() {
    if (_colagem.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: _usarColagem,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Área de colagem: $_colagem',
                      style: const TextStyle(
                        color: Color(0xFFB71C1C),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await ListaStore.instance.setColagem('');
                      setState(() => _colagem = '');
                    },
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFFB71C1C)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Impressão (fiel ao Compose) ----
  Future<void> _imprimirItem(PriceSign item, int qty) async {
    final signData = item.printingData;
    if (signData == null) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final tamanho = _size;

    if (_usarEletro) {
      final qtdEletro = qty < 1 ? 1 : qty;
      await _abrirModelo(
        List.generate(qtdEletro, (_) => _eletroData(signData)),
        semOverlay: false,
        apiSemOverlay: false,
        modoEditavel: true,
        modoVencimentos: false,
        hideGerarPreview: false,
        mostrarCheckboxOverlay: false,
        removerEan: item.ean,
      );
      return;
    }

    if (_abrePreview) {
      if (_usarMisto) {
        final lista = List.generate(
            qty,
            (_) => _ajustarDadosLeveGanhe(signData.copyWith(
                  template: signData.template ??
                      _templatePorMovimento(item.movement),
                  quantity: 1,
                  size: tamanho,
                )));
        await _abrirModelo(lista,
            semOverlay: false,
            apiSemOverlay: true,
            modoEditavel: false,
            modoVencimentos: false,
            hideGerarPreview: false,
            mostrarCheckboxOverlay: true);
        return;
      }
      if (_usarModeloEditavel && _isItemComum(item)) {
        ToastUtils.show(
            context, 'Esta papeleta é do tipo Comum, selecione o modo Comum');
        return;
      }
      if (_usarComumEditavel && !_isItemComum(item)) {
        ToastUtils.show(context,
            'Esta papeleta é do tipo Promocional, selecione o modo Promocional');
        return;
      }
      final lista = List.generate(
          qty,
          (_) => _ajustarDadosLeveGanhe(signData.copyWith(
                template:
                    signData.template ?? _templatePorMovimento(item.movement),
                quantity: 1,
                size: tamanho,
              )));
      await _abrirModelo(lista,
          semOverlay: _usarComumEditavel,
          apiSemOverlay:
              (_usarMisto || _usarModeloEditavel || _usarVencimentos),
          modoEditavel: _isModoEditavel,
          modoVencimentos: _usarVencimentos,
          hideGerarPreview: !_isModoEditavel,
          mostrarCheckboxOverlay: !_usarComumEditavel,
          removerEan: item.ean);
      return;
    }

    // Sem modelo -> envia direto pela API.
    final lista = List.generate(
        qty, (_) => signData.copyWith(quantity: 1, size: tamanho));
    await _send(lista);
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _persist();
  }

  Future<void> _imprimirTodas() async {
    if (_isGerando) return;
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Nenhuma papeleta para imprimir');
      return;
    }
    if (_usarEletro) {
      final lista = <PapeletaPrintingData>[];
      for (final item in _items) {
        final d = item.printingData;
        if (d == null) continue;
        final qtd = item.quantity < 1 ? 1 : item.quantity;
        for (var i = 0; i < qtd; i++) {
          lista.add(_eletroData(d));
        }
      }
      if (lista.isEmpty) {
        ToastUtils.show(context, 'Dados de impressão não disponíveis');
        return;
      }
      await _abrirModelo(
        lista,
        semOverlay: false,
        apiSemOverlay: false,
        modoEditavel: true,
        modoVencimentos: false,
        hideGerarPreview: false,
        mostrarCheckboxOverlay: false,
        acao: _AcaoSucesso.limpar,
      );
      return;
    }
    setState(() => _isGerando = true);
    try {
      final tamanho = _size;

      if (_abrePreview) {
        if (_usarMisto) {
          final lista = <PapeletaPrintingData>[];
          for (final item in _items) {
            final d = item.printingData;
            if (d == null) continue;
            for (int i = 0; i < item.quantity; i++) {
              lista.add(_ajustarDadosLeveGanhe(d.copyWith(
                template:
                    d.template ?? _templatePorMovimento(item.movement),
                quantity: 1,
                size: tamanho,
              )));
            }
          }
          if (lista.isEmpty) {
            ToastUtils.show(context, 'Nenhum item para imprimir');
            return;
          }
          await _abrirModelo(lista,
              semOverlay: false,
              apiSemOverlay: true,
              modoEditavel: false,
              modoVencimentos: false,
              hideGerarPreview: false,
              mostrarCheckboxOverlay: true);
          return;
        }

        if (_isModoEditavel) {
          final lista = <PapeletaPrintingData>[];
          for (final item in _items) {
            final ehComum = _isItemComum(item);
            if (_tipoPapeleta == 'Normal' && !ehComum) continue;
            if (_tipoPapeleta == 'Promocional' && ehComum) continue;
            final passa = _usarComumEditavel ? ehComum : !ehComum;
            if (!passa) continue;
            if (ehComum && !_isComumElegivel(item)) continue;
            final d = item.printingData;
            if (d == null) continue;
            for (int i = 0; i < item.quantity; i++) {
              lista.add(_ajustarDadosLeveGanhe(d.copyWith(
                template:
                    d.template ?? _templatePorMovimento(item.movement),
                quantity: 1,
                size: tamanho,
              )));
            }
          }
          if (lista.isEmpty) {
            ToastUtils.show(context,
                _usarComumEditavel ? 'Nenhum item do tipo Comum' : 'Nenhum item na lista');
            return;
          }
          await _abrirModelo(lista,
              semOverlay: _usarComumEditavel,
              apiSemOverlay: true,
              modoEditavel: true,
              modoVencimentos: false,
              hideGerarPreview: false,
              mostrarCheckboxOverlay: !_usarComumEditavel,
              acao: _AcaoSucesso.limpar);
          return;
        }

        // Promocional / Vencimentos.
        final lista = <PapeletaPrintingData>[];
        final qtds = <int>[];
        for (final item in _items) {
          final ehComum = _isItemComum(item);
          if (!_usarVencimentos) {
            if (_tipoPapeleta == 'Normal' && !ehComum) continue;
            if (_tipoPapeleta == 'Promocional' && ehComum) continue;
            if (ehComum && !_isComumElegivel(item)) continue;
          }
          final d = item.printingData;
          if (d == null) continue;
          final base = _ajustarDadosLeveGanhe(d.copyWith(
            template: d.template ?? _templatePorMovimento(item.movement),
            quantity: 1,
            size: tamanho,
          ));
          for (int i = 0; i < item.quantity; i++) {
            lista.add(base);
            if (_usarVencimentos) qtds.add(1);
          }
        }
        if (lista.isEmpty) {
          ToastUtils.show(context, 'Nenhum item na lista');
          return;
        }
        await _abrirModelo(lista,
            semOverlay: _usarComumEditavel,
            apiSemOverlay:
                (_usarMisto || _usarModeloEditavel || _usarVencimentos),
            modoEditavel: _usarVencimentos,
            modoVencimentos: _usarVencimentos,
            hideGerarPreview: _usarModeloEditavel,
            mostrarCheckboxOverlay: true,
            quantidadesCsv: _usarVencimentos ? qtds.join(',') : null,
            acao: _AcaoSucesso.limpar);
        return;
      }

      // Sem modelo -> envia direto pela API.
      final lista = <PapeletaPrintingData>[];
      for (final item in _items) {
        final d = item.printingData;
        if (d == null) continue;
        final ehComum = _isItemComum(item);
        if (_tipoPapeleta == 'Normal' &&
            (!ehComum || !_isComumElegivel(item))) {
          continue;
        }
        if (_tipoPapeleta == 'Promocional' && ehComum) continue;
        for (int i = 0; i < item.quantity; i++) {
          lista.add(d.copyWith(quantity: 1, size: tamanho));
        }
      }
      if (lista.isEmpty) {
        ToastUtils.show(
            context,
            _tipoPapeleta == 'Normal'
                ? 'Nenhum item do tipo Comum'
                : 'Nenhum item do tipo Promocional');
        return;
      }
      await _send(lista);
      if (!mounted) return;
      setState(() => _items.clear());
      await _persist();
    } finally {
      if (mounted) setState(() => _isGerando = false);
    }
  }

  Future<void> _send(List<PapeletaPrintingData> lista) async {
    setState(() => _loading = true);
    try {
      await _api.sendPriceSigns(
          _store, SendPriceSignRequest(products: lista));
      if (!mounted) return;
      ToastUtils.showSuccess(
          context, '${lista.length} papeletas enviadas!');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('Erro ao enviar papeletas', e);
      ToastUtils.showError(context, 'Erro ao enviar papeletas');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirModelo(
    List<PapeletaPrintingData> lista, {
    required bool semOverlay,
    required bool apiSemOverlay,
    required bool modoEditavel,
    required bool modoVencimentos,
    required bool hideGerarPreview,
    required bool mostrarCheckboxOverlay,
    String? quantidadesCsv,
    String? removerEan,
    _AcaoSucesso acao = _AcaoSucesso.nenhuma,
  }) async {
    if (lista.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final result = await Navigator.pushNamed(context, '/modelo_editavel',
        arguments: {
          'items': lista,
          'size': _size,
          'mostrarCheckboxOverlay': mostrarCheckboxOverlay,
          'modoEditavel': modoEditavel,
          'modoVencimentos': modoVencimentos,
          'semOverlay': semOverlay,
          'apiSemOverlay': apiSemOverlay,
          'hideGerarPreview': hideGerarPreview,
          'quantidadesCsv': quantidadesCsv,
          'title': modoVencimentos ? 'PAPELETA DE VENCIMENTOS' : null,
        });
    if (!mounted) return;
    if (result == true) {
      setState(() {
        if (acao == _AcaoSucesso.limpar) {
          _items.clear();
        } else if (removerEan != null) {
          _items.removeWhere((e) => e.ean == removerEan);
        }
      });
      await _persist();
    }
  }

  Future<void> _limparLista() async {
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Lista já está vazia');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Limpar Lista'),
        content: const Text('Tem certeza que deseja remover todos os itens?'),
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
    if (ok == true) {
      setState(() => _items.clear());
      await _persist();
      ToastUtils.show(context, 'Lista limpa');
    }
  }

  Widget _buildFilterBar() {
    const primaryRed = Color(0xFFD32F2F);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AvulsaSpinnerDropdown(
                                label: 'TIPO',
                                icon: Icons.receipt_long,
                                value: _tipo,
                                options: const ['Normal', 'Promocional'],
                                onChanged: (v) {
                                  if (v != null) setState(() => _tipo = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AvulsaSpinnerDropdown(
                                label: 'MODELO',
                                icon: Icons.tune,
                                value: _modelo,
                                options: const [
                                  'Misto',
                                  'Promocional',
                                  'Promocional Editável',
                                  'Normal',
                                  'Normal Editável',
                                  'Vencimentos',
                                  'Eletro da semana',
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _modelo = v;
                                    if (v == 'Promocional Editável') {
                                      _tipo = 'Promocional';
                                    }
                                    if (v == 'Normal Editável') {
                                      _tipo = 'Normal';
                                    }
                                    if (v == 'Eletro da semana' &&
                                        _size != '1×1' &&
                                        _size != '2×1' &&
                                        _size != '4×1') {
                                      _size = '4×1';
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AvulsaSpinnerDropdown(
                                label: 'BUSCA',
                                icon: Icons.qr_code,
                                value: _buscaTipo,
                                options: const ['EAN', 'SAP', 'Descrição do item'],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _buscaTipo = v;
                                    _eanHint = _baseHint;
                                    _eanKeyboardType = _buscaNumerica
                                        ? TextInputType.number
                                        : TextInputType.text;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AvulsaSpinnerDropdown(
                                label: 'TAMANHO',
                                icon: Icons.aspect_ratio,
                                value: _size,
                                options: _usarEletro
                                    ? const ['1×1', '2×1', '4×1']
                                    : const ['1×1', '2×1', '4×1', '6×1'],
                                onChanged: (v) {
                                  if (v != null) setState(() => _size = v);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: AvulsaSearchField(
                      controller: _eanController,
                      placeholder: _eanHint,
                      numerico: _buscaNumerica,
                      buscando: buscando,
                      onBuscar: _addStandalone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _limparLista,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryRed,
                        side: const BorderSide(color: primaryRed),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.cleaning_services_outlined,
                          size: 18),
                      label: const Text('LIMPAR LISTA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGerando ? null : _imprimirTodas,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isGerando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)),
                            )
                          : const Icon(Icons.print, size: 18),
                      label: Text(
                          _isGerando ? 'IMPRIMINDO...' : 'IMPRIMIR TODAS',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                _items.length == 1
                    ? '1 item na lista'
                    : '${_items.length} itens na lista',
                style: const TextStyle(
                    color: primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text(
        '0 item(a) na lista\n\nEscaneie ou digite\npara adicionar à lista',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF999999), fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        _buildColagem(),
        Expanded(
          child: Stack(
            children: [
              if (_items.isEmpty)
                _emptyState()
              else
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return SwipeToTrashItem(
                      key: Key('papeleta_${item.id}'),
                      onDismissed: () => _delete(item),
                      child: AvulsaPapeletaCard(
                        item: item,
                        onImprimir: (q) => _imprimirItem(item, q),
                        onChangedQuantity: (q) {
                          item.quantity = q;
                          _persist();
                        },
                      ),
                    );
                  },
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: AvulsaFabScanner(onAbrir: _addByScan),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
