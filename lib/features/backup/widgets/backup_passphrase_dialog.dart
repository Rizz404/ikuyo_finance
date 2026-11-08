import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Pilihan ekspor; [passphrase] null berarti opt-out tanpa enkripsi.
/// * Hanya hidup di state layar, tidak pernah masuk event/state bloc
///   (TalkerBlocObserver mencetak event di debug)
class BackupExportChoice {
  final String? passphrase;

  const BackupExportChoice._(this.passphrase);

  const BackupExportChoice.encrypted(String passphrase) : this._(passphrase);
  const BackupExportChoice.unencrypted() : this._(null);

  bool get encrypted => passphrase != null;

  @override
  String toString() => 'BackupExportChoice(encrypted: $encrypted)';
}

Future<BackupExportChoice?> showBackupExportDialog(BuildContext context) {
  return showDialog<BackupExportChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ExportPassphraseDialog(),
  );
}

Future<String?> showBackupImportPassphraseDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ImportPassphraseDialog(),
  );
}

String backupCryptoErrorMessage(BackupCryptoError error) {
  return switch (error) {
    BackupCryptoError.passphraseTooShort =>
      LocaleKeys.backupEncryptionPassphraseTooShort.tr(
        namedArgs: {'min': '${BackupCrypto.minPassphraseLength}'},
      ),
    BackupCryptoError.passphraseRequired ||
    BackupCryptoError.wrongPassphraseOrTampered =>
      LocaleKeys.backupEncryptionWrongPassphrase.tr(),
    BackupCryptoError.truncated => LocaleKeys.backupEncryptionTruncated.tr(),
    BackupCryptoError.unsupportedVersion ||
    BackupCryptoError.invalidParameters =>
      LocaleKeys.backupEncryptionUnsupported.tr(),
    BackupCryptoError.notABackup => LocaleKeys.backupEncryptionNotABackup.tr(),
  };
}

class _WarningBox extends StatelessWidget {
  final String text;

  const _WarningBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.semantic.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.semantic.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: context.semantic.warning),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              text,
              style: AppTextStyle.bodySmall,
              color: context.semantic.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPassphraseDialog extends StatefulWidget {
  const _ExportPassphraseDialog();

  @override
  State<_ExportPassphraseDialog> createState() =>
      _ExportPassphraseDialogState();
}

class _ExportPassphraseDialogState extends State<_ExportPassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, BackupExportChoice.encrypted(_pass.text));
  }

  Future<void> _exportUnencrypted() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          LocaleKeys.backupEncryptionUnencryptedTitle.tr(),
          style: AppTextStyle.titleLarge,
          fontWeight: FontWeight.bold,
        ),
        content: _WarningBox(
          LocaleKeys.backupEncryptionUnencryptedWarning.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.backupEncryptionCancel.tr()),
          ),
          FilledButton(
            key: const Key('backup_unencrypted_confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.semantic.error,
            ),
            child: Text(LocaleKeys.backupEncryptionUnencryptedConfirm.tr()),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, const BackupExportChoice.unencrypted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final min = BackupCrypto.minPassphraseLength;
    return AlertDialog(
      title: AppText(
        LocaleKeys.backupEncryptionExportTitle.tr(),
        style: AppTextStyle.titleLarge,
        fontWeight: FontWeight.bold,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                LocaleKeys.backupEncryptionExportDescription.tr(),
                style: AppTextStyle.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('backup_passphrase_field'),
                controller: _pass,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: LocaleKeys.backupEncryptionPassphraseLabel.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').runes.length < min
                    ? LocaleKeys.backupEncryptionPassphraseTooShort.tr(
                        namedArgs: {'min': '$min'},
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('backup_passphrase_confirm_field'),
                controller: _confirm,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: LocaleKeys.backupEncryptionPassphraseConfirmLabel
                      .tr(),
                ),
                validator: (v) => v != _pass.text
                    ? LocaleKeys.backupEncryptionPassphraseMismatch.tr()
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              _WarningBox(LocaleKeys.backupEncryptionUnrecoverableWarning.tr()),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('backup_export_unencrypted'),
                onPressed: _exportUnencrypted,
                child: Text(LocaleKeys.backupEncryptionExportUnencrypted.tr()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.backupEncryptionCancel.tr()),
        ),
        FilledButton(
          key: const Key('backup_export_encrypted'),
          onPressed: _submit,
          child: Text(LocaleKeys.backupEncryptionEncryptAndExport.tr()),
        ),
      ],
    );
  }
}

class _ImportPassphraseDialog extends StatefulWidget {
  const _ImportPassphraseDialog();

  @override
  State<_ImportPassphraseDialog> createState() =>
      _ImportPassphraseDialogState();
}

class _ImportPassphraseDialogState extends State<_ImportPassphraseDialog> {
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pass.text.isEmpty) return;
    Navigator.pop(context, _pass.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: AppText(
        LocaleKeys.backupEncryptionImportTitle.tr(),
        style: AppTextStyle.titleLarge,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            LocaleKeys.backupEncryptionImportDescription.tr(),
            style: AppTextStyle.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('backup_import_passphrase_field'),
            controller: _pass,
            obscureText: _obscure,
            enableSuggestions: false,
            autocorrect: false,
            autofocus: true,
            decoration: InputDecoration(
              labelText: LocaleKeys.backupEncryptionPassphraseLabel.tr(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.backupEncryptionCancel.tr()),
        ),
        FilledButton(
          key: const Key('backup_import_decrypt'),
          onPressed: _submit,
          child: Text(LocaleKeys.backupEncryptionDecrypt.tr()),
        ),
      ],
    );
  }
}
