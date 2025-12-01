import 'package:flutter/material.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Dialog untuk memilih periode kustom
class CustomPeriodDialog extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const CustomPeriodDialog({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  /// * Show dialog and return selected date range
  static Future<(DateTime, DateTime)?> show({
    required BuildContext context,
    required DateTime initialStartDate,
    required DateTime initialEndDate,
  }) {
    return showDialog<(DateTime, DateTime)?>(
      context: context,
      builder: (_) => CustomPeriodDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }

  @override
  State<CustomPeriodDialog> createState() => _CustomPeriodDialogState();
}

class _CustomPeriodDialogState extends State<CustomPeriodDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText(
        'Pilih Periode',
        style: AppTextStyle.titleMedium,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // * Start date
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const AppText(
              'Tanggal Mulai',
              style: AppTextStyle.bodySmall,
            ),
            subtitle: AppText(
              _formatDate(_startDate),
              style: AppTextStyle.bodyMedium,
              fontWeight: FontWeight.w500,
            ),
            onTap: () => _selectDate(true),
          ),
          const Divider(),
          // * End date
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const AppText(
              'Tanggal Selesai',
              style: AppTextStyle.bodySmall,
            ),
            subtitle: AppText(
              _formatDate(_endDate),
              style: AppTextStyle.bodyMedium,
              fontWeight: FontWeight.w500,
            ),
            onTap: () => _selectDate(false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_startDate, _endDate)),
          child: const Text('Terapkan'),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = isStart ? DateTime(1900) : _startDate;
    final lastDate = isStart ? _endDate : DateTime(2100);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selected != null) {
      setState(() {
        if (isStart) {
          _startDate = selected;
        } else {
          _endDate = selected;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
