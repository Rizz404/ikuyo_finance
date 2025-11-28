import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

class AppRadioGroup<T extends Object> extends StatelessWidget {
  final String name;
  final String label;
  final String? Function(T?)? validator;
  final List<FormBuilderFieldOption<T>> options;
  final ControlAffinity controlAffinity;
  final Widget? separator;

  const AppRadioGroup({
    super.key,
    required this.name,
    required this.label,
    required this.options,
    this.validator,
    this.controlAffinity = ControlAffinity.leading,
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderRadioGroup<T>(
      name: name,
      decoration: InputDecoration(
        labelText: label,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        labelStyle: context.textTheme.bodyLarge?.copyWith(
          color: context.theme.inputDecorationTheme.labelStyle?.color,
        ),
      ),
      validator: validator,
      options: options,
      controlAffinity: controlAffinity,
      separator: separator ?? const SizedBox(width: 20),
    );
  }
}
