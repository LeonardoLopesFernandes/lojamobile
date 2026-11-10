class TokenBody {
  final String token;

  TokenBody({required this.token});

  Map<String, dynamic> toJson() => {'token': token};
}

class BrasilRiskLoginResponse {
  final int? codEmpresa;
  final int? codEmpresaUsuario;
  final String? nomeUsuario;
  final String? mensagem;
  final String? status;
  final int? statusCode;
  final List<BrasilRiskNota>? notaFiscal;

  BrasilRiskLoginResponse({
    this.codEmpresa,
    this.codEmpresaUsuario,
    this.nomeUsuario,
    this.mensagem,
    this.status,
    this.statusCode,
    this.notaFiscal,
  });

  factory BrasilRiskLoginResponse.fromJson(Map<String, dynamic> json) {
    return BrasilRiskLoginResponse(
      codEmpresa: json['CodEmpresa'],
      codEmpresaUsuario: json['CodEmpresaUsuario'],
      nomeUsuario: json['NomeUsuario'],
      mensagem: json['Mensagem'],
      status: json['Status'],
      statusCode: json['StatusCode'],
      notaFiscal: (json['NotaFiscal'] as List? ?? [])
          .map((e) => BrasilRiskNota.fromJson(e))
          .toList(),
    );
  }
}

class BrasilRiskNota {
  final int? codPedido;
  final int? codPedidoDestino;
  final int? codPedidoOcorrenciaTipo;
  final int? codPedidoStatus;
  final int? codEmpresaUsuario;
  final String? numeroViagem;
  final double? progressoViagem;
  final int? codStatusDaEntrega;
  final String? statusDaViagem;
  final String? dataDeSaida;
  final String? dataIniciado;
  final double? distanciaRestante;
  final double? distanciaTotalPrevista;
  final double? distanciaPercorrida;
  final String? nomeMotorista;
  final String? placa;
  final String? carreta;
  final String? previsaoChegada;
  final String? previsaoChegadaRecalculada;
  final String? dtPrevisaoEntrega;
  final String? dataChegadaOrigemRecalculada;
  final String? dataConclusao;
  final String? dataEntrega;
  final String? dataDeEntregaNF;
  final String? status;

  BrasilRiskNota({
    this.codPedido,
    this.codPedidoDestino,
    this.codPedidoOcorrenciaTipo,
    this.codPedidoStatus,
    this.codEmpresaUsuario,
    this.numeroViagem,
    this.progressoViagem,
    this.codStatusDaEntrega,
    this.statusDaViagem,
    this.dataDeSaida,
    this.dataIniciado,
    this.distanciaRestante,
    this.distanciaTotalPrevista,
    this.distanciaPercorrida,
    this.nomeMotorista,
    this.placa,
    this.carreta,
    this.previsaoChegada,
    this.previsaoChegadaRecalculada,
    this.dtPrevisaoEntrega,
    this.dataChegadaOrigemRecalculada,
    this.dataConclusao,
    this.dataEntrega,
    this.dataDeEntregaNF,
    this.status,
  });

  factory BrasilRiskNota.fromJson(Map<String, dynamic> json) {
    return BrasilRiskNota(
      codPedido: json['CodPedido'],
      codPedidoDestino: json['CodPedidoDestino'],
      codPedidoOcorrenciaTipo: json['CodPedidoOcorrenciaTipo'],
      codPedidoStatus: json['CodPedidoStatus'],
      codEmpresaUsuario: json['CodEmpresaUsuario'],
      numeroViagem: json['NumeroViagem']?.toString(),
      progressoViagem: (json['ProgressoViagem'] as num?)?.toDouble(),
      codStatusDaEntrega: json['CodStatusDaEntrega'],
      statusDaViagem: json['StatusDaViagem'],
      dataDeSaida: json['DataDeSaida'],
      dataIniciado: json['DataIniciado'],
      distanciaRestante: (json['DistanciaRestante'] as num?)?.toDouble(),
      distanciaTotalPrevista: (json['DistanciaTotalPrevista'] as num?)?.toDouble(),
      distanciaPercorrida: (json['DistanciaPercorrida'] as num?)?.toDouble(),
      nomeMotorista: json['NomeMotorista'],
      placa: json['Placa'],
      carreta: json['Carreta'],
      previsaoChegada: json['PrevisaoChegada'],
      previsaoChegadaRecalculada: json['PrevisaoChegadaRecalculada'],
      dtPrevisaoEntrega: json['DtPrevisaoEntrega'],
      dataChegadaOrigemRecalculada: json['DataChegadaOrigemRecalculada'],
      dataConclusao: json['DataConclusao'],
      dataEntrega: json['DataEntrega'],
      dataDeEntregaNF: json['DataDeEntregaNF'],
      status: json['Status'],
    );
  }
}

