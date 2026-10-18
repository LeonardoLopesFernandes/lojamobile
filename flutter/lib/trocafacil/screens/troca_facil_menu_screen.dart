import 'package:flutter/material.dart';
import 'package:inventario/network/session_manager.dart';
import 'troca_login_webview.dart';

/// Tela inicial da Troca Fácil: grade com "Realizar troca" e "Operações".
class TrocaFacilMenuScreen extends StatefulWidget {
  const TrocaFacilMenuScreen({super.key});

  @override
  State<TrocaFacilMenuScreen> createState() => _TrocaFacilMenuScreenState();
}

class _TrocaFacilMenuScreenState extends State<TrocaFacilMenuScreen> {
  String _initials = 'GG';

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  Future<void> _carregarUsuario() async {
    final session = await SessionManager.create();
    final nome = session.getUserName() ?? '';
    final parts = nome.trim().split(RegExp(r'\s+'));
    String ini = 'GG';
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      ini = parts.length == 1
          ? parts.first.substring(0, 1).toUpperCase()
          : (parts.first.substring(0, 1) + parts.last.substring(0, 1))
              .toUpperCase();
    }
    if (!mounted) return;
    setState(() => _initials = ini);
  }

  Future<void> _abrir(String rota) async {
    final ok = await ensureTrocaLogin(context);
    if (!ok || !mounted) return;
    Navigator.of(context).pushNamed(rota);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Realizar troca',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            _MenuCard(
              icon: Icons.sync_alt,
              title: 'Realizar troca',
              onTap: () => _abrir('/troca_realizar'),
            ),
            _MenuCard(
              icon: Icons.login_outlined,
              title: 'Operações',
              onTap: () => _abrir('/troca_operacoes'),
            ),
            _MenuCard(
              icon: Icons.lock_outline,
              title: 'Itens bloqueados',
              onTap: () => _abrir('/troca_bloqueios'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: const Color(0xFFD32F2F), size: 28),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
