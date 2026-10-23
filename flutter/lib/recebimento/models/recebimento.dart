class RecebimentoResponse {
  final List<Recebimento> recebimentos;
  final String dateFromGet;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final QtdRecebimentos qtdRecebimentos;

  RecebimentoResponse({
    required this.recebimentos,
    required this.dateFromGet,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.qtdRecebimentos,
  });

  factory RecebimentoResponse.fromJson(Map<String, dynamic> json) {
    return RecebimentoResponse(
      recebimentos: (json['recebimentos'] as List? ?? [])
          .map((e) => Recebimento.fromJson(e))
          .toList(),
      dateFromGet: json['dateFromGet']?.toString() ?? '',
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 0,
      totalItems: json['totalItems'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      qtdRecebimentos: QtdRecebimentos.fromJson(json['qtdRecebimentos'] ?? {}),
    );
  }
}

class QtdRecebimentos {
  final int pendente;
  final int erro;

  QtdRecebimentos({required this.pendente, required this.erro});

  factory QtdRecebimentos.fromJson(Map<String, dynamic> json) {
    return QtdRecebimentos(
      pendente: json['pendente'] ?? 0,
      erro: json['erro'] ?? 0,
    );
  }
}

class DetalhesViagemResponse {
  final String viagemId;
  final String viagemData;
  final String cnpjOrigem;
  final String codigoOrigem;
  final String origem;
  final String status;
  final int qtdImei;
  final double valorTotalViagem;
  final String dataRecebimento;
  final String placaVeiculo;
  final String cnpjDestino;
  final String? protocolo;
  final List<Guia> guias;
  final List<Roll> rolls;

  DetalhesViagemResponse({
    required this.viagemId,
    required this.viagemData,
    required this.cnpjOrigem,
    required this.codigoOrigem,
    required this.origem,
    required this.status,
    required this.qtdImei,
    required this.valorTotalViagem,
    required this.dataRecebimento,
    required this.placaVeiculo,
    required this.cnpjDestino,
    this.protocolo,
    required this.guias,
    required this.rolls,
  });

  factory DetalhesViagemResponse.fromJson(Map<String, dynamic> json) {
    return DetalhesViagemResponse(
      viagemId: json['viagem_id']?.toString() ?? '',
      viagemData: json['viagem_data']?.toString() ?? '',
      cnpjOrigem: json['cnpj_origem']?.toString() ?? '',
      codigoOrigem: json['codigo_origem']?.toString() ?? '',
      origem: json['origem']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      qtdImei: json['qtd_imei'] ?? 0,
      valorTotalViagem: (json['valorTotalViagem'] ?? json['valor_total'] ?? 0).toDouble(),
      dataRecebimento: json['data_recebimento']?.toString() ?? '',
      placaVeiculo: json['placa_veiculo']?.toString() ?? '',
      cnpjDestino: json['cnpj_destino']?.toString() ?? '',
      protocolo: json['protocolo'],
      guias: (json['guias'] as List? ?? []).map((e) => Guia.fromJson(e)).toList(),
      rolls: (json['rolls'] as List? ?? []).map((e) => Roll.fromJson(e)).toList(),
    );
  }
}

class Guia {
  final String num;
  final double valorTotal;
  final int qtdImeiGuia;
  final List<RecebimentoNota> recebimentoNota;

  Guia({
    required this.num,
    required this.valorTotal,
    required this.qtdImeiGuia,
    required this.recebimentoNota,
  });

  factory Guia.fromJson(Map<String, dynamic> json) {
    return Guia(
      num: json['num']?.toString() ?? '',
      valorTotal: (json['valorTotal'] ?? 0).toDouble(),
      qtdImeiGuia: json['qtd_imei_guia'] ?? 0,
      recebimentoNota: (json['recebimento_nota'] as List? ?? [])
          .map((e) => RecebimentoNota.fromJson(e))
          .toList(),
    );
  }
}

class Roll {
  final String num;
  final String numGuia;
  final int qtdImeiRoll;
  final double valorTotal;
  final List<RecebimentoNota> recebimentoNota;

  Roll({
    required this.num,
    required this.numGuia,
    required this.qtdImeiRoll,
    required this.valorTotal,
    required this.recebimentoNota,
  });

  factory Roll.fromJson(Map<String, dynamic> json) {
    return Roll(
      num: json['num']?.toString() ?? '',
      numGuia: json['numGuia']?.toString() ?? '',
      qtdImeiRoll: json['qtd_imei_roll'] ?? 0,
      valorTotal: (json['valorTotal'] ?? 0).toDouble(),
      recebimentoNota: (json['recebimento_nota'] as List? ?? [])
          .map((e) => RecebimentoNota.fromJson(e))
          .toList(),
    );
  }
}

class RecebimentoNota {
  final String notaChave;
  final String notaNumero;
  final String notaSerie;
  final String notaData;
  final String recebimentoStatusDescricao;
  final String dataRecebimento;
  final String? erro;
  final String notaValor;
  final List<RecebimentoItem> recebimentoItem;

  RecebimentoNota({
    required this.notaChave,
    required this.notaNumero,
    required this.notaSerie,
    required this.notaData,
    required this.recebimentoStatusDescricao,
    required this.dataRecebimento,
    this.erro,
    required this.notaValor,
    required this.recebimentoItem,
  });

  factory RecebimentoNota.fromJson(Map<String, dynamic> json) {
    return RecebimentoNota(
      notaChave: json['nota_chave']?.toString() ?? '',
      notaNumero: json['nota_numero']?.toString() ?? '',
      notaSerie: json['nota_serie']?.toString() ?? '',
      notaData: json['nota_data']?.toString() ?? '',
      recebimentoStatusDescricao: json['recebimento_status_descricao']?.toString() ?? '',
      dataRecebimento: json['data_recebimento']?.toString() ?? '',
      erro: json['erro'],
      notaValor: json['nota_valor']?.toString() ?? '0',
      recebimentoItem: (json['recebimento_item'] as List? ?? [])
          .map((e) => RecebimentoItem.fromJson(e))
          .toList(),
    );
  }
}

class RecebimentoItem {
  final String idSap;
  final String idEan;
  final String descricao;
  final int quantidade;
  final double preco;
  final List<String> imeis;
  final String departamento;
  final String? guiaOuRoll;

  RecebimentoItem({
    required this.idSap,
    required this.idEan,
    required this.descricao,
    required this.quantidade,
    required this.preco,
    required this.imeis,
    required this.departamento,
    this.guiaOuRoll,
  });

  factory RecebimentoItem.fromJson(Map<String, dynamic> json) {
    return RecebimentoItem(
      idSap: json['id_sap']?.toString() ?? '',
      idEan: json['id_ean']?.toString() ?? '',
      descricao: json['descricao']?.toString() ?? '',
      quantidade: json['quantidade'] ?? 0,
      preco: (json['preco'] ?? 0).toDouble(),
      imeis: (json['imeis'] as List? ?? []).map((e) => e.toString()).toList(),
      departamento: json['departamento']?.toString() ?? '',
      guiaOuRoll: json['guiaOuRoll'],
    );
  }

  RecebimentoItem copyWith({String? guiaOuRoll}) {
    return RecebimentoItem(
      idSap: idSap,
      idEan: idEan,
      descricao: descricao,
      quantidade: quantidade,
      preco: preco,
      imeis: imeis,
      departamento: departamento,
      guiaOuRoll: guiaOuRoll ?? this.guiaOuRoll,
    );
  }
}

class ProtocoloRequest {
  final String idRecebimento;

  ProtocoloRequest({required this.idRecebimento});

  Map<String, dynamic> toJson() => {'id_recebimento': idRecebimento};
}

class ProtocoloResponse {
  final String? protocolo;
  final bool success;
  final String? message;

  ProtocoloResponse({this.protocolo, required this.success, this.message});

  factory ProtocoloResponse.fromJson(Map<String, dynamic> json) {
    final protocolo = json['protocolo'] as String?;
    return ProtocoloResponse(
      protocolo: protocolo,
      success: (json['success'] as bool?) ??
          (protocolo != null && protocolo.isNotEmpty),
      message: json['message'],
    );
  }
}

class ImpressaoResponse {
  final bool success;
  final String? message;
  final String? url;
  final String? viagemId;
  final String? error;

  ImpressaoResponse({
    required this.success,
    this.message,
    this.url,
    this.viagemId,
    this.error,
  });

  factory ImpressaoResponse.fromJson(Map<String, dynamic> json) {
    return ImpressaoResponse(
      success: json['success'] ?? false,
      message: json['message'],
      url: json['url'],
      viagemId: json['viagemId'],
      error: json['error'],
    );
  }
}

class Recebimento {
  final String id;
  final String viagemData;
  final String codigoOrigem;
  final String origem;
  final String status;
  final String? dataRecebimento;
  final String? placaVeiculo;
  final int qtdRolls;
  final int qtdGuias;
  final String? protocolo;
  final double valorTotal;

  Recebimento({
    required this.id,
    required this.viagemData,
    required this.codigoOrigem,
    required this.origem,
    required this.status,
    this.dataRecebimento,
    this.placaVeiculo,
    required this.qtdRolls,
    required this.qtdGuias,
    this.protocolo,
    required this.valorTotal,
  });

  factory Recebimento.fromJson(Map<String, dynamic> json) {
    final valor = json['valor_total'] ??
        json['valorTotalViagem'] ??
        json['valorTotal'] ??
        0;
    return Recebimento(
      id: json['_id']?.toString() ?? '',
      viagemData: json['viagem_data']?.toString() ?? '',
      codigoOrigem: json['codigo_origem']?.toString() ?? '',
      origem: json['origem']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      dataRecebimento: json['data_recebimento'],
      placaVeiculo: json['placa_veiculo']?.toString(),
      qtdRolls: json['qtd_rolls'] ?? 0,
      qtdGuias: json['qtd_guias'] ?? 0,
      protocolo: json['protocolo'],
      valorTotal: (valor is num ? valor : 0).toDouble(),
    );
  }
}
