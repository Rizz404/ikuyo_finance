import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_group_validator.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/app_time_picker.dart';

class ScheduleFormSection extends StatefulWidget {
  final AutoScheduleFrequency initialFrequency;
  final TimeOfDay initialTime;
  final int? initialDayOfWeek;
  final int? initialDayOfMonth;
  final int? initialMonthOfYear;
  final ValueChanged<AutoScheduleFrequency>? onFrequencyChanged;

  const ScheduleFormSection({
    super.key,
    this.initialFrequency = AutoScheduleFrequency.daily,
    this.initialTime = const TimeOfDay(hour: 8, minute: 0),
    this.initialDayOfWeek,
    this.initialDayOfMonth,
    this.initialMonthOfYear,
    this.onFrequencyChanged,
  });

  @override
  State<ScheduleFormSection> createState() => _ScheduleFormSectionState();
}

class _ScheduleFormSectionState extends State<ScheduleFormSection> {
  late AutoScheduleFrequency _frequency;

  static const _weekDays = [
    (value: 1, label: 'Mon'),
    (value: 2, label: 'Tue'),
    (value: 3, label: 'Wed'),
    (value: 4, label: 'Thu'),
    (value: 5, label: 'Fri'),
    (value: 6, label: 'Sat'),
    (value: 7, label: 'Sun'),
  ];

  static const _months = [
    (value: 1, label: 'Jan'),
    (value: 2, label: 'Feb'),
    (value: 3, label: 'Mar'),
    (value: 4, label: 'Apr'),
    (value: 5, label: 'May'),
    (value: 6, label: 'Jun'),
    (value: 7, label: 'Jul'),
    (value: 8, label: 'Aug'),
    (value: 9, label: 'Sep'),
    (value: 10, label: 'Oct'),
    (value: 11, label: 'Nov'),
    (value: 12, label: 'Dec'),
  ];

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialFrequency;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<int>(
          name: 'frequency',
          label: LocaleKeys.autoTransactionGroupUpsertFrequencyLabel.tr(),
          initialValue: _frequency.index,
          validator: CreateAutoGroupValidator.frequency,
          prefixIcon: const Icon(Icons.repeat),
          items: AutoScheduleFrequency.values
              .map(
                (f) =>
                    AppDropdownItem(value: f.index, label: _frequencyLabel(f)),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              final newFreq = AutoScheduleFrequency.values[val];
              setState(() => _frequency = newFreq);
              widget.onFrequencyChanged?.call(newFreq);
            }
          },
        ),
        const SizedBox(height: 16),
        AppTimePicker(
          name: 'scheduleTime',
          label: LocaleKeys.autoTransactionGroupUpsertScheduleTimeLabel.tr(),
          initialValue: widget.initialTime,
        ),
        if (_frequency == AutoScheduleFrequency.weekly) ...[
          const SizedBox(height: 16),
          FormBuilderField<int>(
            name: 'dayOfWeek',
            initialValue: widget.initialDayOfWeek,
            validator: (v) => CreateAutoGroupValidator.dayOfWeek(v, _frequency),
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.autoTransactionGroupUpsertDayOfWeekLabel.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _weekDays
                      .map(
                        (day) => ChoiceChip(
                          label: Text(day.label),
                          selected: field.value == day.value,
                          onSelected: (_) => field.didChange(day.value),
                        ),
                      )
                      .toList(),
                ),
                if (field.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      field.errorText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_frequency == AutoScheduleFrequency.monthly ||
            _frequency == AutoScheduleFrequency.yearly) ...[
          const SizedBox(height: 16),
          AppTextField(
            name: 'dayOfMonth',
            label: LocaleKeys.autoTransactionGroupUpsertDayOfMonthLabel.tr(),
            placeHolder: LocaleKeys.autoTransactionGroupUpsertDayOfMonthHint
                .tr(),
            initialValue: widget.initialDayOfMonth?.toString(),
            type: AppTextFieldType.number,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            validator: FormBuilderValidators.compose([
              (v) => CreateAutoGroupValidator.dayOfMonth(v, _frequency),
            ]),
          ),
        ],
        if (_frequency == AutoScheduleFrequency.yearly) ...[
          const SizedBox(height: 16),
          AppDropdown<int>(
            name: 'monthOfYear',
            label: LocaleKeys.autoTransactionGroupUpsertMonthOfYearLabel.tr(),
            initialValue: widget.initialMonthOfYear,
            validator: (v) =>
                CreateAutoGroupValidator.monthOfYear(v, _frequency),
            prefixIcon: const Icon(Icons.date_range_outlined),
            items: _months
                .map((m) => AppDropdownItem(value: m.value, label: m.label))
                .toList(),
          ),
        ],
      ],
    );
  }

  String _frequencyLabel(AutoScheduleFrequency f) => switch (f) {
    AutoScheduleFrequency.daily =>
      LocaleKeys.autoTransactionFrequencyDaily.tr(),
    AutoScheduleFrequency.weekly =>
      LocaleKeys.autoTransactionFrequencyWeekly.tr(),
    AutoScheduleFrequency.monthly =>
      LocaleKeys.autoTransactionFrequencyMonthly.tr(),
    AutoScheduleFrequency.yearly =>
      LocaleKeys.autoTransactionFrequencyYearly.tr(),
  };
}
