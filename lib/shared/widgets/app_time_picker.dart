import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

class AppTimePicker extends StatelessWidget {
  final String name;
  final String label;
  final TimeOfDay? initialValue;
  final bool enabled;

  const AppTimePicker({
    super.key,
    required this.name,
    required this.label,
    this.initialValue,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<TimeOfDay>(
      name: name,
      initialValue: initialValue,
      enabled: enabled,
      builder: (FormFieldState<TimeOfDay> field) {
        return InkWell(
          onTap: enabled
              ? () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: field.value ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    field.didChange(time);
                  }
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.access_time),
              filled: !enabled,
              fillColor: !enabled
                  ? context.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    )
                  : null,
            ),
            child: Text(
              field.value != null ? field.value!.format(context) : 'HH:MM',
              style: TextStyle(
                color: enabled
                    ? null
                    : context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}
