// Regression: AAOB-3 / CSE-2 (asset, category and budget lists never load
// past the first page of 20 and the asset statistic total only sums that
// page) and AAOB-7 (the budget edit dropdown misses the budget's category
// when it is not on the first category page). Real ObjectBox, real
// repositories, real blocs and the real router.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/screens/asset_screen.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    // * Cache rate valid agar ExchangeRateService tidak memanggil jaringan
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: 'idr',
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    rootBundle.clear();
    app = await TestApp.boot();
  });
  tearDown(() => app.close());

  const count = 25;
  String name(String prefix, int i) => '$prefix${i.toString().padLeft(2, '0')}';
  // * Index 0 is the oldest, so with the default createdAt-desc sort it is
  // * the last item and lives on the second page.
  DateTime createdAt(int i) => DateTime(2025, 1, 1).add(Duration(hours: i));

  List<Category> seedCategories(String prefix) {
    final cats = [
      for (var i = 0; i < count; i++)
        Category(
          name: name(prefix, i),
          type: CategoryType.expense.index,
          createdAt: createdAt(i),
        ),
    ];
    app.storage.box<Category>().putMany(cats);
    return cats;
  }

  Future<void> start(WidgetTester tester, String location) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.go(location);
    await tester.pumpAndSettle();
  }

  Finder scrollableOf(Type listType) => find.descendant(
    of: find.byType(listType),
    matching: find.byType(Scrollable),
  );

  testWidgets('AAOB-3 the asset list loads past the first page on scroll',
      (tester) async {
    app.storage.box<Asset>().putMany([
      for (var i = 0; i < count; i++)
        Asset(name: name('A', i), type: 0, balance: 1, createdAt: createdAt(i)),
    ]);
    await start(tester, '/asset');

    await tester.scrollUntilVisible(
      find.text(name('A', 0)),
      300,
      scrollable: scrollableOf(ListView).first,
      maxScrolls: 100,
    );
    expect(find.text(name('A', 0)), findsOneWidget);
  });

  testWidgets('AAOB-3 the asset statistic totals every asset, not one page',
      (tester) async {
    app.storage.box<Asset>().putMany([
      for (var i = 0; i < count; i++)
        Asset(name: name('A', i), type: 0, balance: 1, createdAt: createdAt(i)),
    ]);
    await start(tester, '/asset');
    await tester.tap(find.text(LocaleKeys.assetScreenTabStatistic.tr()));
    await tester.pumpAndSettle();

    expect(
      find.text('$count ${LocaleKeys.assetStatisticAssetCount.tr()}'),
      findsOneWidget,
    );
    final ctx = tester.element(find.byType(AssetScreen));
    expect(ctx.read<AssetBloc>().state.assets, hasLength(count));
  });

  testWidgets('CSE-2 the category grid loads past the first page on scroll',
      (tester) async {
    seedCategories('C');
    await start(tester, '/categories');

    await tester.scrollUntilVisible(
      find.text(name('C', 0)),
      300,
      scrollable: scrollableOf(GridView).first,
      maxScrolls: 100,
    );
    expect(find.text(name('C', 0)), findsOneWidget);
  });

  testWidgets('AAOB-3 the budget list loads past the first page on scroll',
      (tester) async {
    final cats = seedCategories('B');
    app.storage.box<Budget>().putMany([
      for (var i = 0; i < count; i++)
        Budget(amountLimit: 10, createdAt: createdAt(i))
          ..category.target = cats[i],
    ]);
    await start(tester, '/budget');

    await tester.scrollUntilVisible(
      find.text(name('B', 0)),
      300,
      scrollable: scrollableOf(ListView).first,
      maxScrolls: 100,
    );
    expect(find.text(name('B', 0)), findsOneWidget);
  });

  testWidgets('AAOB-7 the budget edit dropdown contains the budget category '
      'even when it is beyond the first category page', (tester) async {
    final cats = seedCategories('C');
    final budget = Budget(amountLimit: 10)..category.target = cats[0];
    app.storage.box<Budget>().put(budget);
    await start(tester, '/budget');
    app.router.push('/budget/edit', extra: budget);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(name('C', 0)), findsOneWidget);
  });
}
