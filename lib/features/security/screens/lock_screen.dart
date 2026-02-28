import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_colors.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Lock screen yang tampil saat app terkunci
/// Flow: Biometric → PIN → Password (flexible, bisa langsung pilih)
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  _AuthView _currentView = _AuthView.biometric;
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _hasTriedBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
  }

  @override
  void dispose() {
    _pinController.dispose();
    _passwordController.dispose();
    _pinFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _autoStart() {
    final state = context.read<SecurityCubit>().state;

    // * Otomatis coba biometric dulu jika tersedia
    if (state.canUseBiometric && !_hasTriedBiometric) {
      _hasTriedBiometric = true;
      _currentView = _AuthView.biometric;
      context.read<SecurityCubit>().authenticateWithBiometric();
    } else if (state.canUsePin) {
      setState(() => _currentView = _AuthView.pin);
    } else if (state.canUsePassword) {
      setState(() => _currentView = _AuthView.password);
    }
  }

  void _switchToPin() {
    setState(() => _currentView = _AuthView.pin);
    _pinController.clear();
    context.read<SecurityCubit>().clearAuthResult();
    Future.delayed(
      const Duration(milliseconds: 150),
      () => _pinFocus.requestFocus(),
    );
  }

  void _switchToPassword() {
    setState(() => _currentView = _AuthView.password);
    _passwordController.clear();
    context.read<SecurityCubit>().clearAuthResult();
    Future.delayed(
      const Duration(milliseconds: 150),
      () => _passwordFocus.requestFocus(),
    );
  }

  void _retryBiometric() {
    context.read<SecurityCubit>().authenticateWithBiometric();
  }

  void _submitPin() {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    context.read<SecurityCubit>().authenticateWithPin(pin);
  }

  void _submitPassword() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;
    context.read<SecurityCubit>().authenticateWithPassword(password);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocListener<SecurityCubit, SecurityState>(
      listenWhen: (prev, curr) => prev.authResult != curr.authResult,
      listener: (context, state) {
        if (state.authResult == SecurityAuthResult.failed) {
          // * Haptic feedback saat gagal
          HapticFeedback.heavyImpact();
          _pinController.clear();
          _passwordController.clear();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // * App icon / lock icon
                  _buildLockIcon(colors),
                  const SizedBox(height: 24),

                  AppText(
                    LocaleKeys.securityLockTitle.tr(),
                    style: AppTextStyle.headlineSmall,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    LocaleKeys.securityLockSubtitle.tr(),
                    style: AppTextStyle.bodyMedium,
                    color: colors.textSecondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // * Auth content
                  BlocBuilder<SecurityCubit, SecurityState>(
                    builder: (context, state) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildAuthContent(context, state, colors),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // * Navigation antara metode
                  _buildMethodSwitcher(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon(AppColorsTheme colors) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.lock_outline_rounded, size: 40, color: colors.primary),
    );
  }

  Widget _buildAuthContent(
    BuildContext context,
    SecurityState state,
    AppColorsTheme colors,
  ) {
    switch (_currentView) {
      case _AuthView.biometric:
        return _buildBiometricView(context, state, colors);
      case _AuthView.pin:
        return _buildPinView(context, state, colors);
      case _AuthView.password:
        return _buildPasswordView(context, state, colors);
    }
  }

  // ─── Biometric View ─────────────────────────────────

  Widget _buildBiometricView(
    BuildContext context,
    SecurityState state,
    AppColorsTheme colors,
  ) {
    return Column(
      key: const ValueKey('biometric'),
      children: [
        if (state.authResult == SecurityAuthResult.failed)
          _buildErrorBanner(LocaleKeys.securityBiometricFailed.tr(), colors),
        const SizedBox(height: 16),
        // * Biometric button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: state.status == SecurityStatus.authenticating
                ? null
                : _retryBiometric,
            icon: const Icon(Icons.fingerprint, size: 28),
            label: AppText(
              state.status == SecurityStatus.authenticating
                  ? LocaleKeys.securityAuthenticating.tr()
                  : LocaleKeys.securityUseBiometric.tr(),
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.w600,
              color: colors.textOnPrimary,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PIN View ───────────────────────────────────────

  Widget _buildPinView(
    BuildContext context,
    SecurityState state,
    AppColorsTheme colors,
  ) {
    return Column(
      key: const ValueKey('pin'),
      children: [
        if (state.authResult == SecurityAuthResult.failed)
          _buildErrorBanner(LocaleKeys.securityPinIncorrect.tr(), colors),
        const SizedBox(height: 16),
        // * PIN input
        TextField(
          controller: _pinController,
          focusNode: _pinFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          obscureText: true,
          style: TextStyle(
            fontSize: 24,
            letterSpacing: 12,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: TextStyle(color: colors.textTertiary),
            counterText: '',
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
          ),
          onSubmitted: (_) => _submitPin(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: AppText(
              LocaleKeys.securityUnlock.tr(),
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.w600,
              color: colors.textOnPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Password View ──────────────────────────────────

  Widget _buildPasswordView(
    BuildContext context,
    SecurityState state,
    AppColorsTheme colors,
  ) {
    return Column(
      key: const ValueKey('password'),
      children: [
        if (state.authResult == SecurityAuthResult.failed)
          _buildErrorBanner(LocaleKeys.securityPasswordIncorrect.tr(), colors),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          style: TextStyle(fontSize: 16, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: LocaleKeys.securityEnterPassword.tr(),
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: colors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _submitPassword(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: AppText(
              LocaleKeys.securityUnlock.tr(),
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.w600,
              color: colors.textOnPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────

  Widget _buildErrorBanner(String message, AppColorsTheme colors) {
    final semantic = context.semantic;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: semantic.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: semantic.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: semantic.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              message,
              style: AppTextStyle.bodySmall,
              color: semantic.errorDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSwitcher(BuildContext context) {
    final state = context.watch<SecurityCubit>().state;
    final colors = context.colors;

    return Column(
      children: [
        // * Biometric button (jika tidak di biometric view)
        if (_currentView != _AuthView.biometric && state.canUseBiometric)
          _buildSwitchButton(
            icon: Icons.fingerprint,
            label: LocaleKeys.securityUseBiometric.tr(),
            onTap: () {
              setState(() => _currentView = _AuthView.biometric);
              _retryBiometric();
            },
            colors: colors,
          ),

        // * PIN button (jika tidak di pin view)
        if (_currentView != _AuthView.pin && state.canUsePin)
          _buildSwitchButton(
            icon: Icons.dialpad_rounded,
            label: LocaleKeys.securityUsePin.tr(),
            onTap: _switchToPin,
            colors: colors,
          ),

        // * Password button (jika tidak di password view)
        if (_currentView != _AuthView.password && state.canUsePassword)
          _buildSwitchButton(
            icon: Icons.password_rounded,
            label: LocaleKeys.securityUsePassword.tr(),
            onTap: _switchToPassword,
            colors: colors,
          ),
      ],
    );
  }

  Widget _buildSwitchButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppColorsTheme colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: colors.primary),
        label: AppText(
          label,
          style: AppTextStyle.bodyMedium,
          color: colors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

enum _AuthView { biometric, pin, password }
