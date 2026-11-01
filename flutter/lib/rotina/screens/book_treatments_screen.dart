import 'package:flutter/material.dart';
import 'package:inventario/rotina/api/client.dart';
import 'package:inventario/rotina/api/endpoints.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

/// Fotos das lojas de um book (tratamentos), com filtro por loja.
class BookTreatmentsScreen extends StatefulWidget {
  final BookStatus book;

  const BookTreatmentsScreen({super.key, required this.book});

  @override
  State<BookTreatmentsScreen> createState() => _BookTreatmentsScreenState();
}

class _BookTreatmentsScreenState extends State<BookTreatmentsScreen> {
  static const int _limit = 50;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _hint = Color(0xFF94A3B8);
  static const Color _dark = Color(0xFF334155);

  final _storeController = TextEditingController();
  List<String> _regions = [];
  List<StoreDistrict> _districts = [];
  String? _region;
  String? _district;
  bool _loading = true;
  String? _error;
  List<BookTreatment> _treatments = [];
  int _total = 0;
  int _offset = 0;
  late BookStatus _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _carregarFiltros();
    _load(reset: true);
  }

  Future<void> _carregarFiltros() async {
    try {
      final results = await Future.wait([getRegions(), getDistricts()]);
      if (mounted) {
        setState(() {
          _regions = results[0] as List<String>;
          _districts = results[1] as List<StoreDistrict>;
        });
      }
    } catch (_) {}
  }

  List<StoreDistrict> get _distritosVisiveis {
    if (_region == null) return _districts;
    return _districts.where((d) => d.zone == _region).toList();
  }

  InputDecoration _filtroDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: _hint, fontFamily: 'Open Sans'),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      );

  void _aplicar() {
    setState(() => _offset = 0);
    _load();
  }

  void _irParaPagina(int page) {
    final destino = page.clamp(1, _totalPages);
    setState(() => _offset = (destino - 1) * _limit);
    _load();
  }

  @override
  void dispose() {
    _storeController.dispose();
    super.dispose();
  }

  Map<String, String>? get _headers {
    final token = getAuthToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _offset = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await getBookTreatments(
        widget.book.bookId,
        limit: _limit,
        offset: _offset,
        store: _storeController.text.trim(),
        region: _region,
        district: _district,
      );
      if (mounted) {
        setState(() {
          _treatments = page.treatments;
          _total = page.totalCount;
          if (page.book != null && page.book!.filenames.isNotEmpty) {
            _book = page.book!;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar as fotos.';
          _loading = false;
        });
      }
    }
  }

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _limit).ceil();
  }

  int get _page => (_offset / _limit).floor() + 1;

  String get _itemLabel {
    if (_book.type.toLowerCase() == 'management') return 'Administrativo';
    final desc = _book.item?['description']?.toString() ?? '';
    if (desc.isNotEmpty) return desc;
    return _book.type.isNotEmpty ? _book.type : '—';
  }

  String get _progresso {
    final pct = _book.total > 0 ? _book.treated * 100 / _book.total : 0;
    return '${pct.toStringAsFixed(0)}% (${_book.treated}/${_book.total} Lojas)';
  }

  List<_GridStore> get _gridStores {
    final items = <_GridStore>[];
    // A foto exemplo do book abre sempre como a primeira do grid.
    if (_offset == 0 && _book.filenames.isNotEmpty) {
      items.add(_GridStore(
        label: 'EXEMPLO',
        urls: _book.filenames
            .map((f) => bookExampleImageUrl(_book.bookId, f))
            .toList(),
        exemplo: true,
      ));
    }
    for (final t in _treatments) {
      items.add(_GridStore(
        label: t.store.isEmpty ? '—' : t.store,
        urls: t.filenames
            .map((f) => bookTreatmentImageUrl(t.id, f))
            .toList(),
        exemplo: false,
      ));
    }
    return items;
  }

  void _abrirGaleria(_GridStore store) {
    if (store.urls.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(store.exemplo ? 'Foto exemplo' : 'Loja ${store.label}'),
        ),
        body: PageView.builder(
          itemCount: store.urls.length,
          itemBuilder: (_, i) => InteractiveViewer(
            child: Center(
              child: Image.network(
                store.urls[i],
                headers: _headers,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'Não foi possível carregar a imagem',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = _gridStores;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _muted,
        elevation: 0,
        title: Text(
          'Books > ${_book.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: _muted,
            fontFamily: 'Open Sans',
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Item: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: _itemLabel,
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Open Sans',
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Progresso: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: _progresso,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Open Sans',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),
                _filtros(),
                const SizedBox(height: 16),
                if (!_loading && _error == null) ...[
                  _pagination(),
                  if (_totalPages > 1) const SizedBox(height: 16),
                ],
                _conteudo(stores),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtros() {
    final regiao = DropdownButtonFormField<String>(
      value: _region ?? '',
      isExpanded: true,
      decoration: _filtroDecoration('Região'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todas as regiões')),
        ..._regions.map(
          (r) => DropdownMenuItem(value: r, child: Text(r)),
        ),
      ],
      onChanged: (v) {
        setState(() {
          _region = (v == null || v.isEmpty) ? null : v;
          _district = null;
        });
        _aplicar();
      },
    );

    final distrito = DropdownButtonFormField<String>(
      value: _district ?? '',
      isExpanded: true,
      decoration: _filtroDecoration('Distrito'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos os distritos')),
        ..._distritosVisiveis.map(
          (d) => DropdownMenuItem(
            value: d.code,
            child: Text(
              '${d.code} - ${d.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (v) {
        setState(() => _district = (v == null || v.isEmpty) ? null : v);
        _aplicar();
      },
    );

    final loja = TextField(
      controller: _storeController,
      onSubmitted: (_) => _aplicar(),
      style: const TextStyle(fontSize: 13, fontFamily: 'Open Sans'),
      decoration: _filtroDecoration('Pesquisar por loja').copyWith(
        suffixIcon: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
          iconSize: 18,
          icon: const Icon(Icons.search, color: _hint),
          onPressed: _aplicar,
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: regiao),
            const SizedBox(width: 6),
            Expanded(child: distrito),
          ],
        ),
        const SizedBox(height: 6),
        loja,
      ],
    );
  }

  Widget _pagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBotoes = constraints.maxWidth < 340
            ? 2
            : constraints.maxWidth < 460
                ? 3
                : 4;
        var inicio = _page - (maxBotoes ~/ 2);
        if (inicio < 1) inicio = 1;
        final maxInicio =
            (_totalPages - maxBotoes + 1).clamp(1, _totalPages).toInt();
        if (inicio > maxInicio) inicio = maxInicio;
        final fim = (inicio + maxBotoes - 1).clamp(1, _totalPages).toInt();
        final paginas = <int>[
          for (var p = inicio; p <= fim; p++) p,
        ];
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navButton(
                Icons.first_page,
                _page > 1 ? () => _irParaPagina(1) : null,
              ),
              _navButton(
                Icons.chevron_left,
                _page > 1 ? () => _irParaPagina(_page - 1) : null,
              ),
              ...paginas.map(
                (p) => _pageButton(
                  p.toString().padLeft(2, '0'),
                  p == _page,
                  () => _irParaPagina(p),
                ),
              ),
              _navButton(
                Icons.chevron_right,
                _page < _totalPages ? () => _irParaPagina(_page + 1) : null,
              ),
              _navButton(
                Icons.last_page,
                _page < _totalPages
                    ? () => _irParaPagina(_totalPages)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      icon: Icon(icon),
      onPressed: onTap,
      color: _muted,
      disabledColor: const Color(0xFFCBD5E1),
    );
  }

  Widget _pageButton(String page, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEF4444) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          page,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : _muted,
            fontFamily: 'Open Sans',
          ),
        ),
      ),
    );
  }

  Widget _conteudo(List<_GridStore> stores) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: const TextStyle(fontFamily: 'Open Sans')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _load(reset: true),
                child: const Text('TENTAR NOVAMENTE'),
              ),
            ],
          ),
        ),
      );
    }
    if (stores.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Nenhuma loja encontrada',
            style: TextStyle(
              color: _hint,
              fontFamily: 'Open Sans',
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: stores.length,
      itemBuilder: (_, i) => _storeTile(stores[i]),
    );
  }

  Widget _storeTile(_GridStore store) {
    return GestureDetector(
      onTap: store.urls.isEmpty ? null : () => _abrirGaleria(store),
      child: Container(
        decoration: BoxDecoration(
          color:
              store.urls.isEmpty ? const Color(0xFFF1F5F9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (store.urls.isEmpty)
              const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(0xFFCBD5E1),
                  size: 32,
                ),
              )
            else
              Image.network(
                store.urls.first,
                headers: _headers,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFFCBD5E1),
                    size: 32,
                  ),
                ),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _dark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  store.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Open Sans',
                  ),
                ),
              ),
            ),
            if (store.urls.length > 1)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${store.urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Open Sans',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridStore {
  final String label;
  final List<String> urls;
  final bool exemplo;

  const _GridStore({
    required this.label,
    required this.urls,
    required this.exemplo,
  });
}
