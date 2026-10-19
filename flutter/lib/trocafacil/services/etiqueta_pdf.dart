import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
/// Gera o PDF do comprovante/etiqueta de troca (layout do site) e salva em
/// `Download/Troca` via canal nativo com MediaStore.
class TrocaEtiquetaPdf {
  TrocaEtiquetaPdf._();

  static Future<Uint8List> gerar({
    required String labelNumber,
    required String tradeId,
    required String loja,
    required String data,
    required String produto,
    required String motivo,
    required String modalidade,
    required String cause,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? icone;
    try {
      final bytes = await rootBundle.load('assets/drawables/troca.png');
      icone = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => [
          _card1(
            loja: loja,
            data: data,
            tradeId: tradeId,
            produto: produto,
            modalidade: modalidade,
            icone: icone,
          ),
          pw.SizedBox(height: 12),
          _card2(
            loja: loja,
            data: data,
            tradeId: tradeId,
            labelNumber: labelNumber,
            produto: produto,
            motivo: motivo,
            modalidade: modalidade,
          ),
          pw.SizedBox(height: 12),
          _abas(cause),
        ],
      ),
    );
    return doc.save();
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

  static pw.Widget _card1({
    required String loja,
    required String data,
    required String tradeId,
    required String produto,
    required String modalidade,
    pw.MemoryImage? icone,
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
                    pw.Text('Comprovante de recebimento de troca',
                        style: pw.TextStyle(
                            fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text('Item recebido na loja $loja',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
              if (modalidade.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFCE4EC),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(modalidade,
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF880E4F))),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _info('Recebido em loja no dia', data)),
              pw.Expanded(child: _info('Número de operação', tradeId)),
              pw.Expanded(
                  child: _info('Modalidade da Operação', 'Troca Física')),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Descrição completa dos itens devolvidos:',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text('(1x) $produto',
              style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _card2({
    required String loja,
    required String data,
    required String tradeId,
    required String labelNumber,
    required String produto,
    required String motivo,
    required String modalidade,
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
          pw.Text(produto,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Item recebido na loja $loja',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
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
                      data: tradeId,
                      width: 210,
                      height: 80,
                      drawText: true,
                      textStyle: const pw.TextStyle(fontSize: 9),
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
                        pw.Expanded(child: _info('Recebido em loja', data)),
                        pw.Expanded(child: _info('Nº Etiqueta', labelNumber)),
                        if (modalidade.isNotEmpty)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFFCE4EC),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Text(modalidade,
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColor.fromInt(0xFFAD1457),
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    _info('Descrição do motivo', motivo),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _abas(String cause) {
    final defeito = cause.toUpperCase() == 'DEFEITO';
    final ativo = PdfColor.fromInt(0xFFFF0033);
    final inativo = PdfColor.fromInt(0xFFFDE8ED);
    final txtInativo = PdfColor.fromInt(0xFF880E4F);
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            color: defeito ? inativo : ativo,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Center(
              child: pw.Text('Troca',
                  style: pw.TextStyle(
                      color: defeito ? txtInativo : PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            color: defeito ? ativo : inativo,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Center(
              child: pw.Text('Defeito',
                  style: pw.TextStyle(
                      color: defeito ? PdfColors.white : txtInativo,
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
    required String labelNumber,
    required String tradeId,
    required String loja,
    required String data,
    required String produto,
    required String motivo,
    required String modalidade,
    required String cause,
  }) async {
    final bytes = await gerar(
      labelNumber: labelNumber,
      tradeId: tradeId,
      loja: loja,
      data: data,
      produto: produto,
      motivo: motivo,
      modalidade: modalidade,
      cause: cause,
    );
    const channel = MethodChannel('com.ir/media');
    return channel.invokeMethod<String>('saveToDownloads', {
      'fileName': 'etiqueta_$labelNumber.pdf',
      'mime': 'application/pdf',
      'bytes': bytes,
      'subfolder': 'Troca',
    });
  }
}
