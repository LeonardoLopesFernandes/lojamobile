import 'package:flutter/material.dart';
import '../models/quebra.dart';
import '../network/api_client.dart';
import '../network/inventario_service.dart';
import '../network/session_manager.dart';
import '../utils/constants.dart';
import '../utils/date_format.dart';
import 'quebra_detalhe_screen.dart';

class QuebraScreen extends StatefulWidget {
  final bool apenasConsulta;

  const QuebraScreen({super.key, this.apenasConsulta = false});

  @override
  State<QuebraScreen> createState() => _QuebraScreenState();
}

class _QuebraScreenState extends State<QuebraScreen> {
  final TextEditingController _buscaController = TextEditingController();
  SessionManager? _session;
  InventarioService? _service;

  final List<Breakage> _items = [];
  bool _carregando = false;
  bool _isLastPage = false;
  String? _erro;
  int _offset = 0;
  String _chip = 'Todas';

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
    _carregar(reset: true);
  }

  String get _storeId => _session?.getUserStore() ?? Constants.defaultStore;

  /// Id de uma quebra pendente/aberta do usuário, se existir.
  String? _pendingId(dynamic data) {
    if (data is! Map) return null;
    final aberta = data['openBreakageId']?.toString();
    if (aberta != null && aberta.isNotEmpty) return aberta;
    final breakage = data['breakage'];
    if (breakage is Map) {
      final id = breakage['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> _novaQuebra() async {
    final service = _service;
    final session = _session;
    if (service == null) return;
    // Recupera a quebra pendente do usuário antes de criar outra (o site faz
    // o mesmo; a BFF recusa uma segunda com "Já existe uma quebra aberta").
    try {
      final pendente = await service.getPendingBreakage(
          email: session?.getUserEmail() ?? '', store: _storeId);
      final id = _pendingId(pendente);
      if (id != null) {
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuebraDetalheScreen(breakageId: id),
        ));
        _carregar(reset: true);
        return;
      }
    } catch (_) {
      // sem pendente ou falha ao consultar: segue com a criação
    }
    try {
      final b = await service.createBreakage(
        storeId: _storeId,
        userName: session?.getUserName() ?? '',
        userEmail: session?.getUserEmail() ?? '',
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuebraDetalheScreen(breakageId: b.id),
      ));
      _carregar(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.body.toLowerCase().contains('quebra aberta')
          ? 'Já existe uma quebra aberta para este usuário.'
          : 'Falha ao criar quebra';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
      _carregar(reset: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao criar quebra'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reabrirQuebra(Breakage b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reabrir quebra'),
        content: Text(
            'Deseja reabrir a quebra de ${b.user}? Ela voltará para "Aberta".'),
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
      await _service!.reopenBreakage(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quebra reaberta com sucesso'),
          backgroundColor: Color(Constants.badgeGreen)));
      _carregar(reset: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao reabrir quebra'), backgroundColor: Colors.red));
    }
  }

  Future<void> _abrirDetalhe(Breakage b) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuebraDetalheScreen(
          breakageId: b.id, somenteLeituraInicial: b.processado),
    ));
    _carregar(reset: true);
  }

  Future<void> _removerQuebra(Breakage b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remover quebra'),
        content: Text('Deseja remover a quebra de ${b.user}?'),
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
      await _service!.deleteBreakage(b.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == b.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quebra removida'),
          backgroundColor: Color(Constants.badgeGreen)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Falha ao remover quebra'),
          backgroundColor: Colors.red));
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
      final now = DateTime.now();
      final page = await service.getBreakages(
        year: now.year,
        store: _storeId,
        offset: reset ? 0 : _offset,
        limit: 50,
        // O site só usa mainPageFilter na tela "Cadastrar e processar".
        // Em "Consultar quebras" precisa vir tudo (inclusive PROCESSED/CLOSED).
        mainPageFilter: widget.apenasConsulta ? null : true,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.breakages);
        _offset = _items.length;
        _isLastPage = _items.length >= page.total || page.breakages.isEmpty;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha ao carregar quebras';
        _carregando = false;
      });
    }
  }

  List<Breakage> get _filtrados {
    var lista = _items;
    // Na tela "Cadastrar e processar" mostra só as pendentes/em andamento;
    // as processadas aparecem apenas em "Consultar quebras".
    if (!widget.apenasConsulta) {
      lista = lista.where((b) => !b.processado).toList();
    }
    if (_chip == 'Aberta') {
      lista = lista
          .where((b) =>
              ['PENDING', 'ABERTA', 'OPEN'].contains(b.status.toUpperCase()))
          .toList();
    } else if (_chip == 'Em andamento') {
      lista = lista
          .where((b) => ['IN_PROGRESS', 'EM_ANDAMENTO']
              .contains(b.status.toUpperCase()))
          .toList();
    }
    final q = _buscaController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where((b) =>
              b.user.toLowerCase().contains(q) ||
              b.store.toLowerCase().contains(q) ||
              b.id.toLowerCase().contains(q) ||
              formatDataBr(b.date).contains(q))
          .toList();
    }
    return lista;
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(Constants.invTextDark)),
        title: Text(
          widget.apenasConsulta
              ? 'Consultar quebras'
              : 'Cadastrar e processar quebra',
          style: const TextStyle(
              color: Color(Constants.invTextDark),
              fontSize: 18,
              fontWeight: FontWeight.w500),
        ),
      ),
      body: Column(
        children: [
          if (!widget.apenasConsulta)
            Container(
              width: double.infinity,
              color: const Color(0xFF3F51B5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Text(
                'Esta lista mostra apenas as quebras de hoje e as quebras ainda abertas ou pendentes.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _buscaController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _chipWidget('Todas'),
                const SizedBox(width: 8),
                _chipWidget('Aberta'),
                const SizedBox(width: 8),
                _chipWidget('Em andamento'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _corpo()),
        ],
      ),
      floatingActionButton: widget.apenasConsulta
          ? null
          : FloatingActionButton(
              onPressed: _novaQuebra,
              backgroundColor: const Color(Constants.primaryRed),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
    );
  }

  Widget _chipWidget(String label) {
    final selecionado = _chip == label;
    return GestureDetector(
      onTap: () => setState(() => _chip = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? const Color(Constants.primaryRed) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selecionado
                  ? const Color(Constants.primaryRed)
                  : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selecionado)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
            Text(label,
                style: TextStyle(
                    color: selecionado ? Colors.white : const Color(0xFF222222),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando && _items.isEmpty) {
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
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text('Nenhuma quebra disponível',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _carregar(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final b = lista[i];
          final entradas = <PopupMenuEntry<String>>[
            const PopupMenuItem(value: 'detalhes', child: Text('Detalhes')),
            if (b.canRemove)
              const PopupMenuItem(
                  value: 'remover', child: Text('Remover quebra')),
            if (b.canReopen)
              const PopupMenuItem(
                  value: 'reabrir', child: Text('Reabrir quebra')),
          ];
          final mostraMenu = widget.apenasConsulta || !b.processado;
          final Widget? menu = mostraMenu && entradas.length > 1
              ? PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert,
                      color: Color(Constants.invTextDark), size: 20),
                  onSelected: (v) {
                    if (v == 'detalhes') {
                      _abrirDetalhe(b);
                    } else if (v == 'remover') {
                      _removerQuebra(b);
                    } else if (v == 'reabrir') {
                      _reabrirQuebra(b);
                    }
                  },
                  itemBuilder: (_) => entradas,
                )
              : null;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _abrirDetalhe(b),
            child: _BreakageCard(breakage: b, trailing: menu),
          );
        },
      ),
    );
  }
}

class _BreakageCard extends StatelessWidget {
  final Breakage breakage;
  final Widget? trailing;

  const _BreakageCard({required this.breakage, this.trailing});

  @override
  Widget build(BuildContext context) {
    final processado = breakage.processado;
    final badgeBg = processado
        ? const Color(Constants.invBadgeGreenBg)
        : const Color(0xFFFFF3CD);
    final badgeFg = processado
        ? const Color(Constants.invBadgeGreenText)
        : const Color(0xFF8A6D00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  breakage.user.isEmpty ? 'Quebra' : breakage.user,
                  style: const TextStyle(
                      color: Color(Constants.invTextDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(breakage.statusLabel,
                    style: TextStyle(
                        color: badgeFg,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Text('${breakage.store}   •   ${formatDataBr(breakage.date)}',
              style: const TextStyle(
                  color: Color(Constants.invTextSecondary), fontSize: 12)),
          if (processado && breakage.itemsQuantity > 0) ...[
            const SizedBox(height: 6),
            Text('Itens: ${breakage.itemsQuantity}',
                style: const TextStyle(
                    color: Color(Constants.invTextDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}
