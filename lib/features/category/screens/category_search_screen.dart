import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/widgets/category_card.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Dedicated search screen for categories
class CategorySearchScreen extends StatefulWidget {
  const CategorySearchScreen({super.key});

  @override
  State<CategorySearchScreen> createState() => _CategorySearchScreenState();
}

class _CategorySearchScreenState extends State<CategorySearchScreen> {
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
    context.read<CategoryBloc>().add(CategorySearched(query: query));
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
      body: BlocBuilder<CategoryBloc, CategoryState>(
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
          if (state.categories.isEmpty) {
            return _buildNoResultsState(context, state.currentSearchQuery!);
          }

          // * Results grid
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
        hintText: 'Cari kategori...',
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
              'Cari Kategori',
              style: AppTextStyle.titleMedium,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              'Ketik untuk mencari berdasarkan nama kategori',
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
              'Tidak ditemukan kategori dengan "$query"',
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, CategoryState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: state.categories.length,
      itemBuilder: (context, index) {
        final category = state.categories[index];
        return CategoryCard(category: category);
      },
    );
  }
}
