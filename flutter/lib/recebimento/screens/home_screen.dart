import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/recebimento.dart';
import '../models/brasil_risk.dart';
import '../network/session_manager.dart';
import '../network/brasil_risk_client.dart';
import '../network/brlog_auth.dart';
import '../providers/main_provider.dart';
import '../utils/constants.dart';
import '../utils/excel_downloader.dart';
import '../widgets/trip_card.dart';
import '../widgets/dialog_protocolo_sucesso.dart';

/// Sincroniza as viagens do BRLog via OAuth Microsoft (aad_oauth), o mesmo
/// fluxo do app BRLog. Executada somente ao tocar em "Sincronizar viagens".
Future<void> _sincronizarBRLog(
    ScaffoldMessengerState messenger, MainProvider provider) async {
  messenger.showSnackBar(const SnackBar(
    content: Text('Sincronizando viagens do BRLog...'),
    duration: Duration(seconds: 2),
  ));

  BrLogToken? token;
  try {
    token = await BrLogAuth.login();
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Falha ao abrir o login do BRLog'),
      backgroundColor: Colors.red,
    ));
    return;
  }
  if (token == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Sincronização do BRLog cancelada'),
    ));
    return;
  }

  final session = provider.sessionManager;
  if (token.refreshToken != null && token.refreshToken!.isNotEmpty) {
    session.saveBrlogRefreshToken(token.refreshToken!);
  }

  try {
    final resposta = await BrasilRiskClient()
        .loginMicrosoft(TokenBody(token: token.accessToken));
    final lista = resposta.notaFiscal ?? [];
    final progresso = <String, double>{};
    for (final nota in lista) {
      if (nota.numeroViagem == null || nota.progressoViagem == null) continue;
      var p = nota.progressoViagem!;
      if (p > 1.0) p /= 100.0;
      progresso[nota.numeroViagem!] = p.clamp(0.0, 1.0);
    }
    if (progresso.isNotEmpty) session.saveBrlogProgress(progresso);
    if (resposta.codEmpresaUsuario != null) {
      session.saveBrlogCodEmpresaUsuario(resposta.codEmpresaUsuario!);
    }
    if (lista.isNotEmpty) session.saveBrlogNotas(lista);

    provider.recarregarProgressoBRLog();
    messenger.showSnackBar(SnackBar(
      content: Text(lista.isEmpty
          ? 'BRLog: nenhuma viagem em andamento'
          : 'BRLog sincronizado: ${progresso.length} viagens'),
      backgroundColor: lista.isEmpty ? null : Colors.green,
    ));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Falha ao sincronizar os dados do BRLog'),
      backgroundColor: Colors.red,
    ));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionManager>(
      future: SessionManager.create(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(Constants.primaryRed),
            body: Center(
                child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        return ChangeNotifierProvider(
          create: (_) => MainProvider(snap.data!),
          child: const _HomeBody(),
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MainProvider>(context);
    return Scaffold(
        backgroundColor: const Color(Constants.bgGray),
        drawer: const _AppDrawer(),
        body: Column(
        children: [
          _Header(),
          _Badges(),
          if (provider.showSearch) _BuscaFiltros(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => provider.refresh(),
                  child: provider.items.isEmpty && !provider.isLoading
                      ? _EmptyState()
                      : provider.isModoGrid
                            ? LayoutBuilder(
                              builder: (ctx, constraints) {
                                final cardW = (constraints.maxWidth - 30) / 2;
                                final children = <Widget>[];
                                for (int i = 0;
                                    i < provider.items.length;
                                    i++) {
                                  children.add(SizedBox(
                                    width: cardW,
                                    child: _itemBuilder(ctx, provider, i),
                                  ));
                                }
                                if (provider.isLoading) {
                                  children.add(const SizedBox(
                                    width: double.infinity,
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                  ));
                                }
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(10),
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: children,
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: provider.items.length + 1,
                              itemBuilder: (ctx, i) =>
                                  _itemBuilder(ctx, provider, i),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, MainProvider provider, int i) {
    if (i == provider.items.length) {
      if (provider.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return const SizedBox.shrink();
    }
    final r = provider.items[i];
    final numero = r.id.length > 7 ? r.id.substring(r.id.length - 7) : r.id;
    return TripCard(
      recebimento: r,
      progresso: provider.progressoViagem[numero],
      compact: provider.isModoGrid,
      onVisualizar: () =>
          Navigator.of(context).pushNamed('/detalhes', arguments: r.id),
      onImprimir: () => _gerarExcel(context, r),
      onReceber: () => _gerarProtocolo(context, r),
    );
  }

  void _gerarExcel(BuildContext context, Recebimento r) async {
    final provider = Provider.of<MainProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
      Image.asset('assets/drawables/excel.png',
          width: 20, height: 20, fit: BoxFit.contain,
          color: Colors.white, colorBlendMode: BlendMode.srcIn),
      const SizedBox(width: 10),
      Expanded(
          child: Text(
              "Gerando Excel da viagem ${r.id.length > 7 ? r.id.substring(r.id.length - 7) : r.id}...")),
    ])));
    try {
      final path = await ExcelDownloader.gerarExcel(
        apiService: provider.apiService,
        storeId: provider.storeId,
        viagemId: r.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
        const Icon(Icons.check_box, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text("Excel salvo: $path")),
      ]), action: SnackBarAction(
          label: 'Abrir',
          onPressed: () => ExcelDownloader.abrirArquivo(
              path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'))));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ $e")));
    }
  }

  void _gerarProtocolo(BuildContext context, Recebimento r) async {
    final provider = Provider.of<MainProvider>(context, listen: false);
    try {
      final protocolo = await provider.gerarProtocolo(r);
      showDialog(
        context: context,
        builder: (_) => DialogProtocoloSucesso(protocolo: protocolo),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erro ao gerar protocolo'),
          content: Text('$e'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    }
  }
}



class _Header extends StatefulWidget {
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  String? _foto;

  @override
  void initState() {
    super.initState();
    _carregarFoto();
  }

  Future<void> _carregarFoto() async {
    final session = await SessionManager.create();
    if (!mounted) return;
    setState(() => _foto = session.getProfilePhoto());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MainProvider>(context);
    final vermelho = const Color(Constants.primaryRed);
    return Container(
      color: Colors.white,
      height: 120,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1F1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_shipping, color: vermelho, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Recebimento Centralizado',
                    style: TextStyle(
                        color: vermelho,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(provider.subtitle,
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              await Navigator.of(context).pushNamed('/profile');
              _carregarFoto();
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFF1F1F1),
              backgroundImage: _foto != null ? FileImage(File(_foto!)) : null,
              child: _foto == null ? Icon(Icons.person, color: vermelho) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MainProvider>(context);
    return Container(
      margin: const EdgeInsets.only(top: -25, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _Badge(
            label: 'A Receber',
            count: provider.qtdReceber,
            icon: 'assets/drawables/pendente.png',
            selected: provider.currentStatus == Constants.statusPendente,
            lineColor: const Color(Constants.badgeAmber),
            onTap: () => provider.selectTab(Constants.statusPendente),
          ),
          _Badge(
            label: 'Anomalias',
            count: provider.qtdAnomalia,
            icon: 'assets/drawables/anomalia.png',
            selected: provider.currentStatus == Constants.statusAnomalia,
            lineColor: const Color(Constants.badgeAmber),
            onTap: () => provider.selectTab(Constants.statusAnomalia),
          ),
          _Badge(
            label: 'Erro',
            count: provider.qtdErro,
            icon: 'assets/drawables/erro.png',
            selected: provider.currentStatus == Constants.statusErro,
            lineColor: const Color(Constants.badgeRed),
            onTap: () => provider.selectTab(Constants.statusErro),
          ),
          _Badge(
            label: 'Recebidas',
            count: provider.qtdRecebidas,
            icon: 'assets/drawables/recebidas.png',
            selected: provider.currentStatus == Constants.statusRecebido,
            lineColor: const Color(Constants.badgeGreen),
            onTap: () => provider.selectTab(Constants.statusRecebido),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String count;
  final String icon;
  final bool selected;
  final Color lineColor;
  final VoidCallback onTap;

  const _Badge({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.lineColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(icon,
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.receipt, size: 32)),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(count,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(Constants.textDark))),
            Container(
              margin: const EdgeInsets.only(top: 4, left: 20, right: 20),
              height: 3,
              color: selected ? lineColor : lineColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuscaFiltros extends StatefulWidget {
  @override
  State<_BuscaFiltros> createState() => _BuscaFiltrosState();
}

class _BuscaFiltrosState extends State<_BuscaFiltros> {
  final TextEditingController _ctl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onBusca(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Provider.of<MainProvider>(context, listen: false).setSearch(valor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MainProvider>(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFFA0AEC0)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctl,
                  onChanged: _onBusca,
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar Viagem, Placa...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Color(0xFFA0AEC0)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('Ordenar:',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              _Pill(
                text: 'MAIS RECENTES',
                ativo: provider.currentSort == 'desc',
                onTap: () => provider.setSort('desc'),
              ),
              const SizedBox(width: 6),
              _Pill(
                text: 'MAIS ANTIGAS',
                ativo: provider.currentSort == 'asc',
                onTap: () => provider.setSort('asc'),
              ),
              if (provider.currentStatus == Constants.statusRecebido) ...[
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFE0E0E0),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                InkWell(
                  onTap: () => provider.setModoGrid(false),
                  child: Icon(Icons.view_list,
                      color: provider.isModoGrid
                          ? Colors.grey[400]
                          : const Color(Constants.primaryRed),
                      size: 26),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => provider.setModoGrid(true),
                  child: Icon(Icons.grid_view,
                      color: provider.isModoGrid
                          ? const Color(Constants.primaryRed)
                          : Colors.grey[400],
                      size: 26),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool ativo;
  final VoidCallback onTap;

  const _Pill({required this.text, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ativo ? const Color(Constants.primaryRed) : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: ativo ? Colors.white : const Color(Constants.textDark))),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox, size: 80, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 24),
          const Text('Nenhuma viagem encontrada',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Color(Constants.textDark))),
          const SizedBox(height: 4),
          Text('Puxe para baixo para recarregar',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MainProvider>(context, listen: false);
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            color: const Color(Constants.primaryRed),
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            alignment: Alignment.center,
            child: Image.asset('assets/drawables/ic_caminhao_logo.png',
                width: 72, height: 72),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _MenuItem(
                  const Icon(Icons.sync,
                      color: Color(Constants.primaryRed), size: 24),
                  'Sincronizar viagens do BRLog',
                  () {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    _sincronizarBRLog(messenger, provider);
                  },
                ),
                _MenuItem(
                  const Icon(Icons.photo_library,
                      color: Color(Constants.primaryRed), size: 24),
                  'Imagens do Recebimento',
                  () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed('/imagens');
                  },
                ),
                _MenuItem(
                  Image.asset('assets/drawables/pendente.png',
                      width: 24, height: 24),
                  'Viagens a Receber',
                  () {
                    Navigator.of(context).pop();
                    provider.selectTab(Constants.statusPendente);
                  },
                ),
                _MenuItem(
                  Image.asset('assets/drawables/recebidas.png',
                      width: 24, height: 24),
                  'Viagens Recebidas',
                  () {
                    Navigator.of(context).pop();
                    provider.selectTab(Constants.statusRecebido);
                  },
                ),
                _MenuItem(
                  Image.asset('assets/drawables/anomalia.png',
                      width: 24, height: 24),
                  'Viagens com Anomalia',
                  () {
                    Navigator.of(context).pop();
                    provider.selectTab(Constants.statusAnomalia);
                  },
                ),
                _MenuItem(
                  Image.asset('assets/drawables/erro.png',
                      width: 24, height: 24),
                  'Viagens com Erro',
                  () {
                    Navigator.of(context).pop();
                    provider.selectTab(Constants.statusErro);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(Constants.borderColor)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(Constants.textDark))),
            ),
            const Icon(Icons.chevron_right, color: Color(Constants.textGray)),
          ],
        ),
      ),
    );
  }
}
