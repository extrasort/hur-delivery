import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/localization/app_localizations.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveHelper.getResponsiveCardPadding(context);
    final responsiveMargin = ResponsiveHelper.getResponsiveSpacing(context, 12);
    
    return Container(
      margin: EdgeInsets.only(bottom: responsiveMargin),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Order ID and Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '#${order.id.substring(0, 6)}',
                            style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: order.status),
                  ],
                ),
                
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                
                // Customer Info with elegant card
                Container(
                  padding: ResponsiveHelper.getResponsiveCardPadding(context),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.customerPhone,
                                  style: AppTextStyles.responsiveBodySmall(context).copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Driver Info (if assigned)
                if (order.driverId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delivery_dining,
                            color: AppColors.success,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final loc = AppLocalizations.of(context);
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${loc.merchantLabel}:',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              order.driverName ?? loc.assignedStatus,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (order.driverPhone != null && order.driverPhone!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              order.driverPhone!,
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else if (order.driverName == null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${loc.merchantLabel} ID: ${order.driverId!.substring(0, 8)}...',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Addresses with elegant layout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return Column(
                            children: [
                              _AddressInfo(
                                icon: Icons.store,
                                label: loc.from,
                                address: order.pickupAddress,
                                color: AppColors.primary,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 18),
                                    Icon(
                                      Icons.arrow_downward,
                                      size: 16,
                                      color: AppColors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                              _AddressInfo(
                                icon: Icons.location_on,
                                label: loc.to,
                                address: order.deliveryAddress,
                                color: AppColors.success,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Footer with items and pricing
                Row(
                  children: [
                    // Items count
                    if (order.items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${order.items.length}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // Time
                    Text(
                      _formatTime(order.createdAt, context),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total amount - prominent
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return Text(
                            '${order.grandTotal.toStringAsFixed(0)} ${loc.currencySymbol}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime, BuildContext context) {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return loc.nowText;
    } else if (difference.inMinutes < 60) {
      // Use first character of minutes text for compact display
      final minChar = loc.isArabic ? 'د' : 'm';
      return '${difference.inMinutes}$minChar';
    } else if (difference.inHours < 24) {
      // Use first character of hours text for compact display
      final hrChar = loc.isArabic ? 'س' : 'h';
      return '${difference.inHours}$hrChar';
    } else {
      // Use first character of days text for compact display
      final dayChar = loc.isArabic ? 'ي' : 'd';
      return '${difference.inDays}$dayChar';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case 'pending':
        backgroundColor = AppColors.statusPending.withOpacity(0.1);
        textColor = AppColors.statusPending;
        text = loc.statusPending;
        break;
      case 'assigned':
        backgroundColor = AppColors.statusAccepted.withOpacity(0.1);
        textColor = AppColors.statusAccepted;
        text = loc.statusAssigned;
        break;
      case 'accepted':
        backgroundColor = AppColors.statusAccepted.withOpacity(0.1);
        textColor = AppColors.statusAccepted;
        text = loc.statusAccepted;
        break;
      case 'on_the_way':
        backgroundColor = AppColors.statusInProgress.withOpacity(0.1);
        textColor = AppColors.statusInProgress;
        text = loc.statusOnTheWay;
        break;
      case 'delivered':
        backgroundColor = AppColors.statusCompleted.withOpacity(0.1);
        textColor = AppColors.statusCompleted;
        text = loc.statusDelivered;
        break;
      case 'cancelled':
        backgroundColor = AppColors.statusCancelled.withOpacity(0.1);
        textColor = AppColors.statusCancelled;
        text = loc.statusCancelled;
        break;
      case 'unassigned':
        backgroundColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        text = loc.statusUnassigned;
        break;
      case 'rejected':
        backgroundColor = AppColors.statusCancelled.withOpacity(0.1);
        textColor = AppColors.statusCancelled;
        text = loc.statusRejected;
        break;
      default:
        backgroundColor = AppColors.textTertiary.withOpacity(0.1);
        textColor = AppColors.textTertiary;
        text = loc.statusUnknown;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddressInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;

  const _AddressInfo({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