class BrasilRiskNotaDetalhe {
  final bool? aberturaBauAutorizada;
  final String? cidadeCliente;
  final int? codDestino;
  final int? codEmpresaNF;
  final int? codEmpresaTransacaoNF;
  final int? codEmpresaUsuario;
  final int? codPedido;
  final int? codPedidoDestino;
  final int? codPedidoStatus;
  final String? nomeStatus;
  final int? codStatusDaEntrega;
  final int? codStatusNF;
  final String? dataDeChegada;
  final String? dataDeEntregaNF;
  final String? dataDeSaida;
  final String? dataEmissaoNF;
  final String? dataEntrega;
  final String? dataIniciado;
  final String? dataConclusao;
  final double? distanciaPercorrida;
  final double? distanciaRestante;
  final double? distanciaTotalPrevista;
  final String? dtPrevisaoEntrega;
  final String? mensagem;
  final String? nf;
  final String? nomeCliente;
  final String? nomeMotorista;
  final String? nomeTransportadora;
  final String? nrSerieNF;
  final String? numeroViagem;
  final String? origem;
  final String? placa;
  final String? carreta;
  final String? dataColheita;
  final String? previsaoChegada;
  final String? previsaoChegadaRecalculada;
  final String? produto;
  final double? progressoViagem;
  final String? status;
  final int? statusCode;
  final String? statusNF;
  final double? temperaturaAtual;
  final double? temperaturaSaida;
  final double? temperaturaMaxima;
  final double? temperaturaEntrega;
  final String? localizacao;
  final double? latitudeVeiculo;
  final double? longitudeVeiculo;
  final String? contrato;
  final bool? hibrido;
  final double? latitudeDestino;
  final double? longitudeDestino;
  final double? latitudeOrigem;
  final double? longitudeOrigem;
  final String? dataChegadaOrigemRecalculada;
  final String? regional;
  final String? statusDaViagem;
  final String? dataChegadaCampo;
  final String? dataSaidaCampo;

  BrasilRiskNotaDetalhe({
    this.aberturaBauAutorizada,
    this.cidadeCliente,
    this.codDestino,
    this.codEmpresaNF,
    this.codEmpresaTransacaoNF,
    this.codEmpresaUsuario,
    this.codPedido,
    this.codPedidoDestino,
    this.codPedidoStatus,
    this.nomeStatus,
    this.codStatusDaEntrega,
    this.codStatusNF,
    this.dataDeChegada,
    this.dataDeEntregaNF,
    this.dataDeSaida,
    this.dataEmissaoNF,
    this.dataEntrega,
    this.dataIniciado,
    this.dataConclusao,
    this.distanciaPercorrida,
    this.distanciaRestante,
    this.distanciaTotalPrevista,
    this.dtPrevisaoEntrega,
    this.mensagem,
    this.nf,
    this.nomeCliente,
    this.nomeMotorista,
    this.nomeTransportadora,
    this.nrSerieNF,
    this.numeroViagem,
    this.origem,
    this.placa,
    this.carreta,
    this.dataColheita,
    this.previsaoChegada,
    this.previsaoChegadaRecalculada,
    this.produto,
    this.progressoViagem,
    this.status,
    this.statusCode,
    this.statusNF,
    this.temperaturaAtual,
    this.temperaturaSaida,
    this.temperaturaMaxima,
    this.temperaturaEntrega,
    this.localizacao,
    this.latitudeVeiculo,
    this.longitudeVeiculo,
    this.contrato,
    this.hibrido,
    this.latitudeDestino,
    this.longitudeDestino,
    this.latitudeOrigem,
    this.longitudeOrigem,
    this.dataChegadaOrigemRecalculada,
    this.regional,
    this.statusDaViagem,
    this.dataChegadaCampo,
    this.dataSaidaCampo,
  });

