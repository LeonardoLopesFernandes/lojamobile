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
    if (sap.trim().isEmpty) return '';
    try {
      final hoje = DateTime.now();
      final data = '${hoje.year.toString().padLeft(4, '0')}-'
          '${hoje.month.toString().padLeft(2, '0')}-'
          '${hoje.day.toString().padLeft(2, '0')}';
      final json = await client.get(
        'web/price-tag/store/$storeId/single-label-printing',
        query: {'startDate': data, 'sapId': sap.trim()},
      ) as Map<String, dynamic>;
      final itens = json['items'] as List? ?? [];
      for (final item in itens) {
        if (item is Map) {
          final ean = item['ean']?.toString() ?? '';
          if (ean.isNotEmpty) return ean;
        }
      }
    } catch (_) {}
    return '';
  }
}
