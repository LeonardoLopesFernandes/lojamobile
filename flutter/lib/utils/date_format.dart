const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

DateTime? _parseData(String valor) {
  final texto = valor.trim();
  if (texto.isEmpty) return null;
  final iso = DateTime.tryParse(texto);
  if (iso != null) return iso.toLocal();
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(texto);
  if (m == null) return null;
  var ano = int.parse(m.group(3)!);
  if (ano < 100) ano += 2000;
  final mes = int.parse(m.group(2)!);
  final dia = int.parse(m.group(1)!);
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  return DateTime(ano, mes, dia);
}

String _dataBr(DateTime d) {
  final dia = d.day.toString().padLeft(2, '0');
  final mes = _meses[d.month - 1];
  final ano = (d.year % 100).toString().padLeft(2, '0');
  return '$dia/$mes/$ano';
}

/// Formata para dd/Mês/aa (ex.: 01/Novembro/26).
String formatDataBr(String valor) {
  final d = _parseData(valor);
  return d == null ? valor : _dataBr(d);
}

/// Data por extenso + hora (ex.: 01/Novembro/26 • 20h:30m).
String formatDataHoraBr(String valor) {
  if (valor.isEmpty) return valor;
  final temHora = valor.contains('T') || valor.contains(':');
  final d = _parseData(valor);
  if (d == null) return valor;
  final data = _dataBr(d);
  if (!temHora) return data;
  final hora = '${d.hour.toString().padLeft(2, '0')}h:'
      '${d.minute.toString().padLeft(2, '0')}m';
  return '$data • $hora';
}
