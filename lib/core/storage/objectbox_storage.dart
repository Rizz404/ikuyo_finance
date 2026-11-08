import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ikuyo_finance/objectbox.g.dart';

/// Wrapper untuk ObjectBox Store
/// Digunakan untuk menyimpan data lokal dengan ObjectBox
class ObjectBoxStorage {
  // * Registry per isolate (static = per isolate di Dart): satu Store per
  // * direktori, dibagi oleh semua handle dengan reference counting.
  // * ObjectBox melarang dua Store untuk direktori yang sama di satu isolate.
  static final Map<String, Future<Store>> _opening = {};
  static final Map<String, int> _refCounts = {};

  late final Store _store;
  String? _path;
  bool _closed = false;

  Store get store => _store;

  ObjectBoxStorage();

  /// Wraps an already-open [Store] (e.g. a temp test store) without touching disk.
  ObjectBoxStorage.forTesting(Store store) {
    _store = store;
  }

  /// Initialize ObjectBox Store
  /// Harus dipanggil sebelum menggunakan ObjectBox. Aman dipanggil oleh
  /// beberapa handle di isolate yang sama (store dibagi, bukan dibuka ulang).
  Future<void> init({String? directory}) async {
    final storePath =
        directory ??
        path.join(
          (await getApplicationDocumentsDirectory()).path,
          'ikuyo_finance_db',
        );

    final pending = _opening[storePath] ??= _open(storePath);
    _refCounts[storePath] = (_refCounts[storePath] ?? 0) + 1;
    try {
      _store = await pending;
      _path = storePath;
    } catch (_) {
      _release(storePath);
      rethrow;
    }
  }

  static Future<Store> _open(String storePath) async {
    // * Isolate lain (mis. WorkManager) bisa sudah membuka store di path
    // * yang sama dalam proses ini — attach agar tidak gagal "already open"
    if (Store.isOpen(storePath)) {
      return Store.attach(getObjectBoxModel(), storePath);
    }
    try {
      return await openStore(directory: storePath);
    } on ObjectBoxException catch (_) {
      if (!Store.isOpen(storePath)) rethrow;
      return Store.attach(getObjectBoxModel(), storePath);
    } on StateError catch (_) {
      if (!Store.isOpen(storePath)) rethrow;
      return Store.attach(getObjectBoxModel(), storePath);
    }
  }

  // * Return true bila handle ini yang terakhir untuk path tersebut
  static bool _release(String storePath) {
    final remaining = (_refCounts[storePath] ?? 1) - 1;
    if (remaining > 0) {
      _refCounts[storePath] = remaining;
      return false;
    }
    _refCounts.remove(storePath);
    _opening.remove(storePath);
    return true;
  }

  /// Close store ketika tidak digunakan. Store bersama baru benar-benar
  /// ditutup saat handle terakhir di isolate ini menutupnya.
  void close() {
    final storePath = _path;
    if (storePath == null) {
      _store.close();
      return;
    }
    if (_closed) return;
    _closed = true;
    if (_release(storePath)) _store.close();
  }

  /// Get box untuk entity tertentu
  Box<T> box<T>() {
    return _store.box<T>();
  }
}
