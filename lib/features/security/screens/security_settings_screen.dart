import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_colors.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/other/widgets/setting_group.dart';
import 'package:ikuyo_finance/features/other/widgets/setting_tile.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/widgets/pin_setup_dialog.dart';
import 'package:ikuyo_finance/features/security/widgets/password_setup_dialog.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText(
          LocaleKeys.securitySettingsTitle.tr(),
          style: AppTextStyle.titleLarge,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      body: ScreenWrapper(
        child: BlocBuilder<SecurityCubit, SecurityState>(
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // * Master toggle
                  SettingGroup(
                    title: LocaleKeys.securitySettingsGeneral.tr(),
                    children: [
                      SettingTile(
                        icon: Icons.shield_outlined,
                        title: LocaleKeys.securitySettingsEnable.tr(),
                        subtitle: LocaleKeys.securitySettingsEnableDesc.tr(),
                        trailing: Switch.adaptive(
                          value: state.settings.isEnabled,
                          onChanged: (value) =>
                              _toggleSecurity(context, value, state),
                        ),
                      ),
                    ],
                  ),

                  if (state.settings.isEnabled) ...[
                    const SizedBox(height: 24),

                    // * Auth methods
                    SettingGroup(
                      title: LocaleKeys.securitySettingsMethods.tr(),
                      children: [
                        // * Biometric
                        SettingTile(
                          icon: Icons.fingerprint,
                          title: LocaleKeys.securitySettingsBiometric.tr(),
                          subtitle: state.biometricAvailable
                              ? LocaleKeys.securitySettingsBiometricDesc.tr()
                              : LocaleKeys.securitySettingsBiometricUnavailable
                                    .tr(),
                          trailing: Switch.adaptive(
                            value: state.settings.biometricEnabled,
                            onChanged: state.biometricAvailable
                                ? (v) => context
                                      .read<SecurityCubit>()
                                      .toggleBiometric(v)
                                : null,
                          ),
                        ),
                        // * PIN
                        SettingTile(
                          icon: Icons.dialpad_rounded,
                          title: LocaleKeys.securitySettingsPin.tr(),
                          subtitle: state.settings.pinEnabled
                              ? LocaleKeys.securitySettingsPinActive.tr()
                              : LocaleKeys.securitySettingsPinDesc.tr(),
                          trailing: Switch.adaptive(
                            value: state.settings.pinEnabled,
                            onChanged: (v) => _handlePinToggle(context, v),
                          ),
                        ),
                        // * Password
                        SettingTile(
                          icon: Icons.password_rounded,
                          title: LocaleKeys.securitySettingsPassword.tr(),
                          subtitle: state.settings.passwordEnabled
                              ? LocaleKeys.securitySettingsPasswordActive.tr()
                              : LocaleKeys.securitySettingsPasswordDesc.tr(),
                          trailing: Switch.adaptive(
                            value: state.settings.passwordEnabled,
                            onChanged: (v) => _handlePasswordToggle(context, v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // * Lock behavior
                    SettingGroup(
                      title: LocaleKeys.securitySettingsLockBehavior.tr(),
                      children: [
                        // * Lock trigger
                        _LockTriggerTile(
                          currentTrigger: state.settings.lockTrigger,
                          onChanged: (trigger) => context
                              .read<SecurityCubit>()
                              .setLockTrigger(trigger),
                        ),
                        // * Auto-lock duration
                        _AutoLockDurationTile(
                          currentMinutes: state.settings.autoLockMinutes,
                          onChanged: (minutes) => context
                              .read<SecurityCubit>()
                              .setAutoLockMinutes(minutes),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // * Change PIN / Password
                    if (state.settings.pinEnabled ||
                        state.settings.passwordEnabled)
                      SettingGroup(
                        title: LocaleKeys.securitySettingsManage.tr(),
                        children: [
                          if (state.settings.pinEnabled)
                            SettingTile(
                              icon: Icons.edit_outlined,
                              title: LocaleKeys.securitySettingsChangePin.tr(),
                              showChevron: true,
                              onTap: () => _showPinSetup(context),
                            ),
                          if (state.settings.passwordEnabled)
                            SettingTile(
                              icon: Icons.edit_outlined,
                              title: LocaleKeys.securitySettingsChangePassword
                                  .tr(),
                              showChevron: true,
                              onTap: () => _showPasswordSetup(context),
                            ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleSecurity(
    BuildContext context,
    bool enabled,
    SecurityState state,
  ) {
    // * Jika enable tapi belum set method apapun, paksa set minimal satu
    if (enabled &&
        !state.settings.pinEnabled &&
        !state.settings.passwordEnabled &&
        !state.settings.biometricEnabled) {
      // * Otomatis buka PIN setup dulu
      _showPinSetup(context, enableSecurityAfter: true);
      return;
    }
    context.read<SecurityCubit>().toggleSecurity(enabled);
  }

  void _handlePinToggle(BuildContext context, bool enabled) {
    if (enabled) {
      _showPinSetup(context);
    } else {
      context.read<SecurityCubit>().removePin();
    }
  }

  void _handlePasswordToggle(BuildContext context, bool enabled) {
    if (enabled) {
      _showPasswordSetup(context);
    } else {
      context.read<SecurityCubit>().removePassword();
    }
  }

  void _showPinSetup(BuildContext context, {bool enableSecurityAfter = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<SecurityCubit>(),
        child: PinSetupDialog(
          onSuccess: () {
            if (enableSecurityAfter) {
              context.read<SecurityCubit>().toggleSecurity(true);
            }
            ToastHelper.instance.showSuccess(
              context: context,
              title: LocaleKeys.securityPinSetSuccess.tr(),
            );
          },
        ),
      ),
    );
  }

  void _showPasswordSetup(
    BuildContext context, {
    bool enableSecurityAfter = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<SecurityCubit>(),
        child: PasswordSetupDialog(
          onSuccess: () {
            if (enableSecurityAfter) {
              context.read<SecurityCubit>().toggleSecurity(true);
            }
            ToastHelper.instance.showSuccess(
              context: context,
              title: LocaleKeys.securityPasswordSetSuccess.tr(),
            );
          },
        ),
      ),
    );
  }
}

// ─── Lock Trigger Tile ──────────────────────────────

class _LockTriggerTile extends StatelessWidget {
  final LockTrigger currentTrigger;
  final ValueChanged<LockTrigger> onChanged;

  const _LockTriggerTile({
    required this.currentTrigger,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SettingTile(
      icon: Icons.lock_clock_outlined,
      title: LocaleKeys.securitySettingsLockTrigger.tr(),
      subtitle: _triggerLabel(currentTrigger),
      showChevron: true,
      onTap: () => _showTriggerPicker(context, colors),
    );
  }

  String _triggerLabel(LockTrigger trigger) {
    switch (trigger) {
      case LockTrigger.onAppClose:
        return LocaleKeys.securityTriggerAppClose.tr();
      case LockTrigger.onScreenOff:
        return LocaleKeys.securityTriggerScreenOff.tr();
      case LockTrigger.both:
        return LocaleKeys.securityTriggerBoth.tr();
    }
  }

  void _showTriggerPicker(BuildContext context, AppColorsTheme colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.securitySettingsLockTrigger.tr(),
              style: AppTextStyle.titleMedium,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 8),
            ...LockTrigger.values.map((trigger) {
              return RadioListTile<LockTrigger>(
                value: trigger,
                groupValue: currentTrigger,
                title: Text(_triggerLabel(trigger)),
                activeColor: colors.primary,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Auto Lock Duration Tile ────────────────────────

class _AutoLockDurationTile extends StatelessWidget {
  final int currentMinutes;
  final ValueChanged<int> onChanged;

  const _AutoLockDurationTile({
    required this.currentMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SettingTile(
      icon: Icons.timer_outlined,
      title: LocaleKeys.securitySettingsAutoLock.tr(),
      subtitle: _durationLabel(currentMinutes),
      showChevron: true,
      onTap: () => _showDurationPicker(context, colors),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes == 0) return LocaleKeys.securityAutoLockImmediate.tr();
    if (minutes == 1) return LocaleKeys.securityAutoLock1Min.tr();
    return LocaleKeys.securityAutoLockNMin.tr(args: [minutes.toString()]);
  }

  void _showDurationPicker(BuildContext context, AppColorsTheme colors) {
    final presets = [0, 1, 2, 5, 10, 15, 30];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.securitySettingsAutoLock.tr(),
              style: AppTextStyle.titleMedium,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 8),
            ...presets.map((m) {
              return RadioListTile<int>(
                value: m,
                groupValue: currentMinutes,
                title: Text(_durationLabel(m)),
                activeColor: colors.primary,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                  Navigator.pop(ctx);
                },
              );
            }),
            // * Custom duration
            ListTile(
              leading: Radio<int>(
                value: -1,
                groupValue: presets.contains(currentMinutes)
                    ? null
                    : currentMinutes,
                activeColor: colors.primary,
                onChanged: (_) {},
              ),
              title: Text(LocaleKeys.securityAutoLockCustom.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _showCustomDurationDialog(context, colors);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCustomDurationDialog(BuildContext context, AppColorsTheme colors) {
    final controller = TextEditingController(
      text: currentMinutes > 0 ? currentMinutes.toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.securityAutoLockCustomTitle.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: LocaleKeys.securityAutoLockCustomHint.tr(),
            suffixText: LocaleKeys.securityAutoLockMinutes.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleKeys.securityCancel.tr()),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 0 && value <= 1440) {
                onChanged(value);
              }
              Navigator.pop(ctx);
            },
            child: Text(LocaleKeys.securitySave.tr()),
          ),
        ],
      ),
    );
    controller.dispose;
  }
}
