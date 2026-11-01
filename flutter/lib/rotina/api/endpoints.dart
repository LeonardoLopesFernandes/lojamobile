import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:inventario/rotina/api/client.dart';
import 'package:inventario/rotina/types.dart';
import 'package:inventario/rotina/theme.dart';

Map<String, dynamic> _requestBody({String? date}) => {
      'store': store,
      'selectedRegions': [],
      'selectedDistricts': [],
      if (date != null) 'date': date,
    };

Future<List<Department>> getItems(String dateApi) async {
  final res = await apiClient.get<List<dynamic>>('rotina/items',
      queryParameters: {'store': store, 'date': dateApi});
  final data = res.data ?? [];
  return data
      .map((e) => Department.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<TreatedItemResponse> saveTreatedItem(TreatedItemRequest request) async {
  try {
    final res = await apiClient.post<Map<String, dynamic>>(
      'rotina/treated-items',
      data: request.toJson(),
    );
    if (res.statusCode != null &&
        res.statusCode! >= 200 &&
        res.statusCode! < 300) {
      if (res.data == null) {
        return TreatedItemResponse(success: true, message: null);
      }
      return TreatedItemResponse.fromJson(res.data!);
    }
    throw Exception('Erro ${res.statusCode}');
  } on DioException catch (e) {
    final msg = e.message ?? '';
    if (msg.contains('End of input') ||
        msg.contains('BEGIN_OBJECT') ||
        msg.contains('END_DOCUMENT') ||
        msg.contains('Unexpected end of JSON input')) {
      return TreatedItemResponse(success: true, message: null);
    }
    rethrow;
  }
}

Future<CardsPercentageResponse> getCardsPercentage([String? date]) async {
  final res = await apiClient.post<Map<String, dynamic>>(
    'rotina/treated-items/cards-quantity-percentage',
    data: _requestBody(date: date),
  );
  return CardsPercentageResponse.fromJson(res.data!);
}

Future<List<RoutineStatusItem>> getRoutineStatusList() async {
  final res = await apiClient.post<List<dynamic>>(
    'rotina/treated-items/routine-status',
    data: _requestBody(),
  );
  return (res.data ?? [])
      .map((e) => RoutineStatusItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<ByAnswerItem>> getTreatedByAnswers([String? date]) async {
  final res = await apiClient.post<List<dynamic>>(
    'rotina/treated-items/by-answers',
    data: _requestBody(date: date),
  );
  return (res.data ?? [])
      .map((e) => ByAnswerItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<ByAnswerItem>> getUnsoldTreatedAnswers() async {
  final res = await apiClient.post<List<dynamic>>(
    'rotina/unsold-items/treated-answers',
    data: _requestBody(),
  );
  return (res.data ?? [])
      .map((e) => ByAnswerItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<UnsoldTreatedCardResponse> getUnsoldTreatedCard() async {
  final res = await apiClient.post<Map<String, dynamic>>(
    'rotina/unsold-items/treated-card',
    data: _requestBody(),
  );
  return UnsoldTreatedCardResponse.fromJson(res.data!);
}

Future<List<SpecialItem>> getUnsoldItems() async {
  final res =
      await apiClient.get<List<dynamic>>('rotina/unsold-items/$store');
  return (res.data ?? [])
      .map((e) => SpecialItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<SpecialItem>> getNoSalesHistoryItems() async {
  final res = await apiClient
      .get<List<dynamic>>('rotina/no-sales-history-items/$store');
  return (res.data ?? [])
      .map((e) => SpecialItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<SpecialAnswer>> getUnsoldItemAnswers(String department) async {
  final res = await apiClient
      .get<Map<String, dynamic>>('rotina/unsold-items/answers/$department');
  final list = res.data?['unsoldAnswers'] as List<dynamic>? ?? [];
  return list.map((e) => SpecialAnswer.fromJson(e as Map<String, dynamic>)).toList();
}

Future<List<SpecialAnswer>> getNoSalesHistoryItemAnswers(
    String department) async {
  final res = await apiClient.get<Map<String, dynamic>>(
      'rotina/no-sales-history-items/answers/$department');
  final list = res.data?['noSalesHistoryAnswers'] as List<dynamic>? ?? [];
  return list.map((e) => SpecialAnswer.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveUnsoldItemAnswer(SpecialAnswerRequest request) async {
  await apiClient.post('rotina/unsold-items/answer', data: request.toJson());
}

Future<void> saveNoSalesHistoryItemAnswer(SpecialAnswerRequest request) async {
  await apiClient
      .post('rotina/no-sales-history-items/answer', data: request.toJson());
}

Future<({bool saved, String message})> _downloadPdf(
  String path,
  String fileName, {
  Map<String, dynamic>? queryParameters,
}) async {
  try {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'x-requested-with': 'com.rotina.rotina_comercial',
      'Origin': 'https://rotina-comercial.americanas.io',
      'Referer': 'https://rotina-comercial.americanas.io/',
    };
    if (getAuthToken() != null && getAuthToken()!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${getAuthToken()}';
      headers['Cookie'] = 'rc-newToken=${getAuthToken()}';
    }
    final res = await apiClient.get(
      path,
      queryParameters: queryParameters,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: (_, __) {},
    );
    final bytes = Uint8List.fromList(res.data as List<int>);
    /// No LojaMobile o canal nativo é o `com.ir/media`, que salva em
    /// Downloads e abre o PDF (mesmo usado pelos relatórios de etiquetas).
    await const MethodChannel('com.ir/media').invokeMethod<String>(
      'saveToDownloadsAndOpen',
      {
        'fileName': fileName,
        'bytes': bytes,
        'mime': 'application/pdf',
      },
    );
    return (saved: true, message: 'PDF salvo na pasta Downloads: $fileName');
  } on PlatformException catch (e) {
    return (saved: false, message: 'Erro ao salvar PDF: ${e.message}');
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status != null && status >= 400) {
      return (saved: false, message: 'Erro $status');
    }
    return (saved: false, message: 'Erro ao baixar PDF: ${e.message}');
  } catch (e) {
    return (saved: false, message: 'Erro ao baixar PDF: $e');
  }
}

Future<({bool saved, String message})> downloadDaySchedulePdf(
    String dateApi) async {
  final fileName = 'Rotina_${dateApi.replaceAll('/', '_')}.pdf';
  return _downloadPdf(
    'rotina/pdf/generate-day-schedule',
    fileName,
    queryParameters: {'store': store, 'date': dateApi},
  );
}

Future<({bool saved, String message})> downloadUnsoldItemsPdf() =>
    _downloadPdf(
        'rotina/pdf/generate-unsold-items/$store', 'Itens_sem_venda.pdf');

Future<({bool saved, String message})> downloadNoSalesHistoryItemsPdf() =>
    _downloadPdf('rotina/pdf/generate-no-sales-history-items/$store',
        'Itens_sem_historico_venda.pdf');

/// Books/campanhas pendentes da loja (card da Rotina do dia e tela Books).
Future<List<BookStatus>> getBooks({String? loja}) async {
  final filtro = (loja == null || loja.trim().isEmpty) ? store : loja.trim();
  final res = await apiClient.get<List<dynamic>>('rotina/books/$filtro');
  final data = res.data ?? [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(BookStatus.fromJson)
      .toList();
}

/// Books da loja (histórico completo), percorrendo todas as páginas.
/// Devolve o que já carregou em caso de erro/timeout para a tela não travar.
Future<List<BookStatus>> getAllBooks({String? loja}) async {
  final filtro = loja?.trim() ?? '';
  final todos = await _fetchAllBooks(filtro);
  // Alguns perfis não podem consultar o histórico global; nesse caso tenta
  // novamente apenas com a loja do usuário antes de exibir só os pendentes.
  if (todos.isEmpty && filtro.isEmpty) {
    return _fetchAllBooks(store);
  }
  return todos;
}

Future<({List<BookStatus> books, int total})> _fetchBooksPage(
  String filtro,
  int offset,
) async {
  try {
    final res = await apiClient.get<Map<String, dynamic>>(
      'rotina/books/paginated',
      queryParameters: {
        'limit': 100,
        'offset': offset,
        if (filtro.isNotEmpty) 'store': filtro,
      },
    ).timeout(const Duration(seconds: 20));
    final data = (res.data?['data'] as List?) ?? [];
    return (
      books: data
          .whereType<Map<String, dynamic>>()
          .map(BookStatus.fromJson)
          .toList(),
      total: (res.data?['totalCount'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return (books: const <BookStatus>[], total: 0);
  }
}

Future<List<BookStatus>> _fetchAllBooks(String filtro) async {
  final first = await _fetchBooksPage(filtro, 0);
  final all = <BookStatus>[];
  final vistos = <String>{};

  void adicionar(Iterable<BookStatus> livros) {
    for (final b in livros) {
      if (vistos.add(b.bookId)) all.add(b);
    }
  }

  adicionar(first.books);
  if (first.books.isEmpty) return all;

  final pageSize = first.books.length;
  final totalPages = first.total > pageSize
      ? (first.total / pageSize).ceil().clamp(1, 100).toInt()
      : 1;

  // As páginas restantes são buscadas em pequenos lotes paralelos. Antes elas
  // eram sequenciais, o que deixava a tela de Books lenta com muitos books.
  const lote = 8;
  var pagina = 1;
  while (pagina < totalPages) {
    final fim = pagina + lote < totalPages ? pagina + lote : totalPages;
    final futures = <Future<({List<BookStatus> books, int total})>>[];
    for (var p = pagina; p < fim; p++) {
      futures.add(_fetchBooksPage(filtro, p * pageSize));
    }
    final paginas = await Future.wait(futures);
    for (final p in paginas) {
      adicionar(p.books);
    }
    pagina = fim;
  }
  return all;
}

Future<List<String>> getRegions() async {
  final res = await apiClient.get<List<dynamic>>(
    'rotina/stores/regions',
    queryParameters: {'includeAll': true},
  );
  return (res.data ?? []).map((e) => e.toString()).toList();
}

Future<List<StoreDistrict>> getDistricts() async {
  final res = await apiClient.get<List<dynamic>>(
    'rotina/stores/districts',
    queryParameters: {'includeAll': true},
  );
  return (res.data ?? [])
      .whereType<Map<String, dynamic>>()
      .map(StoreDistrict.fromJson)
      .toList();
}

Future<BookTreatmentsPage> getBookTreatments(
  String bookId, {
  int limit = 50,
  int offset = 0,
  String? store,
  String? region,
  String? district,
}) async {
  final res = await apiClient.get<Map<String, dynamic>>(
    'rotina/books/books-treatments-paginated/$bookId',
    queryParameters: {
      'limit': limit,
      'offset': offset,
      if (store != null && store.isNotEmpty) 'store': store,
      if (region != null && region.isNotEmpty) 'region': region,
      if (district != null && district.isNotEmpty) 'district': district,
    },
  );
  final data = res.data?['data'];
  final raw = (data is Map ? data['treatments'] : null) as List? ?? [];
  final bookJson =
      (data is Map ? data['book'] : null) ?? res.data?['book'];
  return BookTreatmentsPage(
    treatments: raw
        .whereType<Map<String, dynamic>>()
        .map(BookTreatment.fromJson)
        .toList(),
    totalCount: (res.data?['totalCount'] as num?)?.toInt() ?? 0,
    book: bookJson is Map<String, dynamic>
        ? BookStatus.fromJson(bookJson)
        : null,
  );
}

/// Envia as fotos de um book (exatamente `filesQuantity` imagens) para a loja.
Future<void> uploadBookPhotos(
  String bookId,
  List<XFile> files, {
  String? loja,
}) async {
  final form = FormData();
  for (final file in files) {
    final name = file.name.isNotEmpty ? file.name : 'foto.jpg';
    final prepared = await _prepareImageBytes(file);
    final uploadName = prepared.converted ? _jpegName(name) : name;
    form.files.add(MapEntry(
      'files',
      MultipartFile.fromBytes(
        prepared.bytes,
        filename: uploadName,
        contentType: prepared.converted
            ? DioMediaType('image', 'jpeg')
            : _imageMediaType(name),
      ),
    ));
  }
  await apiClient.post<void>(
    'rotina/books/treatments/upload-photo/$bookId',
    queryParameters: {
      'store': (loja == null || loja.trim().isEmpty) ? store : loja.trim(),
    },
    data: form,
  );
}

const int _maxUploadBytes = 900 * 1024;
const int _maxUploadDimension = 4096;

Future<({Uint8List bytes, bool converted})> _prepareImageBytes(
    XFile file) async {
  final raw = await file.readAsBytes();
  // Mantém a foto original quando já está leve. Só comprime o necessário
  // para caber no limite aceito pelo servidor (erro 413).
  if (raw.lengthInBytes <= _maxUploadBytes) {
    return (bytes: raw, converted: false);
  }
  return (bytes: await compute(_compressImage, raw), converted: true);
}

String _jpegName(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return '$base.jpg';
}

Uint8List _compressImage(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;

  var base = decoded;
  if (base.width > _maxUploadDimension || base.height > _maxUploadDimension) {
    base = _resizeToMax(base, _maxUploadDimension);
  }

  // Primeiro tenta manter o tamanho original com a maior qualidade possível.
  // Se ainda passar do limite, reduz a resolução gradualmente.
  const dimensoes = <int?>[
    null,
    2400,
    2000,
    1800,
    1600,
    1400,
    1280,
    1024,
    900,
    800
  ];
  const qualidades = [95, 92, 90, 88, 85, 82, 80, 78, 75, 72, 70, 65, 60, 55];

  for (final dimensao in dimensoes) {
    final candidata =
        dimensao == null ? base : _resizeToMax(base, dimensao);
    for (final qualidade in qualidades) {
      final bytes =
          Uint8List.fromList(img.encodeJpg(candidata, quality: qualidade));
      if (bytes.lengthInBytes <= _maxUploadBytes) return bytes;
    }
  }
  return Uint8List.fromList(
      img.encodeJpg(_resizeToMax(base, 800), quality: 50));
}

img.Image _resizeToMax(img.Image source, int maxDim) {
  if (source.width <= maxDim && source.height <= maxDim) return source;
  return img.copyResize(
    source,
    width: source.width >= source.height ? maxDim : null,
    height: source.height > source.width ? maxDim : null,
    interpolation: img.Interpolation.linear,
  );
}

DioMediaType _imageMediaType(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return DioMediaType('image', 'png');
  if (n.endsWith('.webp')) return DioMediaType('image', 'webp');
  if (n.endsWith('.heic')) return DioMediaType('image', 'heic');
  return DioMediaType('image', 'jpeg');
}

String uploadErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    dynamic item = data;
    if (data is List && data.isNotEmpty) item = data.first;
    if (item is Map) {
      final msg = item['errorDetails'] ?? item['error'] ?? item['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    }
    final status = error.response?.statusCode;
    if (status != null) return 'Erro $status ao enviar as fotos.';
  }
  return 'Não foi possível enviar as fotos.';
}

String bookTreatmentImageUrl(String treatmentId, String filename) =>
    '${baseUrl}rotina/books/store-treatment/$treatmentId/image?filename=${Uri.encodeQueryComponent(filename)}';

/// Foto exemplo do book (campanha), usada como referência para a loja.
String bookExampleImageUrl(String bookId, String filename) =>
    '${baseUrl}rotina/books/example-image/$bookId?filename=${Uri.encodeQueryComponent(filename)}';
