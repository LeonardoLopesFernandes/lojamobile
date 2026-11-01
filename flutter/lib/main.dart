import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_navigator.dart';
import 'widgets/truck_loader.dart';
import 'widgets/voltar_hubs_guard.dart';
import 'utils/constants.dart';
import 'network/session_manager.dart';
import 'auth/hub_tokens.dart';
import 'screens/login_screen.dart';
import 'screens/login_webview_screen.dart';
import 'screens/lista_inventario_screen.dart';
import 'screens/quebra_screen.dart';
import 'screens/quebras_menu_screen.dart';
import 'screens/precificacao_menu_screen.dart';
import 'screens/home_hub_screen.dart';
import 'trocafacil/screens/troca_facil_menu_screen.dart';
import 'trocafacil/screens/realizar_troca_etapa1_screen.dart';
import 'trocafacil/screens/realizar_troca_etapa2_screen.dart';
import 'trocafacil/screens/realizar_troca_itens_screen.dart';
import 'trocafacil/screens/avaliacao_produto_screen.dart';
import 'trocafacil/screens/lista_operacoes_screen.dart';
import 'trocafacil/screens/filtrar_operacoes_screen.dart';
import 'trocafacil/screens/troca_login_webview.dart';
import 'trocafacil/screens/troca_etiqueta_screen.dart';
import 'trocafacil/screens/lista_bloqueios_screen.dart';
import 'trocafacil/screens/bloquear_item_screen.dart';
import 'precificacao/screens/etiquetas/etiquetas_fragment.dart';
import 'precificacao/screens/etiquetas/etiquetas_screen.dart';
import 'precificacao/screens/papeletas/papeletas_fragment.dart';
import 'precificacao/screens/papeletas/papeletas_diarias_screen.dart';
import 'precificacao/screens/barcode/barcode_scanner_screen.dart';
import 'precificacao/screens/etiquetas/gondola_editavel_screen.dart';
import 'precificacao/screens/modelo/modelo_editavel_screen.dart';
import 'precificacao/screens/pdf/pdf_viewer_screen.dart';
import 'precificacao/models/models.dart' as prec_models;
import 'recebimento/screens/home_screen.dart';
import 'recebimento/screens/detalhes_viagem_screen.dart';
import 'recebimento/screens/itens_screen.dart';
import 'recebimento/screens/fotos_recebimento_screen.dart';
import 'recebimento/screens/imagens_recebimento_screen.dart';
import 'screens/profile_screen.dart';
import 'rotina/rotina_hub_screen.dart';
import 'rotina/screens/department_detail_screen.dart';
import 'rotina/screens/special_items_screen.dart';
import 'rotina/screens/dashboard_screen.dart';
import 'precificacao/core/session_manager.dart' as prec_session;
import 'precificacao/network/api_client.dart' as prec_api;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final precSession = await prec_session.SessionManager.getInstance();
  prec_api.ApiClient.instance.init(precSession);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Loja Mobile',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        primaryColor: const Color(Constants.primaryRed),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(Constants.primaryRed),
          primary: const Color(Constants.primaryRed),
        ),
        scaffoldBackgroundColor: const Color(Constants.bgGray),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(Constants.primaryRed),
          foregroundColor: Colors.white,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        datePickerTheme:
            const DatePickerThemeData(backgroundColor: Colors.white),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashDecider(),
        '/login': (ctx) => const LoginScreen(),
        '/login_webview': (ctx) => const LoginWebViewScreen(),
        '/inventario': (ctx) => const VoltarHubsGuard(child: ListaInventarioScreen()),
        '/quebras': (ctx) => const VoltarHubsGuard(child: QuebrasMenuScreen()),
        '/precificacao': (ctx) => const VoltarHubsGuard(child: PrecificacaoMenuScreen()),
        '/rotina': (ctx) => const RotinaHubScreen(),
        'DepartmentDetail': (ctx) => const DepartmentDetailScreen(),
        'SpecialItems': (ctx) => const SpecialItemsScreen(),
        'Dashboard': (ctx) => const DashboardScreen(),
        '/precificacao_etiquetas': (ctx) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                automaticallyImplyLeading: false,
                title: const Text('Etiquetas avulsas',
                    style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
              body: const EtiquetasFragment(),
            ),
        '/precificacao_papeletas': (ctx) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                automaticallyImplyLeading: false,
                title: const Text('Papeletas avulsas',
                    style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
              body: const PapeletasFragment(),
            ),
        '/etiquetas': (ctx) => const EtiquetasScreen(),
        '/papeletas_diarias': (ctx) => const PapeletasDiariasScreen(),
        '/recebimento': (ctx) => const HomeScreen(),
        '/detalhes': (ctx) => const DetalhesViagemScreen(),
        '/itens': (ctx) => const ItensScreen(),
        '/fotos': (ctx) => const FotosRecebimentoScreen(),
        '/imagens': (ctx) => const ImagensRecebimentoScreen(),
        '/profile': (ctx) => const ProfileScreen(),
        '/quebra': (ctx) => const QuebraScreen(),
        '/quebra_consulta': (ctx) => const QuebraScreen(apenasConsulta: true),
        '/barcode': (ctx) => const BarcodeScannerScreen(),
        '/gondola_editavel': (ctx) {
          final args =
              ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
          return GondolaEditavelScreen(
            items: (args?['items'] as List?)
                    ?.cast<prec_models.PrintingData>() ??
                [],
            printerId: args?['printerId'] as String? ?? 'ZEBRA_1',
            barcode: args?['barcode'] as bool? ?? false,
          );
        },
        '/modelo_editavel': (ctx) => const ModeloEditavelScreen(),
        '/pdf_viewer': (ctx) => const PdfViewerScreen(),
        '/troca_facil': (ctx) => const VoltarHubsGuard(child: TrocaFacilMenuScreen()),
        '/troca_login': (ctx) => const TrocaLoginWebViewScreen(),
        '/troca_etiqueta': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          final token = args is Map ? args['token'] as String? : null;
          return TrocaEtiquetaScreen(token: token);
        },
        '/troca_realizar': (ctx) => const RealizarTrocaEtapa1Screen(),
        '/troca_etapa2': (ctx) => const RealizarTrocaEtapa2Screen(),
        '/troca_itens': (ctx) => const RealizarTrocaItensScreen(),
        '/troca_avaliacao': (ctx) => const AvaliacaoProdutoScreen(),
        '/troca_operacoes': (ctx) => const ListaOperacoesScreen(),
        '/troca_operacoes_filtro': (ctx) => const FiltrarOperacoesScreen(),
        '/troca_bloqueios': (ctx) => const ListaBloqueiosScreen(),
        '/troca_bloquear_item': (ctx) => const BloquearItemScreen(),
        '/home': (ctx) => const HomeHubScreen(),
      },
    );
  }
}

/// Decide a tela inicial com base na sessão.
class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final session = await SessionManager.create();
    if (!session.isLoggedIn()) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    // Detecta sessões próprias vencidas (Rotina/Troca Fácil). Se alguma
    // expirou, volta para o Login Microsoft, que renova todos os tokens.
    final rotinaOk = await HubTokens.rotinaValida();
    final trocaOk = await HubTokens.trocaValida();
    if (!rotinaOk || !trocaOk) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(Constants.primaryRed),
      body: Center(
        child: TruckLoader(),
      ),
    );
  }
}

/// Placeholder temporário para telas ainda não implementadas.
class _EmBreve extends StatelessWidget {
  final String titulo;
  const _EmBreve(this.titulo);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(titulo,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      ),
      body: const Center(
        child: Text('Em breve',
            style: TextStyle(color: Colors.black54, fontSize: 16)),
      ),
    );
  }
}
