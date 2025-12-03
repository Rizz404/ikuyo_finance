import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/widgets/asset_card.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Dedicated search screen for assets
class AssetSearchScreen extends StatefulWidget {
  const AssetSearchScreen({super.key});

  @override
  State<AssetSearchScreen> createState() => _AssetSearchScreenState();
}

class _AssetSearchScreenState extends State<AssetSearchScreen> {
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
    context.read<AssetBloc>().add(AssetSearched(query: query));
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
      body: BlocBuilder<AssetBloc, AssetState>(
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
          if (state.assets.isEmpty) {
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
        hintText: 'Cari aset...',
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
              'Cari Aset',
              style: AppTextStyle.titleMedium,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              'Ketik untuk mencari berdasarkan nama aset',
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
              'Tidak ditemukan aset dengan "$query"',
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, AssetState state) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: state.assets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final asset = state.assets[index];
        return AssetCard(asset: asset);
      },
    );
  }
}
