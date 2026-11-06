import 'dart:typed_data';
import '../models/recebimento.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient client;

  ApiService(this.client);

  Future<RecebimentoResponse> getRecebimentos({
    required String storeId,
    required String status,
    String? search,
    String sort = "asc",
    int page = 1,
  }) async {
    final query = <String, String>{
      'status': status,
      'sort': sort,
      'page': page.toString(),
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    final json = await client.get('web/recebimento/$storeId',
        query: query) as Map<String, dynamic>;
    return RecebimentoResponse.fromJson(json);
  }

  Future<DetalhesViagemResponse> getDetalhesViagem(
      String storeId, String viagemId) async {
    final json = await client.get('web/recebimento/$storeId/$viagemId')
        as Map<String, dynamic>;
    return DetalhesViagemResponse.fromJson(json);
  }

  Future<ProtocoloResponse> gerarProtocolo(
      String storeId, ProtocoloRequest request) async {
    final json = await client.post('web/recebimento/$storeId',
        body: request.toJson()) as Map<String, dynamic>;
    return ProtocoloResponse.fromJson(json);
  }

  Future<ImpressaoResponse> imprimirViagem(
      String storeId, String viagemId) async {
    final json = await client.get('web/recebimento/print/$storeId/$viagemId')
        as Map<String, dynamic>;
    return ImpressaoResponse.fromJson(json);
  }

  Future<Uint8List> gerarExcelViagem(
      String storeId, String viagemId) async {
    final bytes = await client.getBytes(
        'web/recebimento/planilha/$storeId/$viagemId');
    return Uint8List.fromList(bytes);
  }

  /// EAN do produto consultado pela etiqueta avulsa do Minha Loja.
  Future<String> getEanBySap(String storeId, String sap) async {
    // O Minha Loja busca SAP sem os zeros à esquerda.
    final digitos = sap.replaceAll(RegExp(r'\D'), '');
    final sapLimpo = digitos.replaceFirst(RegExp(r'^0+'), '');
    if (sapLimpo.isEmpty) return '';

    final hoje = DateTime.now();
    final data = '${hoje.year.toString().padLeft(4, '0')}-'
        '${hoje.month.toString().padLeft(2, '0')}-'
        '${hoje.day.toString().padLeft(2, '0')}';

    final candidatos = <String>{sapLimpo, sap.trim()};

    for (final candidato in candidatos) {
      if (candidato.isEmpty) continue;
      final ean = await _consultarEan(
        'web/price-tag/store/$storeId/single-label-printing',
        {'startDate': data, 'sapId': candidato},
      );
      if (ean.isNotEmpty) return ean;
    }

    // Fallback para a papeleta avulsa, que usa a mesma base de produto.
    for (final candidato in candidatos) {
      if (candidato.isEmpty) continue;
      final ean = await _consultarEan(
        'web/price-sign/store/$storeId/standalone',
        {'type': 'PAPELETA_COMUM', 'startDate': data, 'sapId': candidato},
      );
      if (ean.isNotEmpty) return ean;
    }

    return '';
  }

  Future<String> _consultarEan(
      String path, Map<String, String> query) async {
    try {
      final json = await client.get(path, query: query) as Map<String, dynamic>;
      final itens = json['items'] as List? ?? [];
      for (final item in itens) {
        final ean = _extrairEan(item);
        if (ean.isNotEmpty) return ean;
      }
    } catch (_) {}
    return '';
  }

  String _extrairEan(dynamic item) {
    if (item is! Map) return '';
    var ean = item['ean']?.toString().trim() ?? '';
    if (ean.isEmpty && item['printingData'] is Map) {
      ean = (item['printingData']['ean']?.toString() ?? '').trim();
    }
    if (ean.isEmpty && item['_printingData'] is Map) {
      ean = (item['_printingData']['ean']?.toString() ?? '').trim();
    }
    return ean;
  }
}
