import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

const _texto = Color(0xFF424957);

/// Visualização nativa do PDF da etiqueta, com ações de compartilhar/imprimir.
class EtiquetaPreviewScreen extends StatelessWidget {
  final String titulo;
  final Uint8List bytes;

  const EtiquetaPreviewScreen({
    super.key,
    required this.titulo,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _texto),
        title: Text(
          titulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        useActions: true,
        pdfFileName: 'etiqueta.pdf',
      ),
    );
  }
}
