import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree against an ephemeral
/// ObjectBox store. The group creation form is deliberately NOT driven
/// through the UI here: it has a required native date/time picker
/// (`startDate` has no default for a new group) plus an optional inline
/// "attach a first transaction" searchable dropdown, both of which are
/// fragile to script blindly. Instead this flow seeds a group directly via
/// the real repository (mirroring `AutoTransactionBloc`'s own real-repo
/// unit tests) and exercises what the LIST screen can do on its own: real
/// rendering and the active/inactive [Switch] toggle, which — per
/// `AutoTransactionBloc` — should also call through to the (mocked, since
/// it's an Android AlarmManager side effect) [MockAutoTransactionAlarmService].
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  Future<void> goToAutoTransactionScreen(WidgetTester tester) async {
    // * The "Auto Transaction" card on the Others menu turned out fragile to
    // * drive (its text/widget matched ambiguously and/or sat below the
    // * fold depending on scroll state) — navigate directly via the router
    // * instead, same as the budget flow does for its own screen.
    app.router.go('/auto-transaction');
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there is no data', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await goToAutoTransactionScreen(tester);

    expect(find.text('No auto transaction groups'), findsOneWidget);
  });

  testWidgets(
    'renders a real seeded group and toggling its switch flips isActive in ObjectBox',
    (tester) async {
      final group = (await app.autoTransactionRepository
              .createGroup(
                CreateAutoGroupParams(
                  name: 'Monthly Rent',
                  frequency: AutoScheduleFrequency.monthly,
                  scheduleHour: 8,
                  scheduleMinute: 0,
                  dayOfMonth: 1,
                  startDate: DateTime.now(),
                ),
              )
              .run())
          .fold((_) => throw Exception('setup failed'), (s) => s.data!);
      expect(group.isActive, isTrue);

      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await goToAutoTransactionScreen(tester);

      expect(find.text('Monthly Rent'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final updated = (await app.autoTransactionRepository
              .getGroupByUlid(ulid: group.ulid)
              .run())
          .fold((_) => throw Exception('lookup failed'), (s) => s.data!);
      expect(updated.isActive, isFalse);
      verify(() => app.alarmService.cancelById(group.id)).called(1);
    },
  );
}
