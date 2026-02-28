import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

// * Reusable color picker widget dengan FormBuilder support
// * Supports preset colors dan custom hex input
class AppColorPicker extends StatefulWidget {
  final String name;
  final String? label;
  final String? initialValue;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final List<String> presetColors;
  final bool showCustomInput;

  // * Default preset colors
  static const defaultPresetColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFEB3B', // Yellow
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  const AppColorPicker({
    super.key,
    required this.name,
    this.label,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.presetColors = defaultPresetColors,
    this.showCustomInput = true,
  });

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  late TextEditingController _customColorController;
  String? _selectedColor;
  bool _isCustomColor = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialValue;
    _customColorController = TextEditingController(
      text: widget.initialValue ?? '',
    );
    // * Check if initial value is a custom color
    if (_selectedColor != null &&
        !widget.presetColors.contains(_selectedColor)) {
      _isCustomColor = true;
    }
  }

  @override
  void dispose() {
    _customColorController.dispose();
    super.dispose();
  }

  void _onColorSelected(String colorHex) {
    setState(() {
      _selectedColor = colorHex;
      _isCustomColor = false;
      _customColorController.text = colorHex;
    });
    FormBuilder.of(context)?.fields[widget.name]?.didChange(colorHex);
    widget.onChanged?.call(colorHex);
  }

  void _onCustomColorChanged(String? value) {
    if (value != null && value.isNotEmpty) {
      final hexPattern = RegExp(r'^#?([0-9A-Fa-f]{6})$');
      String colorHex = value;

      // * Add # if missing
      if (!colorHex.startsWith('#')) {
        colorHex = '#$colorHex';
      }

      if (hexPattern.hasMatch(colorHex.substring(1))) {
        setState(() {
          _selectedColor = colorHex.toUpperCase();
          _isCustomColor = true;
        });
        FormBuilder.of(
          context,
        )?.fields[widget.name]?.didChange(colorHex.toUpperCase());
        widget.onChanged?.call(colorHex.toUpperCase());
      }
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: widget.name,
      validator: widget.validator,
      initialValue: widget.initialValue,
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null) ...[
              AppText(
                widget.label!,
                style: AppTextStyle.labelLarge,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(height: 12),
            ],

            // * Preset colors grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.presetColors.map((colorHex) {
                final color = _parseColor(colorHex);
                final isSelected =
                    _selectedColor == colorHex && !_isCustomColor;

                return GestureDetector(
                  onTap: () => _onColorSelected(colorHex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? context.colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected && color != null
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: _isLightColor(color)
                                ? Colors.black
                                : Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            // * Custom color input
            if (widget.showCustomInput) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // * Preview selected custom color
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          _parseColor(_selectedColor) ??
                          context.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isCustomColor
                            ? context.colorScheme.primary
                            : context.colorScheme.outlineVariant,
                        width: _isCustomColor ? 3 : 1,
                      ),
                    ),
                    child: _selectedColor == null
                        ? Icon(
                            Icons.colorize,
                            size: 18,
                            color: context.colorScheme.outline,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // * Hex input field
                  Expanded(
                    child: FormBuilderTextField(
                      name: '${widget.name}_custom',
                      initialValue: _isCustomColor ? _selectedColor : null,
                      decoration: InputDecoration(
                        labelText: LocaleKeys
                            .sharedWidgetsColorPickerCustomColorLabel
                            .tr(),
                        hintText: '#FF5722',
                        prefixIcon: const Icon(Icons.tag),
                        filled: true,
                        fillColor: context.colors.surface,
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: _onCustomColorChanged,
                    ),
                  ),
                ],
              ),
            ],

            // * Error message
            if (field.hasError) ...[
              const SizedBox(height: 8),
              AppText(
                field.errorText ?? '',
                style: AppTextStyle.bodySmall,
                color: context.semantic.error,
              ),
            ],
          ],
        );
      },
    );
  }

  bool _isLightColor(Color? color) {
    if (color == null) return false;
    return color.computeLuminance() > 0.5;
  }
}
