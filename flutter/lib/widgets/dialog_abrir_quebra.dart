import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Diálogo de confirmação exibido ao abrir uma quebra (layout igual ao site).
/// Retorna `true` quando o usuário confirma em "ABRIR QUEBRA".
Future<bool?> mostrarDialogoAbrirQuebra(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('FECHAR',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        SizedBox(width: 4),
                        Icon(Icons.close, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Abrir quebra',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 12),
                const Text(
                  'Ao abrir a quebra, o sistema vai consultar o estoque da loja e calcular o valor da perda com base nos itens incluídos.',
                  style: TextStyle(
                      fontSize: 14, color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Importante',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                      SizedBox(height: 8),
                      _Bullet(
                          'Depois de abrir a quebra, não será possível incluir novos itens.',
                          isWhite: true),
                      SizedBox(height: 4),
                      _Bullet('Esta ação não conclui o processo de quebra.',
                          isWhite: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Após a abertura, você ainda deverá:',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),
                const _Bullet('Conferir os valores de estoque e de perda'),
                const SizedBox(height: 6),
                const _Bullet('Ajustar as quantidades, se necessário'),
                const SizedBox(height: 6),
                const _Bullet('Revisar o motivo da quebra de cada item'),
                const SizedBox(height: 6),
                const _Bullet('Clicar em Processar para concluir'),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Color(Constants.primaryRed),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Text('VOLTAR E REVISAR ITENS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(Constants.primaryRed),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: const Text('ABRIR QUEBRA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Bullet extends StatelessWidget {
  final String text;
  final bool isWhite;

  const _Bullet(this.text, {this.isWhite = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : Colors.black54,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isWhite
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black54,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
