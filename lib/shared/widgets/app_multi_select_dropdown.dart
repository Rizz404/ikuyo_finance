import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Multi-select dropdown widget that opens a bottom sheet with search
/// * Allows selecting multiple items from a list
class AppMultiSelectDropdown<T> extends StatefulWidget {
  final String name;
  final String label;
  final String? hintText;
  final String? searchHintText;
  final List<T>? initialValue;
  final Widget? prefixIcon;
  final bool enabled;
  final String? Function(List<T>?)? validator;

  /// * Callback to search items - receives query and returns filtered items
  final Future<List<T>> Function(String query) onSearch;

  /// * Item configuration
  final String Function(T item) itemDisplayMapper;
  final String Function(T item) itemValueMapper;
  final String? Function(T item)? itemSubtitleMapper;
  final Widget? Function(T item)? itemLeadingMapper;

  /// * Callback when items are selected
  final ValueChanged<List<T>>? onChanged;

  /// * Optional: Load initial items when bottom sheet opens
  final Future<List<T>> Function()? onLoadInitial;

  /// * Custom item builder for more control
  final Widget Function(BuildContext context, T item, bool isSelected)?
  itemBuilder;

  /// * Custom chip builder for selected items
  final Widget Function(BuildContext context, T item)? chipBuilder;

  /// * Empty state message
  final String? emptyMessage;

  /// * Debounce duration for search
  final Duration debounceDuration;

  /// * Max items that can be selected (null = unlimited)
  final int? maxItems;

  const AppMultiSelectDropdown({
    super.key,
    required this.name,
    required this.label,
    required this.onSearch,
    required this.itemDisplayMapper,
    required this.itemValueMapper,
    this.itemSubtitleMapper,
    this.itemLeadingMapper,
    this.hintText,
    this.searchHintText,
    this.initialValue,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onLoadInitial,
    this.itemBuilder,
    this.chipBuilder,
    this.emptyMessage,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.maxItems,
  });

  @override
  State<AppMultiSelectDropdown<T>> createState() =>
      _AppMultiSelectDropdownState<T>();
}

