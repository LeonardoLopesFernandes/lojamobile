import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/inventario.dart';
import '../models/quebra.dart';
import '../network/inventario_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/date_format.dart';
import '../recebimento/utils/excel_downloader.dart';
import '../widgets/dialog_adicionar_quebra.dart';
import '../widgets/dialog_abrir_quebra.dart';
import 'scanner_ean_screen.dart';

class QuebraDetalheScreen extends StatefulWidget {
  final String breakageId;
  final bool somenteLeituraInicial;

  const QuebraDetalheScreen(
      {super.key, required this.breakageId, this.somenteLeituraInicial = false});

  @override
  State<QuebraDetalheScreen> createState() => _QuebraDetalheScreenState();
}

class _QuebraDetalheScreenState extends State<QuebraDetalheScreen> {
  final TextEditingController _buscaController = TextEditingController();
  SessionManager? _session;
  InventarioService? _service;
  List<BreakageReason> _reasons = const [];
  List<BreakageItem> _itens = [];
  Breakage? _breakage;
  final Set<String> _selecionados = {};
  bool _buscando = false;
  bool _porSap = false;
  bool _somenteLeitura = false;
  bool _carregando = true;
  bool _painelExpandido = false;

  @override
  void initState() {
    super.initState();
    _somenteLeitura = widget.somenteLeituraInicial;
    _init();
  }

  String _status = 'PENDING';

  int get _totalQtd => _itens.fold(0, (soma, e) => soma + e.quantity);

  double get _totalValor =>
      _itens.fold(0.0, (soma, e) => soma + e.costPrice * e.quantity);

  String _brl(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _init() async {
    final session = await SessionManager.create();
    final service = InventarioService.forSession(session);
    List<BreakageItem> itens = [];
    List<BreakageReason> reasons = const [];
    Breakage? breakage;
    bool somenteLeitura = false;
    String status = 'PENDING';
    try {
      final d = await service.getBreakageDetail(widget.breakageId);
      itens = d.items;
      reasons = d.reasons;
      breakage = d.breakage;
      status = d.breakage.status.toUpperCase();
      somenteLeitura = d.breakage.isReadOnly;
      if (reasons.isEmpty) {
        try {
          reasons = await service.getBreakageReasons();
        } catch (_) {}
      }
    } catch (_) {
      try {
        reasons = await service.getBreakageReasons();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _service = service;
      _itens = itens;
      _reasons = reasons;
      _breakage = breakage;
      _status = status;
      _somenteLeitura = somenteLeitura;
      _carregando = false;
    });
  }

  String get _storeId => _session?.getUserStore() ?? Constants.defaultStore;

  Future<void> _buscar() async {
    final valor = _buscaController.text.trim();
    if (valor.isEmpty) return;
    setState(() => _buscando = true);
    Product produto;
    try {
      produto = await _service!.getProductStore(
        storeId: _storeId,
        ean: _porSap ? null : valor,
        sapCode: _porSap ? valor : null,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Item não encontrado'), backgroundColor: Colors.red));
      return;
    }
    if (!mounted) return;
    setState(() => _buscando = false);
    final res = await mostrarDialogAdicionarQuebra(context,
        produto: produto, motivos: _reasons);
    if (res == null) return;
    try {
      await _service!.addBreakageItem(
        widget.breakageId,
        ean: produto.ean,
        sapCode: produto.sapCode,
        description: produto.description,
        stock: produto.stock.toInt(),
        quantity: res.quantidade,
        reasonId: res.motivo.id,
      );
      await _recarregarItens();
      if (!mounted) return;
      _buscaController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Item adicionado à quebra'),
          backgroundColor: Color(Constants.badgeGreen)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao adicionar item'),
          backgroundColor: Colors.red));
    }
  }

  /// Recarrega o detalhe para trazer o motivo (label) de cada item, usado
  /// para resolver o reasonId no "Abrir quebra".
  Future<void> _recarregarItens() async {
    try {
      final d = await _service!.getBreakageDetail(widget.breakageId);
      var reasons = d.reasons;
      if (reasons.isEmpty) {
        try {
          reasons = await _service!.getBreakageReasons();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _itens = d.items;
        _breakage = d.breakage;
        _status = d.breakage.status.toUpperCase();
        if (reasons.isNotEmpty) _reasons = reasons;
      });
    } catch (_) {}
  }

