import 'package:flutter/material.dart';

/// Confirmação usada nas telas iniciais dos hubs (Rotina/Recebimento) para
/// voltar à home do LojaMobile.
Future<bool> confirmarVoltarHubs(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.home_outlined, color: Color(0xFFD32F2F)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Voltar ao menu inicial',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: const Text('Deseja voltar para a tela inicial do LojaMobile?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Voltar'),
        ),
      ],
    ),
  );
  return ok == true;
}
