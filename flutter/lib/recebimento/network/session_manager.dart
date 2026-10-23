import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/brasil_risk.dart';

class SessionManager {
  static const String _prefsName = "RecebimentoPrefs";
  static const String _keyBearerToken = "BEARER_TOKEN";
  static const String _keyTokenExpiry = "TOKEN_EXPIRY";
  static const String _keyUserEmail = "USER_EMAIL";
  static const String _keyUserName = "USER_NAME";
  static const String _keyApelido = "USER_APELIDO";
  static const String _keyUserStore = "USER_STORE";
  static const String _keyRememberLogin = "REMEMBER_LOGIN";
  static const String _keyMsPassword = "MS_PASSWORD";
  static const String _keyBrlogRefreshToken = "BRLOG_REFRESH_TOKEN";
  static const String _keyBrlogProgress = "BRLOG_PROGRESS";
  static const String _keyBrlogNotas = "BRLOG_NOTAS";
  static const String _keyBrlogCodEmpresaUsuario = "BRLOG_COD_EMPRESA_USUARIO";
  static const String _keyProfilePhoto = "PROFILE_PHOTO";
  static const int _tokenExpiryDays = 14;

  final SharedPreferences _prefs;

  SessionManager(this._prefs);

  static Future<SessionManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionManager(prefs);
  }

  // ---------- BRLog ----------
  void saveBrlogRefreshToken(String token) =>
      _prefs.setString(_keyBrlogRefreshToken, token);

  String? getBrlogRefreshToken() => _prefs.getString(_keyBrlogRefreshToken);

  void saveBrlogProgress(Map<String, double> progresso) =>
      _prefs.setString(_keyBrlogProgress, jsonEncode(progresso));

  Map<String, double> getBrlogProgress() {
    final json = _prefs.getString(_keyBrlogProgress);
    if (json == null) return {};
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  void saveBrlogNotas(List<BrasilRiskNota> notas) =>
      _prefs.setString(_keyBrlogNotas, jsonEncode(notas.map((n) => _notaToMap(n)).toList()));

  List<BrasilRiskNota> getBrlogNotas() {
    final json = _prefs.getString(_keyBrlogNotas);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => BrasilRiskNota.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  void saveBrlogCodEmpresaUsuario(int cod) =>
      _prefs.setInt(_keyBrlogCodEmpresaUsuario, cod);

  int getBrlogCodEmpresaUsuario() =>
      _prefs.getInt(_keyBrlogCodEmpresaUsuario) ?? 0;

  // ---------- Token principal ----------
  void saveToken(String token) {
    _prefs.setString(_keyBearerToken, token);
    final expiry = DateTime.now()
        .add(const Duration(days: _tokenExpiryDays))
        .millisecondsSinceEpoch;
    _prefs.setInt(_keyTokenExpiry, expiry);
    _prefs.setBool(_keyRememberLogin, true);
  }

  void saveTokenWithExpiry(String token, {int? expiryEpochSeconds}) {
    final expiry = (expiryEpochSeconds != null
            ? expiryEpochSeconds * 1000
            : DateTime.now().millisecondsSinceEpoch +
                (_tokenExpiryDays * 24 * 60 * 60 * 1000))
        .clamp(
            DateTime.now().millisecondsSinceEpoch,
            DateTime.now()
                .add(const Duration(days: 365))
                .millisecondsSinceEpoch);
    _prefs.setString(_keyBearerToken, token);
    _prefs.setInt(_keyTokenExpiry, expiry);
    _prefs.setBool(_keyRememberLogin, true);
  }

  String? getToken() {
    final token = _prefs.getString(_keyBearerToken);
    if (token == null || token.isEmpty) return null;
    if (isTokenExpired()) {
      clearToken();
      return null;
    }
    return token;
  }

  bool isLoggedIn() {
    final remember = _prefs.getBool(_keyRememberLogin) ?? false;
    final token = getToken();
    return remember && token != null && token.isNotEmpty;
  }

  bool isTokenExpired() {
    final expiry = _prefs.getInt(_keyTokenExpiry) ?? 0;
    if (expiry == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expiry;
  }

  void clearToken() {
    _prefs.remove(_keyBearerToken);
    _prefs.remove(_keyTokenExpiry);
    _prefs.setBool(_keyRememberLogin, false);
  }

  void saveUserInfo(String email, String name, String store) {
    _prefs.setString(_keyUserEmail, email);
    _prefs.setString(_keyUserName, name);
    _prefs.setString(_keyUserStore, store);
  }

  String? getUserEmail() => _prefs.getString(_keyUserEmail);
  String getUserStore() => _prefs.getString(_keyUserStore) ?? "L291";
  String? getUserName() => _prefs.getString(_keyUserName);
  void saveUserName(String name) => _prefs.setString(_keyUserName, name);
  String? getApelido() => _prefs.getString(_keyApelido);
  void saveApelido(String apelido) => _prefs.setString(_keyApelido, apelido);

  void saveProfilePhoto(String path) =>
      _prefs.setString(_keyProfilePhoto, path);

  String? getProfilePhoto() => _prefs.getString(_keyProfilePhoto);

  void clearProfilePhoto() => _prefs.remove(_keyProfilePhoto);

  void saveCredentials(String email, String password) {
    _prefs.setString(_keyUserEmail, email);
    _prefs.setString(_keyMsPassword, password);
  }

  String? getSavedPassword() => _prefs.getString(_keyMsPassword);

  bool hasSavedCredentials() {
    final email = getUserEmail();
    final senha = getSavedPassword();
    return email != null &&
        email.isNotEmpty &&
        senha != null &&
        senha.isNotEmpty;
  }

  void clearCredentials() => _prefs.remove(_keyMsPassword);

  /// Logout preserva as pastas de fotos (FOTOS_PASTAS): são dados do
  /// aparelho/loja, não da conta — sem isso as pastas (e as fotos
  /// renomeadas) sumiam da tela Imagens ao deslogar.
  void clearAll() {
    final fotos = _prefs.getString('FOTOS_PASTAS');
    _prefs.clear();
    if (fotos != null) _prefs.setString('FOTOS_PASTAS', fotos);
  }
}

Map<String, dynamic> _notaToMap(BrasilRiskNota n) => {
      'CodPedido': n.codPedido,
      'CodPedidoDestino': n.codPedidoDestino,
      'CodPedidoOcorrenciaTipo': n.codPedidoOcorrenciaTipo,
      'CodEmpresaUsuario': n.codEmpresaUsuario,
      'NumeroViagem': n.numeroViagem,
      'ProgressoViagem': n.progressoViagem,
      'CodStatusDaEntrega': n.codStatusDaEntrega,
      'StatusDaViagem': n.statusDaViagem,
      'DataDeSaida': n.dataDeSaida,
      'DataIniciado': n.dataIniciado,
      'DistanciaRestante': n.distanciaRestante,
      'DistanciaTotalPrevista': n.distanciaTotalPrevista,
      'DistanciaPercorrida': n.distanciaPercorrida,
      'NomeMotorista': n.nomeMotorista,
      'Placa': n.placa,
      'Carreta': n.carreta,
      'PrevisaoChegada': n.previsaoChegada,
      'PrevisaoChegadaRecalculada': n.previsaoChegadaRecalculada,
      'DtPrevisaoEntrega': n.dtPrevisaoEntrega,
      'DataChegadaOrigemRecalculada': n.dataChegadaOrigemRecalculada,
      'DataConclusao': n.dataConclusao,
      'DataEntrega': n.dataEntrega,
      'DataDeEntregaNF': n.dataDeEntregaNF,
      'Status': n.status,
    };
