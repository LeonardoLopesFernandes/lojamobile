import 'api_client.dart';
import 'api_service.dart';
import 'session_manager.dart';

/// Busca o EAN pela etiqueta avulsa do Minha Loja usando o SAP.
class EanResolver {
  static final Map<String, String> _cache = {};
  static final Map<String, Future<String>> _pendentes = {};
  static Future<ApiService>? _apiFuture;
  static String? _storeId;

  static Future<String> bySap(String sap) {
    final chave = sap.trim();
    if (chave.isEmpty) return Future.value('');

    final emCache = _cache[chave];
    if (emCache != null) return Future.value(emCache);

    final pendente = _pendentes[chave];
    if (pendente != null) return pendente;

    final futuro = _buscar(chave);
    _pendentes[chave] = futuro;
    futuro.whenComplete(() => _pendentes.remove(chave));
    return futuro;
  }

  static Future<String> _buscar(String sap) async {
    try {
      final api = await _servico();
      final ean = await api.getEanBySap(_storeId!, sap);
      if (ean.isNotEmpty) _cache[sap] = ean;
      return ean;
    } catch (_) {
      return '';
    }
  }

  static Future<ApiService> _servico() {
    return _apiFuture ??= _criarServico();
  }

  static Future<ApiService> _criarServico() async {
    final session = await SessionManager.create();
    _storeId = session.getUserStore();
    return ApiService(ApiClient(session));
  }
}
