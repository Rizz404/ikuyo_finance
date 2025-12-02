import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/shared/utils/icon_registry.dart';
import 'package:ikuyo_finance/shared/widgets/app_image.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback? onTap;

  const AssetCard({super.key, required this.asset, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getAssetColor(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return GestureDetector(
      onTap: onTap ?? () => context.pushToEditAsset(asset),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // * Asset Icon
            _buildAssetIconContainer(context, color),
            const SizedBox(width: 12),
            // * Asset Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    asset.name,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AppText(
                      _getAssetTypeLabel(),
                      style: AppTextStyle.labelSmall,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // * Balance
            AppText(
              currencyFormat.format(asset.balance),
              style: AppTextStyle.bodyMedium,
              fontWeight: FontWeight.bold,
              color: asset.balance >= 0
                  ? context.semantic.success
                  : context.semantic.error,
            ),
          ],
        ),
      ),
    );
  }

  String _getAssetTypeLabel() {
    return switch (asset.assetType) {
      AssetType.cash => 'Kas',
      AssetType.bank => 'Bank',
      AssetType.eWallet => 'E-Wallet',
      AssetType.stock => 'Saham',
      AssetType.crypto => 'Crypto',
    };
  }

  Color _getAssetColor(BuildContext context) {
    return switch (asset.assetType) {
      AssetType.cash => Colors.green,
      AssetType.bank => Colors.blue,
      AssetType.eWallet => Colors.orange,
      AssetType.stock => Colors.purple,
      AssetType.crypto => Colors.amber,
    };
  }

  IconData _getAssetIcon() {
    return switch (asset.assetType) {
      AssetType.cash => Icons.wallet_outlined,
      AssetType.bank => Icons.account_balance_outlined,
      AssetType.eWallet => Icons.phone_android_outlined,
      AssetType.stock => Icons.trending_up_outlined,
      AssetType.crypto => Icons.currency_bitcoin_outlined,
    };
  }

  /// * Check if icon is from registry (not a file path)
  bool _isRegistryIcon(String? iconData) {
    if (iconData == null || iconData.isEmpty) return true;
    return IconRegistry.isIconKey(iconData);
  }

  Widget _buildAssetIconContainer(BuildContext context, Color color) {
    final iconData = asset.icon;
    final isRegistryIcon = _isRegistryIcon(iconData);

    // * User uploaded image - show without colored background
    if (!isRegistryIcon && iconData != null && iconData.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: AppImage.icon(iconData: iconData, size: 48),
        ),
      );
    }

    // * Flutter Icon - show with colored background
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: _buildAssetIcon(context, color)),
    );
  }

  Widget _buildAssetIcon(BuildContext context, Color color) {
    final iconData = asset.icon;

    // * Jika ada icon data (registry key)
    if (iconData != null && iconData.isNotEmpty) {
      final icon = IconRegistry.getIcon(iconData);
      if (icon != null) {
        return Icon(icon, size: 24, color: color);
      }
    }

    // * Fallback ke icon default berdasarkan tipe
    return Icon(_getAssetIcon(), color: color, size: 24);
  }
}
