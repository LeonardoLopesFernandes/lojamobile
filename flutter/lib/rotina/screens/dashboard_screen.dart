import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario/rotina/api/endpoints.dart';
import 'package:inventario/rotina/hooks/departments_controller.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/utils/time.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _dailyLabels = [
    'Próx. venc.',
    'Mal precif.',
    'Sem repos.',
    'Divergência',
    'Mal exposto',
    'Preço alto',
    'Sem irreg.',
    'Não tratado',
  ];

  static const _unsoldLabels = [
    'Divergência',
    'Mal exposto',
    'Preço elev.',
    'Grade incoer.',
    'Não exposto',
    'Falta 9000',
    'Não conf.',
    'Não tratado',
  ];

  late DateTime _selectedDate;
  bool _loading = true;
  bool _started = false;
  String? _error;
  int _requestToken = 0;
  CardsPercentageResponse? _dailyCards;
  CardsPercentageResponse? _weeklyCards;
  UnsoldTreatedCardResponse? _unsoldCards;
  List<RoutineStatusItem> _routineStatus = [];
  List<ByAnswerItem> _dailyAnswers = [];
  List<ByAnswerItem> _weeklyAnswers = [];
  List<ByAnswerItem> _unsoldAnswers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _selectedDate =
        clampToWeekday(context.read<DepartmentsController>().selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    final token = ++_requestToken;
    setState(() {
      _loading = true;
      _error = null;
    });

    var falhas = 0;
    Future<T?> safe<T>(Future<T> future) async {
      try {
        return await future;
      } catch (_) {
        falhas++;
        return null;
      }
    }

    final date = formatStorageDate(_selectedDate);
    final results = await Future.wait<dynamic>([
      safe(getCardsPercentage(date)),
      safe(getTreatedByAnswers(date)),
      safe(getCardsPercentage()),
      safe(getTreatedByAnswers()),
      safe(getRoutineStatusList()),
      safe(getUnsoldTreatedCard()),
      safe(getUnsoldTreatedAnswers()),
    ]);
    if (!mounted || token != _requestToken) return;

    setState(() {
      _dailyCards = results[0] as CardsPercentageResponse?;
      _dailyAnswers = (results[1] as List<ByAnswerItem>?) ?? [];
      _weeklyCards = results[2] as CardsPercentageResponse?;
      _weeklyAnswers = (results[3] as List<ByAnswerItem>?) ?? [];
      _routineStatus = (results[4] as List<RoutineStatusItem>?) ?? [];
      _unsoldCards = results[5] as UnsoldTreatedCardResponse?;
      _unsoldAnswers = (results[6] as List<ByAnswerItem>?) ?? [];
      _error = falhas == 0
          ? null
          : falhas == results.length
              ? 'Não foi possível carregar os indicadores.'
              : 'Alguns indicadores não puderam ser carregados.';
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final hoje = DateTime.now();
    final primeiro = DateTime(hoje.year - 2, 1, 1);
    final ultimo = DateTime(hoje.year, hoje.month, hoje.day);
    var inicial = _selectedDate;
    if (inicial.isBefore(primeiro)) inicial = primeiro;
    if (inicial.isAfter(ultimo)) inicial = ultimo;

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primeiro,
      lastDate: ultimo,
      selectableDayPredicate: (date) =>
          date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday,
      helpText: 'Escolha o dia',
      cancelText: 'Cancelar',
      confirmText: 'Ver dia',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
    _loadDashboard();
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) return '${value.toInt()}%';
    return '${value.toStringAsFixed(1)}%';
  }

  String _shortWeekday(DateTime date) =>
      getDayOfWeekPt(date).split('-').first;

  String _shortLabel(String question, {bool special = false}) {
    final q = question.toLowerCase();
    if (q.contains('não exposto') || q.contains('nao exposto')) {
      return 'Não exposto';
    }
    if (q.contains('vencimento')) return 'Próx. venc.';
    if (q.contains('precific')) return 'Mal precif.';
    if (q.contains('reposi') || q.contains('grade do cd')) return 'Sem repos.';
    if (q.contains('diverg')) return 'Divergência';
    if (q.contains('exposto') || q.contains('abastec')) return 'Mal exposto';
    if (q.contains('concorr') || q.contains('preço') || q.contains('preco')) {
      return special ? 'Preço elev.' : 'Preço alto';
    }
    if (q.contains('grade')) return 'Grade incoer.';
    if (q.contains('9000') || q.contains('falta')) return 'Falta 9000';
    if (q.contains('confer')) return 'Não conf.';
    if (q.contains('não tratado') || q.contains('nao tratado')) {
      return 'Não tratado';
    }
    if (q.contains('irregular')) return 'Sem irreg.';
    return question.length > 14 ? '${question.substring(0, 13)}…' : question;
  }

  Color _barColor(String label, int index) {
    if (label == 'Próx. venc.') return AppColors.primary;
    if (label == 'Mal precif.') return Colors.orange;
    if (label == 'Sem repos.') return Colors.redAccent;
    if (label == 'Divergência') return Colors.redAccent;
    if (label == 'Mal exposto') return Colors.orange;
    if (label == 'Preço alto' || label == 'Preço elev.') {
      return Colors.pinkAccent;
    }
    if (label == 'Sem irreg.') return Colors.pinkAccent;
    if (label == 'Não tratado') return Colors.black54;
    if (label == 'Não exposto') return Colors.orange;
    if (label == 'Grade incoer.') return Colors.blueGrey;
    if (label == 'Falta 9000') return Colors.deepOrange;
    if (label == 'Não conf.') return Colors.purple;
    const palette = [
      AppColors.primary,
      Colors.orange,
      Colors.redAccent,
      Colors.teal,
      Colors.purple,
      Colors.pinkAccent,
      Colors.black54,
      Colors.blueGrey,
    ];
    return palette[index % palette.length];
  }

  List<_BarDatum> _buildBars(List<ByAnswerItem> items,
      {bool special = false}) {
    final order = special ? _unsoldLabels : _dailyLabels;
    final values = <String, int>{for (final label in order) label: 0};
    for (final item in items) {
      final label = _shortLabel(item.question, special: special);
      values[label] = (values[label] ?? 0) + item.items;
    }
    final labels = [...order];
    for (final key in values.keys) {
      if (!labels.contains(key)) labels.add(key);
    }
    final result = <_BarDatum>[];
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      result.add(_BarDatum(label, values[label] ?? 0, _barColor(label, i)));
    }
    return result;
  }

  String _routineLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('completa')) return 'Rotina completa';
    if (s.contains('parcial')) return 'Rotina parcial';
    if (s.contains('não') ||
        s.contains('nao') ||
        s.contains('executada') ||
        s.contains('sem')) {
      return 'Rotina não executada';
    }
    return status;
  }

  Color _routineColor(String label) {
    if (label == 'Rotina completa') return AppColors.primary;
    if (label == 'Rotina parcial') return Colors.orange;
    if (label == 'Rotina não executada') return const Color(0xFF9CA3AF);
    return Colors.blueGrey;
  }

  List<_RoutineSlice> _buildRoutineSlices() {
    if (_routineStatus.isEmpty) return const [];
    final totalDays =
        _routineStatus.fold<int>(0, (sum, item) => sum + item.days);
    final useDays = totalDays > 0;
    final values = <String, double>{};
    for (final item in _routineStatus) {
      final label = _routineLabel(item.status);
      final value = useDays ? item.days.toDouble() : item.percentage;
      values[label] = (values[label] ?? 0) + value;
    }
    final total = values.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return const [];
    const order = [
      'Rotina completa',
      'Rotina parcial',
      'Rotina não executada',
    ];
    final labels = [...order];
    for (final key in values.keys) {
      if (!labels.contains(key)) labels.add(key);
    }
    return [
      for (final label in labels)
        if ((values[label] ?? 0) > 0)
          _RoutineSlice(label, values[label]!, _routineColor(label)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Column(
        children: [
          _toolbar(context),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : SafeArea(
                    top: false,
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadDashboard,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                        children: [
                          if (_error != null) _errorBanner(),
                          _sectionHeader(
                            title: 'Indicadores por dia (Loja $store):',
                            trailing: _dateChip(),
                          ),
                          const SizedBox(height: 12),
                          _cardWrapper([
                            _metricBox(
                              title: 'Itens tratados:',
                              value: _dailyCards?.treatedItemsQuantity,
                              percentage: _dailyCards?.treatedItemsPercentage,
                            ),
                            const SizedBox(height: 12),
                            _metricBox(
                              title: 'Departamentos tratados:',
                              value: _dailyCards?.treatedDepartmentsQuantity,
                              percentage:
                                  _dailyCards?.treatedDepartmentsPercentage,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _cardWrapper([
                            _chartTitle('Quantidade de itens por resposta:'),
                            const SizedBox(height: 16),
                            _BarChart(data: _buildBars(_dailyAnswers)),
                          ]),
                          const SizedBox(height: 32),
                          _sectionHeader(
                            title: 'Acumulado da semana (Loja $store):',
                          ),
                          const SizedBox(height: 12),
                          _cardWrapper([
                            _metricBox(
                              title: 'Itens tratados:',
                              value: _weeklyCards?.treatedItemsQuantity,
                              percentage:
                                  _weeklyCards?.treatedItemsPercentage,
                            ),
                            const SizedBox(height: 12),
                            _metricBox(
                              title: 'Departamentos tratados:',
                              value: _weeklyCards?.treatedDepartmentsQuantity,
                              percentage:
                                  _weeklyCards?.treatedDepartmentsPercentage,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _cardWrapper([
                            _chartTitle('Quantidade de itens por resposta:'),
                            const SizedBox(height: 16),
                            _BarChart(data: _buildBars(_weeklyAnswers)),
                          ]),
                          const SizedBox(height: 16),
                          _cardWrapper([
                            _chartTitle('Adesão à rotina esta semana:'),
                            const SizedBox(height: 12),
                            _RoutineChart(slices: _buildRoutineSlices()),
                          ]),
                          const SizedBox(height: 32),
                          _sectionHeader(
                            title:
                                'Tratamentos especiais > Itens sem venda (Loja $store):',
                          ),
                          const SizedBox(height: 12),
                          _cardWrapper([
                            _metricBox(
                              title: 'Itens tratados:',
                              value:
                                  _unsoldCards?.unsoldTreatedItemsQuantity,
                              percentage:
                                  _unsoldCards?.unsoldTreatedItemsPercentage,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _cardWrapper([
                            _chartTitle('Quantidade de itens por resposta:'),
                            const SizedBox(height: 16),
                            _BarChart(
                              data:
                                  _buildBars(_unsoldAnswers, special: true),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 12, right: 12),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child:
                      Icon(Icons.arrow_back, color: AppColors.primary, size: 28),
                ),
              ),
            ),
            const Expanded(
              child: Text('Painel de indicadores',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'Open Sans')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({required String title, Widget? trailing}) {
    final titleWidget = Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4B5563),
        fontFamily: 'Open Sans',
        height: 1.25,
      ),
    );
    if (trailing == null) return titleWidget;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 12),
            trailing,
          ],
        );
      },
    );
  }

  Widget _dateChip() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_shortWeekday(_selectedDate)}, '
              '${formatDisplayDate(_selectedDate)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                fontFamily: 'Open Sans',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.calendar_today,
                  size: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardWrapper(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _metricBox({
    required String title,
    int? value,
    double? percentage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontFamily: 'Open Sans',
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(
                value?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontFamily: 'Open Sans',
                  height: 1,
                ),
              ),
              Text(
                percentage == null
                    ? '(sem dados)'
                    : '(${_formatPercent(percentage)} do total)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontFamily: 'Open Sans',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        fontFamily: 'Open Sans',
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Open Sans',
              ),
            ),
          ),
          TextButton(
            onPressed: _loadDashboard,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _BarDatum {
  final String label;
  final int value;
  final Color color;
  const _BarDatum(this.label, this.value, this.color);
}

class _BarChart extends StatelessWidget {
  final List<_BarDatum> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<int>(
      1,
      (max, datum) => datum.value > max ? datum.value : max,
    );
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final datum = entry.value;
          final barHeight = datum.value == 0
              ? 4.0
              : math.max(10.0, (datum.value / maxValue) * 120.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (datum.value > 0)
                    Text(
                      '${datum.value}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontFamily: 'Open Sans',
                      ),
                    ),
                  if (datum.value > 0) const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: datum.value == 0
                          ? const Color(0xFFD1D5DB)
                          : datum.color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
                    child: Text(
                      datum.label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.15,
                        color: Colors.black54,
                        fontFamily: 'Open Sans',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RoutineSlice {
  final String label;
  final double value;
  final Color color;
  const _RoutineSlice(this.label, this.value, this.color);
}

class _RoutineChart extends StatelessWidget {
  final List<_RoutineSlice> slices;
  const _RoutineChart({required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Sem dados',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textHint,
            fontFamily: 'Open Sans',
          ),
        ),
      );
    }
    final total =
        slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final complete = slices
        .where((slice) => slice.label == 'Rotina completa')
        .fold<double>(0, (sum, slice) => sum + slice.value);
    final completePercent = total <= 0 ? 0.0 : (complete / total) * 100;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final slice in slices) _LegendItem(slice: slice),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(168),
                painter: _DonutPainter(slices: slices, total: total),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${completePercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'Open Sans',
                      height: 1,
                    ),
                  ),
                  const Text(
                    'completa',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontFamily: 'Open Sans',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _RoutineSlice slice;
  const _LegendItem({required this.slice});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          slice.label,
          style: const TextStyle(
            fontSize: 11.5,
            color: Colors.black54,
            fontFamily: 'Open Sans',
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_RoutineSlice> slices;
  final double total;
  const _DonutPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep =
          total <= 0 ? 0.0 : (slice.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }
    canvas.drawCircle(
      center,
      radius * 0.58,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}
