import 'package:flutter/material.dart';

import 'dialog_voltar_hubs.dart';

/// Coloca o diálogo "voltar ao menu inicial" apenas na tela inicial do hub.
/// As subtelas empilhadas não usam este guard, então o voltar delas é normal.
class VoltarHubsGuard extends StatefulWidget {
  final Widget child;

  const VoltarHubsGuard({super.key, required this.child});

  @override
  State<VoltarHubsGuard> createState() => _VoltarHubsGuardState();
}

class _VoltarHubsGuardState extends State<VoltarHubsGuard> {
  bool _aberto = false;

  Future<void> _confirmar() async {
    if (_aberto) return;
    _aberto = true;
    final ok = await confirmarVoltarHubs(context);
    _aberto = false;
    if (ok && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmar();
      },
      child: widget.child,
    );
  }
}
