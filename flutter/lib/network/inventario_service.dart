import 'api_client.dart';
import '../utils/constants.dart';
import '../models/inventario.dart';
import '../models/quebra.dart';

/// Serviço da API do Inventário (sl-bff).
class InventarioService {
  final ApiClient client;

  InventarioService(this.client);

  /// Client já configurado para o sl-bff.
  factory InventarioService.forSession(dynamic session) => InventarioService(
        ApiClient(session,
            baseUrl: Constants.slBffBaseUrl,
            platformVersion: Constants.platformVersion),
      );

  Future<CycleCountPage> getCycleCounts({
    required String storeId,
    int offset = 0,
    int limit = 20,
    String? inventoryNumber,
    String? reference,
    String? date,
    String? status,
  }) async {
    final query = <String, String>{
      'storeId': storeId,
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (inventoryNumber != null && inventoryNumber.isNotEmpty) {
      query['inventoryNumber'] = inventoryNumber;
    }
    if (reference != null && reference.isNotEmpty) {
      query['reference'] = reference;
    }
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (status != null && status.isNotEmpty) query['status'] = status;
    final json = await client.get('web/cycle-count', query: query)
        as Map<String, dynamic>;
    return CycleCountPage.fromJson(json);
  }

  Future<StoreInfo?> getStore(String storeId) async {
    final json = await client.get('web/store', query: {
      'limit': '1',
      'offset': '0',
      'ids': storeId,
    }) as Map<String, dynamic>;
    final stores = json['stores'] as List? ?? const [];
    if (stores.isEmpty) return null;
    return StoreInfo.fromJson(Map<String, dynamic>.from(stores.first));
  }

  Future<InventoryDetail> getCycleCount(String id) async {
    final json =
        await client.get('web/cycle-count/$id') as Map<String, dynamic>;
    return InventoryDetail.fromJson(json);
  }

  Future<NotificationPage> getNotifications({
    required String storeId,
    String status = 'UNREAD',
    int limit = 4,
    int offset = 0,
    String? createdAt,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'status': status,
      'storeId': storeId,
    };
    if (createdAt != null) query['createdAt'] = createdAt;
    final json = await client.get('web/notification', query: query)
        as Map<String, dynamic>;
    return NotificationPage.fromJson(json);
  }

  Future<Product> getProduct({
    required String storeId,
    String? ean,
    String? sapCode,
  }) async {
    final query = <String, String>{};
    if (ean != null && ean.isNotEmpty) query['ean'] = ean;
    if (sapCode != null && sapCode.isNotEmpty) query['sapCode'] = sapCode;
    final json = await client.get(
        'web/cycle-count/product/store/$storeId',
        query: query) as Map<String, dynamic>;
    if (json['errorCode'] == 'CYCLECOUNT_ADD_ITEM_DEPARTMENT_BLOCKED') {
      final blocks = json['blocks'];
      final nome = (blocks is List && blocks.isNotEmpty)
          ? (blocks.first['name']?.toString() ?? '')
          : '';
      throw DepartmentBlockedException(nome);
    }
    return Product.fromJson(json);
  }

  /// Adiciona um item ao inventário (draft).
  Future<void> addItem(
    String inventoryId, {
    required String ean,
    required String sapCode,
    required String description,
    int expectedQuantity = 0,
    int countedQuantity = 0,
    double unitPrice = 0,
  }) async {
    await client.post('web/cycle-count/$inventoryId/item', body: {
      'ean': ean,
      'sapCode': sapCode,
      'description': description,
      'expectedQuantity': expectedQuantity,
      'countedQuantity': countedQuantity,
      'unitPrice': unitPrice,
    });
  }

  /// Exclui um inventário.
  Future<void> deleteCycleCount(String inventoryId) async {
    await client.delete('web/cycle-count/$inventoryId');
  }

  /// Cria um inventário (draft). O backend pode devolver o id como string
  /// simples ou como objeto; tratamos os dois casos.
  Future<Inventory> createInventory({
    required String storeId,
    required String email,
  }) async {
    final data = await client.post('web/cycle-count',
        body: {'storeId': storeId, 'email': email});
    if (data is Map) {
      return Inventory.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is String) {
      return Inventory(
        id: data,
        inventoryNumber: '',
        reference: '',
        createdAt: '',
        statusCode: 'DRAFT',
        statusName: 'Em andamento',
      );
    }
    throw Exception('Resposta inesperada ao criar inventário');
  }

  /// Finaliza (processa) o inventário.
  Future<void> processInventory(String inventoryId) async {
    await client.post('web/cycle-count/$inventoryId/process');
  }

  /// Atualiza a quantidade contada de um item.
  Future<void> updateItem(
    String inventoryId,
    String itemId, {
    required int quantity,
  }) async {
    await client.put('web/cycle-count/$inventoryId/item/$itemId',
        body: {'quantity': quantity});
  }

  /// Remove itens do inventário (lista de ids).
  Future<void> removeItems(String inventoryId, List<String> ids) async {
    await client.post('web/cycle-count/$inventoryId/item/remove',
        body: {'items': ids});
  }

  // ---------- Quebra ----------

  /// Produto para a quebra (endpoint diferente do inventário).
  Future<Product> getProductStore({
    required String storeId,
    String? ean,
    String? sapCode,
  }) async {
    final query = <String, String>{};
    if (ean != null && ean.isNotEmpty) query['ean'] = ean;
    if (sapCode != null && sapCode.isNotEmpty) query['sapCode'] = sapCode;
    final json = await client.get('web/product/store/$storeId',
        query: query) as Map<String, dynamic>;
    return Product.fromJson(json);
  }

  Future<BreakagePage> getBreakages({
    required int year,
    required String store,
    int? month,
    int offset = 0,
    int limit = 50,
    bool? mainPageFilter,
  }) async {
    final query = <String, String>{
      'year': '$year',
      'store': store,
      'offset': '$offset',
      'limit': '$limit',
    };
    if (month != null) query['month'] = '$month';
    if (mainPageFilter != null) {
      query['mainPageFilter'] = '$mainPageFilter';
    }
    final json = await client.get('web/breakage', query: query)
        as Map<String, dynamic>;
    return BreakagePage.fromJson(json);
  }

  Future<dynamic> getPendingBreakage({
    required String email,
    required String store,
  }) {
    return client.get('web/breakage/pending',
        query: {'email': email, 'store': store});
  }

  Future<List<BreakageReason>> getBreakageReasons() async {
    final data = await client.get('web/breakage/reasons');
    if (data is List) {
      return data
          .map((e) => BreakageReason.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Cria uma quebra e retorna o objeto criado.
  Future<Breakage> createBreakage({
    required String storeId,
    required String userName,
    required String userEmail,
  }) async {
    final data = await client.post('web/breakage', body: {
      'storeId': storeId,
      'user': {'name': userName, 'email': userEmail},
    });
    if (data is Map && data['breakage'] is Map) {
      return Breakage.fromJson(
          Map<String, dynamic>.from(data['breakage'] as Map));
    }
    throw Exception('Resposta inesperada ao criar quebra');
  }

  /// Adiciona um item à quebra e retorna a lista de itens atualizada.
  Future<List<BreakageItem>> addBreakageItem(
    String breakageId, {
    required String ean,
    required String sapCode,
    required String description,
    required int stock,
    required int quantity,
    required String reasonId,
    String entryMode = 'item',
  }) async {
    final data = await client.post('web/breakage/$breakageId/items', body: {
      'ean': ean,
      'sapCode': sapCode,
      'description': description,
      'stock': stock,
      'quantity': quantity,
      'reasonId': reasonId,
      'entryMode': entryMode,
    });
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => BreakageItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Remove um item da quebra. Retorna a lista atualizada (se vier no body).
  Future<List<BreakageItem>?> removeBreakageItem(
      String breakageId, String itemId) async {
    final data =
        await client.delete('web/breakage/$breakageId/items/$itemId');
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => BreakageItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return null;
  }

  Future<BreakageDetail> getBreakageDetail(String breakageId) async {
    final json = await client.get('web/breakage/$breakageId')
        as Map<String, dynamic>;
    return BreakageDetail.fromJson(json);
  }

  /// Remove a quebra.
  Future<void> deleteBreakage(String breakageId) async {
    await client.delete('web/breakage/$breakageId');
  }

  /// Altera quantidade/motivo de um item da quebra.
  Future<List<BreakageItem>?> updateBreakageItem(
    String breakageId,
    String itemId, {
    required int quantity,
    required String reasonId,
  }) async {
    final data = await client.put('web/breakage/$breakageId/items/$itemId',
        body: {'quantity': quantity, 'reasonId': reasonId});
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => BreakageItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return null;
  }

  /// Abre (finaliza) a quebra: PUT /web/breakage/{id}/open com os itens.
  Future<void> openBreakage(
      String breakageId, List<BreakageItem> items) async {
    await client.put('web/breakage/$breakageId/open', body: {
      'items': items.map((e) => {'id': e.id, 'reasonId': ''}).toList(),
    });
  }

  /// Finaliza (processa) a quebra aberta: PUT /web/breakage/{id}/process.
  Future<void> processBreakage(String breakageId) async {
    await client.put('web/breakage/$breakageId/process');
  }
}

/// Produto bloqueado para inventário (departamento não permitido).
class DepartmentBlockedException implements Exception {
  final String departmentName;
  DepartmentBlockedException(this.departmentName);

  @override
  String toString() => 'Departamento bloqueado: $departmentName';
}