  Future<void> _escanear() async {
    final ean = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerEANScreen()),
    );
    if (ean != null && ean.isNotEmpty) {
      _buscaController.text = ean;
      _buscar();
    }
  }

  Future<void> _editarItem(BreakageItem it) async {
    final produto = Product(
      sapCode: it.sapCode,
      ean: it.ean,
      description: it.description,
      quantity: 0,
      stock: it.stock.toDouble(),
    );
    final res = await mostrarDialogAdicionarQuebra(
      context,
      produto: produto,
      motivos: _reasons,
      quantidadeInicial: it.quantity,
      motivoInicial: it.reason,
    );
    if (res == null) return;
    try {
      // O PUT /web/breakage/{id} substitui a lista inteira; vai com todos os
      // itens e com o reasonId resolvido para não perder os motivos.
      final porLabel = <String, String>{
        for (final r in _reasons)
          if (r.label.trim().isNotEmpty) r.label.trim().toLowerCase(): r.id,
      };
      final atualizados = _itens.map((e) {
        final novo = e.id == it.id
            ? e.copyWith(
                quantity: res.quantidade,
                reason: res.motivo.label,
                reasonId: res.motivo.id,
              )
            : e;
        if (novo.reasonId.isNotEmpty) return novo;
        final id = porLabel[novo.reason.trim().toLowerCase()];
        return id == null ? novo : novo.withReasonId(id);
      }).toList();
      await _service!.updateBreakageItems(widget.breakageId, atualizados);
      await _recarregarItens();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao alterar item'), backgroundColor: Colors.red));
    }
  }

  Future<void> _removerSelecionados() async {
    if (_selecionados.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remover itens'),
        content: Text('Remover ${_selecionados.length} item(ns) selecionado(s)?'),
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
      for (final id in _selecionados.toList()) {
        await _service!.removeBreakageItem(widget.breakageId, id);
      }
      _selecionados.clear();
      final d = await _service!.getBreakageDetail(widget.breakageId);
      if (!mounted) return;
      setState(() => _itens = d.items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao remover itens'), backgroundColor: Colors.red));
    }
  }

  Future<void> _processarQuebra() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Finalizar quebra'),
        content: const Text(
            'Deseja finalizar (processar) a quebra? Após isso não será possível alterar os itens.'),
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
      await _service!.processBreakage(widget.breakageId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quebra finalizada com sucesso'),
          backgroundColor: Color(Constants.badgeGreen)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao finalizar quebra'),
          backgroundColor: Colors.red));
    }
  }

  /// Resolve o reasonId de cada item pelo label do motivo (a API de detalhe
  /// só devolve o label).
  List<BreakageItem> _comMotivos(List<BreakageItem> items) {
    final porLabel = <String, String>{
      for (final r in _reasons)
        if (r.label.trim().isNotEmpty) r.label.trim().toLowerCase(): r.id,
    };
    return items.map((e) {
      if (e.reasonId.isNotEmpty) return e;
      final id = porLabel[e.reason.trim().toLowerCase()];
      return id == null ? e : e.withReasonId(id);
    }).toList();
  }

  List<BreakageItem> _itensComMotivo() => _comMotivos(_itens);

  /// Persiste a alteração de um item (quantidade/motivo) na quebra aberta.
  Future<void> _salvarItem(BreakageItem novo) async {
    final anterior = _itens;
    final lista =
        _itens.map((e) => e.id == novo.id ? novo : e).toList(growable: false);
    setState(() => _itens = lista);
    try {
      await _service!
          .updateBreakageItems(widget.breakageId, _comMotivos(lista));
    } catch (_) {
      if (!mounted) return;
      setState(() => _itens = anterior);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao salvar item'), backgroundColor: Colors.red));
    }
  }

  Future<void> _alterarMotivosSelecionados() async {
    if (_selecionados.isEmpty) return;
    final motivo = await showDialog<BreakageReason>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Alterar motivo'),
        children: _reasons
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(r.label),
                  ),
                ))
            .toList(),
      ),
    );
    if (motivo == null) return;
    final lista = _itens
        .map((e) => _selecionados.contains(e.id)
            ? e.copyWith(reason: motivo.label, reasonId: motivo.id)
            : e)
        .toList(growable: false);
    try {
      await _service!
          .updateBreakageItems(widget.breakageId, _comMotivos(lista));
      if (!mounted) return;
      setState(() => _itens = lista);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Motivos alterados'),
          backgroundColor: Color(Constants.badgeGreen)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao alterar motivos'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _abrirQuebra() async {
    // A BFF aceita reasonId vazio (o próprio site manda "" quando não há
    // motivo local). Mandamos o id resolvido quando possível, sem bloquear.
    final itens = _itensComMotivo();
    final ok = await mostrarDialogoAbrirQuebra(context);
    if (ok != true) return;
    try {
      await _service!.openBreakage(widget.breakageId, itens);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quebra aberta com sucesso'),
          backgroundColor: Color(Constants.badgeGreen)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao abrir quebra'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aberta = _status == 'OPEN';
    return Scaffold(
      backgroundColor:
          aberta ? const Color(0xFFF1F5F9) : const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: aberta ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
            color:
                aberta ? Colors.white : const Color(Constants.invTextDark)),
        title: Text(
            aberta
                ? 'Quebra aberta'
                : (_somenteLeitura ? 'Quebra' : 'Cadastrar quebra'),
            style: TextStyle(
                color: aberta
                    ? Colors.white
                    : const Color(Constants.invTextDark),
                fontSize: 18,
                fontWeight: FontWeight.w500)),
        actions: [
          if (aberta)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C0519).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF881337)),
                  ),
                  child: Text(_brl(_totalValor),
                      style: const TextStyle(
                          color: Color(0xFFFDA4AF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          if (_somenteLeitura)
            IconButton(
              onPressed: _baixarExcel,
              tooltip: 'Gerar Excel',
              icon: SvgPicture.asset('assets/drawables/ic_excel.svg',
                  width: 24, height: 24),
            ),
        ],
      ),
      bottomNavigationBar: aberta ? _barraAberta() : null,
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : aberta
              ? Column(
                  children: [
                    _resumoQuebra(mostrarValor: false),
                    const SizedBox(height: 8),
                    Expanded(child: _corpoAberta()),
                  ],
                )
              : Column(
                  children: [
                    _resumoQuebra(),
                    if (_somenteLeitura) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _avisoConsulta(),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Container(color: Colors.white, child: _seletorEanSap()),
                      const SizedBox(height: 16),
                      _campoBusca(),
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                      child: Row(
                        children: [
                          Text('Itens (${_itens.length})',
                              style: const TextStyle(
                                  color: Color(Constants.invTextDark),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                    Expanded(child: _corpo()),
                    if (!_somenteLeitura) _painelInferior(),
                  ],
                ),
    );
  }

  Future<void> _baixarExcel() async {
    final service = _service;
    if (service == null) return;
    try {
      final bytes = await service.baixarRelatorioQuebra(widget.breakageId);
      final nome = 'quebra_${widget.breakageId}.xlsx';
      final caminho = await ExcelDownloader.salvarArquivoEmDownloads(
        nome: nome,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Excel salvo: $caminho'),
          backgroundColor: const Color(Constants.badgeGreen)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao gerar o Excel'), backgroundColor: Colors.red));
    }
  }

  Widget _seletorEanSap() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          _radio('Incluir por EAN', !_porSap, () => setState(() => _porSap = false)),
          const SizedBox(width: 32),
          _radio('Incluir por SAP', _porSap, () => setState(() => _porSap = true)),
        ],
      ),
    );
  }

  Widget _radio(String label, bool selecionado, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selecionado
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selecionado
                ? const Color(Constants.primaryRed)
                : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: selecionado ? FontWeight.w500 : FontWeight.normal,
                  color: selecionado
                      ? const Color(Constants.invTextDark)
                      : Colors.grey)),
        ],
      ),
    );
  }

  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _buscaController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: _porSap ? 'Digite o SAP' : 'Digite o EAN',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _escanear,
            child: Container(
              height: 50,
              width: 50,
              decoration: const BoxDecoration(
                color: Color(Constants.primaryRed),
                shape: BoxShape.circle,
              ),
              child: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoConsulta() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB26A00), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Quebra processada. Os dados estão disponíveis apenas para consulta.',
              style: TextStyle(color: Color(0xFF7A5200), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpoAberta() {
    if (_itens.isEmpty) {
      return const Center(
        child: Text('Nenhum item na quebra',
            style: TextStyle(fontSize: 15, color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _itens.length,
      itemBuilder: (_, i) {
        final it = _itens[i];
        return _ItemAbertoCard(
          key: ValueKey(it.id),
          item: it,
          reasons: _reasons,
          selected: _selecionados.contains(it.id),
          onSelected: (v) => setState(() {
            if (v) {
              _selecionados.add(it.id);
            } else {
              _selecionados.remove(it.id);
            }
          }),
          onQuantity: (q) => _salvarItem(it.copyWith(quantity: q)),
          onReason: (r) =>
              _salvarItem(it.copyWith(reason: r.label, reasonId: r.id)),
        );
      },
    );
  }

  Widget _barraAberta() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _selecionados.isEmpty ? null : _removerSelecionados,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('EXCLUIR ITENS',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton(
                onPressed: _selecionados.isEmpty
                    ? null
                    : _alterarMotivosSelecionados,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('ALTERAR MOTIVOS',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton(
                onPressed: _itens.isEmpty ? null : _processarQuebra,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('PROCESSAR',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoQuebra({bool mostrarValor = true}) {
    final b = _breakage;
    final nome = (b != null && b.user.isNotEmpty)
        ? b.user
        : (_session?.getUserName() ?? '');
    final loja = (b != null && b.store.isNotEmpty)
        ? b.store
        : (_session?.getUserStore() ?? '');
    final data = b != null ? formatDataBr(b.date) : '';
    final subtitulo = [
      data,
      loja,
      if (_itens.isNotEmpty) '$_totalQtd un.',
    ].where((e) => e.trim().isNotEmpty).join('  •  ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFFEF2F2),
            child: Icon(Icons.person,
                color: Color(Constants.primaryRed), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome.isEmpty ? 'Usuário' : nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ],
            ),
          ),
          if (mostrarValor) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('VALOR TOTAL',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(_brl(_totalValor),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF78350F))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _corpo() {
    if (_itens.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFBDBDBD),
            child: Icon(Icons.sentiment_satisfied, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('Adicione itens para iniciar a quebra',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(Constants.invTextSecondary))),
          const SizedBox(height: 8),
          const Text('Utilize o EAN para adicionar itens e quantidades.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final it = _itens[i];
        final motivo = it.reason;
        final lower = motivo.toLowerCase();
        final isAvaria = lower.contains('avaria');
        final isValidade =
            lower.contains('validade') || lower.contains('vencimento');
        final badgeBg = isAvaria
            ? const Color(0xFFFEF2F2)
            : isValidade
                ? const Color(0xFFF3E8FF)
                : const Color(0xFFFFFBEB);
        final badgeColor = isAvaria
            ? const Color(0xFFB91C1C)
            : isValidade
                ? const Color(0xFF7E22CE)
                : const Color(0xFFB45309);
        final badgeBorder = isAvaria
            ? const Color(0xFFFECACA)
            : isValidade
                ? const Color(0xFFE9D5FF)
                : const Color(0xFFFDE68A);
        final badgeIcon = isAvaria
            ? Icons.warning_amber_rounded
            : isValidade
                ? Icons.calendar_today_rounded
                : Icons.info_outline;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _somenteLeitura ? null : () => _editarItem(it),
          onLongPress: _somenteLeitura ? null : () => _menuItem(it),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_somenteLeitura)
                  Checkbox(
                    value: _selecionados.contains(it.id),
                    activeColor: const Color(Constants.primaryRed),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selecionados.add(it.id);
                      } else {
                        _selecionados.remove(it.id);
                      }
                    }),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.description,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                              height: 1.3)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _codigoChip('EAN: ${it.ean}'),
                          _codigoChip('SAP: ${it.sapCode}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saldo ${it.stock}  •  Valor ${_brl(it.costPrice)}  •  Total ${_brl(it.costPrice * it.quantity)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                      if (motivo.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: badgeBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 12, color: badgeColor),
                              const SizedBox(width: 4),
                              Text('Motivo: $motivo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: badgeColor)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  constraints: const BoxConstraints(minWidth: 64),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('QUEBRA',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text('${it.quantity}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF78350F))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _codigoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _painelInferior() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _painelExpandido = !_painelExpandido),
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -100) {
                setState(() => _painelExpandido = true);
              } else if (v > 100) {
                setState(() => _painelExpandido = false);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _painelExpandido
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(Constants.primaryRed),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: _itens.isEmpty
                                ? null
                                : (_status == 'OPEN'
                                    ? _processarQuebra
                                    : _abrirQuebra),
                            child: Text(
                                _status == 'OPEN'
                                    ? 'Finalizar quebra'
                                    : 'Abrir quebra',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color(Constants.primaryRed),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: _selecionados.isEmpty
                                ? null
                                : _removerSelecionados,
                            child: const Text('Remover itens selecionados',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color(Constants.primaryRed),
                              side: const BorderSide(
                                  color: Color(Constants.primaryRed)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: _descartarQuebra,
                            child: const Text('Descartar quebra',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Future<void> _menuItem(BreakageItem it) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir item'),
              onTap: () => Navigator.pop(ctx, 'excluir'),
            ),
          ],
        ),
      ),
    );
    if (acao == 'excluir') await _removerItem(it);
  }

  Future<void> _removerItem(BreakageItem it) async {
    try {
      final lista = await _service!.removeBreakageItem(widget.breakageId, it.id);
      if (!mounted) return;
      setState(() {
        _selecionados.remove(it.id);
        _itens = lista ?? _itens.where((e) => e.id != it.id).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao excluir item'), backgroundColor: Colors.red));
    }
  }

  Future<void> _descartarQuebra() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Descartar quebra'),
        content: const Text(
            'A quebra será removida por completo, com todos os itens. Deseja continuar?'),
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
      await _service!.deleteBreakage(widget.breakageId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao descartar quebra'),
          backgroundColor: Colors.red));
    }
  }
}

/// Card de item na tela "Quebra aberta" (mesmo layout do site): permite
/// alterar a quantidade e o motivo, e mostra saldo, consolidada e valor.
class _ItemAbertoCard extends StatefulWidget {
  final BreakageItem item;
  final List<BreakageReason> reasons;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onQuantity;
  final ValueChanged<BreakageReason> onReason;

  const _ItemAbertoCard({
    super.key,
    required this.item,
    required this.reasons,
    required this.selected,
    required this.onSelected,
    required this.onQuantity,
    required this.onReason,
  });

  @override
  State<_ItemAbertoCard> createState() => _ItemAbertoCardState();
}

class _ItemAbertoCardState extends State<_ItemAbertoCard> {
  late final TextEditingController _qtd;

  @override
  void initState() {
    super.initState();
    _qtd = TextEditingController(text: '${widget.item.quantity}');
  }

  @override
  void didUpdateWidget(covariant _ItemAbertoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.quantity != oldWidget.item.quantity &&
        _qtd.text != '${widget.item.quantity}') {
      _qtd.text = '${widget.item.quantity}';
    }
  }

  @override
  void dispose() {
    _qtd.dispose();
    super.dispose();
  }

  void _commitQuantidade() {
    var valor = int.tryParse(_qtd.text.trim());
    if (valor == null || valor < 1) {
      _qtd.text = '${widget.item.quantity}';
      return;
    }
    final maximo = widget.item.stock > 0 ? widget.item.stock : valor;
    if (valor > maximo) valor = maximo;
    _qtd.text = '$valor';
    if (valor != widget.item.quantity) widget.onQuantity(valor);
  }

  String? get _reasonIdSelecionado {
    for (final r in widget.reasons) {
      if (r.id == widget.item.reasonId) return r.id;
    }
    final label = widget.item.reason.trim().toLowerCase();
    for (final r in widget.reasons) {
      if (r.label.trim().toLowerCase() == label) return r.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final totalItem = item.quantity * item.costPrice;
    final consolidada = (item.stock - item.quantity).clamp(0, item.stock);
    final reasonId = _reasonIdSelecionado;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: Checkbox(
                    value: widget.selected,
                    onChanged: (v) => widget.onSelected(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: const Color(0xFFE11D48),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _tag('SAP: ${item.sapCode}'),
                          _tag('EAN: ${item.ean}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _info('Saldo Físico', '${item.stock}'),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      children: [
                        const Text('Qtd. Quebra',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFE11D48),
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 45,
                          height: 26,
                          child: TextField(
                            controller: _qtd,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBE123C)),
                            onSubmitted: (_) => _commitQuantidade(),
                            onTapOutside: (_) {
                              FocusScope.of(context).unfocus();
                              _commitQuantidade();
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFFDA4AF))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFFDA4AF))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _info('Consolidada', '$consolidada'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: reasonId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black87),
                    items: widget.reasons
                        .map((r) => DropdownMenuItem<String>(
                              value: r.id,
                              child: Text(r.label,
                                  style: const TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      for (final r in widget.reasons) {
                        if (r.id == id) {
                          widget.onReason(r);
                          break;
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL ITEM',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE11D48))),
                      Text('R\$ ${totalItem.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFBE123C))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }

  Widget _info(String label, String valor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(valor,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
