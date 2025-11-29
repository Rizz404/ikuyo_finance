import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_image.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;
  final Widget? icon;
  final String? imagePath; // * Path ke asset image (SVG/PNG)

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.imagePath,
  });
}

class AppDropdown<T> extends StatelessWidget {
  final String name;
  final T? initialValue;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? label;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final Widget? prefixIcon;
  final bool isExpanded;
  final double? width;
  final String? Function(T?)? validator;
  final double imageSize;
  final Color? imageColor;

  const AppDropdown({
    super.key,
    required this.name,
    this.initialValue,
    required this.items,
    this.onChanged,
    this.hintText,
    this.label,
    this.enabled = true,
    this.contentPadding,
    this.fillColor,
    this.prefixIcon,
    this.isExpanded = true,
    this.width,
    this.validator,
    this.imageSize = 20,
    this.imageColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget dropdown = FormBuilderDropdown<T>(
      name: name,
      initialValue: initialValue,
      enabled: enabled,
      onChanged: onChanged,
      validator: validator,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildItemIcon(item, context),
              const SizedBox(width: 8),
              Flexible(
                child: AppText(
                  item.label,
                  style: AppTextStyle.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      isExpanded: isExpanded,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText ?? "Select option",
        hintStyle: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.textTertiary,
        ),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: fillColor ?? context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.disabled, width: 1),
        ),
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colors.textPrimary,
      ),
      dropdownColor: context.colors.surface,
      iconEnabledColor: context.colors.textSecondary,
      iconDisabledColor: context.colors.textDisabled,
    );

    if (width != null) {
      dropdown = SizedBox(width: width, child: dropdown);
    }

    return dropdown;
  }

  Widget _buildItemIcon(AppDropdownItem<T> item, BuildContext context) {
    // * Prioritas: imagePath > icon > empty
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      return AppImage.icon(
        path: item.imagePath!,
        size: imageSize,
        color: imageColor,
      );
    }
    if (item.icon != null) {
      return item.icon!;
    }
    return SizedBox(width: imageSize, height: imageSize);
  }
}

// Extension to create common dropdown items
extension AppDropdownExtensions on AppDropdown {
  static List<AppDropdownItem<String>> createFilterItems({
    required String allLabel,
    required List<String> filterValues,
    required List<String> filterLabels,
    List<IconData>? filterIcons,
  }) {
    final items = <AppDropdownItem<String>>[
      AppDropdownItem(
        value: 'all',
        label: allLabel,
        icon: const Icon(Icons.list_alt, size: 18),
      ),
    ];

    for (int i = 0; i < filterValues.length; i++) {
      items.add(
        AppDropdownItem(
          value: filterValues[i],
          label: filterLabels[i],
          icon: filterIcons != null && i < filterIcons.length
              ? Icon(filterIcons[i], size: 18)
              : null,
        ),
      );
    }

    return items;
  }
}
