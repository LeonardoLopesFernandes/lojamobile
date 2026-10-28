import 'package:flutter/material.dart';
import '../models/recebimento.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';

class TripCard extends StatelessWidget {
  final Recebimento recebimento;
  final double? progresso;
  final bool compact;
  final bool processando;
  final VoidCallback? onVisualizar;
  final VoidCallback? onImprimir;
  final VoidCallback? onReceber;

  const TripCard({
    super.key,
    required this.recebimento,
    this.progresso,
    this.compact = false,
    this.processando = false,
    this.onVisualizar,
    this.onImprimir,
    this.onReceber,
  });

  bool get _isPendente =>
      recebimento.status.toLowerCase() == Constants.statusPendente;

  int get _ano {
    try {
      final s = recebimento.viagemData;
      if (s.length >= 4) return int.parse(s.substring(0, 4));
    } catch (_) {}
    return 2025;
  }

  String get _numero => recebimento.id.length > 7
      ? recebimento.id.substring(recebimento.id.length - 7)
      : recebimento.id;

  @override
  Widget build(BuildContext context) {
    final is2026 = _ano >= 2026;
    final temProtocolo = recebimento.protocolo != null &&
        recebimento.protocolo!.isNotEmpty;
    return Container(
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          compact
              ? _buildGridTop(temProtocolo)
              : _buildListTop(temProtocolo),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
          compact ? _buildGridInfo(is2026) : _buildListInfo(is2026),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Color(Constants.primaryRed), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
              ),
              onPressed: onVisualizar,
              child: Text(
                'VISUALIZAR',
                style: TextStyle(
                  color: const Color(Constants.primaryRed),
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ),
          ),
          if (_isPendente) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(Constants.primaryRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
                ),
                onPressed: processando ? null : onReceber,
                child: Text(
                  processando ? 'PROCESSANDO...' : 'RECEBER',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListTop(bool temProtocolo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VIAGEM',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                Text(_numero,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50))),
              ],
            ),
            TextButton.icon(
              onPressed: onImprimir,
              icon: const Icon(Icons.print,
                  color: Color(Constants.primaryRed), size: 18),
              label: const Text('IMPRIMIR',
                  style: TextStyle(
                      color: Color(Constants.primaryRed),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (temProtocolo)
          Text('Protocolo: ${recebimento.protocolo}',
              style: const TextStyle(
                  color: Color(Constants.primaryRed),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGridTop(bool temProtocolo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('VIAGEM',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
            InkWell(
              onTap: onImprimir,
              child: const Row(
                children: [
                  Icon(Icons.print,
                      color: Color(Constants.primaryRed), size: 14),
                  SizedBox(width: 2),
                  Text('IMPRIMIR',
                      style: TextStyle(
                          color: Color(Constants.primaryRed),
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        Text(_numero,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50))),
        const SizedBox(height: 2),
        if (temProtocolo)
          Text('Protocolo: ${recebimento.protocolo}',
              style: const TextStyle(
                  color: Color(Constants.primaryRed),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListInfo(bool is2026) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoColumn('Data', _formatarData(), 10, 12),
        _buildInfoColumn('Origem', recebimento.codigoOrigem, 10, 12),
        _buildInfoColumn('Placa', recebimento.placaVeiculo ?? '-', 10, 12),
        _buildInfoColumn(
            'GUIA',
            is2026
                ? "${CurrencyFormatter.formatarInteiro(recebimento.qtdRolls)} Rolls"
                : "${CurrencyFormatter.formatarInteiro(recebimento.qtdGuias)} Guias",
            10,
            12,
            isHighlight: true),
      ],
    );
  }

  Widget _buildGridInfo(bool is2026) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildInfoColumn('Data', _formatarData(), 9, 11)),
            Expanded(
                child: _buildInfoColumn('Origem', recebimento.codigoOrigem, 9, 11)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: _buildInfoColumn(
                    'Placa', recebimento.placaVeiculo ?? '-', 9, 11)),
            Expanded(
                child: _buildInfoColumn(
                    'GUIA',
                    is2026
                        ? "${CurrencyFormatter.formatarInteiro(recebimento.qtdRolls)} Rolls"
                        : "${CurrencyFormatter.formatarInteiro(recebimento.qtdGuias)} Guias",
                    9,
                    11,
                    isHighlight: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value, double labelSize,
      double valueSize,
      {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: labelSize, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? const Color(Constants.primaryRed)
                  : Colors.black87,
            )),
      ],
    );
  }

  String _formatarData() {
    try {
      final data = DateTime.parse(
          recebimento.viagemData.replaceAll('Z', '').replaceAll('T', ' '));
      return "${data.day.toString().padLeft(2, '0')}/"
          "${data.month.toString().padLeft(2, '0')}/"
          "${data.year}";
    } catch (_) {
      return recebimento.viagemData.length >= 10
          ? recebimento.viagemData.substring(0, 10)
          : recebimento.viagemData;
    }
  }
}
