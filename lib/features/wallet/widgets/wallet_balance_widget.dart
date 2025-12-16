import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';

class WalletBalanceWidget extends StatelessWidget {
  const WalletBalanceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, AuthProvider>(
      builder: (context, walletProvider, authProvider, _) {
        if (walletProvider.isLoading) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // Determine background color based on balance status
        Color backgroundColor;
        Color textColor;
        IconData icon;
        
        if (walletProvider.isBalanceCritical) {
          backgroundColor = Colors.white;
          textColor = AppColors.error;
          icon = Icons.warning_amber_rounded;
        } else if (walletProvider.isBalanceLow) {
          backgroundColor = Colors.white;
          textColor = Colors.orange.shade700;
          icon = Icons.warning_outlined;
        } else {
          backgroundColor = Colors.white;
          textColor = AppColors.primary;
          icon = Icons.account_balance_wallet;
        }

        return GestureDetector(
          onTap: () {
            // Navigate to full wallet screen
            context.push('/merchant-wallet');
          },
          child: Container(
            height: 48, // Fixed height to fit properly in AppBar
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24), // Fully rounded (half of height)
              border: Border.all(
                color: textColor.withOpacity(0.3),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: textColor),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).myBalance,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      walletProvider.formattedBalance,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: textColor.withOpacity(0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
