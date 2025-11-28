import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

class AppCheckbox extends StatelessWidget {
  final String name;
  final Widget title;
  final String? Function(bool?)? validator;
  final bool? initialValue;

  const AppCheckbox({
    super.key,
    required this.name,
    required this.title,
    this.validator,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderCheckbox(
      name: name,
      title: title,
      validator: validator,
      initialValue: initialValue,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: context.colors.primary,
      checkColor: context.colors.textOnPrimary,
    );
  }
}
