import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/localization/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String phoneE164;
  final String? prefilledCode;

  const ResetPasswordScreen({super.key, required this.phoneE164, this.prefilledCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null) {
      _codeController.text = widget.prefilledCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPasswordWithOtp(
      phoneE164: widget.phoneE164,
      code: _codeController.text.trim(),
      newPassword: _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.passwordUpdatedSuccess)), 
      );
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? loc.passwordUpdateFailed), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).resetPassword),
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
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                Text(AppLocalizations.of(context).enterCodeNewPassword, style: AppTextStyles.responsiveHeading2(context).copyWith(color: Colors.white), textAlign: TextAlign.center),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                // Code field
                Container(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    decoration: InputDecoration(border: InputBorder.none, hintText: AppLocalizations.of(context).verificationCode, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    validator: (v) {
                      final loc = AppLocalizations.of(context);
                      final val = (v ?? '').trim();
                      if (val.length != 6) return loc.enter6DigitCode;
                      return null;
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Password field
                Container(
                  width: ResponsiveHelper.getFormElementWidth(context),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context).newPassword,
                      suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off)),
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
                        : Text(AppLocalizations.of(context).updatePassword),
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


