import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_group_validator.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/pause_form_section.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/schedule_form_section.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AutoTransactionGroupUpsertScreen extends StatefulWidget {
  final AutoTransactionGroup? group;

  const AutoTransactionGroupUpsertScreen({super.key, this.group});

  bool get isEdit => group != null;

  @override
  State<AutoTransactionGroupUpsertScreen> createState() =>
      _AutoTransactionGroupUpsertScreenState();
}

class _AutoTransactionGroupUpsertScreenState
    extends State<AutoTransactionGroupUpsertScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  void _handleWriteStatus(BuildContext context, AutoTransactionState state) {
    if (state.writeStatus == AutoTransactionWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title:
            state.writeSuccessMessage ??
            LocaleKeys.autoTransactionGroupUpsertUpsertSuccess.tr(),
      );
      context.read<AutoTransactionBloc>().add(const AutoWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == AutoTransactionWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title:
            state.writeErrorMessage ??
            LocaleKeys.autoTransactionGroupUpsertUpsertError.tr(),
      );
      context.read<AutoTransactionBloc>().add(const AutoWriteStatusReset());
    }
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final values = _formKey.currentState!.value;
    final frequencyIndex = values['frequency'] as int?;
    final frequency = frequencyIndex != null
        ? AutoScheduleFrequency.values[frequencyIndex]
        : AutoScheduleFrequency.daily;

    final scheduleTime = values['scheduleTime'] as TimeOfDay?;
    final scheduleHour = scheduleTime?.hour ?? 8;
    final scheduleMinute = scheduleTime?.minute ?? 0;

    final dayOfWeek = values['dayOfWeek'] as int?;
    final dayOfMonthStr = values['dayOfMonth'] as String?;
    final dayOfMonth = dayOfMonthStr != null
        ? int.tryParse(dayOfMonthStr.trim())
        : null;
    final monthOfYear = values['monthOfYear'] as int?;
    final startDate = values['startDate'] as DateTime?;
    final endDate = values['endDate'] as DateTime?;

    if (widget.isEdit) {
      context.read<AutoTransactionBloc>().add(
        AutoGroupUpdated(
          params: UpdateAutoGroupParams(
            ulid: widget.group!.ulid,
            name: values['name'] as String?,
            description: () => values['description'] as String?,
            frequency: frequency,
            scheduleHour: scheduleHour,
            scheduleMinute: scheduleMinute,
            dayOfWeek: () => dayOfWeek,
            dayOfMonth: () => dayOfMonth,
            monthOfYear: () => monthOfYear,
            startDate: startDate,
            endDate: () => endDate,
          ),
        ),
      );
    } else {
      if (startDate == null) return;
      context.read<AutoTransactionBloc>().add(
        AutoGroupCreated(
          params: CreateAutoGroupParams(
            name: (values['name'] as String).trim(),
            description: values['description'] as String?,
            frequency: frequency,
            scheduleHour: scheduleHour,
            scheduleMinute: scheduleMinute,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth,
            monthOfYear: monthOfYear,
            startDate: startDate,
            endDate: endDate,
          ),
        ),
      );
    }
  }

  void _onDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(
          LocaleKeys.autoTransactionGroupUpsertDeleteTitle.tr(),
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: AppText(
          LocaleKeys.autoTransactionGroupUpsertDeleteConfirm.tr(),
          style: AppTextStyle.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: AppText(
              LocaleKeys.autoTransactionGroupUpsertCancel.tr(),
              color: context.colorScheme.outline,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AutoTransactionBloc>().add(
                AutoGroupDeleted(ulid: widget.group!.ulid),
              );
            },
            child: AppText(
              LocaleKeys.autoTransactionGroupUpsertDelete.tr(),
              color: context.semantic.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _onPause() {
    final pauseKey = GlobalKey<FormBuilderState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(
          LocaleKeys.autoTransactionGroupUpsertPauseTitle.tr(),
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: FormBuilder(
          key: pauseKey,
          child: PauseFormSection(
            initialManual: widget.group?.pauseEndAt == null,
            initialPauseUntil: widget.group?.pauseEndAt,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: AppText(LocaleKeys.autoTransactionGroupUpsertCancel.tr()),
          ),
          TextButton(
            onPressed: () {
              pauseKey.currentState?.saveAndValidate();
              final pauseUntil =
                  pauseKey.currentState?.value['pauseUntil'] as DateTime?;
              Navigator.of(ctx).pop();
              context.read<AutoTransactionBloc>().add(
                AutoGroupPaused(
                  ulid: widget.group!.ulid,
                  pauseStartAt: DateTime.now(),
                  resumeAt: pauseUntil,
                ),
              );
            },
            child: AppText(
              LocaleKeys.autoTransactionGroupUpsertPauseButton.tr(),
              color: context.semantic.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return BlocListener<AutoTransactionBloc, AutoTransactionState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            widget.isEdit
                ? LocaleKeys.autoTransactionGroupUpsertEditTitle.tr()
                : LocaleKeys.autoTransactionGroupUpsertAddTitle.tr(),
            style: AppTextStyle.titleLarge,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (widget.isEdit) ...[
              if (group!.isCurrentlyPaused())
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: LocaleKeys.autoTransactionGroupUpsertResumeButton
                      .tr(),
                  onPressed: () => context.read<AutoTransactionBloc>().add(
                    AutoGroupResumed(ulid: group.ulid),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.pause),
                  tooltip: LocaleKeys.autoTransactionGroupUpsertPauseButton
                      .tr(),
                  onPressed: _onPause,
                ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: context.semantic.error),
                onPressed: _onDelete,
              ),
            ],
          ],
        ),
        body: BlocBuilder<AutoTransactionBloc, AutoTransactionState>(
          buildWhen: (prev, curr) => prev.isWriting != curr.isWriting,
          builder: (context, state) {
            return ScreenWrapper(
              child: FormBuilder(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        name: 'name',
                        label: LocaleKeys.autoTransactionGroupUpsertNameLabel
                            .tr(),
                        placeHolder: LocaleKeys
                            .autoTransactionGroupUpsertNameHint
                            .tr(),
                        initialValue: group?.name,
                        prefixIcon: const Icon(Icons.group_outlined),
                        validator: CreateAutoGroupValidator.name,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        name: 'description',
                        label: LocaleKeys
                            .autoTransactionGroupUpsertDescriptionLabel
                            .tr(),
                        placeHolder: LocaleKeys
                            .autoTransactionGroupUpsertDescriptionHint
                            .tr(),
                        initialValue: group?.description,
                        prefixIcon: const Icon(Icons.notes_outlined),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      ScheduleFormSection(
                        initialFrequency:
                            group?.scheduleFrequency ??
                            AutoScheduleFrequency.daily,
                        initialTime: TimeOfDay(
                          hour: group?.scheduleHour ?? 8,
                          minute: group?.scheduleMinute ?? 0,
                        ),
                        initialDayOfWeek: group?.dayOfWeek,
                        initialDayOfMonth: group?.dayOfMonth,
                        initialMonthOfYear: group?.monthOfYear,
                      ),
                      const SizedBox(height: 16),
                      AppDateTimePicker(
                        name: 'startDate',
                        label: LocaleKeys
                            .autoTransactionGroupUpsertStartDateLabel
                            .tr(),
                        initialValue: group?.startDate,
                        inputType: InputType.date,
                        prefixIcon: const Icon(Icons.event_outlined),
                        validator: CreateAutoGroupValidator.startDate,
                      ),
                      const SizedBox(height: 16),
                      AppDateTimePicker(
                        name: 'endDate',
                        label: LocaleKeys.autoTransactionGroupUpsertEndDateLabel
                            .tr(),
                        initialValue: group?.endDate,
                        inputType: InputType.date,
                        prefixIcon: const Icon(Icons.event_available_outlined),
                        validator: CreateAutoGroupValidator.endDate,
                      ),
                      const SizedBox(height: 32),
                      AppButton(
                        text: LocaleKeys.autoTransactionGroupUpsertSave.tr(),
                        isLoading: state.isWriting,
                        onPressed: _onSubmit,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
