import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:inventario/rotina/api/client.dart';
import 'package:inventario/rotina/api/endpoints.dart';
import 'package:inventario/rotina/storage/session.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/utils/time.dart';

class DepartmentsController with ChangeNotifier {
  List<Department> _allDepartments = [];
  List<Department> _departments = [];
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  DateTime _selectedDate = clampToWeekday(DateTime.now());

  /// Cache por data (yyyy-MM-dd): troca de dia fica instantânea ao revisitar.
  final Map<String, List<Department>> _cache = {};

  List<Department> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  DateTime get selectedDate => _selectedDate;

  set selectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> loadDataForDate(DateTime date, [bool silent = false]) async {
    final dateApi = formatApiDate(date);
    final storageDate = formatStorageDate(date);
    final cached = _cache[storageDate];
    if (!silent) {
      _error = null;
      if (cached != null) {
        // Já foi carregada antes: mostra na hora (sem tela de loading).
        _allDepartments = cached;
        _departments = cached;
        _isLoading = false;
      } else {
        _isLoading = true;
      }
      notifyListeners();
    }
    try {
      final items = await getItems(dateApi);

      final allTreatments = await Session.loadAllTreatments(storageDate);

      final merged = <Department>[];
      for (final dept in items) {
        final itemsWithCode = <Item>[];
        for (final item in dept.items) {
          final base = item.copyWith(departmentCode: dept.department.code);
          final stored = allTreatments[item.ean];
          final applied = Session.applyStoredToItem(stored, base);
          itemsWithCode.add(applied.copyWith(
            treated:
                applied.treated || (applied.answers?.isNotEmpty ?? false),
          ));
        }
        merged.add(Department(department: dept.department, items: itemsWithCode));
      }
      _allDepartments = merged;
      _allDepartments.sort((a, b) => a.department.code.compareTo(b.department.code));
      _cache[storageDate] = _allDepartments;
      _departments = _allDepartments;
    } on DioException catch (e) {
      _error = mapErrorMessage(e);
    } catch (e) {
      _error = mapErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadData([bool silent = false]) async {
    final today = clampToWeekday(DateTime.now());
    _selectedDate = today;
    await loadDataForDate(today, silent);
  }

  Future<void> refresh() async {
    await loadDataForDate(_selectedDate);
  }

  void searchDepartment(String query) {
    if (query.trim().isEmpty) {
      _departments = _allDepartments;
    } else {
      final q = query.trim().toLowerCase();
      _departments = _allDepartments
          .where((d) =>
              d.department.name.toLowerCase().contains(q) ||
              d.department.code.toLowerCase().contains(q))
          .toList();
    }
    notifyListeners();
  }

  Future<void> markItemProblems(
      String itemId, List<int> problemNumbers, DateTime date) async {
    final deptIndex = _allDepartments
        .indexWhere((d) => d.items.any((i) => i.id == itemId));
    if (deptIndex < 0) {
      _error = '❌ Item não encontrado';
      notifyListeners();
      return;
    }
    final item =
        _allDepartments[deptIndex].items.firstWhere((i) => i.id == itemId);
    if (item.treated) {
      _error = '⚠️ Este item já foi respondido anteriormente.';
      notifyListeners();
      return;
    }

    final answers = questions
        .asMap()
        .entries
        .map((e) => {
              'question': e.value,
              'answer': problemNumbers.contains(e.key + 1),
            })
        .toList();

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

    await Session.saveTreatment(formatStorageDate(date), item.ean,
        StoredTreatment(treated: true, treatedAt: nowStr, treatedBy: userName, answers: selectedAnswers));

    _allDepartments = _allDepartments.map((dept) {
      if (dept.department.code == _allDepartments[deptIndex].department.code) {
        return Department(
          department: dept.department,
          items: dept.items
              .map((i) => i.id == itemId ? updatedItem : i)
              .toList(),
        );
      }
      return dept;
    }).toList();
    _departments = _allDepartments;
    _cache[formatStorageDate(date)] = _allDepartments;
    _successMessage = '✅ Item salvo com sucesso!';
    _error = null;
    notifyListeners();

    try {
      final response = await saveTreatedItem(TreatedItemRequest(
        store: store,
        date: formatStorageDate(date),
        ean: item.ean,
        answers: answers,
      ));
      if (!response.success) {
        _error = '❌ ${response.message ?? ''}';
        notifyListeners();
      }
    } on DioException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('400') || msg.contains('409')) {
        _error = '⚠️ Este item já foi respondido. Recarregue a lista.';
      } else {
        _error = mapGenericError(e);
      }
      notifyListeners();
    } catch (e) {
      _error = mapGenericError(e);
      notifyListeners();
    }
  }

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }
}
