import '../models/models.dart';
import '../database/app_database.dart';

class ListaStore {
  static final ListaStore instance = ListaStore._();
  ListaStore._();

  // ========== ETIQUETAS ==========
  Future<List<PriceTag>> getEtiquetas({bool amanha = false}) async {
    try {
      return await AppDatabase.recuperarEtiquetas(amanha: amanha);
    } catch (e) {
      return [];
    }
  }

  Future<void> saveEtiquetas(List<PriceTag> list, {bool amanha = false}) async {
    try {
      await AppDatabase.salvarEtiquetas(list, amanha: amanha);
    } catch (e) {}
  }

  Future<void> addEtiqueta(PriceTag item, {bool amanha = false}) async {
    final current = await getEtiquetas(amanha: amanha);
    current.add(item);
    await saveEtiquetas(current, amanha: amanha);
  }

  Future<void> addEtiquetas(List<PriceTag> items, {bool amanha = false}) async {
    final current = await getEtiquetas(amanha: amanha);
    current.addAll(items);
    await saveEtiquetas(current, amanha: amanha);
  }

  Future<void> removeEtiqueta(PriceTag item, {bool amanha = false}) async {
    final current = await getEtiquetas(amanha: amanha);
    current.removeWhere((e) => e.id == item.id);
    await saveEtiquetas(current, amanha: amanha);
  }

  Future<void> clearEtiquetas({bool amanha = false}) async =>
      saveEtiquetas([], amanha: amanha);

  // ========== PAPELETAS ==========
  Future<List<PriceSign>> getPapeletas({bool amanha = false}) async {
    try {
      return await AppDatabase.recuperarPapeletas(amanha: amanha);
    } catch (e) {
      return [];
    }
  }

  Future<void> savePapeletas(List<PriceSign> list,
      {bool amanha = false}) async {
    try {
      await AppDatabase.salvarPapeletas(list, amanha: amanha);
    } catch (e) {}
  }

  Future<void> addPapeleta(PriceSign item, {bool amanha = false}) async {
    final current = await getPapeletas(amanha: amanha);
    current.add(item);
    await savePapeletas(current, amanha: amanha);
  }

  Future<void> addPapeletas(List<PriceSign> items,
      {bool amanha = false}) async {
    final current = await getPapeletas(amanha: amanha);
    current.addAll(items);
    await savePapeletas(current, amanha: amanha);
  }

  Future<void> removePapeleta(PriceSign item, {bool amanha = false}) async {
    final current = await getPapeletas(amanha: amanha);
    current.removeWhere((e) => e.id == item.id);
    await savePapeletas(current, amanha: amanha);
  }

  Future<void> clearPapeletas({bool amanha = false}) async =>
      savePapeletas([], amanha: amanha);

  // ========== ÁREA DE COLAGEM ==========
  Future<String> getColagem() async {
    try {
      return await AppDatabase.recuperarColagem();
    } catch (e) {
      return "";
    }
  }

  Future<void> setColagem(String code) async {
    try {
      await AppDatabase.salvarColagem(code);
    } catch (e) {}
  }
}
