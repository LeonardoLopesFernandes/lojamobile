import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import '../models/recebimento.dart';
import '../utils/currency_formatter.dart';
import '../network/api_service.dart';

class ExcelDownloader {
  static const MethodChannel _channel = MethodChannel('com.recebimento/media');

  /// Baixa o Excel da viagem (streaming) e salva na pasta Downloads nativa.
  static Future<String> gerarExcel({
    required ApiService apiService,
    required String storeId,
    required String viagemId,
  }) async {
    final bytes = await apiService.gerarExcelViagem(storeId, viagemId);
    final nome = "viagem_${_short(viagemId)}_${_timestamp()}.xlsx";
    return _salvarEmDownloads(
        nome, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', bytes);
  }

  /// Gera um xlsx local a partir da lista de itens.
  /// Colunas: DEP, SAP, DESCRIÇÃO, QDTE REAL, CONTAGEM (vazia p/ conferência).
  static Future<String> gerarXlsxItens({
    required String viagemId,
    required String prefixo,
    required List<RecebimentoItem> itens,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Itens'];
    sheet.appendRow([
      TextCellValue('DEP'),
      TextCellValue('SAP'),
      TextCellValue('DESCRIÇÃO'),
      TextCellValue('QDTE REAL'),
      TextCellValue('CONTAGEM'),
    ]);
    for (final item in itens) {
      sheet.appendRow([
        TextCellValue(item.departamento),
        TextCellValue(item.idSap),
        TextCellValue(item.descricao),
        TextCellValue(item.quantidade.toString()),
        TextCellValue(''),
      ]);
    }
    final bytes = excel.save();
    final nome = "${prefixo}_${_short(viagemId)}_${_timestamp()}.xlsx";
    return _salvarEmDownloads(
        nome, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', bytes ?? []);
  }

  /// Gera um PDF local a partir da lista de itens.
  /// Colunas: DEP, SAP, DESCRIÇÃO, QTD, CONFERÊNCIA.
  /// Título = título recebido; subtítulo "Total: R$ 1.234,56" (pt-BR).
  static Future<String> gerarPdfItens({
    required String titulo,
    required String prefixo,
    required List<RecebimentoItem> itens,
    required double total,
    bool mostrarTotal = true,
  }) async {
    final theme = await _loadPdfTheme();
    final doc = pw.Document(theme: theme, title: titulo, creator: 'Recebimento');

    final corMarca = const pdf.PdfColor.fromInt(0xFFE5093A);
    final corBorda = const pdf.PdfColor.fromInt(0xFFCBD5E1);
    final corZebra = const pdf.PdfColor.fromInt(0xFFF5F5F5);

    final headers = ['#', 'DEP', 'SAP', 'DESCRIÇÃO', 'QTD', 'CONFERÊNCIA'];
    final data = itens.asMap().entries.map((e) {
      final idx = e.key;
      final item = e.value;
      final sap = int.tryParse(item.idSap)?.toString() ?? item.idSap;
      return <String>[
        '${idx + 1}',
        item.departamento,
        sap,
        item.descricao,
        item.quantidade.toString(),
        '',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: corMarca, width: 1.2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: corMarca,
                  ),
                ),
              ),
              if (mostrarTotal)
                pw.Text(
                  'Total: ${CurrencyFormatter.formatarMoedaComSimbolo(total)}',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(
                fontSize: 9, color: pdf.PdfColor.fromInt(0xFF64748B)),
          ),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(color: corBorda, width: 0.6),
            headerDecoration: pw.BoxDecoration(color: corMarca),
            headerStyle: pw.TextStyle(
              color: pdf.PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10.5,
            ),
            headerAlignment: pw.Alignment.center,
            headerPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            cellAlignments: const {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(0.55),
              1: pw.FlexColumnWidth(1.7),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(4.6),
              4: pw.FlexColumnWidth(0.85),
              5: pw.FlexColumnWidth(2.1),
            },
            oddRowDecoration: pw.BoxDecoration(color: corZebra),
          ),
        ],
      ),
    );
    final nome = "${prefixo}_${_short(titulo)}_${_timestamp()}.pdf";
    final bytes = await doc.save();
    return _salvarEmDownloads(nome, 'application/pdf', bytes);
  }

  /// Helvetica embutida no PDF: garante o mesmo desenho de fonte em qualquer
  /// visualizador/impressora (as fontes padrão não são embutidas e podem ser
  /// substituídas com menor qualidade). Cai para o tema padrão se faltar.
  static pw.ThemeData? _pdfTheme;
  static Future<pw.ThemeData?> _loadPdfTheme() async {
    if (_pdfTheme != null) return _pdfTheme;
    try {
      final base =
          pw.Font.ttf(await rootBundle.load('assets/fonts/helvetica.ttf'));
      final bold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/helvetica_bold.ttf'));
      return _pdfTheme = pw.ThemeData.withFont(base: base, bold: bold);
    } catch (_) {
      return null;
    }
  }

  /// Salva um arquivo qualquer em Downloads (ex.: foto para compartilhar).
  static Future<String> salvarArquivoEmDownloads({
    required String nome,
    required String mimeType,
    required List<int> bytes,
  }) =>
      _salvarEmDownloads(nome, mimeType, bytes);

  /// Salva na pasta Downloads nativa do Android via MediaStore.
  /// Fallback: pasta Downloads do app (getDownloadsDirectory) ou documents.
  static Future<String> _salvarEmDownloads(
      String nome, String mimeType, List<int> bytes) async {
    try {
      final uri = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': nome,
        'mimeType': mimeType,
        'bytes': Uint8List.fromList(bytes),
      });
      if (uri != null && uri.isNotEmpty) return uri;
    } on PlatformException catch (_) {
      // ignora e tenta fallback
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      final file = File('${downloads.path}/$nome');
      await file.writeAsBytes(bytes);
      return file.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$nome');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static String _short(String v) => v.length > 7 ? v.substring(v.length - 7) : v;

  static String _timestamp() {
    final f = DateFormat('yyyyMMdd_HHmmss');
    return f.format(DateTime.now());
  }
}
