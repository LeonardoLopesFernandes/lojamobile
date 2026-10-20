import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:inventario/network/session_manager.dart';
import '../models/avaliacao.dart';
import '../models/bloqueio.dart';
import '../models/cupom.dart';
import 'troca_session.dart';

/// Cliente HTTP da Troca Fácil (bff-front).
///
/// O token (`authorization`) vem do login Microsoft da Troca Fácil (guardado
/// em [TrocaSession]); a loja vem da sessão principal. `loja` no header leva o
/// prefixo "L" (ex.: L291).
class TrocaApi {
  static const String baseUrl =
      'https://trocafacil-bff-front.americanas.io/bff-frontend';
  static const String _blockedBase =
      'https://trocafacil-bff-front.americanas.io';

  Future<Map<String, String>> _headers() async {
    final troca = await TrocaSession.create();
    final token = troca.getToken() ?? '';
    final session = await SessionManager.create();
    final store = session.getUserStore();
    return {
      'accept': 'application/json, text/plain, */*',
      'authorization': token,
      'loja': store,
      'permissions': 'LOJA_RESPONSAVEL',
      'origin': 'https://trocafacil.americanas.io',
      'referer': 'https://trocafacil.americanas.io/',
    };
  }

  Future<String> _storeRaw() async {
    final session = await SessionManager.create();
    // store sem o prefixo "L" (ex.: 291).
    return session.getUserStore().replaceFirst(RegExp('^L'), '');
  }

  /// Etiquetas têm 13 dígitos (com zero à esquerda). Mantém só dígitos e
  /// completa com zeros para o filtro do BFF casar.
  String _normalizarTag(String v) {
    final d = v.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? v : d.padLeft(13, '0');
  }

  /// Lista as operações/avaliações (endpoint /bff-trade/avaliations).
  Future<AvaliacoesPage> getAvaliacoes({
    required String startDate,
    required String finalDate,
    int sort = -1,
    int pageSize = 20,
    int page = 1,
    String? status,
    String? operation,
    String? cause,
    String? transactionDate,
    String? productName,
    String? costumerName,
    String? costumerDocument,
    String? tag,
    String? tradeId,
    String? origin,
  }) async {
    final session = await SessionManager.create();
    final store = session.getUserStore();
    final query = <String, String>{
      'startDate': startDate,
      'finalDate': finalDate,
      'store': store,
      'sort': '$sort',
      'pageSize': '$pageSize',
      'page': '$page',
      if (status != null && status.isNotEmpty) 'status': status,
      if (operation != null && operation.isNotEmpty) 'operation': operation,
      if (cause != null && cause.isNotEmpty) 'cause': cause,
      if (transactionDate != null && transactionDate.isNotEmpty)
        'transactionDate': transactionDate,
      if (productName != null && productName.isNotEmpty)
        'productName': productName,
      if (costumerName != null && costumerName.isNotEmpty)
        'costumerName': costumerName,
      if (costumerDocument != null && costumerDocument.isNotEmpty)
        'costumerDocument': costumerDocument,
      if (tag != null && tag.isNotEmpty) 'tag': _normalizarTag(tag),
      if (tradeId != null && tradeId.isNotEmpty) 'tradeId': tradeId,
      if (origin != null && origin.isNotEmpty) 'origin': origin,
    };
    final uri = Uri.parse('$baseUrl/bff-trade/avaliations')
        .replace(queryParameters: query);
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
    final body = resp.body.isEmpty
        ? <String, dynamic>{}
        : json.decode(resp.body) as Map<String, dynamic>;
    return AvaliacoesPage.fromJson(body);
  }

