import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Submenu da Precificação: Etiquetas e Papeletas Avulsas.
class PrecificacaoMenuScreen extends StatelessWidget {
  const PrecificacaoMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(Constants.invTextDark)),
        title: const Text('Precificação',
            style: TextStyle(
                color: Color(Constants.invTextDark),
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _item(
            context,
            'Etiquetas Avulsas',
            Icons.sell_outlined,
            () => Navigator.of(context).pushNamed('/precificacao_etiquetas'),
          ),
          const SizedBox(height: 16),
          _item(
            context,
            'Papeletas Avulsas',
            Icons.receipt_long_outlined,
            () => Navigator.of(context).pushNamed('/precificacao_papeletas'),
          ),
          const SizedBox(height: 16),
          _item(
            context,
            'Etiquetas Diárias',
            Icons.sell,
            () => Navigator.of(context).pushNamed('/etiquetas'),
          ),
          const SizedBox(height: 16),
          _item(
            context,
            'Papeletas Diárias',
            Icons.receipt,
            () => Navigator.of(context).pushNamed('/papeletas_diarias'),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, String titulo, IconData icon,
      VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(Constants.primaryRed)),
                const SizedBox(width: 12),
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(Constants.invTextDark))),
              ],
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
