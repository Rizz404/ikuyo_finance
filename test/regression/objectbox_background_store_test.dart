// Regression: BKSEC-4. A background isolate (WorkManager) must be able to use
// the database while the UI isolate already holds it open, and vice versa.
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('ikuyo_bg_store_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('second isolate opens the live store while the main store is open',
      () async {
    final main = ObjectBoxStorage();
    await main.init(directory: dir.path);
    main.box<Category>().put(Category(name: 'Food', type: 0));

    final path = dir.path;
    final count = await Isolate.run(() async {
      final bg = ObjectBoxStorage();
      await bg.init(directory: path);
      final n = bg.box<Category>().count();
      bg.close();
      return n;
    });

    expect(count, 1);
    // * Store utama tetap bisa dipakai setelah isolate background menutup miliknya
    main.box<Category>().put(Category(name: 'Salary', type: 1));
    expect(main.box<Category>().count(), 2);
    main.close();
  });
}
