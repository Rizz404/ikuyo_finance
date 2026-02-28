import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/validators/create_budget_validator.dart';
import 'package:ikuyo_finance/features/budget/validators/update_budget_validator.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class BudgetUpsertScreen extends StatefulWidget {
  final Budget? budget;

  const BudgetUpsertScreen({super.key, this.budget});

  bool get isEdit => budget != null;

  @override
  State<BudgetUpsertScreen> createState() => _BudgetUpsertScreenState();
}

class _BudgetUpsertScreenState extends State<BudgetUpsertScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _selectedPeriod = widget.budget!.budgetPeriod;
    }
    // * Fetch categories for dropdown
    context.read<CategoryBloc>().add(
      const CategoryFetched(type: CategoryType.expense),
    );
  }

  void _handleWriteStatus(BuildContext context, BudgetState state) {
    if (state.writeStatus == BudgetWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title: state.writeSuccessMessage ?? LocaleKeys.budgetUpsertSuccess.tr(),
      );
      context.read<BudgetBloc>().add(const BudgetWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == BudgetWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title:
            state.writeErrorMessage ??
            LocaleKeys.budgetUpsertErrorOccurred.tr(),
      );
      context.read<BudgetBloc>().add(const BudgetWriteStatusReset());
    }
  }

  void _onSubmit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final categoryUlid = values['categoryUlid'] as String?;
      final amountLimitStr = values['amountLimit'] as String?;
      final amountLimit =
          double.tryParse(amountLimitStr?.replaceAll(',', '.') ?? '0') ?? 0;
      final period = BudgetPeriod.values[values['period'] as int];
      final startDate = values['startDate'] as DateTime?;
      final endDate = values['endDate'] as DateTime?;

      if (widget.isEdit) {
        context.read<BudgetBloc>().add(
          BudgetUpdated(
            params: UpdateBudgetParams(
              ulid: widget.budget!.ulid,
              categoryUlid: categoryUlid,
              amountLimit: amountLimit,
              period: period,
              startDate: startDate,
              endDate: endDate,
            ),
          ),
        );
      } else {
        if (categoryUlid == null) return;
        context.read<BudgetBloc>().add(
          BudgetCreated(
            params: CreateBudgetParams(
              categoryUlid: categoryUlid,
              amountLimit: amountLimit,
              period: period,
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
          LocaleKeys.budgetUpsertDeleteTitle.tr(),
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: AppText(
          LocaleKeys.budgetUpsertDeleteConfirm.tr(),
          style: AppTextStyle.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: AppText(
              LocaleKeys.budgetUpsertCancel.tr(),
              color: context.colorScheme.outline,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<BudgetBloc>().add(
                BudgetDeleted(ulid: widget.budget!.ulid),
              );
            },
            child: AppText(
              LocaleKeys.budgetUpsertDelete.tr(),
              color: context.semantic.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BudgetBloc, BudgetState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            widget.isEdit
                ? LocaleKeys.budgetUpsertEditTitle.tr()
                : LocaleKeys.budgetUpsertAddTitle.tr(),
            style: AppTextStyle.titleLarge,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ScreenWrapper(
          child: FormBuilder(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // * Category Dropdown
                  BlocBuilder<CategoryBloc, CategoryState>(
                    builder: (context, state) {
                      final categories = state.categories;
                      return AppDropdown<String>(
                        name: 'categoryUlid',
                        label: LocaleKeys.budgetUpsertCategoryLabel.tr(),
                        hintText: LocaleKeys.budgetUpsertCategoryHint.tr(),
                        initialValue: widget.budget?.category.target?.ulid,
                        prefixIcon: const Icon(Icons.category_outlined),
                        items: categories
                            .map(
                              (c) => AppDropdownItem(
                                value: c.ulid,
                                label: c.name,
                                icon: Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: c.color != null
                                      ? Color(
                                          int.parse(
                                            c.color!.replaceFirst('#', '0xFF'),
                                          ),
                                        )
                                      : context.colorScheme.primary,
                                ),
                              ),
                            )
                            .toList(),
                        validator: widget.isEdit
                            ? UpdateBudgetValidator.categoryUlid
                            : CreateBudgetValidator.categoryUlid,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // * Amount Limit Field
                  AppTextField(
                    name: 'amountLimit',
                    label: LocaleKeys.budgetUpsertAmountLimitLabel.tr(),
                    initialValue: widget.budget?.amountLimit.toStringAsFixed(0),
                    placeHolder: LocaleKeys.budgetUpsertAmountLimitPlaceholder
                        .tr(),
                    type: AppTextFieldType.number,
                    validator: widget.isEdit
                        ? UpdateBudgetValidator.amountLimit
                        : CreateBudgetValidator.amountLimit,
                    prefixIcon: const Icon(Icons.attach_money_outlined),
                  ),
                  const SizedBox(height: 24),

                  // * Period Dropdown
                  AppDropdown<int>(
                    name: 'period',
                    label: LocaleKeys.budgetUpsertPeriodLabel.tr(),
                    hintText: LocaleKeys.budgetUpsertPeriodHint.tr(),
                    initialValue:
                        widget.budget?.period ?? BudgetPeriod.monthly.index,
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPeriod = BudgetPeriod.values[value];
                        });
                      }
                    },
                    items: [
                      AppDropdownItem(
                        value: BudgetPeriod.monthly.index,
                        label: LocaleKeys.budgetUpsertPeriodMonthly.tr(),
                        icon: Icon(
                          Icons.calendar_view_month,
                          size: 20,
                          color: Colors.blue,
                        ),
                      ),
                      AppDropdownItem(
                        value: BudgetPeriod.weekly.index,
                        label: LocaleKeys.budgetUpsertPeriodWeekly.tr(),
                        icon: Icon(
                          Icons.calendar_view_week,
                          size: 20,
                          color: Colors.green,
                        ),
                      ),
                      AppDropdownItem(
                        value: BudgetPeriod.yearly.index,
                        label: LocaleKeys.budgetUpsertPeriodYearly.tr(),
                        icon: Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.purple,
                        ),
                      ),
                      AppDropdownItem(
                        value: BudgetPeriod.custom.index,
                        label: LocaleKeys.budgetUpsertPeriodCustom.tr(),
                        icon: Icon(
                          Icons.date_range,
                          size: 20,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                    validator: widget.isEdit
                        ? UpdateBudgetValidator.period
                        : CreateBudgetValidator.period,
                  ),
                  const SizedBox(height: 24),

                  // * Custom Date Range (only shown for custom period)
                  if (_selectedPeriod == BudgetPeriod.custom) ...[
                    AppDateTimePicker(
                      name: 'startDate',
                      label: LocaleKeys.budgetUpsertStartDateLabel.tr(),
                      initialValue: widget.budget?.startDate,
                      hintText: LocaleKeys.budgetUpsertStartDateHint.tr(),
                      inputType: InputType.date,
                      prefixIcon: const Icon(Icons.event_outlined),
                    ),
                    const SizedBox(height: 24),
                    AppDateTimePicker(
                      name: 'endDate',
                      label: LocaleKeys.budgetUpsertEndDateLabel.tr(),
                      initialValue: widget.budget?.endDate,
                      hintText: LocaleKeys.budgetUpsertEndDateHint.tr(),
                      inputType: InputType.date,
                      prefixIcon: const Icon(Icons.event_outlined),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 8),

                  // * Submit Button
                  BlocBuilder<BudgetBloc, BudgetState>(
                    buildWhen: (prev, curr) =>
                        prev.writeStatus != curr.writeStatus,
                    builder: (context, state) {
                      return AppButton(
                        text: widget.isEdit
                            ? LocaleKeys.budgetUpsertSaveChanges.tr()
                            : LocaleKeys.budgetUpsertAddBudget.tr(),
                        isLoading: state.isWriting,
                        onPressed: state.isWriting ? null : _onSubmit,
                        leadingIcon: Icon(
                          widget.isEdit ? Icons.save_outlined : Icons.add,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // * Delete Button (only for edit mode)
                  if (widget.isEdit) ...[
                    BlocBuilder<BudgetBloc, BudgetState>(
                      buildWhen: (prev, curr) =>
                          prev.writeStatus != curr.writeStatus,
                      builder: (context, state) {
                        return AppButton(
                          text: LocaleKeys.budgetUpsertDeleteBudget.tr(),
                          variant: AppButtonVariant.outlined,
                          color: AppButtonColor.error,
                          isLoading: state.isWriting,
                          onPressed: state.isWriting ? null : _onDelete,
                          leadingIcon: const Icon(Icons.delete_outline),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
