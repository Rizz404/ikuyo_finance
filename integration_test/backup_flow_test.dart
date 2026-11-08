import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree against an ephemeral
/// ObjectBox store.
///
/// SCOPE NOTE: BackupScreen's actual export/import buttons call
/// `FilePicker.platform.getDirectoryPath(...)` / a file-open dialog — a
/// real native OS picker outside the Flutter widget tree that cannot be
/// driven from a widget test (the same category of limitation as
/// biometric hardware or a real Supabase session; kawai_notes documented
/// the identical constraint for its own file-picker-based import). This
/// flow instead exercises what IS real and testable: the data summary
/// card, which reads real counts straight from the real ObjectBox store
/// via `BackupRepository.getDataSummary()` (already covered on the
/// business-logic side by `test/feature/backup/repositories`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  testWidgets('shows a zero-item summary when the database is empty', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    app.router.go('/backup');
    await tester.pumpAndSettle();

    expect(find.textContaining(LocaleKeys.backupScreenTotalItems.tr(namedArgs: {'count': '0'})), findsOneWidget);
  });

  testWidgets(
    'reflects a real seeded category in the data summary card',
    (tester) async {
      await app.categoryRepository
          .createCategory(
            const CreateCategoryParams(name: 'Groceries', type: CategoryType.expense),
          )
          .run();

      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();

      app.router.go('/backup');
      await tester.pumpAndSettle();

      expect(find.text(LocaleKeys.backupScreenCategories.tr()), findsOneWidget);
      expect(find.textContaining(LocaleKeys.backupScreenTotalItems.tr(namedArgs: {'count': '1'})), findsOneWidget);
    },
  );
}
