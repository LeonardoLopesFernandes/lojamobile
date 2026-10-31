/// Formata uma data para dd/MM/yyyy, convertendo de UTC para o horário local
/// quando a string vier no formato ISO (ex.: `2026-10-13T00:33:56Z`).
/// Se não for ISO (ex.: `09/10/2026`), devolve como veio.
String formatDataBr(String valor) {
  if (valor.isEmpty) return valor;
  final d = DateTime.tryParse(valor);
  if (d == null) return valor;
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/${l.year}';
}

/// Formata dd/MM/yyyy • HH:MM quando a string trouxer horário (ISO com "T"
/// ou contendo ":"). Se for só data, devolve no formato dd/MM/yyyy.
String formatDataHoraBr(String valor) {
  if (valor.isEmpty) return valor;
  final temHora = valor.contains('T') || valor.contains(':');
  final d = DateTime.tryParse(valor);
  if (d == null) return valor;
  final l = d.toLocal();
  final data = '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/${l.year}';
  if (!temHora) return data;
  final hora = '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
  return '$data • $hora';
}
