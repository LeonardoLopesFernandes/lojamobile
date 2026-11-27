import 'package:flutter/material.dart';
import '../models/inventario.dart';
import '../network/api_client.dart';
import '../network/inventario_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/date_format.dart';
import 'detalhe_inventario_screen.dart';
import 'criar_inventario_screen.dart';

class ListaInventarioScreen extends StatefulWidget {
  const ListaInventarioScreen({super.key});

  @override
  State<ListaInventarioScreen> createState() => _ListaInventarioScreenState();
}

class _ListaInventarioScreenState extends State<ListaInventarioScreen> {
  static const _limit = 20;

  final ScrollController _scroll = ScrollController();
  SessionManager? _session;
  InventarioService? _service;

  final List<Inventory> _items = [];
  int _offset = 0;
  bool _carregando = false;
  bool _isLastPage = false;
  String? _erro;
  String _filtro = 'Todos';

  // Filtros (servidor): Id. do inventário, Referência e Data de criação.
  String _fInventario = '';
  String _fReferencia = '';
  String _fData = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    final session = await SessionManager.create();
    if (!mounted) return;
    setState(() {
      _session = session;
      _service = InventarioService.forSession(session);
    });
    _carregar(reset: true);
  }

  String get _storeId =>
      _session?.getUserStore() ?? Constants.defaultStore;

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _carregar();
    }
  }

  Future<void> _carregar({bool reset = false}) async {
    if (_carregando) return;
    if (!reset && _isLastPage) return;
    final service = _service;
    if (service == null) return;

    setState(() {
      _carregando = true;
      if (reset) {
        _erro = null;
        _offset = 0;
        _isLastPage = false;
      }
    });

    try {
      final page = await service.getCycleCounts(
        storeId: _storeId,
        offset: reset ? 0 : _offset,
        limit: _limit,
        inventoryNumber: _fInventario,
        reference: _fReferencia,
        date: _fData,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.inventories);
        _offset = _items.length;
        _isLastPage = _items.length >= page.total ||
            page.inventories.isEmpty;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha ao carregar inventários';
        _carregando = false;
      });
    }
  }

  Future<void> _criarInventario() async {
    final service = _service;
    final session = _session;
    if (service == null) return;
    try {
      final inv = await service.createInventory(
          storeId: _storeId, email: session?.getUserEmail() ?? '');
      await _carregar(reset: true);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CriarInventarioScreen(inventoryId: inv.id),
      ));
      _carregar(reset: true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? 'HTTP ${e.code}: ${e.body}' : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Falha ao criar inventário: $msg'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _detalhes(Inventory inv) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => inv.finalizado
          ? DetalheInventarioScreen(
              inventoryId: inv.id,
              inventoryNumber: inv.inventoryNumber,
            )
          : CriarInventarioScreen(
              inventoryId: inv.id,
              titulo: 'Detalhes do inventário',
            ),
    ));
    _carregar(reset: true);
  }

  Future<void> _processar(Inventory inv) async {
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
      await _service!.processInventory(inv.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inventário processado com sucesso'),
          backgroundColor: Color(Constants.badgeGreen)));
      _carregar(reset: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao processar inventário'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _excluir(Inventory inv) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Excluir inventário'),
        content: Text('Deseja excluir ${inv.inventoryNumber}?'),
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
    if (confirmado != true) return;
    final service = _service;
    if (service == null) return;
    try {
      await service.deleteCycleCount(inv.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == inv.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inventário excluído'),
          backgroundColor: Color(Constants.badgeGreen)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao excluir inventário'),
          backgroundColor: Colors.red));
    }
  }

  List<Inventory> get _filtrados {
    switch (_filtro) {
      case 'Finalizado':
        return _items.where((i) => i.finalizado).toList();
      case 'Em andamento':
        return _items.where((i) => !i.finalizado).toList();
      default:
        return _items;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(Constants.bgGray),
      appBar: _appBar(context),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _chip('Todos'),
                const SizedBox(width: 8),
                _chip('Em andamento'),
                const SizedBox(width: 8),
                _chip('Finalizado'),
              ],
            ),
          ),
          Expanded(child: _corpo()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarInventario,
        backgroundColor: const Color(Constants.primaryRed),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 4,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text('Criar inventário',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _corpo() {
    if (_session == null || (_carregando && _items.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _carregar(reset: true),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    final lista = _filtrados;
    if (lista.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _carregar(reset: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Nenhum inventário encontrado')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _carregar(reset: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: lista.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == lista.length) {
            return _carregando
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox(height: 80);
          }
          final inv = lista[index];
          Widget? menu;
          if (!inv.finalizado) {
            menu = PopupMenuButton<String>(
              color: Colors.white,
              icon: const Icon(Icons.more_vert,
                  color: Color(Constants.invTextDark), size: 20),
              onSelected: (v) {
                if (v == 'detalhes') {
                  _detalhes(inv);
                } else if (v == 'processar') {
                  _processar(inv);
                } else if (v == 'excluir') {
                  _excluir(inv);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'detalhes', child: Text('Detalhes')),
                PopupMenuItem(value: 'processar', child: Text('Processar')),
                PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            );
          }
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _detalhes(inv),
            child: _InventarioCard(inventario: inv, trailing: menu),
          );
        },
      ),
    );
  }

  String _fmtData(DateTime d) => formatDataBr(
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}');

  String _fmtYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _abrirFiltros() async {
    final invCtrl = TextEditingController(text: _fInventario);
    final refCtrl = TextEditingController(text: _fReferencia);
    DateTime? dataSel = _fData.isNotEmpty ? DateTime.tryParse(_fData) : null;
    final dataCtrl =
        TextEditingController(text: dataSel != null ? _fmtData(dataSel) : '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Filtrar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: invCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Id. de inventário'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Referência'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dataCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Data de criação',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dataSel ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDlg(() {
                        dataSel = picked;
                        dataCtrl.text = _fmtData(picked);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _fInventario = '';
                  _fReferencia = '';
                  _fData = '';
                });
                _carregar(reset: true);
              },
              child: const Text('Limpar'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _fInventario = invCtrl.text.trim();
                  _fReferencia = refCtrl.text.trim();
                  _fData = dataSel != null ? _fmtYmd(dataSel!) : '';
                });
                _carregar(reset: true);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'Inventário rotativo',
        style: TextStyle(
            color: Color(Constants.invTextDark),
            fontWeight: FontWeight.w500,
            fontSize: 20),
      ),
      actions: [
        IconButton(
          icon: Icon(
            (_fInventario.isNotEmpty ||
                    _fReferencia.isNotEmpty ||
                    _fData.isNotEmpty)
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
            color: const Color(Constants.invTextDark),
          ),
          onPressed: _abrirFiltros,
        ),
      ],
    );
  }

  Widget _chip(String label) {
    final selecionado = _filtro == label;
    return GestureDetector(
      onTap: () => setState(() => _filtro = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(Constants.primaryRed)
              : const Color(Constants.bgGray),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.grey.shade400, width: selecionado ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selecionado)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
            Text(
              label,
              style: TextStyle(
                color: selecionado
                    ? Colors.white
                    : const Color(Constants.invTextDark),
                fontWeight: selecionado ? FontWeight.bold : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventarioCard extends StatelessWidget {
  final Inventory inventario;
  final Widget? trailing;

  const _InventarioCard({required this.inventario, this.trailing});

  @override
  Widget build(BuildContext context) {
    final badgeBg = inventario.finalizado
        ? const Color(Constants.invBadgeGreenBg)
        : const Color(Constants.bgGray);
    final badgeFg = inventario.finalizado
        ? const Color(Constants.invBadgeGreenText)
        : const Color(Constants.invTextSecondary);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: const Color(Constants.invLineGreen)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              inventario.inventoryNumber,
                              style: const TextStyle(
                                  color: Color(Constants.invTextDark),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              inventario.statusName,
                              style: TextStyle(
                                  color: badgeFg,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Referência',
                                    style: TextStyle(
                                        color:
                                            Color(Constants.invTextSecondary),
                                        fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(inventario.reference,
                                    style: const TextStyle(
                                        color: Color(Constants.invTextDark),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data de criação',
                                    style: TextStyle(
                                        color:
                                            Color(Constants.invTextSecondary),
                                        fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(formatDataBr(inventario.createdAt),
                                    style: const TextStyle(
                                        color: Color(Constants.invTextDark),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
