import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';

class AutoTransactionAlarmService {
  Future<void> initialize() async {}
  Future<void> initializeForBackground() async {}
  Future<void> requestExactAlarmPermission() async {}
  Future<bool> canScheduleExactAlarms() async => false;
  Future<void> scheduleForGroup(AutoTransactionGroup group) async {}
  Future<void> cancelForGroup(AutoTransactionGroup group) async {}
  Future<void> cancelById(int groupId) async {}
  Future<void> scheduleAlarmsForAllGroups(List<AutoTransactionGroup> groups) async {}
  Future<void> cancelAll(List<AutoTransactionGroup> groups) async {}
}
