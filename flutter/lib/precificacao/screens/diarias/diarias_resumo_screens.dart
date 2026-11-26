import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/session_manager.dart';
import '../../models/models.dart';
import '../../network/api_client.dart';
import '../../network/api_service.dart';
import '../etiquetas/etiquetas_screen.dart';
import '../papeletas/papeletas_diarias_screen.dart';

const _vermelho = Color(0xFFE60023);
const _texto = Color(0xFF424957);
const _fundo = Color(0xFFF8F8FA);

class DepartamentoResumo {
  final String nome;
  final int imprimir;
  final int impressas;

  const DepartamentoResumo(this.nome, this.imprimir, this.impressas);
}

class ResumoDia {
  final DateTime dia;
  final String periodo;
  final int imprimir;
  final int impressas;
  final Color cor;
  final List<DepartamentoResumo> departamentos;

  const ResumoDia({
    required this.dia,
    required this.periodo,
    required this.imprimir,
    required this.impressas,
    required this.cor,
    required this.departamentos,
  });
}

String _apiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _qtd(int n) => '$n ${n == 1 ? 'item' : 'itens'}';

String _normalizar(String s) {
  const comAcento = 'ÁÀÂÃÉÊÍÓÔÕÚÜÇ';
  const semAcento = 'AAAAEEIOOOUUC';
  var r = s.toUpperCase();
  for (var i = 0; i < comAcento.length; i++) {
    r = r.replaceAll(comAcento[i], semAcento[i]);
  }
  return r;
}

bool _impressa(String status) {
  final s = _normalizar(status);
  return s.contains('IMPRESSA') && !s.contains('NAO');
}

String? _deptNumber(String department) {
  final num = department.split(' -').first.trim();
  return num.isNotEmpty ? num : null;
}

final _api = ApiService(ApiClient.instance.getSlApiService());

Future<ResumoDia> _carregarEtiquetas(DateTime dia) async {
  final store =
      SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
  final date = _apiDate(dia);
  final resp = await _api.getPriceTagsByStatus(
    store,
    Constants.statusAll,
    startDate: date,
  );
  final items = resp.priceTags;
  var imprimir = 0;
  var impressas = 0;
  for (final t in items) {
    if (_impressa(t.status)) {
      impressas++;
    } else {
      imprimir++;
    }
  }
  final filters = await _api.getPriceTagFilters(store, date);
  final contagens = <String, (int, int)>{};
  final nomes = <String, String>{};
  for (final t in items) {
    final id = _deptNumber(t.department);
    if (id == null) continue;
    nomes[id] = t.department;
    final atual = contagens[id] ?? (0, 0);
    if (_impressa(t.status)) {
      contagens[id] = (atual.$1, atual.$2 + 1);
    } else {
      contagens[id] = (atual.$1 + 1, atual.$2);
    }
  }
  final departamentos = <DepartamentoResumo>[];
  for (final d in filters.departments) {
    final c = contagens[d.id] ?? (0, 0);
    if (c.$1 + c.$2 == 0) continue;
    departamentos.add(DepartamentoResumo(
      '${d.id} - ${d.label}',
      c.$1,
      c.$2,
    ));
  }
  for (final entry in contagens.entries) {
    if (filters.departments.any((d) => d.id == entry.key)) continue;
    final c = entry.value;
    if (c.$1 + c.$2 == 0) continue;
    departamentos.add(DepartamentoResumo(
      nomes[entry.key] ?? entry.key,
      c.$1,
      c.$2,
    ));
  }
  departamentos.sort((a, b) => a.nome.compareTo(b.nome));
  return ResumoDia(
    dia: dia,
    periodo: 'Hoje',
    imprimir: imprimir,
    impressas: impressas,
    cor: const Color(0xFF00A526),
    departamentos: departamentos,
  );
}

Future<ResumoDia> _carregarPapeletas(DateTime dia) async {
  final store =
      SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
  final date = _apiDate(dia);
  final comum = await _api.getPriceSigns(
    store,
    Constants.signTypePapeletaComum,
    size: Constants.signSize4x1,
    status: Constants.statusAll,
    startDate: date,
  );
  final promo = await _api.getPriceSigns(
    store,
    Constants.signTypePapeletaPromocional,
    size: Constants.signSize4x1,
    status: Constants.statusAll,
    startDate: date,
  );
  final items = [...comum.priceSigns, ...promo.priceSigns];
  var imprimir = 0;
  var impressas = 0;
  for (final t in items) {
    if (_impressa(t.status)) {
      impressas++;
    } else {
      imprimir++;
    }
  }
  final filters = await _api.getPriceTagFilters(store, date);
  final contagens = <String, (int, int)>{};
  final nomes = <String, String>{};
  for (final t in items) {
    final id = _deptNumber(t.department);
    if (id == null) continue;
    nomes[id] = t.department;
    final atual = contagens[id] ?? (0, 0);
    if (_impressa(t.status)) {
      contagens[id] = (atual.$1, atual.$2 + 1);
    } else {
      contagens[id] = (atual.$1 + 1, atual.$2);
    }
  }
  final departamentos = <DepartamentoResumo>[];
  for (final d in filters.departments) {
    final c = contagens[d.id] ?? (0, 0);
    if (c.$1 + c.$2 == 0) continue;
    departamentos.add(DepartamentoResumo(
      '${d.id} - ${d.label}',
      c.$1,
      c.$2,
    ));
  }
  for (final entry in contagens.entries) {
    if (filters.departments.any((d) => d.id == entry.key)) continue;
    final c = entry.value;
    if (c.$1 + c.$2 == 0) continue;
    departamentos.add(DepartamentoResumo(
      nomes[entry.key] ?? entry.key,
      c.$1,
      c.$2,
    ));
  }
  departamentos.sort((a, b) => a.nome.compareTo(b.nome));
  return ResumoDia(
    dia: dia,
    periodo: 'Hoje',
    imprimir: imprimir,
    impressas: impressas,
    cor: const Color(0xFF00A526),
    departamentos: departamentos,
  );
}

