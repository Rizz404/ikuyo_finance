import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Reusable batch delete modal sheet with search and multi-select.
///
/// [T] is the item type.
/// [getId] extracts a unique string ID from each item.
/// [searchStringOf] extracts the searchable string for filtering.
/// [itemBuilder] builds the item widget; receives [item], [isSelected], and [onToggle].
/// [onDelete] is called with selected items after user confirms.
class AppBatchDeleteDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T item) getId;
  final String Function(T item) searchStringOf;
  final Widget Function(T item, bool isSelected, VoidCallback onToggle)
  itemBuilder;
  final void Function(List<T> selected) onDelete;
  final String? searchHint;
  final String? initialSelectedId;

  const AppBatchDeleteDialog({
    super.key,
    required this.title,
    required this.items,
    required this.getId,
    required this.searchStringOf,
    required this.itemBuilder,
    required this.onDelete,
    this.searchHint,
    this.initialSelectedId,
  });

  static Future<void> show<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T item) getId,
    required String Function(T item) searchStringOf,
    required Widget Function(T item, bool isSelected, VoidCallback onToggle)
    itemBuilder,
    required void Function(List<T> selected) onDelete,
    String? searchHint,
    String? initialSelectedId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBatchDeleteDialog<T>(
        title: title,
        items: items,
        getId: getId,
        searchStringOf: searchStringOf,
        itemBuilder: itemBuilder,
        onDelete: onDelete,
        searchHint: searchHint,
        initialSelectedId: initialSelectedId,
      ),
    );
  }

  @override
  State<AppBatchDeleteDialog<T>> createState() =>
      _AppBatchDeleteDialogState<T>();
}

class _AppBatchDeleteDialogState<T> extends State<AppBatchDeleteDialog<T>> {
  late List<T> _filtered;
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
    if (widget.initialSelectedId != null) {
      _selectedIds.add(widget.initialSelectedId!);
    }
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = widget.items
          .where(
            (item) => widget.searchStringOf(item).toLowerCase().contains(query),
          )
          .toList();
    });
  }

  void _toggle(T item) {
    setState(() {
      final id = widget.getId(item);
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      final allFilteredIds = _filtered.map(widget.getId).toSet();
      if (_selectedIds.containsAll(allFilteredIds)) {
        _selectedIds.removeAll(allFilteredIds);
      } else {
        _selectedIds.addAll(allFilteredIds);
      }
    });
  }

  List<T> get _selectedItems => widget.items
      .where((item) => _selectedIds.contains(widget.getId(item)))
      .toList();

  bool get _allFilteredSelected {
    if (_filtered.isEmpty) return false;
    return _filtered.every((item) => _selectedIds.contains(widget.getId(item)));
  }

  Future<void> _confirmDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('$count item akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus',
              style: TextStyle(color: ctx.colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onDelete(_selectedItems);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // * 92% tinggi layar — background tetap terlihat ~8% di atas
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHandle(context),
          _buildHeader(context),
          _buildSearchField(context),
          Expanded(child: _buildList(context)),
          if (_selectedIds.isNotEmpty) _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: AppText(
              widget.title,
              style: AppTextStyle.titleMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            tooltip: _allFilteredSelected ? 'Batal pilih semua' : 'Pilih semua',
            icon: Icon(
              _allFilteredSelected ? Icons.deselect : Icons.select_all,
            ),
            onPressed: _toggleAll,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: widget.searchHint ?? 'Cari...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: context.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_filtered.isEmpty) {
      return Center(
        child: AppText(
          _searchController.text.isEmpty ? 'Tidak ada item' : 'Tidak ada hasil',
          style: AppTextStyle.bodyMedium,
          color: context.colorScheme.outline,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = _filtered[i];
        final id = widget.getId(item);
        final isSelected = _selectedIds.contains(id);

        return Stack(
          children: [
            widget.itemBuilder(item, isSelected, () => _toggle(item)),
            // * Selection color overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            // * Checkmark indicator (top-right)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    key: ValueKey(isSelected),
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: AppButton(
          text: 'Hapus ${_selectedIds.length} item',
          color: AppButtonColor.error,
          onPressed: _confirmDelete,
        ),
      ),
    );
  }
}
