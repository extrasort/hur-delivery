import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';
import '../../core/localization/app_localizations.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: context.rp(horizontal: 32, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: context.ri(100),
                color: Colors.white.withOpacity(0.9),
              ),
              SizedBox(height: context.rs(24)),
              ResponsiveText(
                loc.noInternetTitle,
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ).responsive(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rs(16)),
              ResponsiveText(
                loc.noInternetMessage,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ).responsive(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rs(32)),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: context.rs(16)),
              ResponsiveText(
                loc.loading,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ).responsive(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
