import 'package:dio/dio.dart';
import 'package:inventario/rotina/api/cronet_adapter.dart';
import 'package:inventario/rotina/storage/session.dart';

/// Proxy detectado do sistema Android em runtime (ex.: '192.168.1.10:8080').
/// Em muitas redes corporativas o app precisa do proxy para alcançar a BFF.
String _systemProxy = '';

void setSystemProxy(String proxy) {
  _systemProxy = proxy;
}

const String baseUrl = 'https://rotina-comercial-bff.americanas.io/';
const String appOrigin = 'https://rotina-comercial.americanas.io';

String? _authToken;
bool _autoLoginTriggered = false;
void Function()? _onSessionExpired;

void setAuthToken(String token) {
  _authToken = _normalizeToken(token);
  if (_authToken != null && _authToken!.isNotEmpty) {
    _autoLoginTriggered = false;
  }
}

String? _normalizeToken(String token) {
  var t = token.trim();
  if (t.toLowerCase().startsWith('bearer ')) {
    t = t.substring(7).trim();
  }
  return t.isEmpty ? null : t;
}

String? getAuthToken() => _authToken;

void clearToken() {
  _authToken = null;
}

void setOnSessionExpired(void Function() handler) {
  _onSessionExpired = handler;
}

Future<void> _handleSessionExpired() async {
  if (_autoLoginTriggered) return;
  _autoLoginTriggered = true;
  clearToken();
  await Session.clearToken();
  _onSessionExpired?.call();
}

final Dio apiClient = Dio(BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: const Duration(seconds: 60),
  receiveTimeout: const Duration(seconds: 180),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'x-requested-with': 'com.rotina.rotina_comercial',
    'Origin': appOrigin,
    'Referer': '$appOrigin/',
  },
));

/// Usa a pilha de rede do Chromium (Cronet) — idêntica à do navegador —
/// para driblar WAF/Akamai/bot-management e respeitar o proxy do sistema.
void _applyTransport() {
  try {
    apiClient.httpClientAdapter = cronetAdapter;
  } catch (_) {
    // Sem Cronet disponível: mantém o adaptador padrão do Dio.
  }
}

/// Reaplica o transporte em runtime (mantido para API de compatibilidade).
void reapplyProxy() {
  _applyTransport();
}

void _refreshTokenFromHeaders(Headers? headers) {
  if (headers == null) return;
  final setCookie = headers['set-cookie'];
  if (setCookie == null) return;
  for (final cookie in setCookie) {
    final idx = cookie.indexOf('rc-newToken=');
    if (idx >= 0) {
      var value = cookie.substring(idx + 'rc-newToken='.length);
      final sep = value.indexOf(';');
      if (sep >= 0) value = value.substring(0, sep);
      value = value.trim();
      if (value.isNotEmpty && value.length > 20) {
        setAuthToken(value);
      }
      break;
    }
  }
}

void setupApiInterceptors() {
  _applyTransport();
  apiClient.interceptors.clear();
  apiClient.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (_authToken != null && _authToken!.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $_authToken';
        // Replicar o cookie que o navegador envia (algumas redes/WAF exigem).
        options.headers['Cookie'] = 'rc-newToken=$_authToken';
      }
      return handler.next(options);
    },
    onResponse: (response, handler) {
      _refreshTokenFromHeaders(response.headers);
      return handler.next(response);
    },
    onError: (error, handler) async {
      _refreshTokenFromHeaders(error.response?.headers);
      if (error.response?.statusCode == 401 && _authToken != null) {
        await _handleSessionExpired();
      }
      return handler.next(error);
    },
  ));
}

String mapErrorMessage(Object error) {
  final message = error is DioException
      ? error.message ?? 'Erro'
      : error.toString();
  if (message.contains('401')) return '❌ Token expirado! Faça login novamente.';
  if (message.contains('403')) return '❌ Acesso negado!';
  if (message.contains('500')) return '❌ Erro no servidor (500). Tente novamente.';
  if (message.contains('conexão') || message.contains('Connection')) {
    return '❌ Sem conexão com a internet.';
  }
  return '❌ $message';
}

String mapGenericError(Object error) {
  final message = error is DioException
      ? error.message ?? 'Erro'
      : error.toString();
  if (message.contains('400') || message.contains('409')) {
    return '⚠️ Este item já foi respondido. Recarregue a lista.';
  }
  return '❌ $message';
}

String errorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status != null && status != 401) {
      return 'Erro $status';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Erro de conexão: timeout';
    }
  }
  final message = error is DioException ? error.message ?? '' : error.toString();
  if (message.contains('Network Error') || message.contains('conexão')) {
    return 'Erro de conexão: sem internet';
  }
  return message;
}
