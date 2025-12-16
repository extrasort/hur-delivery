import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/language_switcher.dart';
import 'phone_input_screen.dart';
import '../../../core/localization/app_localizations.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary, // Hur teal background
      appBar: AppBar(
        title: Text(loc.selectRole),
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
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06), // 6% padding
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing
              
              // Logo - Responsive
              Container(
                width: MediaQuery.of(context).size.width * 0.3, // 30% of screen width
                height: MediaQuery.of(context).size.width * 0.3, // Square aspect ratio
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
                      size: MediaQuery.of(context).size.width * 0.15, // 15% of screen width
                      color: AppColors.textPrimary,
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.03), // 3% spacing
              
              // Header - Responsive
              Text(
                loc.selectRole,
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: MediaQuery.of(context).size.width * 0.06, // 6% of screen width
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 1% spacing
              Text(
                loc.platformForDriversMerchants,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary.withOpacity(0.8),
                  fontSize: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: MediaQuery.of(context).size.height * 0.06), // 6% spacing
              
              // Role Cards - Responsive
              Expanded(
                child: Column(
                  children: [
                    // Merchant Card
                    _RoleCard(
                      icon: Icons.store_rounded,
                      title: loc.merchant,
                      description: loc.merchantDescription,
                      color: AppColors.primary,
                      onTap: () => _navigateToPhoneInput('merchant'),
                    ),
                    
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02), // 2% spacing
                    
                    // Driver Card
                    _RoleCard(
                      icon: Icons.delivery_dining_rounded,
                      title: loc.driver,
                      description: loc.driverDescription,
                      color: AppColors.secondary,
                      onTap: () => _navigateToPhoneInput('driver'),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 4% spacing
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPhoneInput(String role) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PhoneInputScreen(role: role),
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

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: MediaQuery.of(context).size.width * 0.01, // 1% elevation
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03), // 3% radius
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05), // 5% padding
          child: Row(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.15, // 15% of screen width
                height: MediaQuery.of(context).size.width * 0.15, // Square aspect ratio
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03), // 3% radius
                ),
                child: Icon(
                  icon,
                  size: MediaQuery.of(context).size.width * 0.08, // 8% of screen width
                  color: color,
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.04), // 4% spacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: MediaQuery.of(context).size.width * 0.05, // 5% of screen width
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.005), // 0.5% spacing
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: MediaQuery.of(context).size.width * 0.035, // 3.5% of screen width
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: MediaQuery.of(context).size.width * 0.04, // 4% of screen width
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
