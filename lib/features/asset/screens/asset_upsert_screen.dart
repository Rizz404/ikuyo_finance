import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';
import 'package:ikuyo_finance/features/asset/validators/create_asset_validator.dart';
import 'package:ikuyo_finance/features/asset/validators/update_asset_validator.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_file_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AssetUpsertScreen extends StatefulWidget {
  final Asset? asset;

  const AssetUpsertScreen({super.key, this.asset});

  bool get isEdit => asset != null;

  @override
  State<AssetUpsertScreen> createState() => _AssetUpsertScreenState();
}

class _AssetUpsertScreenState extends State<AssetUpsertScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _filePickerKey = GlobalKey<AppFilePickerState>();

  void _handleWriteStatus(BuildContext context, AssetState state) {
    if (state.writeStatus == AssetWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title: state.writeSuccessMessage ?? 'Berhasil',
      );
      context.read<AssetBloc>().add(const AssetWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == AssetWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title: state.writeErrorMessage ?? 'Terjadi kesalahan',
      );
      context.read<AssetBloc>().add(const AssetWriteStatusReset());
    }
  }

  void _onSubmit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final name = values['name'] as String;
      final type = AssetType.values[values['type'] as int];
      final balanceStr = values['balance'] as String?;
      final balance =
          double.tryParse(balanceStr?.replaceAll(',', '.') ?? '0') ?? 0;

      // * Get icon path from file picker
      String? iconPath;
      final iconFiles = values['icon'] as List<PlatformFile>?;
      if (iconFiles != null && iconFiles.isNotEmpty) {
        iconPath = iconFiles.first.path;
      }

      if (widget.isEdit) {
        context.read<AssetBloc>().add(
          AssetUpdated(
            params: UpdateAssetParams(
              ulid: widget.asset!.ulid,
              name: name,
              type: type,
              balance: balance,
              icon: iconPath ?? widget.asset!.icon,
            ),
          ),
        );
      } else {
        context.read<AssetBloc>().add(
          AssetCreated(
            params: CreateAssetParams(
              name: name,
              type: type,
              balance: balance,
              icon: iconPath,
            ),
          ),
        );
      }
    }
  }

  void _onDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText(
          'Hapus Aset',
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: const AppText(
          'Apakah Anda yakin ingin menghapus aset ini? '
          'Transaksi yang terkait dengan aset ini akan terpengaruh.',
          style: AppTextStyle.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: AppText('Batal', color: context.colorScheme.outline),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AssetBloc>().add(
                AssetDeleted(ulid: widget.asset!.ulid),
              );
            },
            child: AppText(
              'Hapus',
              color: context.semantic.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetBloc, AssetState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            widget.isEdit ? 'Edit Aset' : 'Tambah Aset',
            style: AppTextStyle.titleLarge,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ScreenWrapper(
          child: FormBuilder(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // * Asset Type Dropdown
                  AppDropdown<int>(
                    name: 'type',
                    label: 'Tipe Aset',
                    hintText: 'Pilih tipe aset',
                    initialValue: widget.asset?.type ?? AssetType.cash.index,
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                    items: [
                      AppDropdownItem(
                        value: AssetType.cash.index,
                        label: 'Kas',
                        icon: Icon(
                          Icons.wallet_outlined,
                          size: 20,
                          color: Colors.green,
                        ),
                      ),
                      AppDropdownItem(
                        value: AssetType.bank.index,
                        label: 'Bank',
                        icon: Icon(
                          Icons.account_balance_outlined,
                          size: 20,
                          color: Colors.blue,
                        ),
                      ),
                      AppDropdownItem(
                        value: AssetType.eWallet.index,
                        label: 'E-Wallet',
                        icon: Icon(
                          Icons.phone_android_outlined,
                          size: 20,
                          color: Colors.orange,
                        ),
                      ),
                      AppDropdownItem(
                        value: AssetType.stock.index,
                        label: 'Saham',
                        icon: Icon(
                          Icons.trending_up_outlined,
                          size: 20,
                          color: Colors.purple,
                        ),
                      ),
                      AppDropdownItem(
                        value: AssetType.crypto.index,
                        label: 'Crypto',
                        icon: Icon(
                          Icons.currency_bitcoin_outlined,
                          size: 20,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                    validator: widget.isEdit
                        ? UpdateAssetValidator.type
                        : CreateAssetValidator.type,
                  ),
                  const SizedBox(height: 24),

                  // * Name Field
                  AppTextField(
                    name: 'name',
                    label: 'Nama Aset',
                    initialValue: widget.asset?.name,
                    placeHolder: 'Contoh: BCA, GoPay, Dompet',
                    validator: widget.isEdit
                        ? UpdateAssetValidator.name
                        : CreateAssetValidator.name,
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  const SizedBox(height: 24),

                  // * Balance Field
                  AppTextField(
                    name: 'balance',
                    label: 'Saldo Awal',
                    initialValue: widget.asset?.balance.toStringAsFixed(0),
                    placeHolder: '0',
                    type: AppTextFieldType.number,
                    validator: widget.isEdit
                        ? UpdateAssetValidator.balance
                        : CreateAssetValidator.balance,
                    prefixIcon: const Icon(Icons.attach_money_outlined),
                  ),
                  const SizedBox(height: 24),

                  // * Icon File Picker with current preview
                  if (widget.isEdit && widget.asset?.icon != null) ...[
                    const AppText(
                      'Ikon Saat Ini',
                      style: AppTextStyle.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildIconPreview(widget.asset!.icon!, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppText(
                              widget.asset!.icon!.split('/').last,
                              style: AppTextStyle.bodySmall,
                              color: context.colorScheme.outline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppFilePicker(
                    key: _filePickerKey,
                    name: 'icon',
                    label: widget.isEdit ? 'Ganti Ikon' : 'Ikon Aset',
                    hintText: 'Pilih gambar ikon (opsional)',
                    fileType: FileType.image,
                    allowMultiple: false,
                    maxFiles: 1,
                    maxSizeInMB: 2,
                  ),
                  const SizedBox(height: 32),

                  // * Submit Button
                  BlocBuilder<AssetBloc, AssetState>(
                    buildWhen: (prev, curr) =>
                        prev.writeStatus != curr.writeStatus,
                    builder: (context, state) {
                      return AppButton(
                        text: widget.isEdit
                            ? 'Simpan Perubahan'
                            : 'Tambah Aset',
                        isLoading: state.isWriting,
                        onPressed: state.isWriting ? null : _onSubmit,
                        leadingIcon: Icon(
                          widget.isEdit ? Icons.save_outlined : Icons.add,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // * Delete Button (only for edit mode)
                  if (widget.isEdit) ...[
                    BlocBuilder<AssetBloc, AssetState>(
                      buildWhen: (prev, curr) =>
                          prev.writeStatus != curr.writeStatus,
                      builder: (context, state) {
                        return AppButton(
                          text: 'Hapus Aset',
                          variant: AppButtonVariant.outlined,
                          color: AppButtonColor.error,
                          isLoading: state.isWriting,
                          onPressed: state.isWriting ? null : _onDelete,
                          leadingIcon: const Icon(Icons.delete_outline),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// * Adaptive icon preview - handles Flutter Icon codePoint or file images
  Widget _buildIconPreview(String iconData, {double size = 48}) {
    // * Try parsing as Flutter Icon codePoint
    final codePoint = int.tryParse(iconData);
    if (codePoint != null) {
      return Icon(
        IconData(codePoint, fontFamily: 'MaterialIcons'),
        size: size,
        color: context.colorScheme.primary,
      );
    }

    // * Skip old asset paths (no longer supported)
    if (iconData.startsWith('assets/')) {
      return Icon(
        Icons.image_outlined,
        size: size,
        color: context.colorScheme.primary,
      );
    }

    // * Otherwise treat as file path (user uploaded image)
    final file = File(iconData);
    return Image.file(
      file,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        size: size,
        color: context.colorScheme.error,
      ),
    );
  }
}