class EtiquetasDiariasResumoScreen extends StatelessWidget {
  const EtiquetasDiariasResumoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResumoDiariasScreen(
      titulo: 'Etiquetas diárias',
      plural: 'Etiquetas',
      carregar: _carregarEtiquetas,
      telaImpressao: (dia) => EtiquetasScreen(initialDate: _apiDate(dia)),
    );
  }
}

class PapeletasDiariasResumoScreen extends StatelessWidget {
  const PapeletasDiariasResumoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResumoDiariasScreen(
      titulo: 'Papeletas diárias',
      plural: 'Papeletas',
      carregar: _carregarPapeletas,
      telaImpressao: (dia) =>
          PapeletasDiariasScreen(initialDate: _apiDate(dia)),
    );
  }
}

class ResumoDiariasScreen extends StatefulWidget {
  final String titulo;
  final String plural;
  final Future<ResumoDia> Function(DateTime) carregar;
  final Widget Function(DateTime) telaImpressao;

  const ResumoDiariasScreen({
    super.key,
    required this.titulo,
    required this.plural,
    required this.carregar,
    required this.telaImpressao,
  });

  @override
  State<ResumoDiariasScreen> createState() => _ResumoDiariasScreenState();
}

class _ResumoDiariasScreenState extends State<ResumoDiariasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<ResumoDia>> _futuro;
  List<ResumoDia>? _dias;
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _aba != _tabs.index) {
        setState(() => _aba = _tabs.index);
      }
    });
    _futuro = _carregar();
  }

  Future<List<ResumoDia>> _carregar() async {
    final hoje = DateTime.now();
    final amanha = hoje.add(const Duration(days: 1));
    final hojeResumo = await widget.carregar(hoje);
    final amanhaResumo = await widget.carregar(amanha);
    final lista = [
      hojeResumo,
      ResumoDia(
        dia: amanhaResumo.dia,
        periodo: 'Amanhã',
        imprimir: amanhaResumo.imprimir,
        impressas: amanhaResumo.impressas,
        cor: const Color(0xFF1769E8),
        departamentos: amanhaResumo.departamentos,
      ),
    ];
    _dias = lista;
    return lista;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: _texto),
        ),
        title: Text(
          widget.titulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: const [
          Icon(Icons.translate, color: _texto),
          SizedBox(width: 18),
          Icon(Icons.notifications_none, color: _texto),
          SizedBox(width: 18),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _vermelho,
          indicatorWeight: 3,
          labelColor: _vermelho,
          unselectedLabelColor: _texto,
          labelStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: '${widget.plural} de hoje'),
            Tab(text: '${widget.plural} de amanhã'),
          ],
        ),
      ),
      body: FutureBuilder<List<ResumoDia>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar os dados.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        _dias = null;
                        setState(() => _futuro = _carregar());
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final dias = snapshot.data!;
          return TabBarView(
            controller: _tabs,
            children: [
              _ConteudoResumo(
                dados: dias[0],
                plural: widget.plural,
              ),
              _ConteudoResumo(
                dados: dias[1],
                plural: widget.plural,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final dias = _dias;
                if (dias == null || dias.length <= _aba) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => widget.telaImpressao(dias[_aba].dia),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _vermelho,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35),
                ),
              ),
              child: Text(
                'Ir para impressão de ${_aba == 0 ? 'hoje' : 'amanhã'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConteudoResumo extends StatelessWidget {
  final ResumoDia dados;
  final String plural;

  const _ConteudoResumo({
    required this.dados,
    required this.plural,
  });

  @override
  Widget build(BuildContext context) {
    final largura = (MediaQuery.of(context).size.width - 48) / 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 22, bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: largura,
                  child: _CardIndicador(
                    titulo: dados.periodo,
                    valor: _displayDate(dados.dia),
                    cor: dados.cor,
                    destaque: true,
                  ),
                ),
                SizedBox(
                  width: largura,
                  child: _CardIndicador(
                    titulo: '$plural para imprimir',
                    valor: _qtd(dados.imprimir),
                  ),
                ),
                SizedBox(
                  width: largura,
                  child: _CardIndicador(
                    titulo: '$plural impressas',
                    valor: _qtd(dados.impressas),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 65),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Alteração de preço por departamento',
              style: TextStyle(
                color: _texto,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (dados.departamentos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Nenhum departamento com alteração.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            _DepartamentoTabela(
              departamentos: dados.departamentos,
              plural: plural,
            ),
        ],
      ),
    );
  }
}

class _CardIndicador extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color? cor;
  final bool destaque;

  const _CardIndicador({
    required this.titulo,
    required this.valor,
    this.cor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 145,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: destaque ? cor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: destaque ? Colors.white : _texto,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: destaque ? Colors.white : _texto,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartamentoTabela extends StatelessWidget {
  final List<DepartamentoResumo> departamentos;
  final String plural;

  const _DepartamentoTabela({
    required this.departamentos,
    required this.plural,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF0F0F4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              const Expanded(
                flex: 5,
                child: Text('Departamentos ↑',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 3,
                child: Text('$plural à imprimir ↑',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 3,
                child: Text('$plural impressas ↑',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ...departamentos.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE6E6E6)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    item.nome,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: _texto),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${item.imprimir}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _texto),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${item.impressas}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _texto),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
