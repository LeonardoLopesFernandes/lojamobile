class Constants {
  static const String defaultStore = "L291";

  // Status de Recebimento
  static const String statusPendente = "pendente";
  static const String statusAnomalia = "anomalia";
  static const String statusErro = "erro";
  static const String statusRecebido = "recebido";

  // URLs - minhaloja-bff
  static const String baseUrl = "https://minhaloja-bff.americanas.io/";
  static const String slBaseUrl = "https://sl-bff.americanas.io/";

  // BrasilRisk
  static const String brasilRiskBaseUrl = "https://apimobile.brasilrisk.com.br/";

  // Microsoft OAuth (BRLog)
  static const String tenant = "e316d1ac-42c8-4d30-817c-12c7a71f8ab2";
  static const String clientId = "16021f31-43f8-4f7a-8af4-5e47efe7db8a";
  static const String clientSecret =
      const String.fromEnvironment('MICROSOFT_CLIENT_SECRET', defaultValue: '');
  static const String scopes = "openid profile offline_access Files.ReadWrite";
  // Escopo exato do app BRLog (sem Files.ReadWrite, que exige consentimento
  // de administrador no tenant e o app normal nao solicita).
  static const String brlogScopes = "openid profile offline_access";
  static const String redirectUri =
      "https://apimobile.brasilrisk.com.br/Validar/SamlResponseConsumer";
  static const String authorizeUrl =
      "https://login.microsoftonline.com/$tenant/oauth2/v2.0/authorize";
  static const String tokenUrl =
      "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token";

  // Cores
  static const int primaryRed = 0xFFC62828;
  static const int primaryRedDark = 0xFFB2072E;
  static const int headerRed = 0xFFC62828;
  static const int badgeGreen = 0xFF2E7D32;
  static const int badgeRed = 0xFFF44336;
  static const int badgeAmber = 0xFFFFC107;
  static const int textDark = 0xFF2D3748;
  static const int textGray = 0xFF718096;
  static const int bgGray = 0xFFF4F6F8;
  static const int borderColor = 0xFFE2E8F0;
  static const int greenBand = 0xFFE8F5E9;

  // Departamentos de risco
  static const Set<String> riscos = {
    "008",
    "025",
    "027",
    "030",
    "063",
    "067"
  };
}
