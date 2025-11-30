import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Dedicated search screen for transactions
class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  State<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
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
    context.read<TransactionBloc>().add(TransactionSearched(query: query));
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
      body: BlocBuilder<TransactionBloc, TransactionState>(
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
          if (state.transactions.isEmpty) {
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
        hintText: 'Cari transaksi...',
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
              'Cari Transaksi',
              style: AppTextStyle.titleMedium,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              'Ketik untuk mencari berdasarkan deskripsi transaksi',
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
              'Tidak ada hasil',
              style: AppTextStyle.titleMedium,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              'Tidak ditemukan transaksi dengan "$query"',
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, TransactionState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.transactions.length,
      itemBuilder: (context, index) {
        final transaction = state.transactions[index];
        return TransactionTile(transaction: transaction);
      },
    );
  }
}
