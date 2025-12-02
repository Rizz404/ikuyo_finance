import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Item model for searchable dropdown
class AppSearchableDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final String? imagePath;

  const AppSearchableDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.imagePath,
  });
}

/// * Searchable dropdown widget that opens a bottom sheet with search
/// * Ideal for large datasets (assets, categories, etc.)
class AppSearchableDropdown<T> extends StatefulWidget {
  final String name;
  final String label;
  final String? hintText;
  final String searchHintText;
  final T? initialValue;
  final String? initialDisplayText;
  final Widget? prefixIcon;
  final bool enabled;
  final String? Function(T?)? validator;

  /// * Callback to search items - receives query and returns filtered items
  final Future<List<AppSearchableDropdownItem<T>>> Function(String query)
  onSearch;

  /// * Callback when an item is selected
  final ValueChanged<T?>? onChanged;

  /// * Optional: Load initial items when bottom sheet opens
  final Future<List<AppSearchableDropdownItem<T>>> Function()? onLoadInitial;

  /// * Custom item builder for more control
  final Widget Function(
    BuildContext context,
    AppSearchableDropdownItem<T> item,
  )?
  itemBuilder;

  /// * Empty state message
  final String emptyMessage;

  /// * Debounce duration for search
  final Duration debounceDuration;

  const AppSearchableDropdown({
    super.key,
    required this.name,
    required this.label,
    required this.onSearch,
    this.hintText,
    this.searchHintText = 'Cari...',
    this.initialValue,
    this.initialDisplayText,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onLoadInitial,
    this.itemBuilder,
    this.emptyMessage = 'Tidak ada data',
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AppSearchableDropdown<T>> createState() =>
      _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>> {
  String? _displayText;
  T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _displayText = widget.initialDisplayText;
    _selectedValue = widget.initialValue;
  }

  void _openSearchSheet() {
    if (!widget.enabled) return;

    showModalBottomSheet<AppSearchableDropdownItem<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SearchableBottomSheet<T>(
        title: widget.label,
        searchHintText: widget.searchHintText,
        onSearch: widget.onSearch,
        onLoadInitial: widget.onLoadInitial,
        itemBuilder: widget.itemBuilder,
        emptyMessage: widget.emptyMessage,
        debounceDuration: widget.debounceDuration,
        selectedValue: _selectedValue,
      ),
    ).then((selected) {
      if (selected != null) {
        setState(() {
          _displayText = selected.label;
          _selectedValue = selected.value;
        });
        widget.onChanged?.call(selected.value);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _displayText = null;
      _selectedValue = null;
    });
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<T>(
      name: widget.name,
      initialValue: widget.initialValue,
      validator: widget.validator,
      builder: (field) {
        // * Sync field state with local state
        if (field.value != _selectedValue) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            field.didChange(_selectedValue);
          });
        }

        return GestureDetector(
          onTap: widget.enabled ? _openSearchSheet : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              hintText:
                  widget.hintText ?? 'Pilih ${widget.label.toLowerCase()}',
              hintStyle: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textTertiary,
              ),
              prefixIcon: widget.prefixIcon,
              suffixIcon: _buildSuffixIcon(),
              filled: true,
              fillColor: widget.enabled
                  ? context.colors.surface
                  : context.colors.disabled.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: field.hasError
                      ? context.semantic.error
                      : context.colors.border,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: field.hasError
                      ? context.semantic.error
                      : context.colors.border,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: field.hasError
                      ? context.semantic.error
                      : context.colors.primary,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.colors.disabled,
                  width: 1,
                ),
              ),
              errorText: field.errorText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            isEmpty: _displayText == null,
            child: _displayText != null
                ? AppText(
                    _displayText!,
                    style: AppTextStyle.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildSuffixIcon() {
    if (_displayText != null && widget.enabled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.clear, color: context.colors.textSecondary),
            onPressed: _clearSelection,
            tooltip: 'Hapus',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_drop_down, color: context.colors.textSecondary),
          const SizedBox(width: 8),
        ],
      );
    }
    return Icon(Icons.arrow_drop_down, color: context.colors.textSecondary);
  }
}

/// * Bottom sheet with search functionality
class _SearchableBottomSheet<T> extends StatefulWidget {
  final String title;
  final String searchHintText;
  final Future<List<AppSearchableDropdownItem<T>>> Function(String query)
  onSearch;
  final Future<List<AppSearchableDropdownItem<T>>> Function()? onLoadInitial;
  final Widget Function(
    BuildContext context,
    AppSearchableDropdownItem<T> item,
  )?
  itemBuilder;
  final String emptyMessage;
  final Duration debounceDuration;
  final T? selectedValue;

  const _SearchableBottomSheet({
    required this.title,
    required this.searchHintText,
    required this.onSearch,
    this.onLoadInitial,
    this.itemBuilder,
    required this.emptyMessage,
    required this.debounceDuration,
    this.selectedValue,
  });

  @override
  State<_SearchableBottomSheet<T>> createState() =>
      _SearchableBottomSheetState<T>();
}

class _SearchableBottomSheetState<T> extends State<_SearchableBottomSheet<T>> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<AppSearchableDropdownItem<T>> _items = [];
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final items = widget.onLoadInitial != null
          ? await widget.onLoadInitial!()
          : await widget.onSearch('');
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final items = await widget.onSearch(query);
        if (mounted) {
          setState(() {
            _items = items;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _items = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // * Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // * Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'Pilih ${widget.title}',
                        style: AppTextStyle.titleMedium,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // * Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: widget.searchHintText,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.colors.surfaceVariant,
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
              ),
              const SizedBox(height: 12),

              // * Items list
              Expanded(child: _buildContent(scrollController)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: context.colors.textTertiary,
            ),
            const SizedBox(height: 16),
            AppText(
              widget.emptyMessage,
              style: AppTextStyle.bodyMedium,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isSelected = widget.selectedValue == item.value;

        if (widget.itemBuilder != null) {
          return InkWell(
            onTap: () => Navigator.pop(context, item),
            borderRadius: BorderRadius.circular(12),
            child: widget.itemBuilder!(context, item),
          );
        }

        return _buildDefaultItem(item, isSelected);
      },
    );
  }

  Widget _buildDefaultItem(AppSearchableDropdownItem<T> item, bool isSelected) {
    return InkWell(
      onTap: () => Navigator.pop(context, item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: context.colors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            if (item.leading != null) ...[
              item.leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    item.label,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    AppText(
                      item.subtitle!,
                      style: AppTextStyle.bodySmall,
                      color: context.colors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.colors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
