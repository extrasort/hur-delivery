import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/language_switcher.dart';
import 'phone_input_screen.dart';
import 'role_selection_screen.dart';
import '../../../core/localization/app_localizations.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary, // Solid Hur teal background
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: ResponsiveHelper.getResponsivePadding(context, horizontal: MediaQuery.of(context).size.width * 0.06, vertical: MediaQuery.of(context).size.width * 0.06),
              child: Column(
                children: [
                  const Spacer(),
              
              // App Logo and Branding - Animated
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            // Logo with clean background
                            Container(
                              width: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.6),
                              height: ResponsiveHelper.getResponsiveLogoSize(context, MediaQuery.of(context).size.width * 0.6),
                              child: Image.asset(
                                'assets/images/logo.png', // Your logo
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback icon if logo is not found - Responsive size
                                  return Icon(
                                    Icons.local_shipping_rounded,
                                    size: ResponsiveHelper.getResponsiveIconSize(context, MediaQuery.of(context).size.width * 0.5),
                                    color: AppColors.textPrimary,
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: context.rs(24)),
                            ResponsiveText(
                              loc.fastDeliveryService,
                              style: AppTextStyles.responsiveBodyLarge(context).copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: context.rf(20),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.rs(16)),
                            ResponsiveText(
                              loc.platformForDriversMerchants,
                              style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: context.rf(16),
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const Spacer(),
              
              // Action Buttons - Responsive
              Center(
                child: Column(
                  children: [
                  Container(
                    width: ResponsiveHelper.getFormElementWidth(context),
                    margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveSpacing(context, 24)),
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
                      onPressed: () => _navigateToLogin(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black, // Black text for visibility
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rs(12)),
                        ),
                        minimumSize: Size(double.infinity, context.rh(53)),
                        padding: context.rp(horizontal: 0, vertical: 12),
                      ),
                      child: ResponsiveText(
                          loc.login,
                        style: AppTextStyles.responsiveButtonMedium(context).copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rs(16)),
                  Container(
                    width: ResponsiveHelper.getFormElementWidth(context),
                    margin: context.rp(horizontal: 24, vertical: 0),
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
                    child: TextButton(
                      onPressed: () => _navigateToRegistration(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rs(12)),
                        ),
                        minimumSize: Size(double.infinity, context.rh(53)),
                        padding: context.rp(horizontal: 0, vertical: 12),
                      ),
                        child: ResponsiveText(
                          loc.createAccount,
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: context.rf(16),
                          ),
                        ),
                    ),
                  ),
                  ],
                ),
              ),
              
              SizedBox(height: context.rs(24)),
            ],
          ),
        ),
            // Language switcher in top right
            Positioned(
              top: 16,
              right: 16,
              child: LanguageSwitcherButton(),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() {
    context.push('/login');
  }

  void _navigateToRegistration() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RoleSelectionScreen(),
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
