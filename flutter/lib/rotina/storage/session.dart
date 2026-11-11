import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventario/rotina/types.dart';

class Session {
  static const String _token = 'auth_token';
  static const String _tokenExpiry = 'token_expiry';
  static const String _remember = 'remember_login';
  static const String _email = 'user_email';
  static const String _password = 'ms_password';
  static const String _name = 'user_name';
  static const int _tokenExpiryDays = 14;
  static const String _treatmentKey = 'treatments';
  static const String _proxy = 'http_proxy';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await _instance;
    var expiryMs = DateTime.now().millisecondsSinceEpoch +
        _tokenExpiryDays * 86400000;
    // Respeita o `exp` real do JWT da Rotina. Antes o token era considerado
    // válido por 14 dias mesmo quando o JWT expirava antes, causando o 401
    // "Token expirado" dentro da Rotina.
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final claims = jsonDecode(utf8.decode(base64.decode(p)));
        if (claims is Map && claims['exp'] is int) {
          expiryMs = (claims['exp'] as int) * 1000;
        }
      }
    } catch (_) {}
    await prefs.setString(_token, token);
    await prefs.setString(_tokenExpiry, expiryMs.toString());
    await prefs.setString(_remember, 'true');
  }

  static Future<String?> getToken() async {
    final prefs = await _instance;
    final token = prefs.getString(_token);
    if (token == null) return null;
    final expiryStr = prefs.getString(_tokenExpiry);
    if (expiryStr != null) {
      final expiry = int.tryParse(expiryStr);
      if (expiry != null && expiry < DateTime.now().millisecondsSinceEpoch) {
        await clearToken();
        return null;
      }
    }
    return token;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await _instance;
    final remember = prefs.getString(_remember);
    final token = await getToken();
    return remember == 'true' && token != null;
  }

  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await _instance;
    await prefs.setString(_email, email);
    await prefs.setString(_password, password);
  }

  static Future<String> getSavedEmail() async {
    final prefs = await _instance;
    return prefs.getString(_email) ?? '';
  }

  static Future<String> getSavedPassword() async {
    final prefs = await _instance;
    return prefs.getString(_password) ?? '';
  }

  static Future<bool> hasSavedCredentials() async {
    final email = await getSavedEmail();
    final password = await getSavedPassword();
    return email.trim().isNotEmpty && password.trim().isNotEmpty;
  }

  static Future<void> saveProxy(String proxy) async {
    final prefs = await _instance;
    await prefs.setString(_proxy, proxy.trim());
  }

  static Future<String> getProxy() async {
    final prefs = await _instance;
    return prefs.getString(_proxy) ?? '';
  }

  static Future<void> clearCredentials() async {
    final prefs = await _instance;
    await prefs.remove(_password);
  }

  static Future<void> saveUserName(String name) async {
    if (name.isNotEmpty) {
      final prefs = await _instance;
      await prefs.setString(_name, name);
    }
  }

  static Future<String> getUserName() async {
    final prefs = await _instance;
    return prefs.getString(_name) ?? '';
  }

  static Future<void> clearToken() async {
    final prefs = await _instance;
    await prefs.remove(_token);
    await prefs.remove(_tokenExpiry);
    await prefs.remove(_remember);
  }

  static Future<void> clearAll() async {
    final prefs = await _instance;
    await prefs.clear();
  }

  static Future<void> saveTreatment(
      String date, String ean, StoredTreatment item) async {
    final prefs = await _instance;
    final raw = prefs.getString(_treatmentKey);
    final map = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      map.addAll(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    }
    map['$date:$ean'] = item.toJson();
    await prefs.setString(_treatmentKey, jsonEncode(map));
  }

  static Future<StoredTreatment?> loadTreatment(String date, String ean) async {
    final prefs = await _instance;
    final raw = prefs.getString(_treatmentKey);
    if (raw == null || raw.isEmpty) return null;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final json = map['$date:$ean'] as Map<String, dynamic>?;
    if (json == null) return null;
    return StoredTreatment.fromJson(json);
  }

  static Future<Map<String, StoredTreatment>> loadAllTreatments(String date) async {
    final prefs = await _instance;
    final raw = prefs.getString(_treatmentKey);
    if (raw == null || raw.isEmpty) return {};
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final result = <String, StoredTreatment>{};
    final prefix = '$date:';
    for (final entry in map.entries) {
      if (entry.key.startsWith(prefix)) {
        final ean = entry.key.substring(prefix.length);
        result[ean] = StoredTreatment.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return result;
  }

  static bool _hasInvalidApiAnswers(Item item) {
    return item.answers != null &&
        item.answers!.isNotEmpty &&
        item.answers!.every((a) => a.number == 0);
  }

  static Item applyStoredToItem(StoredTreatment? stored, Item item) {
    if (stored == null || !stored.treated) {
      return item;
    }
    final mergedAnswers = stored.answers != null && stored.answers!.isNotEmpty
        ? stored.answers
        : (item.answers != null &&
                item.answers!.isNotEmpty &&
                !_hasInvalidApiAnswers(item)
            ? item.answers
            : item.answers);
    return item.copyWith(
      treated: true,
      treatedAt: stored.treatedAt ?? item.treatedAt,
      treatedBy: stored.treatedBy ?? item.treatedBy,
      answers: mergedAnswers,
    );
  }

  static Future<Item> applyToItem(String date, Item item) async {
    final stored = await loadTreatment(date, item.ean);
    return applyStoredToItem(stored, item);
  }
}
