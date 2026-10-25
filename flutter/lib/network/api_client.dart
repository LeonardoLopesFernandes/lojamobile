import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/constants.dart';
import 'session_manager.dart';

class ApiClient {
  final SessionManager sessionManager;
  final String baseUrl;
  final String platformVersion;

  ApiClient(this.sessionManager,
      {this.baseUrl = Constants.slBffBaseUrl,
      this.platformVersion = Constants.platformVersion});

  Map<String, String> buildHeaders() {
    final token = sessionManager.getToken();
    final storeId = sessionManager.getUserStore();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Store': 'minhaloja/$storeId',
      'Platform-Version': platformVersion,
      'Accept': 'application/json, text/plain, */*',
      'Origin': 'https://minhaloja.americanas.io',
      'Referer': 'https://minhaloja.americanas.io/',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path,
      {Map<String, String>? query,
      bool authenticated = true,
      Duration timeout = const Duration(seconds: 60)}) async {
    final uri = Uri.parse(baseUrl + path)
        .replace(queryParameters: query?.cast<String, String>());
    final response = await _withTimeout(
        http.get(uri, headers: buildHeaders()), timeout);
    return _process(response);
  }

  Future<dynamic> post(String path,
      {Map<String, dynamic>? body,
      bool authenticated = true,
      Duration timeout = const Duration(seconds: 60)}) async {
    final uri = Uri.parse(baseUrl + path);
    final response = await _withTimeout(
        http.post(uri,
            headers: buildHeaders(),
            body: body == null ? null : jsonEncode(body)),
        timeout);
    return _process(response);
  }

  Future<dynamic> put(String path,
      {Map<String, dynamic>? body,
      Duration timeout = const Duration(seconds: 60)}) async {
    final uri = Uri.parse(baseUrl + path);
    final response = await _withTimeout(
        http.put(uri, headers: buildHeaders(), body: jsonEncode(body)),
        timeout);
    return _process(response);
  }

  Future<dynamic> delete(String path,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final uri = Uri.parse(baseUrl + path);
    final response =
        await _withTimeout(http.delete(uri, headers: buildHeaders()), timeout);
    return _process(response);
  }

  /// Download de bytes (Excel da viagem).
  Future<List<int>> getBytes(String path,
      {Map<String, String>? query,
      Duration timeout = const Duration(seconds: 120)}) async {
    final uri = Uri.parse(baseUrl + path)
        .replace(queryParameters: query?.cast<String, String>());
    final response =
        await _withTimeout(http.get(uri, headers: buildHeaders()), timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<http.Response> _withTimeout(
      Future<http.Response> future, Duration timeout) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      throw ApiException(408, 'Tempo limite excedido. Tente novamente.');
    }
  }

  dynamic _process(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }
}

class ApiException implements Exception {
  final int code;
  final String body;
  ApiException(this.code, this.body);

  @override
  String toString() => "ApiException($code): $body";
}