class _AppMultiSelectDropdownState<T> extends State<AppMultiSelectDropdown<T>> {
  List<T> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _selectedItems = List.from(widget.initialValue!);
    }
  }

  void _openSearchSheet() {
    if (!widget.enabled) return;

    showModalBottomSheet<List<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _MultiSelectBottomSheet<T>(
        title: widget.label,
        searchHintText:
            widget.searchHintText ??
            LocaleKeys.sharedWidgetsMultiSelectDropdownSearchHint.tr(),
        onSearch: widget.onSearch,
        itemDisplayMapper: widget.itemDisplayMapper,
        itemValueMapper: widget.itemValueMapper,
        itemSubtitleMapper: widget.itemSubtitleMapper,
        itemLeadingMapper: widget.itemLeadingMapper,
        onLoadInitial: widget.onLoadInitial,
        itemBuilder: widget.itemBuilder,
        emptyMessage:
            widget.emptyMessage ??
            LocaleKeys.sharedWidgetsMultiSelectDropdownNoData.tr(),
        debounceDuration: widget.debounceDuration,
        selectedItems: _selectedItems,
        maxItems: widget.maxItems,
      ),
    ).then((selected) {
      if (selected != null) {
        setState(() {
          _selectedItems = selected;
        });
        widget.onChanged?.call(selected);
      }

      // * Unfocus agar focus tidak jump ke field lain setelah bottom sheet ditutup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  void _removeItem(T item) {
    setState(() {
      _selectedItems.removeWhere(
        (e) => widget.itemValueMapper(e) == widget.itemValueMapper(item),
      );
    });
    widget.onChanged?.call(_selectedItems);
  }

  void _clearAll() {
    setState(() {
      _selectedItems.clear();
    });
    widget.onChanged?.call([]);
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<List<T>>(
      name: widget.name,
      initialValue: widget.initialValue,
      validator: widget.validator,
      builder: (field) {
        // * Sync field state with local state
        final currentValues = _selectedItems;
        if (!_listEquals(field.value, currentValues)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            field.didChange(currentValues);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // * Main selector button
            GestureDetector(
              onTap: widget.enabled ? _openSearchSheet : null,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText:
                      widget.hintText ??
                      LocaleKeys.sharedWidgetsMultiSelectDropdownSelectHint.tr(
                        namedArgs: {'label': widget.label.toLowerCase()},
                      ),
                  hintStyle: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: _buildSuffixIcon(),
                  filled: true,
                  fillColor: widget.enabled
                      ? context.colors.surfaceVariant.withValues(alpha: 0.3)
                      : context.colors.disabled.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.primary,
                      width: 2,
                    ),
                  ),
                  errorText: field.errorText,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                isEmpty: _selectedItems.isEmpty,
                child: _selectedItems.isNotEmpty
                    ? AppText(
                        LocaleKeys.sharedWidgetsMultiSelectDropdownItemsSelected
                            .tr(
                              namedArgs: {
                                'count': _selectedItems.length.toString(),
                              },
                            ),
                        color: context.colors.textPrimary,
                      )
                    : null,
              ),
            ),

            // * Selected items chips
            if (_selectedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedItems.map((item) {
                  if (widget.chipBuilder != null) {
                    return widget.chipBuilder!(context, item);
                  }
                  return _buildDefaultChip(item);
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDefaultChip(T item) {
    final displayLabel = widget.itemDisplayMapper(item);
    final subtitleLabel = widget.itemSubtitleMapper?.call(item);
    final leadingWidget = widget.itemLeadingMapper?.call(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  displayLabel,
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.w500,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitleLabel != null)
                  AppText(
                    subtitleLabel,
                    style: AppTextStyle.labelSmall,
                    color: context.colors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeItem(item),
            child: Icon(
              Icons.close,
              size: 16,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuffixIcon() {
    if (_selectedItems.isNotEmpty && widget.enabled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.clear, color: context.colors.textSecondary),
            onPressed: _clearAll,
            tooltip: LocaleKeys.sharedWidgetsMultiSelectDropdownClearAll.tr(),
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

  bool _listEquals<E>(List<E>? a, List<E>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// * Bottom sheet with multi-select functionality
class _MultiSelectBottomSheet<T> extends StatefulWidget {
  final String title;
  final String searchHintText;
  final Future<List<T>> Function(String query) onSearch;
  final Future<List<T>> Function()? onLoadInitial;
  final String Function(T item) itemDisplayMapper;
  final String Function(T item) itemValueMapper;
  final String? Function(T item)? itemSubtitleMapper;
  final Widget? Function(T item)? itemLeadingMapper;
  final Widget Function(BuildContext context, T item, bool isSelected)?
  itemBuilder;
  final String emptyMessage;
  final Duration debounceDuration;
  final List<T> selectedItems;
  final int? maxItems;

  const _MultiSelectBottomSheet({
    required this.title,
    required this.searchHintText,
    required this.onSearch,
    required this.itemDisplayMapper,
    required this.itemValueMapper,
    this.itemSubtitleMapper,
    this.itemLeadingMapper,
    this.onLoadInitial,
    this.itemBuilder,
    required this.emptyMessage,
    required this.debounceDuration,
    required this.selectedItems,
    this.maxItems,
  });

  @override
  State<_MultiSelectBottomSheet<T>> createState() =>
      _MultiSelectBottomSheetState<T>();
}

class _MultiSelectBottomSheetState<T>
    extends State<_MultiSelectBottomSheet<T>> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<T> _items = [];
  List<T> _selectedItems = [];
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedItems);
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

  void _toggleItem(T item) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (e) => widget.itemValueMapper(e) == widget.itemValueMapper(item),
      );
      if (existingIndex >= 0) {
        _selectedItems.removeAt(existingIndex);
      } else {
        // * Check max items limit
        if (widget.maxItems != null &&
            _selectedItems.length >= widget.maxItems!) {
          return;
        }
        _selectedItems.add(item);
      }
    });
  }

  bool _isSelected(T item) {
    return _selectedItems.any(
      (e) => widget.itemValueMapper(e) == widget.itemValueMapper(item),
    );
  }

  void _confirm() {
    Navigator.pop(context, _selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        // * Perbesar sheet saat keyboard muncul agar item tetap terlihat
        initialChildSize: keyboardVisible ? 0.95 : 0.7,
        minChildSize: keyboardVisible ? 0.7 : 0.4,
        maxChildSize: 0.95,
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
                  color: context.colors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // * Title with selected count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            widget.title,
                            style: AppTextStyle.titleMedium,
                            fontWeight: FontWeight.bold,
                          ),
                          if (_selectedItems.isNotEmpty)
                            AppText(
                              LocaleKeys
                                  .sharedWidgetsMultiSelectDropdownItemsSelected
                                  .tr(
                                    namedArgs: {
                                      'count': _selectedItems.length.toString(),
                                    },
                                  ),
                              style: AppTextStyle.bodySmall,
                              color: context.colors.primary,
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedItems.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedItems.clear()),
                            child: AppText(
                              LocaleKeys
                                  .sharedWidgetsMultiSelectDropdownClearAll
                                  .tr(),
                              color: context.semantic.error,
                            ),
                          ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _confirm,
                          child: AppText(
                            LocaleKeys.sharedWidgetsMultiSelectDropdownDone
                                .tr(),
                          ),
                        ),
                      ],
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
                  decoration: InputDecoration(
                    hintText: widget.searchHintText,
                    hintStyle: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textTertiary,
                    ),
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
                    fillColor: context.colors.surfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _onSearchChanged,
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
        final isSelected = _isSelected(item);

        if (widget.itemBuilder != null) {
          return InkWell(
            onTap: () => _toggleItem(item),
            borderRadius: BorderRadius.circular(12),
            child: widget.itemBuilder!(context, item, isSelected),
          );
        }

        return _buildDefaultItem(item, isSelected);
      },
    );
  }

  Widget _buildDefaultItem(T item, bool isSelected) {
    final displayLabel = widget.itemDisplayMapper(item);
    final subtitleLabel = widget.itemSubtitleMapper?.call(item);
    final leadingWidget = widget.itemLeadingMapper?.call(item);

    return InkWell(
      onTap: () => _toggleItem(item),
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
            // * Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? context.colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: context.colors.textOnPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    displayLabel,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  if (subtitleLabel != null)
                    AppText(
                      subtitleLabel,
                      style: AppTextStyle.bodySmall,
                      color: context.colors.textSecondary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
