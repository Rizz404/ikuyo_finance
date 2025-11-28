import 'package:flutter/material.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';

class AppDetailActionButtons extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AppDetailActionButtons({super.key, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasDelete = onDelete != null;
    final hasEdit = onEdit != null;

    if (!hasDelete && !hasEdit) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            if (hasDelete) ...[
              Expanded(
                child: AppButton(
                  text: 'Delete',
                  color: AppButtonColor.error,
                  variant: AppButtonVariant.outlined,
                  onPressed: onDelete,
                ),
              ),
              if (hasEdit) const SizedBox(width: 16),
            ],
            if (hasEdit)
              Expanded(
                child: AppButton(text: 'Edit', onPressed: onEdit),
              ),
          ],
        ),
      ),
    );
  }
}
