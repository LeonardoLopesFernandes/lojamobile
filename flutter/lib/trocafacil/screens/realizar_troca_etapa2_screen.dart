import 'package:flutter/material.dart';
import 'package:inventario/network/session_manager.dart';
import 'package:inventario/precificacao/utils/toast_utils.dart';
import '../models/cupom.dart';
import '../network/troca_api.dart';
import '../network/troca_session.dart';

/// Etapa 2/2 — "Dados do cupom" (Troca Fácil).
class RealizarTrocaEtapa2Screen extends StatefulWidget {
  const RealizarTrocaEtapa2Screen({super.key});

  @override
  State<RealizarTrocaEtapa2Screen> createState() =>
      _RealizarTrocaEtapa2ScreenState();
}

class _RealizarTrocaEtapa2ScreenState
    extends State<RealizarTrocaEtapa2Screen> {
  static const List<String> _motivosDefeito = [
    'Bateria',
    'Avariado (Arranhado, rasgado, furado)',
    'Tela com defeito',
    'Áudio com defeito',
    'Câmera com defeito',
    'Fora da validade',
    'Faltando peças',
    'Não está ligando',
    'Outros',
  ];
  static const List<String> _motivosInsatisfacao = [
    'Cor',
    'Tamanho',
    'Voltagem',
    'Presente',
    'Não se adaptou',
    'Outros',
  ];

  final TrocaApi _api = TrocaApi();

  final _loja = TextEditingController();
  final _pdv = TextEditingController();
  final _data = TextEditingController();
  final _cupom = TextEditingController();
  final _descricao = TextEditingController();

  bool _clienteSemCupom = false;
  DateTime? _dataSelecionada;
  String _motivoTipo = 'Defeito';
  String _tipoOperacao = 'Troca';
  String _motivoSelecionado = 'Selecione um motivo';

  bool _carregando = false;
  bool _argsLidos = false;
  Map<String, dynamic> _cliente = {};

  @override
  void initState() {
    super.initState();
    for (final c in [_loja, _pdv, _data, _cupom, _descricao]) {
      c.addListener(() => setState(() {}));
    }
    _dataSelecionada = DateTime.now();
    _data.text = _fmt(_dataSelecionada!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLidos) return;
    _argsLidos = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) _cliente = Map<String, dynamic>.from(args);
    _initLoja();
  }

  Future<void> _initLoja() async {
    final session = await SessionManager.create();
    final loja = session.getUserStore().replaceFirst(RegExp('^L'), '');
    if (!mounted) return;
    setState(() => _loja.text = loja);
  }

  @override
  void dispose() {
    _loja.dispose();
    _pdv.dispose();
    _data.dispose();
    _cupom.dispose();
    _descricao.dispose();
    super.dispose();
  }

  List<String> get _motivos =>
      _motivoTipo == 'Defeito' ? _motivosDefeito : _motivosInsatisfacao;

  String get _cause => _motivoTipo == 'Defeito' ? 'DEFEITO' : 'INSATISFACAO';
  String get _operationType =>
      _tipoOperacao == 'Devolução' ? 'DEVOLUCAO' : 'TROCA';

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _compact(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  bool get _preenchido =>
      _loja.text.trim().isNotEmpty &&
      _pdv.text.trim().isNotEmpty &&
      _cupom.text.trim().isNotEmpty &&
      _dataSelecionada != null &&
      _motivoSelecionado != 'Selecione um motivo' &&
      (_motivoSelecionado != 'Outros' || _descricao.text.trim().isNotEmpty);

  Future<void> _pickData() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dataSelecionada = picked;
      _data.text = _fmt(picked);
    });
  }

  Future<void> _escolherMotivo() async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _motivos.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (_, i) {
            final item = _motivos[i];
            return ListTile(
              dense: true,
              title: Text(item,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
              onTap: () => Navigator.pop(ctx, item),
            );
          },
        ),
      ),
    );
    if (escolha == null) return;
    setState(() => _motivoSelecionado = escolha);
  }

  String get _reason => _motivoSelecionado == 'Outros'
      ? _descricao.text.trim()
      : _motivoSelecionado;

  Future<void> _enviar() async {
    if (!_preenchido || _carregando) return;
    setState(() => _carregando = true);
    try {
      final cupom = await _api.getCupom(
        storeId: _loja.text.trim(),
        pdv: _pdv.text.trim(),
        data: _compact(_dataSelecionada!),
        cupom: _cupom.text.trim(),
        cause: _cause,
      );
      if (!mounted) return;
      if (cupom.products.isEmpty) {
        ToastUtils.showInfo(context, 'Cupom não encontrado');
        return;
      }
      Navigator.of(context).pushNamed('/troca_itens', arguments: {
        'cupom': cupom,
        'cliente': _cliente,
        'cause': _cause,
        'motivoLabel': _motivoTipo,
        'reason': _reason,
        'operationType': _operationType,
      });
    } on TrocaApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        final t = await TrocaSession.create();
        t.clear();
        ToastUtils.showError(context, 'Sessão expirada. Faça login novamente.');
      } else {
        ToastUtils.showError(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao buscar cupom');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Dados do cupom',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Text('Insira os dados relacionados ao cupom do cliente:',
              style: TextStyle(fontSize: 15, color: Colors.black54)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Cliente sem cupom fiscal?',
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(width: 8),
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: _clienteSemCupom,
                  activeColor: const Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (v) =>
                      setState(() => _clienteSemCupom = v ?? false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _campoComTitulo(
                  titulo: 'Loja de origem do cupom (Apenas números)',
                  controller: _loja,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _campoComTitulo(titulo: 'PDV', controller: _pdv),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _campoComTitulo(
                  titulo: 'Data',
                  controller: _data,
                  readOnly: true,
                  suffixIcon: Icons.keyboard_arrow_down,
                  onTap: _pickData,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _campoComTitulo(titulo: 'Cupom', controller: _cupom),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Motivo da troca ou devolução',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _radio('Defeito', _motivoTipo, (v) {
                          setState(() {
                            _motivoTipo = v!;
                            _motivoSelecionado = 'Selecione um motivo';
                          });
                        }),
                        const SizedBox(width: 12),
                        _radio('Insatisfação', _motivoTipo, (v) {
                          setState(() {
                            _motivoTipo = v!;
                            _motivoSelecionado = 'Selecione um motivo';
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _escolherMotivo,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _motivoSelecionado,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _motivoSelecionado ==
                                          'Selecione um motivo'
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down,
                                color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de Operação',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _radio('Troca', _tipoOperacao,
                            (v) => setState(() => _tipoOperacao = v!)),
                        const SizedBox(width: 12),
                        _radio('Devolução', _tipoOperacao,
                            (v) => setState(() => _tipoOperacao = v!)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_motivoSelecionado == 'Outros') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _descricao,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Descreva o motivo...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('‹ Voltar',
                    style: TextStyle(color: Colors.black87)),
              ),
              ElevatedButton(
                onPressed: (_preenchido && !_carregando) ? _enviar : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Enviar',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _campoComTitulo({
    required String titulo,
    required TextEditingController controller,
    IconData? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final field = Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly || onTap != null,
        onTap: onTap,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, color: Colors.grey, size: 20)
              : null,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _radio(String title, String groupValue, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: Radio<String>(
            value: title,
            groupValue: groupValue,
            activeColor: const Color(0xFFD32F2F),
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Text(title,
            style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    );
  }
}
