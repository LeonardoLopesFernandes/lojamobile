import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recebimento.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/excel_downloader.dart';
import '../widgets/item_row.dart';

class ItensScreen extends StatefulWidget {
  const ItensScreen({super.key});

  @override
  State<ItensScreen> createState() => _ItensScreenState();
}

class _ItensScreenState extends State<ItensScreen> {
  String _titulo = '';
  List<RecebimentoItem> _todos = [];
  List<RecebimentoItem> _filtrados = [];
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;
    _titulo = args?['titulo'] ?? 'Itens';
    _todos = (args?['itens'] as List? ?? [])
        .whereType<RecebimentoItem>()
        .toList();
    _filtrados = _todos;
  }

  void _filtrar(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtrados = _todos.where((i) {
        return i.descricao.toLowerCase().contains(query) ||
            i.idSap.toLowerCase().contains(query) ||
            i.departamento.toLowerCase().contains(query) ||
            i.idEan.toLowerCase().contains(query);
      }).toList();
    });
  }

  double get _soma => _todos.fold(0.0, (s, i) => s + i.preco);

  void _gerarExcel() async {
    if (_todos.isEmpty) {
      _snack("Nenhum item para gerar Excel.");
      return;
    }
    _snackCom(
        Image.asset('assets/drawables/excel.png',
            width: 20, height: 20, fit: BoxFit.contain,
            color: Colors.white, colorBlendMode: BlendMode.srcIn),
        'Gerando Excel...');
    try {
      final path = await ExcelDownloader.gerarXlsxItens(
        viagemId: _titulo,
        prefixo: "itens",
        itens: _todos,
      );
      _snackCom(const Icon(Icons.check_box, color: Colors.white, size: 20),
          'Excel salvo: $path',
          action: SnackBarAction(
              label: 'Abrir',
              onPressed: () => ExcelDownloader.abrirArquivo(
                  path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')));
    } catch (e) {
      _snack("❌ $e");
    }
  }

  void _gerarPdf() async {
    if (_todos.isEmpty) {
      _snack("Nenhum item para gerar PDF.");
      return;
    }
    _snackCom(
        Image.asset('assets/drawables/pdf.png',
            width: 20, height: 20, fit: BoxFit.contain,
            color: Colors.white, colorBlendMode: BlendMode.srcIn),
        'Gerando PDF...');
    try {
      final path = await ExcelDownloader.gerarPdfItens(
        titulo: _titulo,
        prefixo: "itens",
        itens: _todos,
        total: _soma,
      );
      _snackCom(const Icon(Icons.check_box, color: Colors.white, size: 20),
          'PDF salvo: $path',
          action: SnackBarAction(
              label: 'Abrir',
              onPressed: () =>
                  ExcelDownloader.abrirArquivo(path, 'application/pdf')));
    } catch (e) {
      _snack("❌ $e");
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _snackCom(Widget icone, String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          icone,
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ],
      ),
      action: action,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Header / toolbar (gradiente, fiel ao HTML de Itens de Risco)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).padding.top + 4, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titulo.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BotaoExport(
                        asset: 'assets/drawables/excel.png',
                        label: 'XLS',
                        onTap: _gerarExcel,
                      ),
                      const SizedBox(width: 6),
                      _BotaoExport(
                        asset: 'assets/drawables/pdf.png',
                        label: 'PDF',
                        onTap: _gerarPdf,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // KPI box "Total"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatarMoedaComSimbolo(_soma),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Busca
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFFA0AEC0)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: _filtrar,
                    decoration: const InputDecoration(
                      hintText: 'Pesquisar item (nome, SAP ou departamento)',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                    ),
                  ),
                ),
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _search.clear();
                      _filtrar('');
                    },
                  ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: _filtrados.isEmpty
                ? const Center(child: Text('Nenhum item encontrado'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtrados.length,
                    itemBuilder: (ctx, i) => ItemRow(item: _filtrados[i]),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

class _BotaoExport extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onTap;

  const _BotaoExport({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset,
                width: 18, height: 18, fit: BoxFit.contain,
                color: Colors.white, colorBlendMode: BlendMode.srcIn),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