  /// Consulta uma operação/troca por id.
  Future<Map<String, dynamic>> getOperacao(String tradeId) async {
    final uri = Uri.parse('$baseUrl/bff-trade/operation/$tradeId');
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// Lista os itens bloqueados da loja (bff-item-blocked/listByStore).
  Future<BloqueioPage> listarBloqueios({
    int page = 1,
    int size = 10,
    int sort = -1,
    bool? answered,
  }) async {
    final session = await SessionManager.create();
    final store = session.getUserStore();
    final uri = Uri.parse('$_blockedBase/bff-item-blocked/listByStore');
    final headers = await _headers();
    headers['content-type'] = 'application/json';
    final resp = await http.post(uri,
        headers: headers,
        body: json.encode({
          'filter': {
            'page': page,
            'size': size,
            'answered': answered,
            'createdAt': null,
            'sort': sort,
          },
          'stores': [store],
        }));
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
    final body = resp.body.isEmpty
        ? <String, dynamic>{}
        : json.decode(resp.body) as Map<String, dynamic>;
    return BloqueioPage.fromJson(body);
  }

  /// Busca as informações do produto pelo EAN (bff-trade/infos-product).
  Future<List<ProductInfo>> infosProduct({required String ean}) async {
    final session = await SessionManager.create();
    final store = _storeNumeric(session.getUserStore());
    final uri = Uri.parse('$baseUrl/bff-trade/infos-product')
        .replace(queryParameters: {'store': store, 'ean': ean});
    final headers = await _headers();
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
    final raw = resp.body.isEmpty ? null : json.decode(resp.body);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => ProductInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  String _storeNumeric(String store) {
    final digits = store.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return store;
    return digits.padLeft(4, '0');
  }

  /// Cancela a operação/troca (PUT bff-trade/deleteTags).
  Future<void> cancelOperation({
    required String tradeId,
    required String avaliation,
    required List<String> tags,
    required String deletedBy,
  }) async {
    final uri = Uri.parse('$baseUrl/bff-trade/deleteTags');
    final headers = await _headers();
    headers['content-type'] = 'application/json';
    final resp = await http.put(uri,
        headers: headers,
        body: json.encode({
          'avaliation': avaliation,
          'id': tradeId,
          'tag': tags,
          'deletedBy': deletedBy,
          'groups': const ['LOJA_RESPONSAVEL'],
        }));
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
  }

  /// Consulta os dados do cupom (base-cupom/get_cupom).
  /// [storeId] sem prefixo "L" (ex.: 291).
  Future<Cupom> getCupom({
    required String storeId,
    required String pdv,
    required String data,
    required String cupom,
    String origin = 'FISICO',
    String cause = 'INSATISFACAO',
  }) async {
    final uri = Uri.parse('$baseUrl/base-cupom/get_cupom').replace(
      queryParameters: {
        'storeId': storeId,
        'pdv': pdv,
        'data': data,
        'cupom': cupom,
        'origin': origin,
        'cause': cause,
      },
    );
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Cupom não encontrado');
    }
    final body = resp.body.isEmpty
        ? <String, dynamic>{}
        : json.decode(resp.body) as Map<String, dynamic>;
    return Cupom.fromJson(body);
  }

  /// Perguntas de avaliação (bff-frontend/questions).
  /// [infosProduct] no formato "D034,L34010345;" (departamento,linha;) por item.
  Future<List<Map<String, dynamic>>> getQuestions({
    String operation = 'TROCA',
    String cause = 'INSATISFACAO',
    String origin = 'FISICO',
    required String infosProduct,
  }) async {
    final uri = Uri.parse('$baseUrl/questions').replace(queryParameters: {
      'operation': operation,
      'cause': cause,
      'origin': origin,
      'infosProduct': infosProduct,
    });
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
    final raw = resp.body.isEmpty ? const [] : json.decode(resp.body);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  /// Verifica se o cliente está bloqueado (bff-client/block-client/{cnpj}).
  /// [cnpj] só dígitos (ex.: 90259904104).
  Future<Map<String, dynamic>> getBlockClient(String cnpj) async {
    final uri = Uri.parse('$baseUrl/bff-client/block-client/$cnpj');
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(resp.statusCode, 'Erro ${resp.statusCode}');
    }
    if (resp.body.isEmpty) return const {};
    final body = json.decode(resp.body);
    return body is Map ? Map<String, dynamic>.from(body) : const {};
  }

  /// Finaliza a troca (bff-trade/finish-trade). Retorna o objeto da operação.
  Future<Map<String, dynamic>> finishTrade(Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/bff-trade/finish-trade');
    final headers = await _headers();
    headers['content-type'] = 'application/json';
    final resp = await http.post(uri,
        headers: headers, body: json.encode(body));
    if (resp.statusCode == 401) {
      throw TrocaApiException(401, 'Sessão expirada');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TrocaApiException(
          resp.statusCode, resp.body.isNotEmpty ? resp.body : 'Erro ${resp.statusCode}');
    }
    if (resp.body.isEmpty) return const {};
    final decoded = json.decode(resp.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }

  /// Formata data ISO/AAAA-MM-DDTHH:mm:ss em dd/MM/yyyy.
  static String fmtIsoDate(String iso) {
    if (iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Formata AAAAMMDD em dd/MM/yyyy.
  static String fmtCompactDate(String v) {
    if (v.length != 8) return v;
    return '${v.substring(6, 8)}/${v.substring(4, 6)}/${v.substring(0, 4)}';
  }
}

class TrocaApiException implements Exception {
  final int statusCode;
  final String message;
  TrocaApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
