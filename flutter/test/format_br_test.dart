import 'package:flutter_test/flutter_test.dart';
import 'package:inventario/utils/date_format.dart';
import 'package:inventario/utils/numero_format.dart';

void main() {
  test('data e hora no padrao do app', () {
    expect(formatDataBr('2026-11-01T20:30:00'), '01/Novembro/26');
    expect(formatDataHoraBr('2026-11-01T20:30:00'),
        '01/Novembro/26 • 20h:30m');
    expect(formatDataBr('01/11/2026'), '01/Novembro/26');
  });

  test('milhar em moeda e inteiro', () {
    expect(formatBrl(1234.5), 'R\$ 1.234,50');
    expect(formatIntBr(1234), '1.234');
    expect(formatIntBr(0), '0');
  });
}
