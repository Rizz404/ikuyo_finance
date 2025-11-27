import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ikuyo_finance/objectbox.g.dart';

/// Wrapper untuk ObjectBox Store
/// Digunakan untuk menyimpan data lokal dengan ObjectBox
class ObjectBoxStorage {
  late final Store _store;

  Store get store => _store;

  /// Initialize ObjectBox Store
  /// Harus dipanggil sebelum menggunakan ObjectBox
  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = path.join(docsDir.path, 'ikuyo_finance_db');

    _store = openStore(directory: storePath);
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
