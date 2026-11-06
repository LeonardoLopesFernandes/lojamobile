import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableText extends StatelessWidget {
  final String texto;
  final String valorCopia;
  final String rotulo;
  final TextStyle? style;

  const CopyableText({
    super.key,
    required this.texto,
    required this.valorCopia,
    required this.rotulo,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: valorCopia.trim().isEmpty
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: valorCopia));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$rotulo copiado: $valorCopia')),
              );
            },
      child: Text(texto, style: style),
    );
  }
}
