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
import 'package:inventario/precificacao/screens/barcode/barcode_scanner_screen.dart';
import 'package:inventario/precificacao/widgets/avulsa_cards.dart';
import 'package:inventario/precificacao/widgets/compose_avulsa.dart';
import 'package:inventario/precificacao/widgets/action_swipe_card.dart';
import 'package:inventario/precificacao/services/lista_pdf_service.dart';

String _formatToday() {
  final d = DateTime.now();
  final y = d.year.toString();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class EtiquetasFragment extends StatefulWidget {
  const EtiquetasFragment({super.key});

  @override
  State<EtiquetasFragment> createState() => _EtiquetasFragmentState();
}

class _EtiquetasFragmentState extends State<EtiquetasFragment>
    with BuscarAnimMixin {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());

  late final String _storeId;
  late final String _today;

  List<PriceTag> _tags = [];

  bool _loading = false;

  final TextEditingController _eanController = TextEditingController();
  final FocusNode _eanFocus = FocusNode();
  String _buscaTipo = 'EAN';
  String _eanHint = 'Digite o EAN';
  TextInputType _eanKeyboardType = TextInputType.number;
  String _printer = 'Zebra 1';
  String _modo = 'Normal';
  bool _imprimindo = false;
  bool _limpando = false;
  bool _gerandoPdf = false;
  String? _deletingId;
  String _colagem = '';

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

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    _today = _formatToday();
    _loadSaved();
    _carregarColagem();
    _eanFocus.addListener(() {
      if (_eanFocus.hasFocus && _eanController.text.isNotEmpty) {
        _eanController.clear();
      }
    });
  }

  @override
  void dispose() {
    _eanFocus.dispose();
    _eanController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      _tags = List<PriceTag>.from(await ListaStore.instance.getEtiquetas());
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.saveEtiquetas(_tags);
  }

  void _deleteTag(PriceTag tag) {
    if (_deletingId != null) return;
    setState(() => _deletingId = tag.id);
    setState(() {
      _tags.removeWhere((e) => e.id == tag.id);
      _deletingId = null;
    });
    ListaStore.instance.removeEtiqueta(tag);
  }

  Future<void> _addByScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(continuo: true)),
    );
    await _loadSaved();
    await _carregarColagem();
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
      LogHelper.e('EtiquetasFragment: erro ao copiar para clipboard', e);
    }
  }

  Future<void> _usarColagem() async {
    final code = _colagem.trim();
    if (code.isEmpty) return;
    _eanController.text = code;
    await _fetchAndAdd(code);
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

  Future<void> _fetchAndAdd(String code) async {
    final c = code.trim();
    if (c.isEmpty) {
      ToastUtils.show(context, _baseHint);
      return;
    }
    startBuscarAnim();
    try {
      final resp = await api.getSingleLabelByEan(
        _storeId,
        ean: _buscaTipo == 'EAN' ? c : null,
        sapId: _buscaTipo == 'SAP' ? c : null,
        description: _buscaTipo == 'Descrição' ? c : null,
        startDate: _today,
      );
      if (!mounted) return;
      if (resp.items.isEmpty) {
        ToastUtils.showInfo(context, 'Nenhuma etiqueta encontrada');
        return;
      }
      int added = 0;
      int incremented = 0;
      for (final item in resp.items) {
        final idx = _tags.indexWhere((t) => t.ean == item.ean);
        if (idx >= 0) {
          _tags[idx].quantity += 1;
          incremented++;
        } else {
          _tags.add(singleToPriceTag(item));
          added++;
        }
      }
      setState(() {});
      await _persist();
      ToastUtils.showSuccess(
          context, _mensagemBusca(added, incremented));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao adicionar', e);
      ToastUtils.showError(context, 'Erro ao buscar etiqueta');
    } finally {
      stopBuscarAnim();
    }
  }

  String _mensagemBusca(int added, int incremented) {
    final parts = <String>[];
    if (added > 0) parts.add('$added adicionado(s)');
    if (incremented > 0) parts.add('$incremented incrementado(s)');
    return parts.join(' | ');
  }

  Future<void> _sendToPrinter() async {
    final selected = _tags.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos um item');
      return;
    }
    if (_modo == 'Edição') {
      await _abrirEdicao(selected);
      return;
    }
    final printingDataList = <PrintingData>[];
    for (final t in selected) {
      final pd = t.printingData;
      if (pd == null) continue;
      final template = pd.takeAndWin != null
          ? Constants.signTemplateModelo
          : Constants.templateNormalizado(pd.template);
      for (int i = 0; i < t.quantity; i++) {
        printingDataList
            .add(pd.copyWith(quantity: 1, template: template));
      }
    }
    if (printingDataList.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final printerId = _printer == 'Zebra 1'
        ? Constants.printerZebra1
        : Constants.printerZebra2;
    setState(() => _loading = true);
    try {
      await api.sendPriceTagsToPrinter(
        _storeId,
        printerId,
        Constants.tagGondola,
        SendPriceTagsRequest(products: printingDataList),
      );
      if (!mounted) return;
      setState(() {
        for (final t in selected) {
          _tags.removeWhere((e) => e.id == t.id);
        }
      });
      await _persist();
      ToastUtils.showSuccess(context, 'Enviado para impressão');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao enviar', e);
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _imprimirItem(PriceTag tag) async {
    // Imprime/remove apenas o item tocado (fiel ao Compose).
    final pd = tag.printingData;
    if (pd == null) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final template = pd.takeAndWin != null
        ? Constants.signTemplateModelo
        : Constants.templateNormalizado(pd.template);
    final printingDataList = <PrintingData>[];
    for (int i = 0; i < tag.quantity; i++) {
      printingDataList.add(pd.copyWith(quantity: 1, template: template));
    }
    final printerId = _printer == 'Zebra 1'
        ? Constants.printerZebra1
        : Constants.printerZebra2;
    setState(() => _loading = true);
    try {
      await api.sendPriceTagsToPrinter(
        _storeId,
        printerId,
        Constants.tagGondola,
        SendPriceTagsRequest(products: printingDataList),
      );
      if (!mounted) return;
      setState(() => _tags.removeWhere((e) => e.id == tag.id));
      await _persist();
      ToastUtils.showSuccess(context, 'Enviado para impressão');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao enviar item', e);
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirEdicao(List<PriceTag> selected) async {
    final lista = <PrintingData>[];
    for (final t in selected) {
      final pd = t.printingData;
      if (pd == null) continue;
      final template = pd.takeAndWin != null
          ? Constants.signTemplateModelo
          : Constants.templateNormalizado(pd.template);
      lista.add(pd.copyWith(quantity: 1, template: template));
    }
    if (lista.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final printerId = _printer == 'Zebra 1'
        ? Constants.printerZebra1
        : Constants.printerZebra2;
    await Navigator.pushNamed(context, '/gondola_editavel',
        arguments: {'items': lista, 'printerId': printerId});
  }

  Future<void> _imprimirTodas() async {
    if (_tags.isEmpty) {
      ToastUtils.show(context, 'Nenhuma etiqueta para imprimir');
      return;
    }
    setState(() => _imprimindo = true);
    for (final t in _tags) {
      t.checkbox = true;
    }
    setState(() {});
    await _sendToPrinter();
    setState(() => _imprimindo = false);
  }

  Future<void> _limparLista() async {
    if (_tags.isEmpty) {
      ToastUtils.show(context, 'Lista já está vazia');
      return;
    }
    setState(() => _limpando = true);
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
    setState(() => _limpando = false);
    if (ok == true) {
      setState(() => _tags.clear());
      await _persist();
      ToastUtils.show(context, 'Lista limpa');
    }
  }

  Future<void> _gerarPdfEtiquetas() async {
    if (_gerandoPdf || _tags.isEmpty) return;
    setState(() => _gerandoPdf = true);
    try {
      await ListaPdfService.compartilharRelatorioEtiquetas(_tags);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao gerar PDF', e);
      ToastUtils.showError(context, 'Erro ao gerar o PDF');
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
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
                    child: Row(
                      children: [
                        Expanded(
                          child: AvulsaSpinnerDropdown(
                            label: 'IMPRESSORA',
                            icon: Icons.print,
                            value: _printer,
                            options: const ['Zebra 1', 'Zebra 2'],
                            onChanged: (v) {
                              if (v != null) setState(() => _printer = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AvulsaSpinnerDropdown(
                            label: 'TIPO',
                            icon: Icons.qr_code,
                            value: _buscaTipo,
                            options: const ['EAN', 'SAP', 'Descrição'],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _buscaTipo = v;
                                _eanHint = _baseHint;
                                _eanKeyboardType = v == 'Descrição'
                                    ? TextInputType.text
                                    : TextInputType.number;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AvulsaSpinnerDropdown(
                            label: 'MODO',
                            icon: Icons.tune,
                            value: _modo,
                            options: const ['Normal', 'Edição'],
                            onChanged: (v) {
                              if (v != null) setState(() => _modo = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: AvulsaSearchField(
                      controller: _eanController,
                      focusNode: _eanFocus,
                      placeholder: _eanHint,
                      numerico: _buscaTipo == 'EAN' || _buscaTipo == 'SAP',
                      buscando: buscando,
                      onBuscar: () => _fetchAndAdd(_eanController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _limpando ? null : _limparLista,
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
                      onPressed: _imprimindo ? null : _imprimirTodas,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _imprimindo
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
                          _imprimindo ? 'IMPRIMINDO...' : 'IMPRIMIR TODAS',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tags.length == 1
                          ? '1 item na lista'
                          : '${_tags.length} itens na lista',
                      style: const TextStyle(
                          color: primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  IconButton(
                    onPressed: _gerarPdfEtiquetas,
                    tooltip: 'Gerar PDF da lista',
                    icon:
                        const Icon(Icons.picture_as_pdf, color: primaryRed),
                  ),
                ],
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
              if (_tags.isEmpty)
                _emptyState()
              else
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                  itemCount: _tags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final tag = _tags[i];
                    return SwipeToTrashItem(
                      key: ValueKey(tag.id),
                      onDismissed: () => _deleteTag(tag),
                      child: AvulsaEtiquetaCard(
                        tag: tag,
                        onImprimir: (q) {
                          tag.quantity = q;
                          _imprimirItem(tag);
                        },
                        onChangedQuantity: (q) {
                          tag.quantity = q;
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
