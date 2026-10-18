/// Modelos da lista de itens bloqueados (bff-item-blocked).
class ItemBloqueado {
  final String id;
  final String ean;
  final int quantity;
  final String reasonBlocking;
  final String description;
  final String precovigente;
  final String approved;
  final List<String> tags;
  final String blockedAt;
  final String treatmentDescription;
  final String line;
  final String departamentCode;
  final String treatmentCode;

  ItemBloqueado({
    required this.id,
    required this.ean,
    required this.quantity,
    required this.reasonBlocking,
    required this.description,
    required this.precovigente,
    required this.approved,
    required this.tags,
    required this.blockedAt,
    required this.treatmentDescription,
    required this.line,
    required this.departamentCode,
    required this.treatmentCode,
  });

  factory ItemBloqueado.fromJson(Map<String, dynamic> j) {
    final rawTags = j['tags'];
    return ItemBloqueado(
      id: (j['id'] ?? '').toString(),
      ean: (j['ean'] ?? '').toString(),
      quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      reasonBlocking: (j['reasonBlocking'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      precovigente: (j['precovigente'] ?? '').toString(),
      approved: (j['approved'] ?? '').toString(),
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
      blockedAt: (j['blockedAt'] ?? '').toString(),
      treatmentDescription: (j['treatmentDescription'] ?? '').toString(),
      line: (j['line'] ?? '').toString(),
      departamentCode: (j['departamentCode'] ?? '').toString(),
      treatmentCode: (j['treatmentCode'] ?? '').toString(),
    );
  }
}

class BloqueioOperacao {
  final String id;
  final List<ItemBloqueado> itemsBlocked;
  final bool answered;
  final String createdAt;
  final String store;
  final String nameStore;
  final double totalQuantity;
  final double totalPrecoVigente;
  final String createdBy;
  final String answeredAt;
  final String answeredBy;

  BloqueioOperacao({
    required this.id,
    required this.itemsBlocked,
    required this.answered,
    required this.createdAt,
    required this.store,
    required this.nameStore,
    required this.totalQuantity,
    required this.totalPrecoVigente,
    required this.createdBy,
    required this.answeredAt,
    required this.answeredBy,
  });

  factory BloqueioOperacao.fromJson(Map<String, dynamic> j) {
    final raw = j['itemsBlocked'];
    return BloqueioOperacao(
      id: (j['id'] ?? '').toString(),
      itemsBlocked: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => ItemBloqueado.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      answered: j['answered'] == true,
      createdAt: (j['createdAt'] ?? '').toString(),
      store: (j['store'] ?? '').toString(),
      nameStore: (j['nameStore'] ?? '').toString(),
      totalQuantity: (j['totalQuantity'] as num?)?.toDouble() ?? 0,
      totalPrecoVigente:
          (j['totalPrecoVigente'] as num?)?.toDouble() ?? 0,
      createdBy: (j['createdBy'] ?? '').toString(),
      answeredAt: (j['answeredAt'] ?? '').toString(),
      answeredBy: (j['answeredBy'] ?? '').toString(),
    );
  }
}

/// Informações do produto retornadas por bff-trade/infos-product.
class ProductInfo {
  final String category;
  final String description;
  final String name;
  final String sku;
  final String ean;
  final String catalog;
  final String cdepartamento;
  final String linha;
  final String nserie;
  final bool excededTime;
  final String? message;
  final String? note;
  final String codtratamento;
  final String desctratamento;
  final String precovigente;
  final String codfornecedor;
  final String descfornecedor;

  ProductInfo({
    required this.category,
    required this.description,
    required this.name,
    required this.sku,
    required this.ean,
    required this.catalog,
    required this.cdepartamento,
    required this.linha,
    required this.nserie,
    required this.excededTime,
    required this.message,
    required this.note,
    required this.codtratamento,
    required this.desctratamento,
    required this.precovigente,
    required this.codfornecedor,
    required this.descfornecedor,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> j) {
    return ProductInfo(
      category: (j['category'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      sku: (j['sku'] ?? '').toString(),
      ean: (j['ean'] ?? '').toString(),
      catalog: (j['catalog'] ?? '').toString(),
      cdepartamento: (j['cdepartamento'] ?? '').toString(),
      linha: (j['linha'] ?? '').toString(),
      nserie: (j['nserie'] ?? '').toString(),
      excededTime: j['excededTime'] == true,
      message: j['message']?.toString(),
      note: j['note']?.toString(),
      codtratamento: (j['codtratamento'] ?? '').toString(),
      desctratamento: (j['desctratamento'] ?? '').toString(),
      precovigente: (j['precovigente'] ?? '').toString(),
      codfornecedor: (j['codfornecedor'] ?? '').toString(),
      descfornecedor: (j['descfornecedor'] ?? '').toString(),
    );
  }
}

class BloqueioPage {
  final List<BloqueioOperacao> results;
  final int totalElements;
  final int totalPages;
  final int currentPage;

  BloqueioPage({
    required this.results,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
  });

  factory BloqueioPage.fromJson(Map<String, dynamic> j) {
    final raw = j['results'];
    final meta = (j['metadata'] as Map?) ?? const {};
    return BloqueioPage(
      results: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => BloqueioOperacao.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      totalElements: (meta['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      currentPage: (meta['currentPage'] as num?)?.toInt() ?? 1,
    );
  }
}
