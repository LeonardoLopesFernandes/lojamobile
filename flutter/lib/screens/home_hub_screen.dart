import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFavoritosKey = 'hubs_favoritos';

class _Hub {
  final String id;
  final String iconAsset;
  final IconData fallbackIcon;
  final String title;
  final String rota;

  const _Hub({
    required this.id,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.title,
    required this.rota,
  });
}

const List<_Hub> _hubs = [
  _Hub(
    id: 'precificacao',
    iconAsset: 'assets/drawables/precificacao.png',
    fallbackIcon: Icons.request_quote_outlined,
    title: 'Precificação',
    rota: '/precificacao',
  ),
  _Hub(
    id: 'recebimento',
    iconAsset: 'assets/drawables/recebimento.png',
    fallbackIcon: Icons.local_shipping_outlined,
    title: 'Recebimento Centralizado',
    rota: '/recebimento',
  ),
  _Hub(
    id: 'inventario',
    iconAsset: 'assets/drawables/inventario.png',
    fallbackIcon: Icons.inventory_2_outlined,
    title: 'Inventário',
    rota: '/inventario',
  ),
  _Hub(
    id: 'quebra',
    iconAsset: 'assets/drawables/quebras.png',
    fallbackIcon: Icons.broken_image_outlined,
    title: 'Quebra',
    rota: '/quebras',
  ),
  _Hub(
    id: 'trocafacil',
    iconAsset: 'assets/drawables/trocafacil.png',
    fallbackIcon: Icons.swap_horiz,
    title: 'Troca Fácil',
    rota: '/troca_facil',
  ),
];

/// Home: cabeçalho vermelho + grade com 4 acessos.
class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
  final Set<String> _favoritos = {};
  final TextEditingController _buscaController = TextEditingController();
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _carregarFavoritos();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_kFavoritosKey) ?? [];
    if (!mounted) return;
    setState(() {
      _favoritos
        ..clear()
        ..addAll(favs);
    });
  }

  Future<void> _toggleFavorito(String id) async {
    setState(() {
      if (_favoritos.contains(id)) {
        _favoritos.remove(id);
      } else {
        _favoritos.add(id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoritosKey, _favoritos.toList());
  }

  void _toggleBusca() {
    setState(() {
      _buscando = !_buscando;
      if (!_buscando) _buscaController.clear();
    });
  }

  List<_Hub> get _filtrados {
    final q = _buscaController.text.trim().toLowerCase();
    if (q.isEmpty) return _hubs;
    return _hubs
        .where((h) => h.title.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _confirmarSaida() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sair do app'),
        content: const Text('Deseja sair do aplicativo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim')),
        ],
      ),
    );
    if (ok == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmarSaida();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Image.asset(
                      'assets/drawables/logo_mloja.png',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Loja Mobile',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleBusca,
                      icon: Icon(_buscando ? Icons.close : Icons.search,
                          color: Colors.white),
                      tooltip: 'Pesquisar',
                    ),
                  ],
                ),
                if (_buscando) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _buscaController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar módulo...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white24,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum módulo encontrado',
                      style: TextStyle(color: Colors.black54, fontSize: 15),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        for (final hub in filtrados)
                          _MenuCard(
                            iconAsset: hub.iconAsset,
                            fallbackIcon: hub.fallbackIcon,
                            title: hub.title,
                            favorito: _favoritos.contains(hub.id),
                            onFavoritar: () => _toggleFavorito(hub.id),
                            onTap: () =>
                                Navigator.of(context).pushNamed(hub.rota),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String iconAsset;
  final IconData fallbackIcon;
  final String title;
  final bool favorito;
  final VoidCallback onFavoritar;
  final VoidCallback onTap;

  const _MenuCard({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.title,
    required this.favorito,
    required this.onFavoritar,
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
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  iconAsset,
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) =>
                      Icon(fallbackIcon, color: const Color(0xFFD32F2F), size: 40),
                ),
                InkWell(
                  onTap: onFavoritar,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      favorito ? Icons.star : Icons.star_border,
                      color: favorito ? const Color(0xFFD32F2F) : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
