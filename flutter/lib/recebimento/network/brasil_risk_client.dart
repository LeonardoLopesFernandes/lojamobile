import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/brasil_risk.dart';

class BrasilRiskClient {
  static const String baseUrl = Constants.brasilRiskBaseUrl;

  Future<BrasilRiskLoginResponse> loginMicrosoft(TokenBody body) async {
    final uri = Uri.parse(baseUrl + 'validar/LoginMobileDeliveryClientMicrosoft');
    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body.toJson()));
    return BrasilRiskLoginResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<BrasilRiskNotaDetalhe> obterInformacoesNotaCliente(
      int? codEmpresaUsuario, int? codPedido) async {
    final query = <String, String>{
      'CodEmpresaUsuario': (codEmpresaUsuario ?? 0).toString(),
      'CodPedido': (codPedido ?? 0).toString(),
    };
    final uri = Uri.parse(baseUrl + 'listar/ObterInformacoesNotaCliente')
        .replace(queryParameters: query);
    final response = await http.get(uri);
    return BrasilRiskNotaDetalhe.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<BrasilRiskBauResponse> autorizarAberturaBau(
      AutorizarAberturaBauRequest request) async {
    final uri = Uri.parse(baseUrl + 'salvar/AutorizarAberturaBau');
    final response = await http
        .post(uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()))
        .timeout(const Duration(seconds: 20));
    final texto = response.body.trim();
    Map<String, dynamic> json = const {};
    if (texto.isNotEmpty) {
      try {
        final decoded = jsonDecode(texto);
        if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        } else if (decoded is bool) {
          json = {'AberturaBauAutorizada': decoded};
        } else if (decoded is String) {
          json = {'Mensagem': decoded};
        }
      } catch (_) {
        json = {'Mensagem': texto};
      }
    }
    return BrasilRiskBauResponse.fromJson(
      json,
      httpStatus: response.statusCode,
      rawBody: texto,
    );
  }
}
