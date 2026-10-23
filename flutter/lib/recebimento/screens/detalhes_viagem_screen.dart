import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recebimento.dart';
import '../models/brasil_risk.dart';
import '../network/session_manager.dart';
import '../network/api_client.dart';
import '../network/api_service.dart';
import '../network/brasil_risk_client.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/excel_downloader.dart';
import '../widgets/guia_card.dart';
import '../widgets/dialog_protocolo_sucesso.dart';

class DetalhesViagemScreen extends StatefulWidget {
  const DetalhesViagemScreen({super.key});

  @override
  State<DetalhesViagemScreen> createState() => _DetalhesViagemScreenState();
}

class _DetalhesViagemScreenState extends State<DetalhesViagemScreen> {
  late final SessionManager _session;
  late final ApiService _api;
  late final BrasilRiskClient _brLog;
  String _viagemId = '';
  DetalhesViagemResponse? _detalhes;
  String _storeId = Constants.defaultStore;
  bool _inicializado = false;

  // BRLog
  BrasilRiskNota? _brlogNota;
  BrasilRiskNotaDetalhe? _brlogDetalhe;
  bool _bauAutorizado = false;
  double _progresso = 0.0;

  // Loading
  bool _carregando = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as String?;
    _viagemId = args ?? '';
    if (_viagemId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop());
      return;
    }
    if (!_inicializado) {
      _inicializado = true;
      _init();
    }
  }

  Future<void> _init() async {
    _session = await SessionManager.create();
    _api = ApiService(ApiClient(_session));
    _brLog = BrasilRiskClient();
    _storeId = _session.getUserStore() ?? Constants.defaultStore;
    await _carregarDetalhes();
  }

  Future<void> _carregarDetalhes() async {
    try {
      final body = await _api.getDetalhesViagem(_storeId, _viagemId);
      if (!mounted) return;
      setState(() {
        _detalhes = body;
        _carregando = false;
      });
      _carregarRastreioBRLog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  void _carregarRastreioBRLog() {
    final numero = _pegarNumeroViagem();
    final nota = _session.getBrlogNotas().cast<BrasilRiskNota?>().firstWhere(
        (n) => _semZeros(n?.numeroViagem) == numero,
        orElse: () => null);
    if (nota == null) {
      setState(() => _brlogNota = null);
      return;
    }
    setState(() {
      _brlogNota = nota;
      _progresso = _normalizar(nota.progressoViagem ?? 0.0);
      _bauAutorizado = false;
    });
    final codEmpresa = _session.getBrlogCodEmpresaUsuario();
    if (nota.codPedido != null && codEmpresa > 0) {
      _brLog
          .obterInformacoesNotaCliente(codEmpresa, nota.codPedido)
          .then((detalhe) {
        if (!mounted) return;
        setState(() {
          _brlogDetalhe = detalhe;
          _progresso = _normalizar(detalhe.progressoViagem ?? _progresso);
          _bauAutorizado = detalhe.aberturaBauAutorizada == true;
        });
      }).catchError((_) {});
    }
  }

  double _normalizar(double p) {
    var v = p;
    if (v > 1.0) v /= 100.0;
    return v.clamp(0.0, 1.0);
  }

  String _pegarNumeroViagem() {
    final id = _detalhes?.viagemId ?? _viagemId;
    final curto = id.length > 7 ? id.substring(id.length - 7) : id;
    return curto.replaceFirst(RegExp(r'^0+'), '');
  }

  String _semZeros(String? v) => (v ?? '').replaceFirst(RegExp(r'^0+'), '');

  String _formatarDataBr(String iso) {
    try {
      final d = DateFormat("yyyy-MM-dd'T'HH:mm:ss").parseUtc(iso);
      return DateFormat("dd/MM/yyyy HH:mm").format(d.toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _formatarDataViagem(String iso) {
    try {
      final d = DateTime.parse(iso.replaceAll('Z', ''));
      return DateFormat("dd/MM/yyyy HH:mm:ss").format(d);
    } catch (_) {
      return iso;
    }
  }

  List<GuiaOuRoll> _montarGuias() {
    final d = _detalhes!;
    if (d.guias.isNotEmpty) {
      return d.guias.map((g) {
        final produtos = <RecebimentoItem>[];
        for (final n in g.recebimentoNota) {
          produtos.addAll(n.recebimentoItem.map((i) =>
              i.copyWith(guiaOuRoll: "GUIA: ${g.num}")));
        }
        final detalhe = "Notas: ${g.recebimentoNota.length}" +
            g.recebimentoNota
                .map((n) => " • NF ${n.notaNumero} (Série ${n.notaSerie})")
                .join("");
        return GuiaOuRoll(
            numero: g.num,
            valorTotal: g.valorTotal,
            detalheNotas: detalhe,
            produtos: produtos);
      }).toList();
    } else if (d.rolls.isNotEmpty) {
      final map = <String, List<Roll>>{};
      for (final r in d.rolls) {
        final key = r.numGuia.isNotEmpty ? r.numGuia : r.num;
        map.putIfAbsent(key, () => []).add(r);
      }
      return map.entries.map((e) {
        final rolls = e.value;
        final valorTotal = rolls.fold(0.0, (s, r) => s + r.valorTotal);
        final notas = rolls.expand((r) => r.recebimentoNota).toList();
        final produtos = <RecebimentoItem>[];
        for (final n in notas) {
          produtos.addAll(n.recebimentoItem.map((i) =>
              i.copyWith(guiaOuRoll: "GUIA: ${e.key}")));
        }
        final detalhe = "Notas: ${notas.length}" +
            notas
                .map((n) => " • NF ${n.notaNumero} (Série ${n.notaSerie})")
                .join("");
        return GuiaOuRoll(
            numero: e.key,
            valorTotal: valorTotal,
            detalheNotas: detalhe,
            produtos: produtos);
      }).toList();
    }
    return [];
  }

  void _executarBuscaGeral(String query) {
    final d = _detalhes;
    if (d == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Dados não carregados")));
      return;
    }
    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Digite SAP ou item")));
      return;
    }
    final todos = <RecebimentoItem>[];
    for (final g in d.guias) {
      for (final n in g.recebimentoNota) {
        for (final i in n.recebimentoItem) {
          todos.add(i.copyWith(guiaOuRoll: "GUIA: ${g.num}"));
        }
      }
    }
    for (final r in d.rolls) {
      final ref = r.numGuia.isNotEmpty ? r.numGuia : r.num;
      for (final n in r.recebimentoNota) {
        for (final i in n.recebimentoItem) {
          todos.add(i.copyWith(guiaOuRoll: "GUIA: $ref"));
        }
      }
    }
    final q = query.toLowerCase();
    final filtrados = todos.where((i) =>
        i.idSap.toLowerCase().contains(q) ||
        i.descricao.toLowerCase().contains(q)).toList();
    if (filtrados.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Nenhum item p/ '$query'")));
      return;
    }
    Navigator.of(context).pushNamed('/itens',
        arguments: {'titulo': 'BUSCA GERAL', 'itens': filtrados});
  }

  void _abrirItensRisco() {
    final d = _detalhes;
    if (d == null) return;
    final todos = <RecebimentoItem>[];
    for (final g in d.guias) {
      for (final n in g.recebimentoNota) {
        for (final i in n.recebimentoItem) {
          todos.add(i.copyWith(guiaOuRoll: "GUIA: ${g.num}"));
        }
      }
    }
    for (final r in d.rolls) {
      final ref = r.numGuia.isNotEmpty ? r.numGuia : r.num;
      for (final n in r.recebimentoNota) {
        for (final i in n.recebimentoItem) {
          todos.add(i.copyWith(guiaOuRoll: "GUIA: $ref"));
        }
      }
    }
    final risco = todos
        .where((i) => Constants.riscos.contains(i.departamento))
        .toList()
      ..sort((a, b) => a.departamento.compareTo(b.departamento));
    if (risco.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhum item de risco nesta viagem.")));
      return;
    }
    Navigator.of(context).pushNamed('/itens',
        arguments: {'titulo': 'ITENS DE RISCO', 'itens': risco});
  }

  List<RecebimentoItem> _todosItens() {
    final d = _detalhes;
    final todos = <RecebimentoItem>[];
    if (d == null) return todos;
    for (final g in d.guias) {
      for (final n in g.recebimentoNota) {
        for (final i in n.recebimentoItem) {
          todos.add(i.copyWith(guiaOuRoll: "GUIA: ${g.num}"));
        }
      }
    }
    for (final r in d.rolls) {
      final ref = r.numGuia.isNotEmpty ? r.numGuia : r.num;
      for (final n in r.recebimentoNota) {
        for (final i in n.recebimentoItem) {
          todos.add(i.copyWith(guiaOuRoll: "GUIA: $ref"));
        }
      }
    }
    return todos;
  }

  void _imprimirPorDepartamento() async {
    final todos = _todosItens();
    if (todos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhum item para imprimir.")));
      return;
    }
    final deptos = <String, int>{};
    for (final i in todos) {
      final dep = i.departamento.trim();
      if (dep.isEmpty) continue;
      deptos[dep] = (deptos[dep] ?? 0) + 1;
    }
    if (deptos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhum departamento encontrado.")));
      return;
    }
    final ordenados = deptos.keys.toList()..sort();
    final selecionados = <String>{};
    final escolha = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Imprimir por departamento',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: Text('Todos (${todos.length})',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    value: selecionados.length == ordenados.length,
                    activeColor: const Color(Constants.primaryRed),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => set(() {
                      if (v == true) {
                        selecionados.addAll(ordenados);
                      } else {
                        selecionados.clear();
                      }
                    }),
                  ),
                  const Divider(height: 8),
                  ...ordenados.map((dep) => CheckboxListTile(
                        title: Text('$dep (${deptos[dep]})',
                            style: const TextStyle(fontSize: 14)),
                        value: selecionados.contains(dep),
                        activeColor:
                            const Color(Constants.primaryRed),
                        controlAffinity:
                            ListTileControlAffinity.leading,
                        onChanged: (v) => set(() {
                          if (v == true) {
                            selecionados.add(dep);
                          } else {
                            selecionados.remove(dep);
                          }
                        }),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(Constants.primaryRed),
                foregroundColor: Colors.white,
              ),
              onPressed: selecionados.isEmpty
                  ? null
                  : () => Navigator.of(ctx)
                      .pop(Set<String>.from(selecionados)),
              child: Text('IMPRIMIR (${selecionados.length})'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || escolha.isEmpty) return;
    // Agrupa por departamento (ordem alfabética) preservando a sequência
    // original dos itens (1, 2, 3...) dentro de cada um.
    final porDep = <String, List<RecebimentoItem>>{};
    for (final i in todos) {
      final dep = i.departamento.trim();
      if (!escolha.contains(dep)) continue;
      (porDep[dep] ??= []).add(i);
    }
    final filtrados = [
      for (final d in ordenados)
        if (porDep.containsKey(d)) ...porDep[d]!
    ];
    final numViagem = _viagemId.replaceFirst(RegExp(r'^0+'), '');
    final sufixo = escolha.length == 1
        ? ' - DEP: ${escolha.first}'
        : (escolha.length == ordenados.length
            ? ''
            : ' - ${escolha.length} deps');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
      Icon(Icons.print, color: Colors.white, size: 20),
      SizedBox(width: 10),
      Expanded(child: Text('Gerando PDF...')),
    ])));
    try {
      final total = filtrados.fold(0.0, (s, i) => s + i.preco);
      final path = await ExcelDownloader.gerarPdfItens(
        titulo: 'VIAGEM: $numViagem$sufixo',
        prefixo: 'viagem-dep',
        itens: filtrados,
        total: total,
        mostrarTotal: false,
      );
      if (!mounted) return;
      await _abrirPreviewPdf(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ $e")));
    }
  }

  /// Abre o PDF no visualizador nativo (chooser quando houver mais de um).
  Future<void> _abrirPreviewPdf(String pdf) async {
    try {
      final uri =
          pdf.startsWith('content://') ? Uri.parse(pdf) : Uri.file(pdf);
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('sem app');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF salvo: $pdf')));
    }
  }

  void _gerarExcel() async {
    if (_detalhes == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
      Image.asset('assets/drawables/excel.png',
          width: 20, height: 20, fit: BoxFit.contain,
          color: Colors.white, colorBlendMode: BlendMode.srcIn),
      const SizedBox(width: 10),
      const Expanded(child: Text('Baixando relatório...')),
    ])));
    try {
      final path = await ExcelDownloader.gerarExcel(
        apiService: _api,
        storeId: _storeId,
        viagemId: _detalhes!.viagemId,
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

  void _gerarProtocolo() async {
    if (_detalhes == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("🔄 Gerando protocolo...")));
    try {
      final resp = await _api.gerarProtocolo(_storeId,
          ProtocoloRequest(idRecebimento: _detalhes!.viagemId));
      if (resp.success) {
        setState(() {
          _detalhes = DetalhesViagemResponse(
            viagemId: _detalhes!.viagemId,
            viagemData: _detalhes!.viagemData,
            cnpjOrigem: _detalhes!.cnpjOrigem,
            codigoOrigem: _detalhes!.codigoOrigem,
            origem: _detalhes!.origem,
            status: _detalhes!.status,
            qtdImei: _detalhes!.qtdImei,
            valorTotalViagem: _detalhes!.valorTotalViagem,
            dataRecebimento: _detalhes!.dataRecebimento,
            placaVeiculo: _detalhes!.placaVeiculo,
            cnpjDestino: _detalhes!.cnpjDestino,
            protocolo: resp.protocolo ?? _detalhes!.protocolo,
            guias: _detalhes!.guias,
            rolls: _detalhes!.rolls,
          );
        });
        showDialog(
          context: context,
          builder: (_) =>
              DialogProtocoloSucesso(protocolo: resp.protocolo ?? "Gerado"),
        );
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Falha ao gerar protocolo'),
            content: Text(resp.message ?? 'Falha'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
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

  void _solicitarLiberacao() async {
    final nota = _brlogNota;
    if (nota == null) return;
    final d = _detalhes;

    if (_bauAutorizado) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Abertura de baú já autorizada"),
          content: Text(
            "Viagem: ${d?.viagemId ?? '-'}\n"
            "Placa: ${d?.placaVeiculo ?? '-'}\n"
            "Status: ${d?.status ?? '-'}",
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK")),
          ],
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Autorizar a abertura do baú?"),
        content: Text(
          "Viagem: ${_pegarNumeroViagem()}\n"
          "Data: ${_formatarDataViagem(d?.viagemData ?? '')}\n"
          "Placa: ${d?.placaVeiculo ?? '-'}\n"
          "Origem: ${d?.origem ?? '-'}\n"
          "Pedido: ${nota.codPedido ?? '-'}",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Autorizar")),
        ],
      ),
    );
    if (confirmar != true) return;

    final codEmpresa = _session.getBrlogCodEmpresaUsuario();
    if (nota.codPedido == null ||
        nota.codPedidoDestino == null ||
        nota.codPedidoOcorrenciaTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Dados do pedido indisponíveis para liberação.")));
      return;
    }
    final dataCadastro = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS").format(DateTime.now());
    try {
      final resp = await _brLog.autorizarAberturaBau(AutorizarAberturaBauRequest(
        codPedido: nota.codPedido!,
        codEmpresaUsuario: codEmpresa,
        dataCadastro: dataCadastro,
        codPedidoDestino: nota.codPedidoDestino!,
        codPedidoOcorrenciaTipo: nota.codPedidoOcorrenciaTipo!,
      ));
      if (resp.aberturaBauAutorizada == true ||
          resp.status?.toLowerCase() == "ok" ||
          (resp.status == null && resp.mensagem == null)) {
        setState(() {
          _bauAutorizado = true;
        });
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Abertura de baú autorizada"),
            content: Text(
              "Viagem: ${d?.viagemId ?? '-'}\n"
              "Placa: ${d?.placaVeiculo ?? '-'}\n"
              "Pedido: ${nota.codPedido ?? '-'}",
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK")),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ ${resp.mensagem ?? 'Não autorizado'})")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detalhes;
    final isPendente = d?.status.toLowerCase() == Constants.statusPendente;
    final guias = d != null ? _montarGuias() : <GuiaOuRoll>[];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(Constants.primaryRed),
        title: const Text('DETALHES DA VIAGEM',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _gerarExcel,
            icon: Image.asset('assets/drawables/excel.png',
                width: 24, height: 24, fit: BoxFit.contain,
                color: Colors.white, colorBlendMode: BlendMode.srcIn),
            tooltip: 'Gerar Excel',
          ),
          IconButton(
            onPressed: _imprimirPorDepartamento,
            icon: const Icon(Icons.print, color: Colors.white, size: 24),
            tooltip: 'Imprimir por departamento',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Center(child: Text("Viagem não encontrada"))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _CardInfo(d, isPendente, _abrirItensRisco),
                    _CardBrlog(
                      nota: _brlogNota,
                      detalhe: _brlogDetalhe,
                      progresso: _progresso,
                      bauAutorizado: _bauAutorizado,
                      onSolicitar: _progresso >= 1.0 && !_bauAutorizado
                          ? _solicitarLiberacao
                          : null,
                    ),
                    if (isPendente)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _gerarProtocolo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(Constants.primaryRed),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('GERAR PROTOCOLO / RECEBER',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // GUIAS label + busca
                    Row(
                      children: [
                        const Icon(Icons.note_alt,
                            size: 22, color: Color(0xFF333333)),
                        const SizedBox(width: 8),
                        Text("GUIAS (${guias.length})",
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDE000000))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    size: 18, color: Color(0xFFA0AEC0)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onSubmitted: _executarBuscaGeral,
                                    decoration: const InputDecoration(
                                      hintText: 'Buscar SAP ou item',
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFA0AEC0)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...guias.map((g) => GuiaCard(
                          guia: g,
                          onVerTudo: () => Navigator.of(context).pushNamed(
                            '/itens',
                            arguments: {
                              'titulo': "GUIA: ${g.numero}",
                              'itens': g.produtos,
                            },
                          ),
                        )),
                  ],
                ),
    );
  }
}

class _CardInfo extends StatelessWidget {
  final DetalhesViagemResponse d;
  final bool isPendente;
  final VoidCallback onRisco;

  const _CardInfo(this.d, this.isPendente, this.onRisco);

  @override
  Widget build(BuildContext context) {
    final numero = d.viagemId.length > 7
        ? d.viagemId.substring(d.viagemId.length - 7)
        : d.viagemId;
    final statusColor = switch (d.status.toLowerCase()) {
      'pendente' => const Color(0xFFFF9800),
      'erro' => const Color(0xFFF44336),
      'anomalia' => const Color(0xFFFFC107),
      'recebido' => const Color(0xFF4CAF50),
      _ => Colors.black,
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                        width: 65,
                        child: Text('Data',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9E9E9E)))),
                    Expanded(
                      child: Text(_fmtData(d.viagemData),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                    InkWell(
                      onTap: onRisco,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(Constants.primaryRed),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ITENS DE RISCO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(
                        width: 65,
                        child: Text('Origem',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9E9E9E)))),
                    Expanded(
                      child: Text("${d.origem} (${d.codigoOrigem})",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(
                        width: 65,
                        child: Text('Placa',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9E9E9E)))),
                    Expanded(
                      child: Text(d.placaVeiculo,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                  ],
                ),
                if (d.dataRecebimento.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            "Recebimento: ${_fmtDataReceb(d.dataRecebimento)}",
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text(d.status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                    if (d.protocolo != null && d.protocolo!.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.verified_user,
                          size: 16, color: Color(Constants.primaryRed)),
                      const SizedBox(width: 6),
                      Text("PROTOCOLO: ${d.protocolo}",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(Constants.primaryRed))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Faixa verde valor total
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: Color(Constants.greenBand),
              border: Border(
                top: BorderSide(color: Color(Constants.badgeGreen)),
                bottom: BorderSide(color: Color(Constants.badgeGreen)),
                left: BorderSide(color: Color(Constants.badgeGreen)),
                right: BorderSide(color: Color(Constants.badgeGreen)),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                const Text('Valor Total',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A8A8A))),
                Text(
                    CurrencyFormatter.formatarMoedaComSimbolo(
                        d.valorTotalViagem),
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtData(String iso) {
    try {
      final dt = DateTime.parse(iso.replaceAll('Z', ''));
      return DateFormat("dd/MM/yyyy HH:mm").format(dt);
    } catch (_) {
      return iso;
    }
  }

  static String _fmtDataReceb(String iso) {
    try {
      final dt = DateTime.parse(iso.replaceAll('Z', ''));
      return DateFormat("dd/MM/yyyy - HH'h'mm'min'").format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _CardBrlog extends StatelessWidget {
  final BrasilRiskNota? nota;
  final BrasilRiskNotaDetalhe? detalhe;
  final double progresso;
  final bool bauAutorizado;
  final VoidCallback? onSolicitar;

  const _CardBrlog({
    this.nota,
    this.detalhe,
    required this.progresso,
    required this.bauAutorizado,
    this.onSolicitar,
  });

  @override
  Widget build(BuildContext context) {
    if (nota == null && detalhe == null) {
      return const SizedBox.shrink();
    }
    final motorista = detalhe?.nomeMotorista ??
        nota?.nomeMotorista ??
        '--';
    final saiu = _fmt(detalhe?.dataDeSaida ?? nota?.dataDeSaida ??
        detalhe?.dataIniciado ?? nota?.dataIniciado);
    final chegada = _fmt(detalhe?.previsaoChegada ?? nota?.previsaoChegada ??
        detalhe?.previsaoChegadaRecalculada ?? nota?.previsaoChegadaRecalculada);
    final dist = _fmtDist(detalhe?.distanciaRestante ?? nota?.distanciaRestante);
    final concluida = _fmt(detalhe?.dataConclusao ?? nota?.dataConclusao ??
        detalhe?.dataEntrega ?? nota?.dataEntrega ??
        detalhe?.dataDeEntregaNF ?? nota?.dataDeEntregaNF);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('RASTREIO BRLOG',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(Constants.primaryRed))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(Constants.primaryRed),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("${(progresso * 100).toInt()}%",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Linha('Motorista', motorista),
          _Linha('Saiu p/ entrega', saiu),
          _Linha('Chegada prevista', chegada),
          _Linha('Dist. restante', dist),
          _Linha('Entrega concluída', concluida),
          if (bauAutorizado)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Baú já autorizado para abertura.',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(Constants.badgeGreen))),
            ),
          if (onSolicitar != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onSolicitar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(Constants.primaryRed),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SOLICITAR LIBERAÇÃO',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _Linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9E9E9E))),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ),
        ],
      ),
    );
  }

  String _fmt(String? v) {
    if (v == null || v.isEmpty) return '--';
    try {
      final dt = DateFormat("yyyy-MM-dd'T'HH:mm:ss").parse(v);
      return DateFormat("dd/MM/yyyy HH:mm").format(dt);
    } catch (_) {
      return v;
    }
  }

  String _fmtDist(double? km) {
    if (km == null) return '--';
    if (km >= 1.0) return "${km.toStringAsFixed(1)} km";
    return "${(km * 1000).toInt()} m";
  }
}
