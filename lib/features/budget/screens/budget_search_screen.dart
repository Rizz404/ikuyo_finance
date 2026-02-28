import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/widgets/budget_card.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Dedicated search screen for budgets
class BudgetSearchScreen extends StatefulWidget {
  const BudgetSearchScreen({super.key});

  @override
  State<BudgetSearchScreen> createState() => _BudgetSearchScreenState();
}

class _BudgetSearchScreenState extends State<BudgetSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // * Auto-focus on search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    context.read<BudgetBloc>().add(BudgetSearched(query: query));
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearch('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildSearchField(context),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch),
        ],
      ),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, state) {
          // * Show initial state
          if (state.currentSearchQuery == null ||
              state.currentSearchQuery!.isEmpty) {
            return _buildEmptySearchState(context);
          }

          // * Loading state
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // * No results
          if (state.budgets.isEmpty) {
            return _buildNoResultsState(context, state.currentSearchQuery!);
          }

          // * Results list
          return _buildSearchResults(context, state);
        },
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      onChanged: _onSearch,
      decoration: InputDecoration(
        hintText: LocaleKeys.budgetSearchHint.tr(),
        hintStyle: TextStyle(color: context.colorScheme.outline),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      style: context.textTheme.bodyLarge,
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: context.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.budgetSearchTitle.tr(),
              style: AppTextStyle.titleMedium,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              LocaleKeys.budgetSearchSubtitle.tr(),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: context.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.budgetSearchNoResults.tr(),
              style: AppTextStyle.titleMedium,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              LocaleKeys.budgetSearchNoResultsFor.tr(
                namedArgs: {'query': query},
              ),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, BudgetState state) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.budgets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final budget = state.budgets[index];
        return BudgetCard(budget: budget);
      },
    );
  }
}
