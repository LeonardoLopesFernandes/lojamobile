import 'package:flutter_test/flutter_test.dart';
import 'package:inventario/recebimento/models/brasil_risk.dart';

void main() {
  test('autorizacao com mensagem de sucesso', () {
    final r = BrasilRiskBauResponse.fromJson(
      {'Mensagem': 'Abertura de baú autorizada com sucesso'},
      httpStatus: 200,
    );
    expect(r.autorizado, isTrue);
  });

  test('autorizacao com campo em minusculo/booleano', () {
    final r = BrasilRiskBauResponse.fromJson(
      {'aberturaBauAutorizada': true},
      httpStatus: 200,
    );
    expect(r.autorizado, isTrue);
  });

  test('erro nao vira sucesso', () {
    final r = BrasilRiskBauResponse.fromJson(
      {'Mensagem': 'Não autorizado', 'Status': 'Erro'},
      httpStatus: 200,
    );
    expect(r.autorizado, isFalse);
    expect(r.erroDescricao, contains('Não autorizado'));
  });

  test('detalhe aceita autorizacao como texto/numero', () {
    final texto = BrasilRiskNotaDetalhe.fromJson(
        {'AberturaBauAutorizada': 'true', 'Hibrido': '1'});
    final numero = BrasilRiskNotaDetalhe.fromJson(
        {'AberturaBauAutorizada': 1, 'Hibrido': 0});
    expect(texto.aberturaBauAutorizada, isTrue);
    expect(texto.hibrido, isTrue);
    expect(numero.aberturaBauAutorizada, isTrue);
    expect(numero.hibrido, isFalse);
  });

  test('pedido destino vai como inteiro', () {
    final req = AutorizarAberturaBauRequest(
      codPedido: 1,
      codEmpresaUsuario: 2,
      dataCadastro: '2026-11-01T20:30:00.000',
      codPedidoDestino: 3,
      codPedidoOcorrenciaTipo: 4,
    );
    expect(req.toJson()['CodPedidoDestino'], 3);
  });
}
