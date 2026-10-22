import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/inventario.dart';
import '../network/inventario_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import 'scanner_ean_screen.dart';

class CriarInventarioScreen extends StatefulWidget {
  final String? inventoryId;
  final String titulo;

  const CriarInventarioScreen(
      {super.key, this.inventoryId, this.titulo = 'Criar inventário'});

  @override
  State<CriarInventarioScreen> createState() => _CriarInventarioScreenState();
}

class _CriarInventarioScreenState extends State<CriarInventarioScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String _buscaTipo = 'EAN';
  SessionManager? _session;
  InventarioService? _service;

  InventoryDetail? _draft;
  bool _carregando = true;
  bool _adicionando = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await SessionManager.create();
    if (!mounted) return;
    setState(() {
      _session = session;
      _service = InventarioService.forSession(session);
    });
    _carregar();
  }

  String get _storeId => _session?.getUserStore() ?? Constants.defaultStore;

  Future<void> _carregar() async {
    final id = widget.inventoryId;
    if (id == null) {
      setState(() => _carregando = false);
      return;
    }
    try {
      final d = await _service!.getCycleCount(id);
      if (!mounted) return;
      setState(() {
        _draft = d;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  Future<void> _buscar() async {
    final valor = _buscaController.text.trim();
    if (valor.isEmpty) return;
    final id = widget.inventoryId;
    if (id == null) return;
    setState(() => _adicionando = true);
    Product p;
    try {
      final buscandoSap = _buscaTipo == 'SAP';
      p = await _service!.getProduct(
        storeId: _storeId,
        ean: buscandoSap ? null : valor,
        sapCode: buscandoSap ? valor : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _adicionando = false);
      if (e is DepartmentBlockedException) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Departamento bloqueado para inventário'),
            content: Text(
                'Este item pertence ao ${e.departmentName} e não pode ser adicionado ao inventário. Informe outro EAN.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Item não encontrado'),
            backgroundColor: Colors.red));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _adicionando = false);
    final qtd = await _mostrarDialogAdicionar(p);
    if (qtd == null) return;
    try {
      await _service!.addItem(
        id,
        ean: p.ean,
        sapCode: p.sapCode,
        description: p.description,
        expectedQuantity: p.quantity.toInt(),
        countedQuantity: qtd,
      );
      _buscaController.clear();
      await _carregar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao adicionar item'),
          backgroundColor: Colors.red));
    }
  }

  int _qtdAtualDoItem(String ean) {
    for (final i in _draft?.items ?? const <InventoryItem>[]) {
      if (i.ean == ean) return i.countedQuantity;
    }
    return 0;
  }

  Future<int?> _mostrarDialogAdicionar(Product p) {
    final controller =
        TextEditingController(text: _qtdAtualDoItem(p.ean).toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Adicionar itens ao inventário rotativo',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(Constants.invTextDark)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.description,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(Constants.invTextDark))),
                        const SizedBox(height: 4),
                        Text('EAN: ${p.ean}',
                            style: const TextStyle(
                                color: Color(Constants.invTextSecondary),
                                fontSize: 14)),
                        Text('SAP: ${p.sapCode}',
                            style: const TextStyle(
                                color: Color(Constants.invTextSecondary),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quantidade atual',
                            style: TextStyle(
                                color: Color(Constants.invTextSecondary),
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('${p.stock.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: p.stock < 0
                                    ? Colors.red
                                    : const Color(Constants.invTextDark))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Indique abaixo a nova quantidade.',
                  style: TextStyle(
                      color: Color(Constants.invTextDark), fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nova quantidade',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
              child: const Text('Adicionar')),
        ],
      ),
    );
  }

  Future<void> _escanear() async {
    final ean = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerEANScreen()),
    );
    if (ean != null && ean.isNotEmpty) {
      setState(() => _buscaTipo = 'EAN');
      _buscaController.text = ean;
      _buscar();
    }
  }

  Future<void> _editarItem(InventoryItem item) async {
    final controller =
        TextEditingController(text: item.countedQuantity.toString());
    final qtd = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Quantidade contada'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(controller.text.trim())),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (qtd == null) return;
    try {
      await _service!
          .updateItem(widget.inventoryId!, item.id, quantity: qtd);
      await _carregar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao atualizar item'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _removerItem(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Excluir item'),
        content: Text('Remover "${item.description}"?'),
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
      await _service!.removeItems(widget.inventoryId!, [item.id]);
      await _carregar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao excluir item'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _processar() async {
    final id = widget.inventoryId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Processar inventário'),
        content: const Text(
            'Deseja processar o inventário? Depois de processado não será possível alterar os itens.'),
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
      await _service!.processInventory(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inventário processado com sucesso'),
          backgroundColor: Color(Constants.badgeGreen)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao processar inventário'),
          backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itens = _draft?.items ?? [];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('EAN'),
                  selected: _buscaTipo == 'EAN',
                  onSelected: (_) => setState(() => _buscaTipo = 'EAN'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('SAP'),
                  selected: _buscaTipo == 'SAP',
                  onSelected: (_) => setState(() => _buscaTipo = 'SAP'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      hintText: _buscaTipo == 'SAP' ? 'SAP' : 'EAN',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF9E9E9E)),
                      filled: true,
                      fillColor: const Color(Constants.bgGray),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _escanear,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(Constants.primaryRed),
                      shape: BoxShape.circle,
                    ),
                    child: _adicionando
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _corpo(itens)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: itens.isEmpty ? null : _processar,
        backgroundColor: itens.isEmpty
            ? Colors.grey
            : const Color(Constants.primaryRed),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        icon: const Icon(Icons.check),
        label: const Text('PROCESSAR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _corpo(List<InventoryItem> itens) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (itens.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/drawables/ic_empty_wink.svg',
            width: 64,
            height: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Adicione itens ao inventário rotativo',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(Constants.invTextDark)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Utilize o EAN para adicionar itens e quantidades.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Color(Constants.invTextSecondary)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 90),
      itemCount: itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = itens[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _editarItem(item),
          onLongPress: () => _removerItem(item),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(Constants.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description,
                          style: const TextStyle(
                              color: Color(Constants.invTextDark),
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('EAN ${item.ean}   •   SAP ${item.sapCode}',
                          style: const TextStyle(
                              color: Color(Constants.invTextSecondary),
                              fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Contado',
                        style: TextStyle(
                            color: Color(Constants.invTextSecondary),
                            fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${item.countedQuantity}',
                        style: const TextStyle(
                            color: Color(Constants.invTextDark),
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar() {
    final count = _draft?.items.length ?? 0;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Color(Constants.invTextDark)),
      title: Text(widget.titulo,
          style: const TextStyle(
              color: Color(Constants.invTextDark),
              fontWeight: FontWeight.bold,
              fontSize: 20)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(Constants.primaryRed), shape: BoxShape.circle),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
