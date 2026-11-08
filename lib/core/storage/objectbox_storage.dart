import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ikuyo_finance/objectbox.g.dart';

/// Wrapper untuk ObjectBox Store
/// Digunakan untuk menyimpan data lokal dengan ObjectBox
class ObjectBoxStorage {
  late final Store _store;

  Store get store => _store;

  ObjectBoxStorage();

  /// Wraps an already-open [Store] (e.g. a temp test store) without touching disk.
  ObjectBoxStorage.forTesting(Store store) {
    _store = store;
  }

  /// Initialize ObjectBox Store
  /// Harus dipanggil sebelum menggunakan ObjectBox
  Future<void> init({String? directory}) async {
    final storePath =
        directory ??
        path.join(
          (await getApplicationDocumentsDirectory()).path,
          'ikuyo_finance_db',
        );

    // * Isolate lain (mis. WorkManager) bisa sudah membuka store di path
    // * yang sama dalam proses ini — attach agar tidak gagal "already open"
    if (Store.isOpen(storePath)) {
      _store = Store.attach(getObjectBoxModel(), storePath);
      return;
    }
    try {
      _store = await openStore(directory: storePath);
    } on ObjectBoxException catch (_) {
      if (!Store.isOpen(storePath)) rethrow;
      _store = Store.attach(getObjectBoxModel(), storePath);
    } on StateError catch (_) {
      if (!Store.isOpen(storePath)) rethrow;
      _store = Store.attach(getObjectBoxModel(), storePath);
    }
  }

  /// Close store ketika tidak digunakan
  void close() {
    _store.close();
  }

  /// Get box untuk entity tertentu
  Box<T> box<T>() {
    return _store.box<T>();
  }
}
