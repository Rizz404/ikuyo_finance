import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_group_validator.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_item_validator.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/pause_form_section.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/schedule_form_section.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_searchable_dropdown.dart';
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
  bool _syncWithItem = false;
  bool _isSingleMode = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isEdit) {
      context.read<TransactionBloc>().add(
        TransactionFetched(startDate: DateTime(2000), endDate: DateTime(2099)),
      );
    }
  }

  static List<int> _maskToDays(int mask) {
    if (mask == 0) return [];
    return [
      for (int i = 0; i < 7; i++)
        if ((mask >> i) & 1 == 1) i + 1,
    ];
  }

  static int _daysToMask(List<int> days) {
    if (days.isEmpty) return 0;
    return days.fold(0, (acc, d) => acc | (1 << (d - 1)));
  }

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
    final activeDaysRaw = values['activeDays'] as List<int>? ?? [];
    final activeDaysMask = _daysToMask(activeDaysRaw);
    final intervalDaysStr = values['intervalDays'] as String?;
    final intervalDays = int.tryParse(intervalDaysStr?.trim() ?? '') ?? 1;
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
            intervalDays: intervalDays,
            activeDaysMask: activeDaysMask,
            startDate: startDate,
            endDate: () => endDate,
          ),
        ),
      );
    } else {
      if (startDate == null) return;

      if (_isSingleMode) {
        final txUlid = values['transactionUlid'] as String?;
        if (txUlid == null) return;

        final txState = context.read<TransactionBloc>().state;
        String txName = '';
        for (final t in txState.transactions) {
          if (t.ulid == txUlid) {
            txName = t.description?.trim() ?? '';
            break;
          }
        }
        final customName = (values['name'] as String?)?.trim();
        context.read<AutoTransactionBloc>().add(
          AutoGroupWithItemCreated(
            groupParams: CreateAutoGroupParams(
              name: customName?.isNotEmpty == true
                  ? customName!
                  : (txName.isNotEmpty ? txName : '—'),
              description: values['description'] as String?,
              frequency: frequency,
              scheduleHour: scheduleHour,
              scheduleMinute: scheduleMinute,
              dayOfWeek: dayOfWeek,
              dayOfMonth: dayOfMonth,
              monthOfYear: monthOfYear,
              intervalDays: intervalDays,
              activeDaysMask: activeDaysMask,
              startDate: startDate,
              endDate: endDate,
            ),
            transactionUlid: txUlid,
          ),
        );
      } else {
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
              intervalDays: intervalDays,
              activeDaysMask: activeDaysMask,
              startDate: startDate,
              endDate: endDate,
            ),
          ),
        );
      }
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
                      if (!widget.isEdit) ...[
                        _buildSingleModeToggle(),
                        const SizedBox(height: 16),
                      ],
                      AppTextField(
                        name: 'name',
                        label: LocaleKeys.autoTransactionGroupUpsertNameLabel
                            .tr(),
                        placeHolder: _isSingleMode && !widget.isEdit
                            ? LocaleKeys
                                  .autoTransactionGroupUpsertSingleItemNameHint
                                  .tr()
                            : LocaleKeys.autoTransactionGroupUpsertNameHint
                                  .tr(),
                        initialValue: group?.name,
                        prefixIcon: const Icon(Icons.group_outlined),
                        validator: (_isSingleMode && !widget.isEdit)
                            ? null
                            : CreateAutoGroupValidator.name,
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
                      if (widget.isEdit && (group?.items.length ?? 0) == 1) ...[
                        const SizedBox(height: 8),
                        _buildSyncToggle(group!),
                      ],
                      if (_isSingleMode && !widget.isEdit) ...[
                        const SizedBox(height: 16),
                        BlocBuilder<TransactionBloc, TransactionState>(
                          builder: (_, txState) =>
                              _buildTransactionSection(txState),
                        ),
                      ],
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
                        initialActiveDays: group != null
                            ? _maskToDays(group.activeDaysMask)
                            : const [],
                        initialIntervalDays: group?.intervalDays,
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

  Widget _buildSingleModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _isSingleMode
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSingleMode
              ? context.colorScheme.primary.withValues(alpha: 0.35)
              : context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: SwitchListTile(
        value: _isSingleMode,
        onChanged: (val) => setState(() {
          _isSingleMode = val;
          if (!val) {
            _formKey.currentState?.fields['transactionUlid']?.reset();
          }
        }),
        title: AppText(
          LocaleKeys.autoTransactionGroupUpsertSingleItemModeLabel.tr(),
          style: AppTextStyle.bodyMedium,
          fontWeight: FontWeight.w500,
        ),
        subtitle: AppText(
          LocaleKeys.autoTransactionGroupUpsertSingleItemModeHint.tr(),
          style: AppTextStyle.bodySmall,
          color: context.colorScheme.outline,
        ),
        secondary: Icon(
          Icons.looks_one_outlined,
          color: _isSingleMode
              ? context.colorScheme.primary
              : context.colorScheme.outline,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTransactionSection(TransactionState txState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchableDropdown<Transaction>(
          name: 'transactionUlid',
          label: LocaleKeys.autoTransactionItemUpsertTransactionLabel.tr(),
          hintText: LocaleKeys.autoTransactionItemUpsertTransactionHint.tr(),
          items: txState.transactions,
          isLoading: txState.status == TransactionStatus.loading,
          isLoadingMore: txState.status == TransactionStatus.loadingMore,
          hasMore: !txState.hasReachedMax,
          onSearch: (query) => context.read<TransactionBloc>().add(
            TransactionSearched(query: query),
          ),
          onLoadMore: () => context.read<TransactionBloc>().add(
            const TransactionFetchedMore(),
          ),
          itemDisplayMapper: (tx) => tx.description ?? 'Unnamed',
          itemValueMapper: (tx) => tx.ulid,
          itemSubtitleMapper: (tx) {
            final date = tx.transactionDate != null
                ? DateFormat('dd MMM yyyy').format(tx.transactionDate!)
                : null;
            final cat = tx.category.target?.name;
            final parts = [cat, date].whereType<String>().toList();
            return parts.isEmpty ? null : parts.join(' · ');
          },
          validator: (value) => CreateAutoItemValidator.transactionUlid(value),
          prefixIcon: const Icon(Icons.receipt_outlined),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _onCreateNewTransaction,
            icon: const Icon(Icons.add, size: 16),
            label: AppText(
              LocaleKeys.autoTransactionItemUpsertCreateNewTransaction.tr(),
              style: AppTextStyle.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onCreateNewTransaction() async {
    await context.pushToAddTransaction();
    if (!mounted) return;
    context.read<TransactionBloc>().add(
      TransactionFetched(startDate: DateTime(2000), endDate: DateTime(2099)),
    );
  }

  Widget _buildSyncToggle(AutoTransactionGroup group) {
    final singleItem = group.items.first;
    final txName = singleItem.transaction.target?.description ?? '';

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: SwitchListTile(
        value: _syncWithItem,
        onChanged: (val) {
          setState(() => _syncWithItem = val);
          if (val) {
            _formKey.currentState?.fields['name']?.didChange(txName);
            _formKey.currentState?.fields['description']?.didChange(null);
          }
        },
        title: AppText(
          LocaleKeys.autoTransactionGroupUpsertSyncWithItemLabel.tr(),
          style: AppTextStyle.bodyMedium,
          fontWeight: FontWeight.w500,
        ),
        subtitle: AppText(
          LocaleKeys.autoTransactionGroupUpsertSyncWithItemHint.tr(),
          style: AppTextStyle.bodySmall,
          color: context.colorScheme.outline,
        ),
        secondary: Icon(
          Icons.link,
          color: _syncWithItem
              ? context.colorScheme.primary
              : context.colorScheme.outline,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
