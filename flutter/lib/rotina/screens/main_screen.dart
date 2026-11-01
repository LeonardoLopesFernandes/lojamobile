import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:inventario/rotina/api/endpoints.dart';
import 'package:inventario/rotina/auth/auth_provider.dart';
import 'package:inventario/rotina/components/checklist_modal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventario/rotina/components/department_card.dart';
import 'package:inventario/rotina/components/campaign_book_card.dart';
import 'package:inventario/rotina/components/photo_upload_dialog.dart';
import 'package:inventario/rotina/components/uploading_dialog.dart';
import 'package:inventario/rotina/components/success_toast.dart';
import 'package:inventario/rotina/components/treatment_badge_modal.dart';
import 'package:inventario/rotina/hooks/departments_controller.dart';
import 'package:inventario/rotina/screens/books_screen.dart';
import 'package:inventario/rotina/screens/profile_screen.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/utils/time.dart';
import 'package:inventario/rotina/utils/toast.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late bool _blocked;
  final _queryController = TextEditingController();
  bool _showMenu = false;
  bool _showLogout = false;
  bool _showExit = false;
  bool _showDatePicker = false;
  late DateTime _calendarMonth;
  Item? _checklistItem;
  Item? _badgeItem;
  bool _showSuccessToast = false;
  bool _loaded = false;
  bool _ocultarTopo = false;
  List<BookStatus> _books = [];

  @override
  void initState() {
    super.initState();
    _blocked = isBlocked();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loaded) {
        _loaded = true;
        context.read<DepartmentsController>().loadData();
        _loadBooks();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<DepartmentsController>();
    final success = controller.successMessage;
    if (success != null) {
      _showSuccessToast = true;
      controller.clearSuccessMessage();
    }
  }

  Future<void> _loadBooks() async {
    try {
      final books = await getBooks();
      if (mounted) setState(() => _books = books);
    } catch (_) {}
  }

  Future<void> _openBooks() async {
    setState(() => _showMenu = false);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BooksScreen()));
    if (mounted) _loadBooks();
  }

  Future<void> _anexarFotos(BookStatus book) async {
    if (!book.podeEnviarFotos) return;
    final fotos = await showDialog<List<XFile>>(
      context: context,
      builder: (_) => PhotoUploadDialog(
        filesQuantity: book.filesQuantity,
        bookName: book.name,
      ),
    );
    if (fotos == null || fotos.isEmpty || !mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadingDialog(),
    );
    try {
      await uploadBookPhotos(book.bookId, fotos, loja: store);
      navigator.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${fotos.length} foto(s) enviada(s) para ${book.name}.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadBooks();
    } catch (e) {
      navigator.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadErrorMessage(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DepartmentsController>();
    final booksPendentes = _books.where((b) => b.pendente).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Consome o voltar apenas se o teclado estiver visível; foco retido
        // sem teclado aberto não deve bloquear o fluxo de saída
        if (MediaQuery.of(context).viewInsets.bottom > 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }
        FocusManager.instance.primaryFocus?.unfocus();
        if (_showMenu) {
          setState(() => _showMenu = false);
          return;
        }
        if (_showLogout) {
          setState(() => _showLogout = false);
          return;
        }
        if (_showExit) return;
        if (_showDatePicker) {
          setState(() => _showDatePicker = false);
          return;
        }
        if (_checklistItem != null) {
          setState(() => _checklistItem = null);
          return;
        }
        if (_badgeItem != null) {
          setState(() => _badgeItem = null);
          return;
        }
        if (!sameDay(controller.selectedDate, DateTime.now())) {
          final today = clampToWeekday(DateTime.now());
          controller.selectedDate = today;
          controller.loadDataForDate(today);
          return;
        }
        setState(() => _showExit = true);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Column(
              children: [
                _toolbar(context, controller),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: _ocultarTopo
                              ? _minimalDateCard(controller)
                              : _mainCard(controller),
                        ),
                        const SizedBox(height: 6),
                        if (booksPendentes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: CampaignBookCard(
                                book: booksPendentes.first,
                                minimalista: _ocultarTopo,
                                onAddPhoto: () =>
                                    _anexarFotos(booksPendentes.first),
                                onView: _openBooks,
                              ),
                            ),
                          ),
                        if (booksPendentes.length > 1)
                          GestureDetector(
                            onTap: _openBooks,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '+${booksPendentes.length - 1} book(s) pendente(s)',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    fontFamily: 'Open Sans'),
                              ),
                            ),
                          ),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.depth == 0 &&
                                  n is ScrollUpdateNotification) {
                                if (n.metrics.pixels <= 0) {
                                  if (_ocultarTopo) {
                                    setState(() => _ocultarTopo = false);
                                  }
                                } else if ((n.scrollDelta ?? 0) > 4 &&
                                    !_ocultarTopo) {
                                  setState(() => _ocultarTopo = true);
                                }
                              }
                              return false;
                            },
                            child: _content(controller),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_showMenu) _menuOverlay(context),
            if (_showExit) _exitDialog(),
            if (_showLogout) _logoutDialog(context),
            if (_showDatePicker)
              _datePickerSheet(context, controller),
            ChecklistModal(
              visible: _checklistItem != null,
              item: _checklistItem,
              onClose: () => setState(() => _checklistItem = null),
              onSave: (item, problems) async {
                await controller.markItemProblems(
                    item.id, problems, controller.selectedDate);
                if (mounted) setState(() => _checklistItem = null);
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
      ),
    );
  }

  Widget _toolbar(BuildContext context, DepartmentsController controller) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 12, right: 12),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _showMenu = true),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(Icons.menu, color: AppColors.primary, size: 30),
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/rotina/logo_rotina.png', width: 26, height: 26),
                  const SizedBox(width: 8),
                  const Text('Rotina Comercial',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Open Sans')),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x03000000), blurRadius: 12, offset: Offset(0, 8)),
                  ],
                ),
                child: Center(
                  child: Image.asset('assets/rotina/ic_user.png', width: 28, height: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainCard(DepartmentsController controller) {
    final dayOfWeek = getDayOfWeekPt(controller.selectedDate);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _showDatePicker = true;
              _calendarMonth =
                  DateTime(controller.selectedDate.year, controller.selectedDate.month, 1);
            }),
            child: Row(
              children: [
                const Icon(Icons.today, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dia da Semana:',
                          style: TextStyle(fontSize: 15, color: AppColors.textMuted, fontFamily: 'Open Sans')),
                      Text(dayOfWeek,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'Open Sans')),
                    ],
                  ),
                ),
                Image.asset('assets/rotina/agenda.png', width: 110, height: 44),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _showDatePicker = true;
              _calendarMonth =
                  DateTime(controller.selectedDate.year, controller.selectedDate.month, 1);
            }),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Data:',
                          style: TextStyle(fontSize: 15, color: AppColors.textMuted, fontFamily: 'Open Sans')),
                      Text(formatDisplayDate(controller.selectedDate),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'Open Sans')),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    showToast('Gerando PDF...');
                    final result = await downloadDaySchedulePdf(
                        formatApiDate(controller.selectedDate));
                    showToast(result.message, isError: true);
                  },
                  child: Image.asset('assets/rotina/imprimir.png', width: 110, height: 44),
                ),
              ],
            ),
          ),
          const Divider(height: 18, color: AppColors.divider),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC8C6C4)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'Open Sans',
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Pesquisar por departamento',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontFamily: 'Open Sans',
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (text) => controller.searchDepartment(text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _minimalDateCard(DepartmentsController controller) {
    final diaSemana =
        getDayOfWeekPt(controller.selectedDate).split('-').first;
    return GestureDetector(
      onTap: () => setState(() {
        _showDatePicker = true;
        _calendarMonth = DateTime(controller.selectedDate.year,
            controller.selectedDate.month, 1);
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.today, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$diaSemana, ${formatDisplayDate(controller.selectedDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: 'Open Sans',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(DepartmentsController controller) {
    final list = controller.departments;
    // Só mostra a tela de loading quando ainda não há lista para exibir.
    if (controller.isLoading && list.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (controller.error != null && list.isEmpty) {
      return Center(
        child: Text(controller.error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 15, fontFamily: 'Open Sans'),
            textAlign: TextAlign.center),
      );
    }
    if (list.isEmpty) {
      return const Center(
        child: Text('Nenhum item encontrado para esta data',
            style: TextStyle(color: AppColors.textHint, fontSize: 15, fontFamily: 'Open Sans'),
            textAlign: TextAlign.center),
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => controller.refresh(),
          child: ListView.builder(
            itemCount: controller.departments.length,
            itemBuilder: (context, index) {
              final dept = controller.departments[index];
              return DepartmentCard(
                department: dept,
                blocked: _blocked,
                onViewAll: (d) {
                  Navigator.of(context).pushNamed(
                    'DepartmentDetail',
                    arguments: {
                      'deptCode': d.department.code,
                      'deptName': d.department.name,
                      'selectedDate': controller.selectedDate.millisecondsSinceEpoch,
                      'items': d.items,
                    },
                  );
                },
                onEditItem: (item) => setState(() => _checklistItem = item),
                onShowBadge: (item) => setState(() => _badgeItem = item),
              );
            },
          ),
        ),
        // Loader fino no topo enquanto atualiza (não some com a lista).
        if (controller.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
                color: AppColors.primary, minHeight: 3),
          ),
      ],
    );
  }

  Widget _menuOverlay(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showMenu = false),
      child: Container(
        color: const Color(0x33000000),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.only(top: 60, left: 12),
            width: 290,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      fontFamily: 'Open Sans',
                    ),
                  ),
                ),
                _menuItem(Icons.dashboard, 'Painel de indicadores', () {
                  setState(() => _showMenu = false);
                  Navigator.of(context).pushNamed('Dashboard');
                }),
                _menuItem(Icons.today, 'Rotina do dia', () => setState(() => _showMenu = false)),
                _menuItem(Icons.menu_book, 'Books', _openBooks),
                _menuItem(Icons.remove_shopping_cart, 'Itens sem venda', () {
                  setState(() => _showMenu = false);
                  Navigator.of(context).pushNamed('SpecialItems',
                      arguments: {'itemType': 'unsold'});
                }),
                _menuItem(Icons.history, 'Itens sem histórico de venda', () {
                  setState(() => _showMenu = false);
                  Navigator.of(context).pushNamed('SpecialItems',
                      arguments: {'itemType': 'no_sales_history'});
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Open Sans')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exitDialog() {
    return _centerDialog(
      icon: Icons.exit_to_app,
      title: 'Sair do app',
      message: 'Deseja realmente sair do aplicativo?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Sair',
      onCancel: () => setState(() => _showExit = false),
      onConfirm: () {
        setState(() => _showExit = false);
        SystemNavigator.pop();
      },
    );
  }

  Widget _logoutDialog(BuildContext context) {
    return _centerDialog(
      icon: Icons.logout,
      title: 'Sair da conta',
      message: 'Deseja realmente sair da sua conta?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Sair',
      onCancel: () => setState(() => _showLogout = false),
      onConfirm: () async {
        setState(() => _showLogout = false);
        showToast('Deslogado com sucesso!');
        await context.read<AuthProvider>().logout();
      },
    );
  }

  Widget _centerDialog({
    required IconData icon,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    return Container(
      color: const Color(0x66000000),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Open Sans')),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Open Sans')),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(cancelLabel,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFamily: 'Open Sans')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x47000000),
                            blurRadius: 3.6,
                            offset: Offset(0, 1.6),
                          ),
                        ],
                      ),
                      child: Text(confirmLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Open Sans')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerSheet(BuildContext context, DepartmentsController controller) {
    const weekShort = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cells = <DateTime?>[];
    for (var i = 0; i < leading; i++) cells.add(null);
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_calendarMonth.year, _calendarMonth.month, d));
    }
    while (cells.length % 7 != 0) cells.add(null);

    // Current week range: Monday to Friday of the week containing today
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1=Mon, 7=Sun
    final weekStart = now.subtract(Duration(days: currentWeekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 4)); // Friday
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEndDay = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);

    return Container(
      color: const Color(0x66000000),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 28),
                    onPressed: () => setState(() {
                      _calendarMonth = DateTime(
                          _calendarMonth.year, _calendarMonth.month - 1, 1);
                    }),
                  ),
                  Text('${months[_calendarMonth.month - 1]} ${_calendarMonth.year}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Open Sans')),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.primary, size: 28),
                    onPressed: () => setState(() {
                      _calendarMonth = DateTime(
                          _calendarMonth.year, _calendarMonth.month + 1, 1);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: weekShort
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(w,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                    fontFamily: 'Open Sans')),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1,
                children: cells.map((day) {
                  if (day == null) return const SizedBox.shrink();
                  final dayOnly = DateTime(day.year, day.month, day.day);
                  final isWeekday = day.weekday >= 1 && day.weekday <= 5;
                  final inCurrentWeek = !dayOnly.isBefore(weekStartDay) && !dayOnly.isAfter(weekEndDay);
                  final isEnabled = isWeekday && inCurrentWeek;
                  final selected = sameDay(day, controller.selectedDate);
                  final isToday = sameDay(day, DateTime.now());
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: !isEnabled
                        ? null
                        : () {
                            controller.selectedDate = day;
                            setState(() => _showDatePicker = false);
                            controller.loadDataForDate(day);
                          },
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: selected
                            ? const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle)
                            : (isToday && isEnabled
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary),
                                  )
                                : null),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 17,
                              color: selected
                                  ? Colors.white
                                  : (isEnabled
                                      ? (isToday
                                          ? AppColors.primary
                                          : AppColors.textPrimary)
                                      : AppColors.textHint),
                              fontWeight: selected || (isToday && isEnabled)
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontFamily: 'Open Sans',
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final today = clampToWeekday(DateTime.now());
                        controller.selectedDate = today;
                        setState(() => _showDatePicker = false);
                        controller.loadDataForDate(today);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text('Ir para hoje',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  fontFamily: 'Open Sans')),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showDatePicker = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text('Fechar',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: 'Open Sans')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