  factory BrasilRiskNotaDetalhe.fromJson(Map<String, dynamic> json) {
    return BrasilRiskNotaDetalhe(
      aberturaBauAutorizada: json['AberturaBauAutorizada'],
      cidadeCliente: json['CidadeCliente'],
      codDestino: json['CodDestino'],
      codEmpresaNF: json['CodEmpresaNF'],
      codEmpresaTransacaoNF: json['CodEmpresaTransacaoNF'],
      codEmpresaUsuario: json['CodEmpresaUsuario'],
      codPedido: json['CodPedido'],
      codPedidoDestino: json['CodPedidoDestino'],
      codPedidoStatus: json['CodPedidoStatus'],
      nomeStatus: json['NomeStatus'],
      codStatusDaEntrega: json['CodStatusDaEntrega'],
      codStatusNF: json['CodStatusNF'],
      dataDeChegada: json['DataDeChegada'],
      dataDeEntregaNF: json['DataDeEntregaNF'],
      dataDeSaida: json['DataDeSaida'],
      dataEmissaoNF: json['DataEmissaoNF'],
      dataEntrega: json['DataEntrega'],
      dataIniciado: json['DataIniciado'],
      dataConclusao: json['DataConclusao'],
      distanciaPercorrida: (json['DistanciaPercorrida'] as num?)?.toDouble(),
      distanciaRestante: (json['DistanciaRestante'] as num?)?.toDouble(),
      distanciaTotalPrevista: (json['DistanciaTotalPrevista'] as num?)?.toDouble(),
      dtPrevisaoEntrega: json['DtPrevisaoEntrega'],
      mensagem: json['Mensagem'],
      nf: json['NF'],
      nomeCliente: json['NomeCliente'],
      nomeMotorista: json['NomeMotorista'],
      nomeTransportadora: json['NomeTransportadora'],
      nrSerieNF: json['NrSerieNF'],
      numeroViagem: json['NumeroViagem']?.toString(),
      origem: json['Origem'],
      placa: json['Placa'],
      carreta: json['Carreta'],
      dataColheita: json['DataColheita'],
      previsaoChegada: json['PrevisaoChegada'],
      previsaoChegadaRecalculada: json['PrevisaoChegadaRecalculada'],
      produto: json['Produto'],
      progressoViagem: (json['ProgressoViagem'] as num?)?.toDouble(),
      status: json['Status'],
      statusCode: json['StatusCode'],
      statusNF: json['StatusNF'],
      temperaturaAtual: (json['TemperaturaAtual'] as num?)?.toDouble(),
      temperaturaSaida: (json['TemperaturaSaida'] as num?)?.toDouble(),
      temperaturaMaxima: (json['TemperaturaMaxima'] as num?)?.toDouble(),
      temperaturaEntrega: (json['TemperaturaEntrega'] as num?)?.toDouble(),
      localizacao: json['Localizacao'],
      latitudeVeiculo: (json['LatitudeVeiculo'] as num?)?.toDouble(),
      longitudeVeiculo: (json['LongitudeVeiculo'] as num?)?.toDouble(),
      contrato: json['Contrato'],
      hibrido: json['Hibrido'],
      latitudeDestino: (json['LatitudeDestino'] as num?)?.toDouble(),
      longitudeDestino: (json['LongitudeDestino'] as num?)?.toDouble(),
      latitudeOrigem: (json['LatitudeOrigem'] as num?)?.toDouble(),
      longitudeOrigem: (json['LongitudeOrigem'] as num?)?.toDouble(),
      dataChegadaOrigemRecalculada: json['DataChegadaOrigemRecalculada'],
      regional: json['Regional'],
      statusDaViagem: json['StatusDaViagem'],
      dataChegadaCampo: json['DataChegadaCampo'],
      dataSaidaCampo: json['DataSaidaCampo'],
    );
  }
}

class AutorizarAberturaBauRequest {
  final int codPedido;
  final int codEmpresaUsuario;
  final String dataCadastro;
  final int codPedidoDestino;
  final int codPedidoOcorrenciaTipo;

  AutorizarAberturaBauRequest({
    required this.codPedido,
    required this.codEmpresaUsuario,
    required this.dataCadastro,
    required this.codPedidoDestino,
    required this.codPedidoOcorrenciaTipo,
  });

  Map<String, dynamic> toJson() => {
        'CodPedido': codPedido,
        'CodEmpresaUsuario': codEmpresaUsuario,
        'DataCadastro': dataCadastro,
        'CodPedidoDestino': codPedidoDestino.toString(),
        'CodPedidoOcorrenciaTipo': codPedidoOcorrenciaTipo,
      };
}

class BrasilRiskBauResponse {
  final String? mensagem;
  final String? status;
  final int? statusCode;
  final bool? aberturaBauAutorizada;

  BrasilRiskBauResponse({
    this.mensagem,
    this.status,
    this.statusCode,
    this.aberturaBauAutorizada,
  });

  factory BrasilRiskBauResponse.fromJson(Map<String, dynamic> json) {
    return BrasilRiskBauResponse(
      mensagem: json['Mensagem'],
      status: json['Status'],
      statusCode: json['StatusCode'],
      aberturaBauAutorizada: json['AberturaBauAutorizada'],
    );
  }
}
