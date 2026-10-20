import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Dados de uma etiqueta de bloqueio (um card por etiqueta).
class BloqueioEtiquetaItem {
  final String descricao;
  final String motivo;
  final String etiqueta;

  const BloqueioEtiquetaItem({
    required this.descricao,
    required this.motivo,
    required this.etiqueta,
  });
}

/// PDF da etiqueta de item bloqueado (layout do comprovante de bloqueio).
class BloqueioEtiquetaPdf {
  BloqueioEtiquetaPdf._();

  static Future<Uint8List> gerar({
    required String numeroOperacao,
    required String loja,
    required String dataBloqueio,
    required List<BloqueioEtiquetaItem> itens,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? icone;
    try {
      final b = await rootBundle.load('assets/drawables/troca.png');
      icone = pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {}
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => [
          for (final item in itens) ...[
            _card(
              numeroOperacao: numeroOperacao,
              loja: loja,
              dataBloqueio: dataBloqueio,
              descricao: item.descricao,
              motivo: item.motivo,
              numeroEtiqueta: item.etiqueta,
              icone: icone,
            ),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _card({
    required String numeroOperacao,
    required String loja,
    required String dataBloqueio,
    required String descricao,
    required String motivo,
    required String numeroEtiqueta,
    required pw.MemoryImage? icone,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFAFAFA),
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (icone != null) ...[
                pw.Container(
                  width: 44,
                  height: 44,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFEBEE),
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Image(icone, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(descricao,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Item bloqueado na loja $loja',
                        style: const pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Nº da operação',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: numeroOperacao,
                      width: 210,
                      height: 80,
                      drawText: true,
                      textStyle: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                            child: _info('Data do Bloqueio', dataBloqueio)),
                        pw.Expanded(
                            child: _info('Nº Etiqueta', numeroEtiqueta)),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    _info('Motivo do bloqueio', motivo),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _abas(),
        ],
      ),
    );
  }

  static pw.Widget _info(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _abas() {
    final ativo = PdfColor.fromInt(0xFFFF0033);
    final inativo = PdfColor.fromInt(0xFFFDE8ED);
    final txtInativo = PdfColor.fromInt(0xFF880E4F);
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            color: ativo,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Center(
              child: pw.Text('Bloqueio',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            color: inativo,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Center(
              child: pw.Text('Defeito na loja',
                  style: pw.TextStyle(
                      color: txtInativo,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }

  /// Gera e salva em Download/Troca. Retorna a URI salva (ou null).
  static Future<String?> salvarNoDownloads({
    required String numeroOperacao,
    required String loja,
    required String dataBloqueio,
    required List<BloqueioEtiquetaItem> itens,
  }) async {
    final bytes = await gerar(
      numeroOperacao: numeroOperacao,
      loja: loja,
      dataBloqueio: dataBloqueio,
      itens: itens,
    );
    final nome = itens.isNotEmpty && itens.first.etiqueta.isNotEmpty
        ? itens.first.etiqueta
        : numeroOperacao;
    const channel = MethodChannel('com.ir/media');
    return channel.invokeMethod<String>('saveToDownloads', {
      'fileName': 'etiqueta_bloqueio_$nome.pdf',
      'mime': 'application/pdf',
      'bytes': bytes,
      'subfolder': 'Troca',
    });
  }
}
