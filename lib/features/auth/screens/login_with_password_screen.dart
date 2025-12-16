import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../core/localization/app_localizations.dart';

class LoginWithPasswordScreen extends StatefulWidget {
  const LoginWithPasswordScreen({super.key});

  @override
  State<LoginWithPasswordScreen> createState() => _LoginWithPasswordScreenState();
}

class _LoginWithPasswordScreenState extends State<LoginWithPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = AppConstants.countryCode + _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(phone, password);
    if (!mounted) return;
    if (ok) {
      // Navigate immediately after login - don't wait for additional checks
      final role = auth.user?.role;
      if (role == 'merchant') {
        context.go('/merchant-dashboard');
      } else if (role == 'driver') {
        context.go('/driver-dashboard');
      } else if (role == 'admin') {
        context.go('/admin-dashboard');
      } else {
        context.go('/');
      }
    } else {
      final loc = AppLocalizations.of(context);
      final errorMessage = auth.error ?? loc.invalidCredentials;
      
      // Check if this is a "no account" error
      final isNoAccount = errorMessage.contains(loc.noAccountRegistered) || errorMessage.contains('No account');
      
      if (isNoAccount) {
        // Show dialog with action button to create account
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.noAccountTitle,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/role-selection');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(loc.createAccount),
              ),
            ],
          ),
        );
      } else {
        // Show regular snackbar for other errors
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).loginWithPassword),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          LanguageSwitcherButton(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo and branding (same style as signup)
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Center(
                  child: Container(
                    width: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.5),
                    height: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.05),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_shipping_rounded,
                          size: ResponsiveHelper.getResponsiveIconSize(context, MediaQuery.of(context).size.width * 0.2),
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          loc.welcomeBack,
                          style: AppTextStyles.responsiveHeading2(context).copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                        Text(
                          loc.enterPhonePassword,
                          style: AppTextStyles.responsiveBodyMedium(context).copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),

                // Phone
                Container(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      // Text field first
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 10,
                          decoration: const InputDecoration(border: InputBorder.none, hintText: '7XX XXX XXXX', counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                          validator: (v) {
                            final loc = AppLocalizations.of(context);
                            final val = (v ?? '').trim();
                            // Allow test numbers starting with 999, or regular numbers starting with 7
                            if (val.length != 10 || (!val.startsWith('7') && !val.startsWith('999'))) return loc.invalidPhone;
                            return null;
                          },
                        ),
                      ),
                      // Divider
                      Container(width: 1, height: 30, color: Colors.black12),
                      // Country code on the right
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        child: Text('+964', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Password
                Container(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context).password,
                      suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off)),
                      contentPadding: context.rp(horizontal: 16, vertical: 14),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? AppLocalizations.of(context).passwordRequired : null,
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                SizedBox(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  height: ResponsiveHelper.getFormElementHeight(context),
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white,
                      disabledForegroundColor: Colors.black54,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: auth.isLoading
                        ? SizedBox(width: context.ri(20), height: context.ri(20), child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(AppLocalizations.of(context).loginWithPassword),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    // Send OTP for reset via phone input screen
                    context.push('/phone-input', extra: 'login');
                  },
                  child: Text(AppLocalizations.of(context).forgotPassword, style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


