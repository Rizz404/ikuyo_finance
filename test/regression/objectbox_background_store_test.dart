// Regression: BKSEC-4, R08. A background isolate (WorkManager) must be able to use
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

  test('R08 a second init in the same isolate reuses the open store and '
      'closing one handle keeps the other usable', () async {
    final first = ObjectBoxStorage();
    await first.init(directory: dir.path);
    final second = ObjectBoxStorage();
    await second.init(directory: dir.path);

    second.box<Category>().put(Category(name: 'Food', type: 0));
    expect(first.box<Category>().count(), 1);

    first.close();
    expect(second.box<Category>().count(), 1);
    second.close();
  });

  test('R08 concurrent inits in the same isolate both succeed', () async {
    final a = ObjectBoxStorage();
    final b = ObjectBoxStorage();
    await Future.wait([
      a.init(directory: dir.path),
      b.init(directory: dir.path),
    ]);
    a.box<Category>().put(Category(name: 'Food', type: 0));
    expect(b.box<Category>().count(), 1);
    b.close();
    a.close();
  });

  test('R08 two handles inside a background isolate while the UI isolate '
      'holds the store', () async {
    final main = ObjectBoxStorage();
    await main.init(directory: dir.path);
    final path = dir.path;
    final count = await Isolate.run(() async {
      final tx = ObjectBoxStorage();
      await tx.init(directory: path);
      final backup = ObjectBoxStorage();
      await backup.init(directory: path);
      tx.box<Category>().put(Category(name: 'Bg', type: 0));
      tx.close();
      final n = backup.box<Category>().count();
      backup.close();
      return n;
    });
    expect(count, 1);
    expect(main.box<Category>().count(), 1);
    main.close();
  });
}
