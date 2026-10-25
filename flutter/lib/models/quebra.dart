// Models da API de Quebra (sl-bff).
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Motivos de quebra (carregados de /web/breakage/reasons).
class BreakageReason {
  final String id;
  final String label;
  final int reasonNumber;
  final int code;

  BreakageReason({
    required this.id,
    required this.label,
    required this.reasonNumber,
    required this.code,
  });

  factory BreakageReason.fromJson(Map<String, dynamic> j) => BreakageReason(
        id: (j['id'] ?? j['_id'])?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        reasonNumber: (j['reasonNumber'] as num?)?.toInt() ?? 0,
        code: (j['code'] as num?)?.toInt() ?? 0,
      );
}

class Breakage {
  final String id;
  final String store;
  final String user;
  final String email;
  final String date;
  final String status;
  final int itemsQuantity;

  Breakage({
    required this.id,
    required this.store,
    required this.user,
    required this.email,
    required this.date,
    required this.status,
    required this.itemsQuantity,
  });

  factory Breakage.fromJson(Map<String, dynamic> j) => Breakage(
        id: (j['id'] ?? j['_id'])?.toString() ?? '',
        store: j['store']?.toString() ?? '',
        user: j['user']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        date: (j['date'] ?? j['createdAt'])?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        itemsQuantity: (j['itemsQuantity'] as num?)?.toInt() ?? 0,
      );

  String get _statusUpper => status.toUpperCase();

  bool get isProcessed => _statusUpper == 'PROCESSED';
  bool get isOpen => _statusUpper == 'OPEN';
  bool get isPending => _statusUpper == 'PENDING' || _statusUpper == 'ABERTA';
  bool get isClosed => _statusUpper == 'CLOSED' || _statusUpper == 'ERROR';

  /// Status em que o site permite remover a quebra.
  bool get canRemove => isPending || isOpen || isClosed;

  /// Status em que o site permite reabrir (volta para "Aberta").
  bool get canReopen => isClosed;

  /// Processada/fechada: não pode mais alterar itens.
  bool get isReadOnly => isProcessed || isClosed;

  /// Mantido para compatibilidade com a tela de lista.
  bool get processado => isProcessed;

  String get statusLabel {
    switch (_statusUpper) {
      case 'PROCESSED':
        return 'Processada';
      case 'CLOSED':
        return 'Fechada';
      case 'ERROR':
        return 'Processada com erro';
      case 'PENDING':
        return 'Pendente';
      case 'ABERTA':
      case 'OPEN':
        return 'Aberta';
      case 'IN_PROGRESS':
      case 'EM_ANDAMENTO':
        return 'Em andamento';
      default:
        return status;
    }
  }
}

class BreakagePage {
  final int total;
  final int limit;
  final int offset;
  final List<Breakage> breakages;

  BreakagePage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.breakages,
  });

  factory BreakagePage.fromJson(Map<String, dynamic> j) {
    final r = _map(j['_result']);
    return BreakagePage(
      total: (r['total'] as num?)?.toInt() ?? 0,
      limit: (r['limit'] as num?)?.toInt() ?? 0,
      offset: (r['offset'] as num?)?.toInt() ?? 0,
      breakages: (j['breakages'] as List? ?? const [])
          .map((e) => Breakage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class BreakageItem {
  final String id;
  final String user;
  final String sapCode;
  final String ean;
  final String description;
  final int stock;
  final int quantity;
  final double costPrice;
  final String reason;
  final String reasonId;

  BreakageItem({
    required this.id,
    required this.user,
    required this.sapCode,
    required this.ean,
    required this.description,
    required this.stock,
    required this.quantity,
    required this.costPrice,
    required this.reason,
    this.reasonId = '',
  });

  factory BreakageItem.fromJson(Map<String, dynamic> j) => BreakageItem(
        id: (j['id'] ?? j['_id'])?.toString() ?? '',
        user: j['user']?.toString() ?? '',
        sapCode: j['sapCode']?.toString() ?? '',
        ean: j['ean']?.toString() ?? '',
        description: j['description']?.toString().trim() ?? '',
        stock: (j['stock'] as num?)?.toInt() ?? 0,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        costPrice: (j['costPrice'] as num?)?.toDouble() ?? 0,
        reason: j['reason']?.toString() ?? '',
        reasonId: j['reasonId']?.toString() ?? '',
      );

  BreakageItem withReasonId(String newReasonId) =>
      copyWith(reasonId: newReasonId);

  BreakageItem copyWith({
    int? quantity,
    String? reason,
    String? reasonId,
  }) =>
      BreakageItem(
        id: id,
        user: user,
        sapCode: sapCode,
        ean: ean,
        description: description,
        stock: stock,
        quantity: quantity ?? this.quantity,
        costPrice: costPrice,
        reason: reason ?? this.reason,
        reasonId: reasonId ?? this.reasonId,
      );
}

class BreakageDetail {
  final Breakage breakage;
  final List<BreakageItem> items;
  final List<BreakageReason> reasons;

  BreakageDetail({
    required this.breakage,
    required this.items,
    required this.reasons,
  });

  factory BreakageDetail.fromJson(Map<String, dynamic> j) {
    final reasons = (j['reasons'] as List? ?? const [])
        .map((e) => BreakageReason.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // A API de detalhe manda apenas o label do motivo em cada item. Para o
    // "abrir quebra" (que exige reasonId) resolvemos o id pelo label.
    final byLabel = <String, String>{
      for (final r in reasons)
        if (r.label.trim().isNotEmpty) r.label.trim().toLowerCase(): r.id,
    };
    final items = (j['data'] as List? ?? const []).map((e) {
      final item = BreakageItem.fromJson(Map<String, dynamic>.from(e));
      if (item.reasonId.isNotEmpty) return item;
      final id = byLabel[item.reason.trim().toLowerCase()];
      return id == null ? item : item.withReasonId(id);
    }).toList();
    return BreakageDetail(
      breakage: Breakage.fromJson(_map(j['breakage'])),
      items: items,
      reasons: reasons,
    );
  }
}
