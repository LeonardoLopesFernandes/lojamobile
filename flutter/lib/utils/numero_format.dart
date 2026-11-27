String _milhar(String inteiro) {
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
  return buf.toString();
}

/// Moeda no padrão pt-BR: R$ 1.234,56.
String formatBrl(double valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final inteiro = _milhar(partes[0]);
  return '${negativo ? '-' : ''}R\$ $inteiro,${partes[1]}';
}

/// Inteiro com separador de milhar: 1.234.
String formatIntBr(int valor) {
  final negativo = valor < 0;
  return '${negativo ? '-' : ''}${_milhar(valor.abs().toString())}';
}
