import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import 'top_up_dialog.dart';

class CreditLimitGuard extends StatefulWidget {
  final Widget child;

  const CreditLimitGuard({
    super.key,
    required this.child,
  });

  @override
  State<CreditLimitGuard> createState() => _CreditLimitGuardState();
}

class _CreditLimitGuardState extends State<CreditLimitGuard> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        // Check if merchant has reached credit limit
        if (walletProvider.balance <= walletProvider.creditLimit && !_dialogShown) {
          // Show blocking dialog overlay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_dialogShown) {
              _dialogShown = true;
              _showCreditLimitDialog(context, walletProvider);
            }
          });
        } else if (walletProvider.balance > walletProvider.creditLimit && _dialogShown) {
          // Reset dialog flag when balance is restored
          _dialogShown = false;
        }
        
        // Always show child (dashboard remains visible)
        return widget.child;
      },
    );
  }
  
  void _showCreditLimitDialog(BuildContext context, WalletProvider walletProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    children: [
                      Text(
                        loc.balanceNeedsTopUp,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          content: Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balance Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          loc.currentBalance,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          walletProvider.formattedBalance,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Message
                  Text(
                    loc.cannotCreateOrdersUntilTopUp,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Payment methods info
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickInfo(
                          Icons.flash_on,
                          loc.zainCashKi,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickInfo(
                          Icons.person,
                          loc.hurRep(1000),
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _dialogShown = false;
                  showDialog(
                    context: context,
                    builder: (context) => const TopUpDialog(),
                  ).then((_) {
                    // Re-check balance after top-up dialog closes
                    if (walletProvider.balance <= walletProvider.creditLimit) {
                      // Still need to top up, show dialog again
                      Future.delayed(Duration(milliseconds: 500), () {
                        _dialogShown = false;
                        _showCreditLimitDialog(context, walletProvider);
                      });
                    }
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('شحن المحفظة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _dialogShown = false;
    });
  }
  
  Widget _buildQuickInfo(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
