import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

class AppDateTimePicker extends StatelessWidget {
  final String name;
  final String label;
  final InputType inputType;
  final IconData? icon;
  final String? Function(DateTime?)? validator;
  final DateTime? initialValue;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? hintText;
  final Widget? prefixIcon;

  const AppDateTimePicker({
    super.key,
    required this.name,
    required this.label,
    this.inputType = InputType.date,
    this.icon,
    this.validator,
    this.initialValue,
    this.firstDate,
    this.lastDate,
    this.hintText,
    this.prefixIcon,
  });

  IconData get _defaultIcon {
    switch (inputType) {
      case InputType.time:
        return Icons.access_time_outlined;
      case InputType.both:
        return Icons.calendar_month_outlined;
      case InputType.date:
        return Icons.calendar_today_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderDateTimePicker(
      name: name,
      inputType: inputType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: Icon(icon ?? _defaultIcon),
        filled: true,
        fillColor: context.colors.surface,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.semantic.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.semantic.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
      initialValue: initialValue,
      firstDate: firstDate,
      lastDate: lastDate,
      valueTransformer: (value) => value?.toLocal(),
    );
  }
}
