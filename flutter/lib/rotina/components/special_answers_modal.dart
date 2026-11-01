import 'package:flutter/material.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/utils/time.dart';
import 'package:inventario/rotina/utils/toast.dart';

class SpecialAnswersModal extends StatefulWidget {
  final bool visible;
  final SpecialItem? item;
  final List<SpecialAnswer> answers;
  final VoidCallback onClose;
  final void Function(SpecialItem, String, bool) onSave;

  const SpecialAnswersModal({
    super.key,
    required this.visible,
    required this.item,
    required this.answers,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<SpecialAnswersModal> createState() => _SpecialAnswersModalState();
}

class _SpecialAnswersModalState extends State<SpecialAnswersModal> {
  int? _selectedNumber;
  bool _showConfirmation = false;

  @override
  void didUpdateWidget(covariant SpecialAnswersModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _selectedNumber = null;
      _showConfirmation = false;
    }
  }

  List<SpecialAnswer> get _activeAnswers =>
      widget.answers.where((a) => a.active).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  bool get _blocked => isBlocked();
  bool get _treated =>
      widget.item?.treatedBy?.isNotEmpty ?? false;

  void _toggleOption(int number) {
    if (_blocked || _treated) return;
    setState(() {
      _selectedNumber = _selectedNumber == number ? null : number;
    });
  }

  void _handleFinalize() {
    if (_treated) {
      showToast('Este item já foi respondido!');
      widget.onClose();
      return;
    }
    setState(() => _showConfirmation = true);
  }

  void _handleConfirm() {
    if (_selectedNumber == null) return;
    final active = _activeAnswers.firstWhere((a) => a.number == _selectedNumber);
    widget.onSave(widget.item!, active.question, true);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || widget.item == null) {
      return const SizedBox.shrink();
    }
    final active = _activeAnswers;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: const Color(0x80000000)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item?.description ?? 'Selecionar problema',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'Open Sans',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'EAN: ${widget.item?.ean ?? ''} / SAP: ${widget.item?.sap ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'Open Sans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (_blocked)
                    _stateBox('🔒 ${getBlockedMessage()}', AppColors.danger,
                        const Color(0xFFFEE2E2))
                  else if (_treated)
                    _stateBox('Item já respondido!', AppColors.success,
                        const Color(0xFFE8F5E9))
                  else
                    const Text('Selecione um problema:',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6C757D))),
                  if (!_blocked && !_showConfirmation)
                    ...active.map((a) => _optionCard(
                          _selectedNumber == a.number,
                          '${a.number} - ${a.question}',
                          () => _toggleOption(a.number),
                        )),
                  if (!_blocked && _showConfirmation) _confirmation(),
                  if (!_blocked) _actions(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stateBox(String text, Color textColor, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Open Sans')),
    );
  }

  Widget _optionCard(bool isSelected, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEE2E2) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFC7C7C7),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Open Sans')),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : null,
                border: isSelected
                    ? null
                    : Border.all(color: const Color(0xFFC0C0C0), width: 2),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? const Text('✓',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Open Sans'))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmation() {
    if (_selectedNumber == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Deseja confirmar que este item está OK?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Open Sans')),
          SizedBox(height: 4),
          Text('Nenhum problema selecionado',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontFamily: 'Open Sans')),
        ],
      );
    }
    final q = _activeAnswers
        .firstWhere((a) => a.number == _selectedNumber)
        .question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deseja registrar o problema selecionado?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Open Sans')),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('$_selectedNumber - $q',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Open Sans')),
        ),
      ],
    );
  }

  Widget _actions() {
    if (_showConfirmation) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _button('Voltar', const Color(0xFFF1F3F4), AppColors.textPrimary, false,
              () => setState(() => _showConfirmation = false)),
          _button('Sim, confirmar', AppColors.danger, Colors.white, false,
              _handleConfirm),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _button('Cancelar', const Color(0xFFF1F3F4), AppColors.textPrimary, false,
            widget.onClose),
        _button(
          _treated ? 'Item já respondido' : 'Finalizar',
          _treated ? const Color(0xFF9E9E9E) : AppColors.danger,
          Colors.white,
          _treated,
          _treated ? null : _handleFinalize,
          withCheck: !_treated,
        ),
      ],
    );
  }

  Widget _button(String label, Color bg, Color fg, bool disabled,
      VoidCallback? onPressed,
      {bool withCheck = false}) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: bg == AppColors.danger
              ? const [
                  BoxShadow(
                    color: Color(0x47000000),
                    blurRadius: 3.6,
                    offset: Offset(0, 1.6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontFamily: 'Open Sans')),
            if (withCheck) ...[
              const SizedBox(width: 6),
              Text('✓',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Open Sans')),
            ],
          ],
        ),
      ),
    );
  }
}
