import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/top_up_dialog.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoadingSummary = true;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.user != null) {
      await walletProvider.initialize(authProvider.user!.id);
      final summary = await walletProvider.getWalletSummary(authProvider.user!.id);
      setState(() {
        _summary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _refresh() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      await context.read<WalletProvider>().refresh(authProvider.user!.id);
      await _loadData();
    }
  }

  void _showTopUpDialog() {
    showDialog(
      context: context,
      builder: (context) => const TopUpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).myWallet),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          if (walletProvider.isLoading && walletProvider.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Balance Card
                  _buildBalanceCard(walletProvider),

                  SizedBox(height: context.rs(16)),

                  // Summary Cards
                  if (_summary != null) _buildSummaryCards(_summary!),

                  SizedBox(height: context.rs(24)),

                  // Transactions List
                  _buildTransactionsList(walletProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(WalletProvider walletProvider) {
    final loc = AppLocalizations.of(context);
    Color balanceColor;
    IconData balanceIcon;
    String balanceStatus;

    if (walletProvider.isBalanceCritical) {
      balanceColor = AppColors.error;
      balanceIcon = Icons.warning_amber_rounded;
      balanceStatus = loc.pleaseTopUp;
    } else if (walletProvider.isBalanceLow) {
      balanceColor = Colors.orange;
      balanceIcon = Icons.warning_outlined;
      balanceStatus = loc.balanceLow;
    } else {
      balanceColor = AppColors.primary;
      balanceIcon = Icons.check_circle;
      balanceStatus = loc.balanceGood;
    }

    return Container(
      margin: context.rp(horizontal: 16, vertical: 16),
      padding: context.rp(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [balanceColor, balanceColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(20)),
        boxShadow: [
          BoxShadow(
            color: balanceColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(balanceIcon, color: Colors.white, size: context.ri(28)),
              SizedBox(width: context.rs(8)),
              ResponsiveText(
                balanceStatus,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ).responsive(context),
              ),
            ],
          ),
          SizedBox(height: context.rs(16)),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  ResponsiveText(
                    loc.currentBalance,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ).responsive(context),
                  ),
                  SizedBox(height: context.rs(8)),
                  ResponsiveText(
                    walletProvider.formattedBalance,
                    style: AppTextStyles.heading1.copyWith(
                      color: Colors.white,
                      fontSize: context.rf(36),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.rs(4)),
                  ResponsiveText(
                    loc.creditLimit(walletProvider.creditLimit),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ).responsive(context),
                  ),
                  SizedBox(height: context.rs(20)),
                  PrimaryButton(
                    text: loc.topUpWallet,
                    onPressed: _showTopUpDialog,
                    icon: Icons.add_circle_outline,
                    backgroundColor: Colors.white,
                    textColor: balanceColor,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Padding(
      padding: context.rp(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      loc.totalOrders,
                      summary['total_orders']?.toString() ?? '0',
                      Icons.shopping_bag,
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(width: context.rs(12)),
                  Expanded(
                    child: _buildSummaryCard(
                      loc.totalFees,
                      '${(summary['total_spent'] as num?)?.toStringAsFixed(0) ?? '0'} IQD',
                      Icons.payments,
                      AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: context.rp(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rs(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: context.rp(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: context.ri(24)),
          ),
          SizedBox(height: context.rs(12)),
          ResponsiveText(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ).responsive(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rs(4)),
          ResponsiveText(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ).responsive(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(WalletProvider walletProvider) {
    if (walletProvider.transactions.isEmpty) {
      return Container(
        padding: context.rp(horizontal: 40, vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              size: context.ri(64),
              color: AppColors.textTertiary,
            ),
            SizedBox(height: context.rs(16)),
            ResponsiveText(
              AppLocalizations.of(context).noTransactions,
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textTertiary,
              ).responsive(context),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: context.rp(horizontal: 16, vertical: 0),
      padding: context.rp(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rs(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            AppLocalizations.of(context).recentTransactions,
            style: AppTextStyles.heading3.responsive(context),
          ),
          SizedBox(height: context.rs(16)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walletProvider.transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final transaction = walletProvider.transactions[index];
              return _buildTransactionItem(transaction);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    final dateFormat = DateFormat('dd/MM/yyyy - hh:mm a', 'ar');

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: transaction.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.icon,
            color: transaction.color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (transaction.notes != null)
                Text(
                  transaction.notes!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                dateFormat.format(transaction.createdAt),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.formattedAmount,
              style: AppTextStyles.bodyLarge.copyWith(
                color: transaction.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).balance(transaction.balanceAfter),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}




