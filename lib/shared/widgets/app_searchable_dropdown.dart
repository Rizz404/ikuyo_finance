import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class AppSearchableDropdown<T> extends StatefulWidget {
  final String name;
  final T? initialValue;
  final String? label;
  final String? hintText;
  final bool enabled;
  final String? Function(String?)? validator;

  // * Data & callbacks
  final List<T> items;
  final bool isLoading;
  final ValueChanged<String> onSearch;
  final VoidCallback? onLoadMore;

  // * Pagination state
  final bool hasMore;
  final bool isLoadingMore;

  // * Item configuration
  final String Function(T item) itemDisplayMapper;
  final String Function(T item) itemValueMapper;
  final String? Function(T item)? itemSubtitleMapper;
  final Widget? Function(T item)? itemLeadingMapper;

  // * Selection callback
  final void Function(T? item)? onChanged;

  // * UI customization
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final Widget? prefixIcon;
  final double dropdownMaxHeight;

  const AppSearchableDropdown({
    super.key,
    required this.name,
    required this.items,
    required this.isLoading,
    required this.onSearch,
    required this.itemDisplayMapper,
    required this.itemValueMapper,
    this.initialValue,
    this.label,
    this.hintText,
    this.enabled = true,
    this.validator,
    this.itemSubtitleMapper,
    this.itemLeadingMapper,
    this.onChanged,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.contentPadding,
    this.fillColor,
    this.prefixIcon,
    this.dropdownMaxHeight = 400,
  });

  @override
  State<AppSearchableDropdown<T>> createState() =>
      _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>>
    with WidgetsBindingObserver {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late GlobalKey<FormBuilderFieldState<FormBuilderField<String>, String>>
  _fieldKey;

  OverlayEntry? _overlayEntry;
  T? _selectedItem;
  Timer? _debounceTimer;
  ScrollController? _scrollController;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fieldKey =
        GlobalKey<FormBuilderFieldState<FormBuilderField<String>, String>>();
    _selectedItem = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant AppSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // * Update selected item jika initialValue berubah (untuk mode edit)
    if (widget.initialValue != oldWidget.initialValue) {
      _selectedItem = widget.initialValue;
    }

    // * Rebuild overlay saat items/loading state berubah
    if (_overlayEntry != null) {
      if (widget.items != oldWidget.items ||
          widget.isLoading != oldWidget.isLoading ||
          widget.isLoadingMore != oldWidget.isLoadingMore ||
          widget.hasMore != oldWidget.hasMore) {
        // * Schedule rebuild for next frame to avoid calling during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _overlayEntry?.markNeedsBuild();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // * Rebuild overlay saat keyboard muncul/hilang agar posisi & ukuran update
    if (_overlayEntry != null && _isDropdownOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onSearch(query);
    });
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;

    if (_isDropdownOpen) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_isDropdownOpen) return;

    _scrollController?.dispose();
    _scrollController = ScrollController();
    _setupScrollListener();

    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isDropdownOpen = true;

    // * Trigger search for empty query to ensure data context matches this specific field
    widget.onSearch('');

    // * Request focus ke search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    setState(() {});
  }

  void _hideDropdown() {
    if (!_isDropdownOpen) return;

    // * Unfocus search field sebelum remove overlay agar focus tidak jump ke field lain
    _searchFocusNode.unfocus();

    _removeOverlay();
    _searchController.clear();
    _debounceTimer?.cancel();
    _isDropdownOpen = false;

    // * Reset search saat close
    widget.onSearch('');

    // * Pastikan tidak ada field lain yang ter-focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });

    setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _setupScrollListener() {
    _scrollController?.addListener(() {
      if (_scrollController == null || !_scrollController!.hasClients) return;

      // * Trigger loadMore saat scroll 80% dari max extent
      if (widget.onLoadMore != null &&
          widget.hasMore &&
          !widget.isLoadingMore) {
        final maxScroll = _scrollController!.position.maxScrollExtent;
        final currentScroll = _scrollController!.position.pixels;
        final threshold = maxScroll * 0.8;

        if (currentScroll >= threshold) {
          widget.onLoadMore!();
        }
      }
    });
  }

  void _selectItem(T item) {
    final value = widget.itemValueMapper(item);
    _fieldKey.currentState?.didChange(value);

    setState(() {
      _selectedItem = item;
    });

    widget.onChanged?.call(item);
    _hideDropdown();
  }

  void _clearSelection() {
    _fieldKey.currentState?.didChange(null);

    setState(() {
      _selectedItem = null;
    });

    widget.onChanged?.call(null);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        // * Hitung posisi di dalam builder agar update saat keyboard muncul/hilang
        final renderBox = context.findRenderObject() as RenderBox;
        final size = renderBox.size;
        final offset = renderBox.localToGlobal(Offset.zero);
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;
        final keyboardHeight = mediaQuery.viewInsets.bottom;

        // * Kurangi tinggi layar dengan keyboard height
        final effectiveScreenHeight = screenHeight - keyboardHeight;

        final spaceBelow = effectiveScreenHeight - offset.dy - size.height;
        final spaceAbove = offset.dy;
        final maxHeight = widget.dropdownMaxHeight;

        final shouldShowAbove =
            spaceBelow < maxHeight && spaceAbove > spaceBelow;
        final availableHeight = shouldShowAbove
            ? (spaceAbove - 8).clamp(100.0, maxHeight)
            : (spaceBelow - 8).clamp(100.0, maxHeight);

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: shouldShowAbove
                ? Offset(0, -(availableHeight + 4))
                : Offset(0, size.height + 4),
            child: TapRegion(
              onTapOutside: (_) => _hideDropdown(),
              child: Material(
                elevation: 16,
                borderRadius: BorderRadius.circular(12),
                color: context.colors.surface,
                child: Container(
                  constraints: BoxConstraints(maxHeight: availableHeight),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchHeader(),
                      Flexible(child: _buildItemsList()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _performSearch,
        decoration: InputDecoration(
          hintText: LocaleKeys.sharedWidgetsSearchableDropdownSearchHint.tr(),
          hintStyle: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: context.colors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: context.colors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        style: context.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildItemsList() {
    final items = widget.items;
    final isLoading = widget.isLoading;

    if (isLoading && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(context.colors.primary),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: AppText(
            LocaleKeys.sharedWidgetsSearchableDropdownNoResults.tr(),
            style: AppTextStyle.bodyMedium,
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    // * Calculate extra item count for loading/end indicators
    int extraItems = 0;
    if (widget.isLoadingMore) {
      extraItems = 1;
    } else if (!widget.hasMore && items.isNotEmpty) {
      extraItems = 1;
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      itemCount: items.length + extraItems,
      itemBuilder: (context, index) {
        // * Loading indicator saat loadMore
        if (index == items.length && widget.isLoadingMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(context.colors.primary),
                ),
              ),
            ),
          );
        }

        // * End of list message
        if (index == items.length && !widget.hasMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: AppText(
                'Tidak ada data lagi',
                style: AppTextStyle.bodySmall,
                color: context.colors.textTertiary,
              ),
            ),
          );
        }

        final item = items[index];
        final isSelected =
            _selectedItem != null &&
            widget.itemValueMapper(_selectedItem as T) ==
                widget.itemValueMapper(item);

        return _buildItem(item, isSelected);
      },
    );
  }

  Widget _buildItem(T item, bool isSelected) {
    final displayText = widget.itemDisplayMapper(item);
    final subtitle = widget.itemSubtitleMapper?.call(item);
    final leadingWidget = widget.itemLeadingMapper?.call(item);

    return InkWell(
      onTap: () => _selectItem(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: context.colors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    displayText,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textPrimary,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    AppText(
                      subtitle,
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

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: FormBuilderField<String>(
        key: _fieldKey,
        name: widget.name,
        initialValue: widget.initialValue != null
            ? widget.itemValueMapper(widget.initialValue as T)
            : null,
        enabled: widget.enabled,
        validator: widget.validator,
        builder: (FormFieldState<String> field) {
          final hasError = field.hasError;
          final displayText = _selectedItem != null
              ? widget.itemDisplayMapper(_selectedItem as T)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _toggleDropdown,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText:
                        widget.hintText ??
                        LocaleKeys.sharedWidgetsSearchableDropdownSelectOption
                            .tr(),
                    hintStyle: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // * Clear button saat ada selection
                        if (_selectedItem != null && widget.enabled)
                          IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                            onPressed: _clearSelection,
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        Icon(
                          _isDropdownOpen
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: widget.enabled
                              ? context.colors.textSecondary
                              : context.colors.textDisabled,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    filled: true,
                    fillColor: widget.fillColor ?? context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.border,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.semantic.error,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.semantic.error,
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
                    contentPadding:
                        widget.contentPadding ??
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                    errorText: hasError ? field.errorText : null,
                  ),
                  child: displayText != null
                      ? AppText(
                          displayText,
                          style: AppTextStyle.bodyMedium,
                          color: widget.enabled
                              ? context.colors.textPrimary
                              : context.colors.textDisabled,
                        )
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
