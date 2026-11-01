import 'package:flutter/material.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/utils/time.dart';
import 'package:inventario/rotina/utils/toast.dart';

class ChecklistModal extends StatefulWidget {
  final bool visible;
  final Item? item;
  final VoidCallback onClose;
  final void Function(Item, List<int>) onSave;

  const ChecklistModal({
    super.key,
    required this.visible,
    required this.item,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<ChecklistModal> createState() => _ChecklistModalState();
}

class _ChecklistModalState extends State<ChecklistModal> {
  List<int> _selected = [];
  bool _showConfirmation = false;

  @override
  void didUpdateWidget(covariant ChecklistModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _selected = [];
      _showConfirmation = false;
    }
  }

  void _toggleOption(int index) {
    if (widget.item == null) return;
    if (_blocked || _alreadyTreated || index == _disableIndex) return;
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  bool get _blocked => isBlocked();
  bool get _alreadyTreated => widget.item?.treated ?? false;
  int get _disableIndex => deptsDisableExpiry
          .contains(widget.item?.departmentCode ?? '')
      ? 0
      : 5;

  void _handleFinalize() {
    if (_alreadyTreated) {
      showToast('Este item já foi respondido!');
      widget.onClose();
      return;
    }
    setState(() => _showConfirmation = true);
  }

  void _handleConfirm() {
    if (widget.item == null) return;
    widget.onSave(widget.item!, _selected);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || widget.item == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: SingleChildScrollView(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.item?.description ?? 'Checklist do item',
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
                    else if (_alreadyTreated)
                      _stateBox('Item já respondido!', AppColors.success,
                          const Color(0xFFE8F5E9))
                    else
                      const Text(
                        'Selecione os problemas:',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
                      ),
                    if (!_blocked && !_showConfirmation)
                      ...shortQuestions.asMap().entries.map((e) {
                        final index = e.key;
                        final q = e.value;
                        final disabled = index == _disableIndex;
                        final isSelected = _selected.contains(index);
                        return _optionCard(
                          isSelected,
                          disabled,
                          '${index + 1} - $q',
                          () => _toggleOption(index),
                        );
                      }),
                    if (!_blocked && _showConfirmation) _confirmation(),
                    if (!_blocked) _actions(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateBox(String text, Color textColor, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Widget _optionCard(bool isSelected, bool disabled, String label,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0037).withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFC8C6C4),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3D3D3D)
                      .withOpacity(disabled ? 0.5 : 1),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : null,
                border: Border.all(
                  color: isSelected
                      ? AppColors.success
                      : const Color(0xFFC0C0C0),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? const Text('✓',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmation() {
    if (_selected.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Deseja confirmar que este item está OK?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Nenhum problema selecionado',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deseja registrar ${_selected.length} problema${_selected.length > 1 ? 's' : ''}?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ..._selected.map((i) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${i + 1} - ${shortQuestions[i]}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            )),
      ],
    );
  }

  Widget _actions() {
    if (_showConfirmation) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _button('Voltar', const Color(0xFFF1F3F4), AppColors.textPrimary,
              false, () => setState(() => _showConfirmation = false)),
          _button('Sim, confirmar', const Color(0xFFF3010B), Colors.white, false,
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
          _alreadyTreated ? 'Item já respondido' : 'Finalizar',
          _alreadyTreated ? const Color(0xFF9E9E9E) : const Color(0xFFF3010B),
          Colors.white,
          _alreadyTreated,
          _alreadyTreated ? null : _handleFinalize,
          withCheck: true,
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF9E9E9E) : bg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: disabled ? null : [
            BoxShadow(
              color: const Color(0x47000000),
              blurRadius: 3.6,
              offset: const Offset(0, 1.6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: disabled ? Colors.white : fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'Open Sans')),
            if (withCheck && !disabled) ...[
              const SizedBox(width: 6),
              Text('✓',
                  style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'Open Sans')),
            ],
          ],
        ),
      ),
    );
  }
}
