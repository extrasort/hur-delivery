import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/localization/app_localizations.dart';

class CreatePasswordScreen extends StatefulWidget {
  final String phoneE164;
  final String role;
  final String? otpCode; // passed from OTP screen

  const CreatePasswordScreen({super.key, required this.phoneE164, required this.role, this.otpCode});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final password = _passwordController.text.trim();
    bool ok = await auth.signUpWithPassword(widget.phoneE164, password, otpCode: widget.otpCode);
    // If still not ok and code exists, try reset+login as fallback
    if (!ok && (widget.otpCode?.isNotEmpty ?? false)) {
      final resetOk = await auth.resetPasswordWithOtp(phoneE164: widget.phoneE164, code: widget.otpCode!, newPassword: password);
      if (resetOk) {
        ok = await auth.loginWithPassword(widget.phoneE164, password);
      }
    }
    if (!mounted) return;
    if (ok) {
      // Proceed to registration form for role
      Navigator.of(context).pushReplacementNamed('/user-registration', arguments: widget.role);
    } else {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? loc.accountCreationFailed), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).createPassword),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Center(
                  child: Container(
                    width: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.5),
                    height: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.5),
                    decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.05)),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.local_shipping_rounded, size: ResponsiveHelper.getResponsiveIconSize(context, MediaQuery.of(context).size.width * 0.2), color: Colors.white);
                    }),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          loc.chooseStrongPassword,
                          style: AppTextStyles.responsiveHeading2(context).copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                        Text(
                          loc.lettersNumbersOnly8Min,
                          style: AppTextStyles.responsiveBodyMedium(context).copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                Container(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '********',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (v) {
                      final loc = AppLocalizations.of(context);
                      final val = (v ?? '').trim();
                      if (val.isEmpty) return loc.passwordRequired;
                      final ok = RegExp(r'^[A-Za-z0-9]{8,}$').hasMatch(val);
                      if (!ok) return loc.lettersNumbersOnly8Min;
                      return null;
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                SizedBox(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  height: ResponsiveHelper.getFormElementHeight(context),
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(AppLocalizations.of(context).createAccount),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


