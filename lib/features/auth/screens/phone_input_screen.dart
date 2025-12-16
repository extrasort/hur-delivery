import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../core/localization/app_localizations.dart';
import 'otp_verification_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  final String role;
  
  const PhoneInputScreen({
    super.key,
    required this.role,
  });

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isValidPhone = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final phone = _phoneController.text.trim();
    final fullPhone = AppConstants.countryCode + phone;
    final regex = RegExp(AppConstants.phonePattern);
    // Allow test numbers:
    // - Driver test: 78000000XX (where XX is 00-99)
    // - Merchant test: 77000000XX (where XX is 00-99)
    // - Legacy test: 999XXXXXXX
    // - Regular numbers: starting with 7
    final isDriverTest = phone.startsWith('78000000') && phone.length == 10;
    final isMerchantTest = phone.startsWith('77000000') && phone.length == 10;
    final isLegacyTest = phone.startsWith('999') && phone.length == 10;
    final isRegular = phone.startsWith('7') && phone.length == 10;
    final isValidFormat = isDriverTest || isMerchantTest || isLegacyTest || isRegular;
    setState(() {
      _isValidPhone = isValidFormat && regex.hasMatch(fullPhone);
    });
  }

  String _getRoleDisplayName() {
    final loc = AppLocalizations.of(context);
    switch (widget.role) {
      case 'merchant':
        return loc.merchant;
      case 'driver':
        return loc.driver;
      case 'customer':
        return loc.customer;
      case 'login':
        return loc.login;
      default:
        return loc.user;
    }
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final fullPhone = AppConstants.countryCode + phone;

    final authProvider = context.read<AuthProvider>();
    final purpose = widget.role == 'login' ? 'reset_password' : 'signup';
    final success = await authProvider.sendOtpViaOtpiq(fullPhone, purpose: purpose);

    if (success && mounted) {
      _navigateToOTP(fullPhone);
    } else if (mounted) {
      final loc = AppLocalizations.of(context);
      final errorMessage = authProvider.error ?? loc.errorGeneric;
      
      // Check if this is a specific error that needs action buttons
      final isAlreadyRegistered = errorMessage.contains(loc.accountAlreadyRegistered);
      final isNoAccount = errorMessage.contains(loc.noAccountRegistered);
      
      if (isAlreadyRegistered || isNoAccount) {
        // Show dialog with action buttons for better UX
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isAlreadyRegistered ? Icons.info_outline : Icons.warning_amber_rounded,
                  color: isAlreadyRegistered ? AppColors.primary : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAlreadyRegistered ? loc.haveAccount : loc.noAccount,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                errorMessage,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Navigate to appropriate screen
                  if (isAlreadyRegistered) {
                    // User tried to signup but has account - go to login
                    context.go('/phone-input', extra: 'login');
                  } else {
                    // User tried to login but has no account - go to signup
                    context.go('/role-selection');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isAlreadyRegistered ? loc.login : loc.createAccount),
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
    return Scaffold(
      backgroundColor: AppColors.primary, // Hur teal background
      resizeToAvoidBottomInset: true, // Allow keyboard to resize the screen
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).phoneNumber),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          LanguageSwitcherButton(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: AppColors.textPrimary,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveHelper.getResponsivePadding(context, horizontal: MediaQuery.of(context).size.width * 0.06, vertical: MediaQuery.of(context).size.width * 0.06),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.05), // Replace Spacer
                
                // Logo and Branding - Larger like landing screen
                Column(
                  children: [
                    // Logo - Larger size like landing screen
                    Container(
                      width: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.5),
                      height: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.5),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.05), // 5% radius
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.local_shipping_rounded,
                            size: ResponsiveHelper.getResponsiveIconSize(context, MediaQuery.of(context).size.width * 0.2),
                            color: AppColors.textPrimary,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing
                    Text(
                      AppLocalizations.of(context).welcomeToHur,
                      style: AppTextStyles.responsiveHeading2(context).copyWith(
                        color: Colors.white,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, MediaQuery.of(context).size.width * 0.05),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 1% spacing
                    Text(
                      widget.role == 'login'
                          ? AppLocalizations.of(context).enterIraqiPhoneLogin
                          : AppLocalizations.of(context).enterIraqiPhoneOtp,
                      style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, MediaQuery.of(context).size.width * 0.035),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                SizedBox(height: MediaQuery.of(context).size.height * 0.1), // Replace Spacer
                
                // Phone Input and Button
                Column(
                  children: [
                    // Phone Input with LTR layout
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ResponsiveText(
                          AppLocalizations.of(context).phoneNumber,
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: context.rf(18),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.rs(8)),
                        Center(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Container(
                              width: ResponsiveHelper.getFormElementWidth(context),
                              height: ResponsiveHelper.getFormElementHeight(context),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(context.rs(12)),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Country code on the left - Fixed padding
                                Container(
                                  padding: context.rp(horizontal: 16, vertical: 12),
                                  child: ResponsiveText(
                                    '+964',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: context.rf(14),
                                    ),
                                  ),
                                ),
                                // Divider - Fixed size
                                Container(
                                  height: context.rs(30),
                                  width: 1,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                // Phone number input
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.black,
                                      fontSize: context.rf(14),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '7XX XXX XXXX',
                                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                                        color: Colors.grey.withOpacity(0.6),
                                        fontSize: context.rf(14),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: context.rp(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      counterText: '',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return AppLocalizations.of(context)
                                            .phoneRequired;
                                      }
                                      if (value.length != 10) {
                                        return AppLocalizations.of(context)
                                            .phoneMustBe10Digits;
                                      }
                                      // Allow test numbers:
                                      // - Driver test: 78000000XX
                                      // - Merchant test: 77000000XX
                                      // - Legacy test: 999XXXXXXX
                                      // - Regular numbers: starting with 7
                                      final isDriverTest = value.startsWith('78000000');
                                      final isMerchantTest = value.startsWith('77000000');
                                      final isLegacyTest = value.startsWith('999');
                                      final isRegular = value.startsWith('7');
                                      if (!isDriverTest &&
                                          !isMerchantTest &&
                                          !isLegacyTest &&
                                          !isRegular) {
                                        return AppLocalizations.of(context)
                                            .phoneMustStartWithPattern;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03), // 3% spacing
                    
                    // Send OTP Button - Responsive
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        return Container(
                          width: ResponsiveHelper.getFormElementWidth(context),
                          height: ResponsiveHelper.getFormElementHeight(context),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isValidPhone && !authProvider.isLoading ? () { _sendOTP(); } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black, // Black text for visibility
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.rs(12)),
                              ),
                              minimumSize: Size(ResponsiveHelper.getFormElementWidth(context), ResponsiveHelper.getFormElementHeight(context)),
                              padding: context.rp(horizontal: 0, vertical: 12),
                            ),
                            child: authProvider.isLoading
                                ? SizedBox(
                                    width: context.ri(20),
                                    height: context.ri(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  )
                                    : ResponsiveText(
                                        AppLocalizations.of(context)
                                            .sendCode, // generic send code label
                                        style:
                                            AppTextStyles.buttonMedium.copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: context.rf(16),
                                        ),
                                      ),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: context.rs(16)),
                    
                    // Back Button - Consistent with PrimaryButton style
                    Center(
                      child: Container(
                        width: ResponsiveHelper.getFormElementWidth(context),
                        height: ResponsiveHelper.getFormElementHeight(context),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(context.rs(12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black, // Black text for visibility
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(context.rs(12)),
                            ),
                            minimumSize: Size(double.infinity, ResponsiveHelper.getFormElementHeight(context)),
                            padding: context.rp(horizontal: 0, vertical: 12),
                          ),
                          child: ResponsiveText(
                            AppLocalizations.of(context).back,
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: context.rf(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToOTP(String phone) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => OtpVerificationScreen(
          phone: phone,
          role: widget.role, // Pass the role
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
