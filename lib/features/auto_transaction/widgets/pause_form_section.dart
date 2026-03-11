import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';

class PauseFormSection extends StatefulWidget {
  final bool initialManual;
  final DateTime? initialPauseUntil;

  const PauseFormSection({
    super.key,
    this.initialManual = true,
    this.initialPauseUntil,
  });

  @override
  State<PauseFormSection> createState() => _PauseFormSectionState();
}

class _PauseFormSectionState extends State<PauseFormSection> {
  late bool _isManual;

  @override
  void initState() {
    super.initState();
    _isManual = widget.initialManual;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(LocaleKeys.autoTransactionGroupUpsertPauseManual.tr()),
          value: _isManual,
          onChanged: (v) => setState(() => _isManual = v),
          contentPadding: EdgeInsets.zero,
        ),
        if (!_isManual) ...[
          const SizedBox(height: 8),
          AppDateTimePicker(
            name: 'pauseUntil',
            label: LocaleKeys.autoTransactionGroupUpsertPauseUntilLabel.tr(),
            initialValue: widget.initialPauseUntil,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            inputType: InputType.date,
          ),
        ],
      ],
    );
  }
}
