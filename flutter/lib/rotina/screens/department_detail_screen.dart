import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario/rotina/api/endpoints.dart';
import 'package:inventario/rotina/auth/auth_provider.dart';
import 'package:inventario/rotina/components/checklist_modal.dart';
import 'package:inventario/rotina/components/success_toast.dart';
import 'package:inventario/rotina/components/product_card.dart';
import 'package:inventario/rotina/components/sticky_check.dart';
import 'package:inventario/rotina/components/treatment_badge_modal.dart';
import 'package:inventario/rotina/storage/session.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/utils/time.dart';
import 'package:inventario/rotina/utils/toast.dart';

class DepartmentDetailScreen extends StatefulWidget {
  const DepartmentDetailScreen({super.key});

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  late String _deptCode;
  late String _deptName;
  late DateTime _selectedDate;
  List<Item> _list = [];
  bool _loaded = false;
  Item? _checklistItem;
  Item? _badgeItem;
  bool _saving = false;
  bool _showSuccessToast = false;
  late bool _blocked;

  @override
  void initState() {
    super.initState();
    _blocked = isBlocked();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && !_loaded) {
      _deptCode = args['deptCode'] as String;
      _deptName = args['deptName'] as String;
      _selectedDate =
          DateTime.fromMillisecondsSinceEpoch(args['selectedDate'] as int);
      final items = (args['items'] as List<Item>)
          .map((e) => e.copyWith(departmentCode: _deptCode))
          .toList();
      _list = items;
      _loaded = true;
    }
  }

  Future<void> _saveItemProblems(Item item, List<int> problemNumbers) async {
    setState(() => _saving = true);
    try {
      final answers = questions
          .asMap()
          .entries
          .map((e) => {
                'question': e.value,
                'answer': problemNumbers.contains(e.key + 1),
              })
          .toList();
      final response = await saveTreatedItem(TreatedItemRequest(
        store: store,
        date: formatStorageDate(_selectedDate),
        ean: item.ean,
        answers: answers,
      ));
      if (!response.success) {
        showToast(response.message ?? 'Erro ao salvar', isError: true);
        return;
      }
      final userName = await Session.getUserName();
      final nowStr = formatIso(DateTime.now());
      final selectedAnswers = problemNumbers
          .map((n) => TreatedAnswer(
                question: questions[n - 1],
                shortQuestion: shortQuestions[n - 1],
                answer: true,
                number: n,
                items: 1,
                percentage: 100.0,
              ))
          .toList();
      final updatedItem = item.copyWith(
        treated: true,
        treatedAt: nowStr,
        treatedBy: userName,
        answers: selectedAnswers,
      );
      setState(() {
        _list = _list
            .map((i) => i.id == item.id ? updatedItem : i)
            .toList();
      });
      await Session.saveTreatment(formatStorageDate(_selectedDate), item.ean,
          StoredTreatment(treated: true, treatedAt: nowStr, treatedBy: userName, answers: selectedAnswers));
      setState(() => _showSuccessToast = true);
    } catch (e) {
      showToast('Erro: $e', isError: true);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    final treatedCount = _list.where((i) => i.treated).length;
    final allTreated = _list.isNotEmpty && treatedCount == _list.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _toolbar(allTreated, blocked),
              Expanded(
                child: _saving
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _list.length,
                        itemBuilder: (context, index) {
                          final item = _list[index];
                          return ProductCard(
                            item: item,
                            blocked: blocked,
                            onEdit: (i) => setState(() => _checklistItem = i),
                            onShowBadge: (i) => setState(() => _badgeItem = i),
                          );
                        },
                      ),
              ),
            ],
          ),
          ChecklistModal(
            visible: _checklistItem != null,
            item: _checklistItem,
            onClose: () => setState(() => _checklistItem = null),
            onSave: (item, problems) {
              _saveItemProblems(item, problems);
              setState(() => _checklistItem = null);
            },
          ),
          TreatmentBadgeModal(
            visible: _badgeItem != null,
            item: _badgeItem,
            userName: context.read<AuthProvider>().userName,
            onClose: () => setState(() => _badgeItem = null),
          ),
          if (_showSuccessToast)
            SuccessToast(
              onHide: () => setState(() => _showSuccessToast = false),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(bool allTreated, bool blocked) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 12, right: 12),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text('$_deptCode - $_deptName',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Open Sans'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (allTreated) ...[
                    const SizedBox(width: 8),
                    const StickyCheck(size: 44),
                  ],
                ],
              ),
            ),
            if (blocked)
              Image.asset('assets/rotina/ic_block.png', width: 26, height: 26),
          ],
        ),
      ),
    );
  }
}
