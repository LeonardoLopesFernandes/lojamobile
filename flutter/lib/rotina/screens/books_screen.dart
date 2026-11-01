import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventario/rotina/api/client.dart';
import 'package:inventario/rotina/api/endpoints.dart';
import 'package:inventario/rotina/components/photo_upload_dialog.dart';
import 'package:inventario/rotina/components/uploading_dialog.dart';
import 'package:inventario/rotina/screens/book_treatments_screen.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

/// Lista de books/campanhas da loja (menu lateral Books).
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  static const int _perPage = 10;
  static List<BookStatus>? _cacheBooks;
  static Set<String>? _cachePendingIds;

  final _searchController = TextEditingController();
  final _lojaController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<BookStatus> _books = [];
  Set<String> _pendingIds = {};
  String _query = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    final cache = _cacheBooks;
    if (cache != null) {
      _books = cache;
      _pendingIds = {...?_cachePendingIds};
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lojaController.dispose();
    super.dispose();
  }

  void _aplicarLoja() {
    setState(() => _page = 1);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_books.isEmpty) _loading = true;
    });
    final loja = _lojaController.text.trim();
    var falhou = false;

    Future<List<BookStatus>> safe(Future<List<BookStatus>> future) async {
      try {
        return await future;
      } catch (_) {
        falhou = true;
        return <BookStatus>[];
      }
    }

    // Carrega pendentes e histórico em paralelo e só monta a lista quando os
    // dois terminam, para não exibir apenas os pendentes por alguns segundos.
    final results = await Future.wait([
      safe(getBooks(loja: loja).timeout(const Duration(seconds: 20))),
      safe(getAllBooks(loja: loja)),
    ]);
    final pendentes = results[0];
    final historico = results[1];
    final porId = <String, BookStatus>{
      for (final b in historico) b.bookId: b,
    };
    for (final p in pendentes) {
      porId[p.bookId] = p;
    }
    final books = porId.values.toList();
    if (!mounted) return;
    if (books.isEmpty) {
      setState(() {
        _error = _books.isEmpty && falhou
            ? 'Não foi possível carregar os books.'
            : null;
        _loading = false;
      });
      return;
    }
    final pendingIds = {
      ...pendentes.map((b) => b.bookId),
      for (final b in books)
        if (b.pendente) b.bookId,
    };
    books.sort((a, b) {
      final pa = pendingIds.contains(a.bookId);
      final pb = pendingIds.contains(b.bookId);
      if (pa != pb) return pa ? -1 : 1;
      final da = DateTime.tryParse(a.startDateTime) ?? DateTime(2000);
      final db = DateTime.tryParse(b.startDateTime) ?? DateTime(2000);
      return db.compareTo(da);
    });
    if (loja.isEmpty) {
      _cacheBooks = List<BookStatus>.unmodifiable(books);
      _cachePendingIds = Set<String>.unmodifiable(pendingIds);
    }
    setState(() {
      _books = books;
      _pendingIds = pendingIds;
      _loading = false;
      _error = null;
    });
  }

  List<BookStatus> get _filtrados {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _books;
    return _books
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.description.toLowerCase().contains(q))
        .toList();
  }

  int get _totalPages {
    final total = _filtrados.length;
    if (total == 0) return 1;
    return (total / _perPage).ceil();
  }

  List<BookStatus> get _pageItems {
    final list = _filtrados;
    final start = (_page - 1) * _perPage;
    if (start >= list.length) return const [];
    return list.sublist(start, (start + _perPage).clamp(0, list.length));
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _page = 1;
    });
  }

  String _fmt(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final l = d.toLocal();
    final p = (int n) => n.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)}/${l.year} ${p(l.hour)}:${p(l.minute)}';
  }

  String _itemLabel(BookStatus book) {
    if (book.type == 'management') return 'Administrativo';
    final desc = book.item?['description']?.toString() ?? '';
    if (book.type == 'item-family') return '[Família] $desc';
    return desc;
  }

  String _progresso(BookStatus book) {
    if (book.total <= 0) return '0%';
    final pct = book.treated * 100 / book.total;
    return '${pct.toStringAsFixed(0)}% (${book.treated}/${book.total} Lojas)';
  }

  Map<String, String>? get _imageHeaders {
    final token = getAuthToken();
    if (token == null || token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'Cookie': 'rc-newToken=$token',
    };
  }

  String _statusLabel(BookStatus book) {
    if (book.encerrado) return 'ENCERRADO';
    if (_pendingIds.contains(book.bookId)) return 'PENDENTE';
    return 'DISPONÍVEL';
  }

  Widget _chipFor(BookStatus book) {
    final label = _statusLabel(book);
    final pendente = label == 'PENDENTE';
    final disponivel = label == 'DISPONÍVEL';
    final fg = pendente
        ? const Color(0xFFC62828)
        : disponivel
            ? const Color(0xFF2E7D32)
            : const Color(0xFF6B7280);
    final bg = pendente
        ? const Color(0xFFFFEBEE)
        : disponivel
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFF3F4F6);
    final bd = pendente
        ? const Color(0xFFFFCDD2)
        : disponivel
            ? const Color(0xFFC8E6C9)
            : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bd),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
          fontFamily: 'Open Sans',
        ),
      ),
    );
  }

  Widget _dateColumn(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontFamily: 'Open Sans')),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  fontFamily: 'Open Sans')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final items = _pageItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: const Text(
          'Books',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Open Sans'),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _lojaController,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _aplicarLoja(),
              style: const TextStyle(fontSize: 14, fontFamily: 'Open Sans'),
              decoration: InputDecoration(
                hintText: 'Filtrar por loja (ex.: L291)',
                hintStyle:
                    const TextStyle(fontSize: 14, fontFamily: 'Open Sans'),
                prefixIcon: const Icon(Icons.storefront, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: _aplicarLoja,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _setQuery,
              style: const TextStyle(fontSize: 14, fontFamily: 'Open Sans'),
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome ou descrição...',
                hintStyle:
                    const TextStyle(fontSize: 14, fontFamily: 'Open Sans'),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontFamily: 'Open Sans',
                                      color: AppColors.danger)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _load,
                                child: const Text('TENTAR NOVAMENTE'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: items.isEmpty
                            ? ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Center(
                                      child: Text(
                                        'Nenhum book encontrado',
                                        style: const TextStyle(
                                            color: AppColors.textHint,
                                            fontFamily: 'Open Sans'),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: items.length,
                                itemBuilder: (_, i) => _card(items[i]),
                              ),
                      ),
          ),
          if (!_loading && _error == null && _filtrados.isNotEmpty)
            _pagination(),
        ],
      ),
    );
  }

  Widget _card(BookStatus book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _detalhes(book),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      book.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                        fontFamily: 'Open Sans',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _chipFor(book),
                ],
              ),
              const Divider(height: 16),
              if (book.description.isNotEmpty) ...[
                Text(
                  book.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Open Sans',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _dateColumn('Início', _fmt(book.startDateTime)),
                  _dateColumn('Fim', _fmt(book.endDateTime)),
                ],
              ),
              if (book.createdBy.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Por: ${book.createdBy}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Open Sans'),
                ),
              ],
              if (book.total > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Lojas: ${book.treated}/${book.total} tratadas',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Open Sans'),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fotos: ${book.filesQuantity}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'Open Sans'),
                  ),
                  Row(
                    children: [
                      if (book.podeEnviarFotos)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          icon: SvgPicture.asset(
                            'assets/rotina/icons/books_add_image.svg',
                            width: 18,
                            height: 19,
                            colorFilter: const ColorFilter.mode(
                                AppColors.primary, BlendMode.srcIn),
                          ),
                          onPressed: () => _anexarFotos(book),
                        ),
                      const Text('Ver detalhes',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Open Sans')),
                      SvgPicture.asset(
                        'assets/rotina/icons/books_eye.svg',
                        width: 20,
                        height: 15,
                        colorFilter: const ColorFilter.mode(
                            AppColors.primary, BlendMode.srcIn),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagination() {
    final total = _totalPages;
    final pages = List<int>.generate(total, (i) => i + 1);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            icon: const Icon(Icons.chevron_left),
            color: _page > 1 ? AppColors.primary : AppColors.textHint,
          ),
          ...pages.map(
            (p) => GestureDetector(
              onTap: () => setState(() => _page = p),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p == _page ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: p == _page ? Colors.white : Colors.black87,
                    fontFamily: 'Open Sans',
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _page < total ? () => setState(() => _page++) : null,
            icon: const Icon(Icons.chevron_right),
            color: _page < total ? AppColors.primary : AppColors.textHint,
          ),
        ],
      ),
    );
  }

  Future<void> _anexarFotos(BookStatus book) async {
    if (!book.podeEnviarFotos) return;
    final fotos = await showDialog<List<XFile>>(
      context: context,
      builder: (_) => PhotoUploadDialog(
        filesQuantity: book.filesQuantity,
        bookName: book.name,
      ),
    );
    if (fotos == null || fotos.isEmpty || !mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadingDialog(),
    );
    try {
      await uploadBookPhotos(book.bookId, fotos, loja: store);
      navigator.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${fotos.length} foto(s) enviada(s) para ${book.name}.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _load();
    } catch (e) {
      navigator.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadErrorMessage(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _detalhes(BookStatus book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    book.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Open Sans'),
                  ),
                ),
                _chipFor(book),
              ],
            ),
            const SizedBox(height: 12),
            if (book.description.isNotEmpty)
              Text(book.description,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Open Sans')),
            const SizedBox(height: 12),
            if (book.createdBy.isNotEmpty)
              _linha('Criado por', book.createdBy),
            _linha('Data e hora de início', _fmt(book.startDateTime)),
            _linha('Data e hora de fim', _fmt(book.endDateTime)),
            if (_itemLabel(book).isNotEmpty) _linha('Item', _itemLabel(book)),
            _linha('Progresso', _progresso(book)),
            if (book.filenames.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Foto exemplo',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Open Sans',
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: book.filenames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url =
                        bookExampleImageUrl(book.bookId, book.filenames[i]);
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _verFotos(book);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          headers: _imageHeaders,
                          width: 160,
                          height: 110,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      width: 160,
                                      height: 110,
                                      color: const Color(0xFFF2F2F2),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                          errorBuilder: (_, __, ___) => Container(
                            width: 160,
                            height: 110,
                            color: const Color(0xFFF2F2F2),
                            child: const Icon(Icons.broken_image,
                                color: AppColors.textHint),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _verFotos(book);
                },
                icon: SvgPicture.asset(
                  'assets/rotina/icons/books_image.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                      AppColors.primary, BlendMode.srcIn),
                ),
                label: const Text(
                  'VER FOTOS DAS LOJAS',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Open Sans'),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (book.podeEnviarFotos) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _anexarFotos(book);
                  },
                  icon: SvgPicture.asset(
                    'assets/rotina/icons/books_add_image.svg',
                    width: 18,
                    height: 19,
                    colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn),
                  ),
                  label: const Text(
                    'ANEXAR IMAGENS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Open Sans'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _verFotos(BookStatus book) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookTreatmentsScreen(book: book)));
  }

  Widget _linha(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Open Sans')),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontFamily: 'Open Sans')),
            ),
          ],
        ),
      );
}
