import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import 'user_registration_screen.dart';
import '../../../core/localization/app_localizations.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final String role; // Add role parameter
  
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.role,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _countdown = 60;
  bool _canResend = false;
  String _deliveryMethod = 'WhatsApp';

  @override
  void initState() {
    super.initState();
    _startCountdown();
    
    // Check if this is a test number and auto-fill OTP
    final cleaned = widget.phone.replaceAll(RegExp(r'[^\d]'), '');
    final isDriverTest = cleaned.startsWith('96478000000') && cleaned.length == 13;
    final isMerchantTest = cleaned.startsWith('96477000000') && cleaned.length == 13;
    
    if (isDriverTest || isMerchantTest) {
      // Auto-fill OTP 000000 for test numbers
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpController.text = '000000';
        // Also fill individual controllers for the 6-digit display
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = '0';
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _countdown = seconds;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String _getOTP() {
    return _otpController.text;
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOTP();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    if (otp.length != 6) return;

    final authProvider = context.read<AuthProvider>();
    // Unified authentication flow - no longer uses purpose parameter
    final success = await authProvider.verifyOtpViaOtpiq(widget.phone, otp);

    if (success && mounted) {
      final auth = context.read<AuthProvider>();
      
      // Check if user is authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user after OTP verification');
        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.otpFailedIdentity),
              backgroundColor: AppColors.error,
            ),
          );
          context.go('/');
        }
        return;
      }
      
      print('✅ OTP verified successfully for user: ${currentUser.id}');
      
      // Load profile in background (keeps logic responsive)
      unawaited(auth.loadUserProfile());
      
      final quickRole = await _resolveUserRoleQuickly(auth, currentUser);
      if (quickRole != null && quickRole.isNotEmpty) {
        _navigateByRole(quickRole);
                return;
              }
      
      await _handleRoleResolutionFallback(auth, currentUser);
    } else if (mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? loc.otpInvalid),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    final authProvider = context.read<AuthProvider>();
    // Unified authentication flow - use signup purpose for all
    final success = await authProvider.sendOtpViaOtpiq(widget.phone, purpose: 'signup');

    if (success && mounted) {
      _startCountdown();
      setState(() { _deliveryMethod = 'WhatsApp'; });
      
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.otpResentVia(_deliveryMethod),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      final retry = authProvider.otpRetryAfterSeconds;
      if (retry != null && retry > 0) {
        _startCountdown(retry);
      }
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? loc.otpSendError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _resolveUserRoleQuickly(AuthProvider auth, User currentUser) async {
    // 1) Cache/profile memory
    final cachedRole = auth.user?.role;
    if (cachedRole != null && cachedRole.isNotEmpty) {
      print('⚡ Using cached profile role: $cachedRole');
      return cachedRole;
    }

    // 2) Fast DB lookup by ID (single query, short timeout)
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('⏱️ Role lookup timed out');
              return null;
            },
          );
      final dbRole = response?['role'] as String?;
      if (dbRole != null && dbRole.isNotEmpty) {
        print('⚡ Quick DB role lookup succeeded: $dbRole');
        return dbRole;
      }
    } catch (e) {
      print('⚠️ Quick role lookup error: $e');
    }

    // 3) No role yet (probably new user)
    return null;
  }

  Future<void> _handleRoleResolutionFallback(AuthProvider auth, User currentUser) async {
    print('🧭 Entering fallback role resolution flow');
    
    Map<String, dynamic>? profileCheck;
    String? userRole;
    final user = auth.user;
    
    try {
      profileCheck = await Supabase.instance.client
          .from('users')
          .select('role, id, phone')
          .eq('id', currentUser.id)
          .maybeSingle();
    } catch (e) {
      print('⚠️ Fallback lookup by ID failed: $e');
    }
    
    if (profileCheck != null) {
      userRole = profileCheck['role'] as String?;
    } else if (widget.phone.isNotEmpty) {
      try {
        String cleanedPhone = widget.phone.replaceAll(RegExp(r'[^\d]'), '');
        cleanedPhone = cleanedPhone.replaceFirst(RegExp(r'^0+'), '');
        if (!cleanedPhone.startsWith('964')) {
          cleanedPhone = '964$cleanedPhone';
        }
        final phoneWithPlus = '+$cleanedPhone';

        profileCheck = await Supabase.instance.client
            .from('users')
            .select('role, id, phone')
            .or('phone.eq.$cleanedPhone,phone.eq.$phoneWithPlus')
            .maybeSingle();

        userRole ??= profileCheck?['role'] as String?;
      } catch (e) {
        print('⚠️ Fallback phone search failed: $e');
      }
    }

    if (userRole != null && userRole.isNotEmpty) {
      _navigateByRole(userRole);
      return;
    }

    // Handle new user / missing profile flows
    final routeRole = widget.role.trim().toLowerCase();
    final isLoginFlow = routeRole == 'login';

    if (isLoginFlow) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).noAccountRegisteredThisNumber),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: AppLocalizations.of(context).register,
              textColor: Colors.white,
              onPressed: () {
                context.go('/role-selection');
              },
            ),
          ),
        );
        context.go('/');
      }
      return;
    }

    if (routeRole == 'merchant' || routeRole == 'driver') {
      print('🆕 New user detected, navigating to registration: $routeRole');
      if (mounted) context.go('/user-registration', extra: routeRole);
      return;
    }

    if (user != null) {
      print('🚨 Existing user but no role found even after fallback');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).userDataErrorContactSupport),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
        context.go('/');
      }
      return;
    }

    // Default: send to merchant registration
    if (mounted) context.go('/user-registration', extra: 'merchant');
  }

  void _navigateByRole(String role) {
    final normalizedRole = role.trim().toLowerCase();
    print('➡️ Fast navigation using role: $normalizedRole');

    switch (normalizedRole) {
      case 'merchant':
        if (mounted) context.go('/merchant-dashboard');
        break;
      case 'driver':
        if (mounted) context.go('/driver-dashboard');
        break;
      case 'admin':
        if (mounted) context.go('/admin-dashboard');
        break;
      case 'customer':
        if (mounted) context.go('/');
        break;
      default:
        if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary, // Hur teal background
      resizeToAvoidBottomInset: true, // Allow keyboard to resize the screen
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).verifyCode),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          LanguageSwitcherButton(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight - 50,
            ),
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06), // 6% padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing
                  
                  // Logo - Larger like landing screen
                  Center(
                    child: Container(
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
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing - consistent with phone input
                  
                  // Header - Responsive
                  Text(
                    AppLocalizations.of(context).enterOtp,
                    style: AppTextStyles.responsiveHeading2(context).copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 1% spacing
                  Text(
                    '${AppLocalizations.of(context).otpSentTo} +${widget.phone}',
                    style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Show test number hint if applicable
                  Builder(
                    builder: (context) {
                      final cleaned = widget.phone.replaceAll(RegExp(r'[^\d]'), '');
                      final isDriverTest = cleaned.startsWith('96478000000') && cleaned.length == 13;
                      final isMerchantTest = cleaned.startsWith('96477000000') && cleaned.length == 13;
                      
                      if (isDriverTest || isMerchantTest) {
                        return Padding(
                          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.01),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width * 0.04,
                              vertical: MediaQuery.of(context).size.height * 0.01,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).testNumberHint,
                              style: AppTextStyles.responsiveBodySmall(context).copyWith(
                                color: Colors.orange.shade100,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 1% spacing
                  // WhatsApp delivery method indicator
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.012,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.2), // WhatsApp green tint
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF25D366).withOpacity(0.5), // WhatsApp green border
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp icon (using Material icon that looks similar)
                        Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.01),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366), // WhatsApp green
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 18),
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.025),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'WhatsApp',
                              style: AppTextStyles.responsiveBodySmall(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context).sentViaWhatsapp,
                              style: AppTextStyles.responsiveBodySmall(context).copyWith(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w400,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.06), // 6% spacing
                  
                  // OTP Input Field - Elegant and compact
                  Center(
                    child: Container(
                      width: ResponsiveHelper.getFormElementWidth(context),
                      height: ResponsiveHelper.getFormElementHeight(context),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        textDirection: TextDirection.ltr,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          // Auto-verify when 6 digits are entered
                          if (value.length == 6) {
                            _verifyOTP();
                          }
                        },
                        style: TextStyle(
                          letterSpacing: ResponsiveHelper.getResponsiveSpacing(context, 2),
                          color: Colors.black,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: ResponsiveHelper.getResponsivePadding(context, horizontal: 16, vertical: 12),
                          hintText: '000000',
                          hintStyle: TextStyle(
                            letterSpacing: ResponsiveHelper.getResponsiveSpacing(context, 2),
                            color: Colors.grey.shade400,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, MediaQuery.of(context).size.height * 0.02)), // Reduced spacing
                  
                  // Verify Button - Matching input field dimensions and directly below
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
                          onPressed: _getOTP().length == 6 && !authProvider.isLoading ? () { _verifyOTP(); } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black, // Black text for visibility
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(double.infinity, ResponsiveHelper.getFormElementHeight(context)),
                            padding: ResponsiveHelper.getResponsivePadding(context, horizontal: 12, vertical: 12),
                          ),
                          child: authProvider.isLoading
                              ? SizedBox(
                                  width: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                  height: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context).confirmOtp,
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, MediaQuery.of(context).size.height * 0.02)),
                  
                  // Resend OTP - Below verify button
                  Center(
                    child: _canResend
                        ? TextButton(
                            onPressed: _resendOTP,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: ResponsiveHelper.getResponsivePadding(context, horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              AppLocalizations.of(context).resendOtp,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context)
                                .resendInSeconds(_countdown),
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                  ),
                  
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, MediaQuery.of(context).size.height * 0.02)),
                  
                  // Back Button - Matching form element dimensions
                  Center(
                    child: Container(
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
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black, // Black text for visibility
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                            minimumSize: Size(double.infinity, ResponsiveHelper.getFormElementHeight(context)),
                            padding: ResponsiveHelper.getResponsivePadding(context, horizontal: 12, vertical: 12),
                        ),
                        child: Text(
                          AppLocalizations.of(context).changePhone,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
