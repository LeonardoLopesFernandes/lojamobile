import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Gera um PDF em formato de relatório/tabela com os itens da lista.
/// Colunas: Quantidade, EAN, SAP, Descrição. Depois oferece compartilhamento.
class ListaPdfService {
  ListaPdfService._();

  /// Gera o PDF com os [itens]. Cada item usa a quantidade selecionada.
  static Future<Uint8List> gerarRelatorioEtiquetas(List<PriceTag> itens) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Relatório de Etiquetas',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${itens.length} ${itens.length == 1 ? 'item' : 'itens'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _tabelaEtiquetas(itens),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total de etiquetas: ${itens.fold<int>(0, (s, t) => s + t.quantity)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Gera o PDF e oferece o compartilhamento do arquivo.
  static Future<void> compartilharRelatorioEtiquetas(
      List<PriceTag> itens) async {
    final bytes = await gerarRelatorioEtiquetas(itens);
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/relatorio_etiquetas_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf');
    await _escreverArquivo(arquivo, bytes);
    await Share.shareXFiles(
      [XFile(arquivo.path, mimeType: 'application/pdf')],
      text: 'Relatório de Etiquetas',
    );
  }

  /// Gera o PDF a partir de itens de papeletas (PriceSign).
  static Future<Uint8List> gerarRelatorioPapeletas(
      List<PriceSign> itens) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Relatório de Papeletas',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${itens.length} ${itens.length == 1 ? 'item' : 'itens'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Quantidade', 'EAN', 'SAP', 'Descrição'],
            data: [
              for (final s in itens)
                [
                  s.quantity.toString(),
                  s.ean,
                  s.sap,
                  s.description,
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.red700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(100),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FlexColumnWidth(),
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total de papeletas: ${itens.fold<int>(0, (s, t) => s + t.quantity)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> compartilharRelatorioPapeletas(
      List<PriceSign> itens) async {
    final bytes = await gerarRelatorioPapeletas(itens);
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/relatorio_papeletas_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf');
    await _escreverArquivo(arquivo, bytes);
    await Share.shareXFiles(
      [XFile(arquivo.path, mimeType: 'application/pdf')],
      text: 'Relatório de Papeletas',
    );
  }

  /// Tabela do relatório de etiquetas: QTD, EAN, DESCRIÇÃO, CÓDIGO DE BARRAS
  /// (Code 128 gerado a partir do EAN).
  static pw.Widget _tabelaEtiquetas(List<PriceTag> itens) {
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 10,
    );
    const cellStyle = pw.TextStyle(fontSize: 9);

    pw.Widget cell(pw.Widget child, {pw.Alignment? align}) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Align(
            alignment: align ?? pw.Alignment.center,
            child: child,
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FixedColumnWidth(90),
        2: const pw.FlexColumnWidth(),
        3: const pw.FixedColumnWidth(190),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.red700),
          children: [
            cell(pw.Text('QTD', style: headerStyle, textAlign: pw.TextAlign.center)),
            cell(pw.Text('COD EAN', style: headerStyle, textAlign: pw.TextAlign.center)),
            cell(pw.Text('DESCRIÇÃO', style: headerStyle, textAlign: pw.TextAlign.center)),
            cell(pw.Text('CÓDIGO DE BARRAS', style: headerStyle, textAlign: pw.TextAlign.center)),
          ],
        ),
        for (final t in itens)
          pw.TableRow(
            children: [
              cell(pw.Text(t.quantity.toString(), style: cellStyle, textAlign: pw.TextAlign.center)),
              cell(pw.Text(t.ean, style: cellStyle, textAlign: pw.TextAlign.center)),
              cell(pw.Text(t.description, style: cellStyle, textAlign: pw.TextAlign.center)),
              cell(pw.SizedBox(
                width: 175,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(t.description,
                        style: cellStyle, textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 2),
                    pw.BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: t.ean,
                      width: 175,
                      height: 34,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(t.ean,
                        style: cellStyle, textAlign: pw.TextAlign.center),
                  ],
                ),
              )),
            ],
          ),
      ],
    );
  }

  static Future<void> _escreverArquivo(File arquivo, Uint8List bytes) async {
    await arquivo.writeAsBytes(bytes, flush: true);
  }
}