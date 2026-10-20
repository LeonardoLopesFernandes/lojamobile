import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const Color avulsaRed = Color(0xFFD32F2F);
const Color avulsaLabelGrey = Color(0xFF8C9BA5);
const Color avulsaTexto = Color(0xFF1E293B);
const Color avulsaGreen = Color(0xFF4CAF50);

/// Spinner com ícone no rótulo (espelha SpinnerDropdown do Compose).
class AvulsaSpinnerDropdown extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const AvulsaSpinnerDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: avulsaRed, size: 14),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: avulsaLabelGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down, color: avulsaRed),
            style: const TextStyle(
              color: avulsaTexto,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            onChanged: onChanged,
            items: options
                .map((o) => DropdownMenuItem<String>(
                      value: o,
                      child: Text(o,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: avulsaTexto, fontSize: 13)),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Campo de busca com o botão BUSCAR dentro (à direita), altura única 52.
class AvulsaSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final bool numerico;
  final bool buscando;
  final VoidCallback onBuscar;

  const AvulsaSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.placeholder,
    required this.numerico,
    required this.buscando,
    required this.onBuscar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9AA5B1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType:
                      numerico ? TextInputType.number : TextInputType.text,
                  style: const TextStyle(color: avulsaTexto, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: placeholder,
                    hintStyle: const TextStyle(
                        color: Color(0xFF8C9BA5), fontSize: 15),
                  ),
                  onSubmitted: (_) => onBuscar(),
                ),
              ),
            ),
            _BotaoBuscarAnimado(
              buscando: buscando,
              onTap: onBuscar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão de busca: ícone de lupa; só anima
/// (spinner) quando está buscando — ou seja, a animação roda apenas ao clicar.
class _BotaoBuscarAnimado extends StatelessWidget {
  final bool buscando;
  final VoidCallback onTap;

  const _BotaoBuscarAnimado({
    required this.buscando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: avulsaRed,
      child: InkWell(
        onTap: buscando ? null : onTap,
        child: SizedBox(
          width: 72,
          height: 52,
          child: Center(
            child: buscando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.search, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// FAB scanner 56dp vermelho com pulsação (espelha FabScanner do Compose).
class AvulsaFabScanner extends StatefulWidget {
  final VoidCallback onAbrir;
  const AvulsaFabScanner({super.key, required this.onAbrir});

  @override
  State<AvulsaFabScanner> createState() => _AvulsaFabScannerState();
}

class _AvulsaFabScannerState extends State<AvulsaFabScanner>
    with SingleTickerProviderStateMixin {
  bool _revelado = false;
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_revelado) {
          setState(() => _revelado = true);
        } else {
          widget.onAbrir();
        }
      },
      child: ScaleTransition(
        scale: _revelado ? _scale : const AlwaysStoppedAnimation(1.0),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: avulsaRed,
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(
            'assets/drawables/ic_barcode_scan.svg',
            width: 12,
            height: 12,
          ),
        ),
      ),
    );
  }
}

/// Container verde do badge (badge_green_container): fundo #4CAF50, raio 12.
class GreenBadgeContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GreenBadgeContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: avulsaGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// Badge branco com borda verde, texto colorido 10sp (WhiteTypeBadge).
class WhiteTypeBadge extends StatelessWidget {
  final String text;
  final Color color;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  const WhiteTypeBadge({
    super.key,
    required this.text,
    required this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(color: avulsaGreen),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
