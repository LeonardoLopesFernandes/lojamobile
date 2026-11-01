import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../precificacao/core/session_manager.dart' as loja;
import 'api/client.dart';
import 'api/cronet_adapter.dart';
import 'auth/auth_provider.dart';
import 'hooks/departments_controller.dart';
import 'screens/main_screen.dart';
import 'theme.dart' as rotina_theme;

/// Hub da Rotina Comercial dentro do LojaMobile.
///
/// Reaproveita o token e a loja do login principal (mesma conta) e sobe o
/// MainScreen da Rotina com os providers que ele espera.
class RotinaHubScreen extends StatefulWidget {
  const RotinaHubScreen({super.key});

  @override
  State<RotinaHubScreen> createState() => _RotinaHubScreenState();
}

class _RotinaHubScreenState extends State<RotinaHubScreen> {
  static bool _booted = false;

  late final AuthProvider _auth;
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final prec = loja.SessionManager.instance;
    if (prec != null) {
      rotina_theme.store = prec.getUserStore();
    }

    if (!_booted) {
      _booted = true;
      try {
        initCronetTransport();
      } catch (_) {}
      setupApiInterceptors();
    }

    await _auth.initialize();
    if (mounted) setState(() => _pronto = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F4F8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE60014)),
        ),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<DepartmentsController>(
            create: (_) => DepartmentsController()),
      ],
      child: const MainScreen(),
    );
  }
}
