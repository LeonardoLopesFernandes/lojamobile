import 'package:inventario/rotina/theme.dart';

bool isBlocked() {
  return DateTime.now().hour < 8;
}

String getBlockedMessage() => blockedMessage;

const List<String> _weekdaysPt = [
  'domingo',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
];

String capitalize(String str) {
  if (str.isEmpty) return str;
  return str[0].toUpperCase() + str.substring(1);
}

String getDayOfWeekPt(DateTime date) {
  return capitalize(_weekdaysPt[date.weekday % 7]);
}

String _pad(int n) => n < 10 ? '0$n' : '$n';

String formatApiDate(DateTime date) {
  // dd/MM/yyyy — usado no GET rotina/items
  return '${_pad(date.day)}/${_pad(date.month)}/${date.year}';
}

String formatStorageDate(DateTime date) {
  // yyyy-MM-dd — usado no POST de tratados e chave do cache local
  return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
}

String formatIso(DateTime date) {
  // yyyy-MM-dd'T'HH:mm:ss
  return '${formatStorageDate(date)}T${_pad(date.hour)}:${_pad(date.minute)}:${_pad(date.second)}';
}

String formatDisplayDate(DateTime date) {
  return '${_pad(date.day)}/${_pad(date.month)}/${date.year}';
}

DateTime clampToWeekday(DateTime date) {
  var d = DateTime(date.year, date.month, date.day);
  final dow = d.weekday;
  if (dow == DateTime.sunday) {
    d = d.subtract(const Duration(days: 2));
  } else if (dow == DateTime.saturday) {
    d = d.subtract(const Duration(days: 1));
  }
  return d;
}

({DateTime monday, DateTime friday}) getWeekRange(DateTime date) {
  final dow = date.weekday;
  var monday = DateTime(date.year, date.month, date.day);
  monday = monday.subtract(Duration(days: dow == DateTime.sunday ? 6 : dow - 1));
  final friday = monday.add(const Duration(days: 4));
  return (monday: monday, friday: friday);
}

/// Retorna todas as datas habilitadas (segunda a sexta) da semana da data fornecida
List<DateTime> getEnabledDaysInWeek(DateTime date) {
  final range = getWeekRange(date);
  final days = <DateTime>[];
  var current = range.monday;
  while (!current.isAfter(range.friday)) {
    days.add(DateTime(current.year, current.month, current.day));
    current = current.add(const Duration(days: 1));
  }
  return days;
}

final List<RegExp> _dateFormatsIn = [
  RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.(\d+)$'),
  RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$'),
  RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$'),
  RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$'),
  RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$'),
];

DateTime? parseTreatedDate(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final re in _dateFormatsIn) {
    final m = re.firstMatch(value);
    if (m != null) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final h = int.tryParse(m.group(4) ?? '0') ?? 0;
      final mi = int.tryParse(m.group(5) ?? '0') ?? 0;
      final s = int.tryParse(m.group(6) ?? '0') ?? 0;
      return DateTime(y, mo, d, h, mi, s);
    }
  }
  return null;
}

String formatBadgeDate(String? value) {
  final d = parseTreatedDate(value);
  if (d == null) return '—';
  return '${formatDisplayDate(d)} - ${_pad(d.hour)}:${_pad(d.minute)}';
}

bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool isTreatedAnswerActive(dynamic a) {
  final active = a.active;
  final answer = a.answer;
  final percentage = a.percentage;
  final items = a.items;
  return active == true ||
      answer == true ||
      (percentage != null && percentage > 0) ||
      (items != null && items > 0);
}
