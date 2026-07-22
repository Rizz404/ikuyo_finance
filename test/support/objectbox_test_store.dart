import 'dart:io';

import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

/// Opens a throwaway ObjectBox store backed by a temp directory, so
/// repository/bloc tests hit a real store without touching the app's DB.
class ObjectBoxTestStore {
  final ObjectBoxStorage storage;
  final Directory _dir;

  ObjectBoxTestStore._(this.storage, this._dir);

  static Future<ObjectBoxTestStore> open() async {
    final dir = Directory.systemTemp.createTempSync('ikuyo_finance_test_db_');
    final store = await openStore(directory: dir.path);
    return ObjectBoxTestStore._(ObjectBoxStorage.forTesting(store), dir);
  }

  void close() {
    storage.close();
    if (_dir.existsSync()) {
      _dir.deleteSync(recursive: true);
    }
  }
}
