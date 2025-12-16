import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../core/localization/app_localizations.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(loc.orderDetails),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer2<OrderProvider, AuthProvider>(
        builder: (context, orderProvider, authProvider, _) {
          final order = orderProvider.getOrderById(widget.orderId);
          
          if (order == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final user = authProvider.user;
          final isMerchant = user?.isMerchant ?? false;
          final isDriver = user?.isDriver ?? false;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Status Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(order.status),
                        _getStatusColor(order.status).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(order.status).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: context.rp(horizontal: 24, vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(order.status),
                          color: Colors.white,
                          size: context.ri(48),
                        ),
                        SizedBox(height: context.rs(12)),
                        ResponsiveText(
                          order.statusDisplay,
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ).responsive(context),
                        ),
                        SizedBox(height: context.rs(8)),
                        ResponsiveText(
                          '${loc.orderNumberPrefix}${order.id.substring(0, 8)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ).responsive(context),
                        ),
                        SizedBox(height: context.rs(20)),
                        _OrderProgressIndicator(status: order.status),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: context.rs(20)),
                
                Padding(
                  padding: context.rp(horizontal: 16, vertical: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer & Driver Info - Enhanced for merchants
                      _ModernInfoCard(
                        icon: Icons.people_outline,
                        title: loc.partyInfo,
                        color: AppColors.primary,
                        children: [
                          _ModernInfoRow(
                            icon: Icons.person_outline,
                            label: loc.customerLabel(order.customerName ?? ''),
                            value: order.customerName,
                          ),
                          _ModernInfoRow(
                            icon: Icons.phone_outlined,
                            label: loc.customerPhone,
                            value: order.customerPhone,
                          ),
                          if (order.driverId != null) ...[
                            const Divider(height: 24),
                            _ModernInfoRow(
                              icon: Icons.delivery_dining,
                              label: loc.merchantLabel,
                              value: order.driverName ?? loc.assignedStatus,
                              valueColor: AppColors.success,
                            ),
                            if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
                              _ModernInfoRow(
                                icon: Icons.phone_outlined,
                                label: loc.driverPhone,
                                value: order.driverPhone!,
                              ),
                          ] else if (isMerchant && order.isPending) ...[
                            const Divider(height: 24),
                            _ModernInfoRow(
                              icon: Icons.pending_outlined,
                              label: loc.merchantLabel,
                              value: loc.searchingDriver,
                              valueColor: AppColors.warning,
                            ),
                          ],
                          // Order timing info for merchants
                          if (isMerchant) ...[
                            const Divider(height: 24),
                            _ModernInfoRow(
                              icon: Icons.access_time_outlined,
                              label: loc.createdAt,
                              value: _formatDateTime(order.createdAt),
                            ),
                            if (order.driverAssignedAt != null)
                              _ModernInfoRow(
                                icon: Icons.check_circle_outline,
                                label: loc.assignedAt,
                                value: _formatDateTime(order.driverAssignedAt!),
                              ),
                            if (order.status == 'rejected' && order.rejectedAt != null)
                              _ModernInfoRow(
                                icon: Icons.cancel_outlined,
                                label: loc.rejectedAt,
                                value: _formatDateTime(order.rejectedAt!),
                                valueColor: AppColors.error,
                              ),
                          ],
                        ],
                      ),
                      
                      SizedBox(height: context.rs(16)),
                      
                      // Locations Card
                      _ModernInfoCard(
                        icon: Icons.location_on_outlined,
                        title: loc.deliveryLocations,
                        color: AppColors.success,
                        children: [
                          _LocationRow(
                            icon: Icons.store_outlined,
                            label: loc.from,
                            address: order.pickupAddress,
                            iconColor: AppColors.primary,
                          ),
                          SizedBox(height: context.rs(12)),
                          Center(
                            child: Icon(
                              Icons.arrow_downward,
                              color: AppColors.textTertiary,
                              size: context.ri(20),
                            ),
                          ),
                          SizedBox(height: context.rs(12)),
                          _LocationRow(
                            icon: Icons.location_on,
                            label: loc.to,
                            address: order.deliveryAddress,
                            iconColor: AppColors.success,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: context.rs(16)),
                      
                      // Proof images (if any)
                      _ModernInfoCard(
                        icon: Icons.photo_library_outlined,
                        title: loc.deliveryProof,
                        color: AppColors.primary,
                        children: [
                          _OrderProofGallery(orderId: order.id),
                        ],
                      ),
                      
                      SizedBox(height: context.rs(16)),
                      
                      // Order Items
                      if (order.items.isNotEmpty) ...[
                        _ModernInfoCard(
                          icon: Icons.shopping_bag_outlined,
                          title: '${loc.orderItems} (${order.items.length})',
                          color: AppColors.secondary,
                          children: order.items.map((item) => _ModernOrderItem(item: item)).toList(),
                        ),
                        SizedBox(height: context.rs(16)),
                      ],
                      
                      // Financial Summary
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(context.rs(20)),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: context.rp(horizontal: 20, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: context.rp(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(context.rs(12)),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: AppColors.primary,
                                    size: context.ri(20),
                                  ),
                                ),
                                SizedBox(width: context.rs(12)),
                                ResponsiveText(
                                  loc.financialSummary,
                                  style: AppTextStyles.heading3.copyWith(
                                    color: AppColors.primary,
                                  ).responsive(context),
                                ),
                              ],
                            ),
                            SizedBox(height: context.rs(16)),
                            _PriceRow(
                              label: loc.orderPriceNoDelivery,
                              amount: order.totalAmount,
                            ),
                            SizedBox(height: context.rs(12)),
                            _PriceRow(
                              label: loc.deliveryFee,
                              amount: order.deliveryFee,
                            ),
                            Padding(
                              padding: context.rp(horizontal: 0, vertical: 12),
                              child: const Divider(),
                            ),
                            _PriceRow(
                              label: loc.grandTotal,
                              amount: order.grandTotal,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                      
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        SizedBox(height: context.rs(16)),
                        Container(
                          width: double.infinity,
                          padding: context.rp(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(context.rs(16)),
                            border: Border.all(
                              color: Colors.amber.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.note_outlined,
                                    color: Colors.amber.shade700,
                                    size: context.ri(20),
                                  ),
                                  SizedBox(width: context.rs(8)),
                                  ResponsiveText(
                                    loc.notes,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade900,
                                    ).responsive(context),
                                  ),
                                ],
                              ),
                              SizedBox(height: context.rs(8)),
                              ResponsiveText(
                                order.notes!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ).responsive(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                
                SizedBox(height: context.rs(24)),
                
                // Action Buttons - Removed assign driver button for merchants
                if (isMerchant && order.isPending) ...[
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      text: loc.cancelOrder,
                      onPressed: () => _cancelOrder(order.id),
                    ),
                  ),
                ] else if (isMerchant && order.isRejected) ...[
                  // Rejected order actions for merchants
                  Container(
                    padding: context.rp(horizontal: 16, vertical: 16),
                    margin: EdgeInsets.only(bottom: context.rs(16)),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(context.rs(12)),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.allDriversRejected,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: loc.cancelOrder,
                          onPressed: () => _cancelOrder(order.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.success,
                                AppColors.success.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _repostOrder(order.id, order.deliveryFee),
                            icon: const Icon(Icons.replay, color: Colors.white),
                            label: Text(
                              loc.repostOrder,
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isDriver && order.isAssigned) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: loc.rejectOrder,
                          onPressed: () => _rejectOrder(order.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: loc.acceptOrder,
                          onPressed: () => _acceptOrder(order.id),
                        ),
                      ),
                    ],
                  ),
                ] else if (isDriver && order.isAccepted) ...[
                  PrimaryButton(
                    text: loc.pickedUp,
                    onPressed: () => _markPickedUp(order.id),
                  ),
                ] else if (isDriver && order.isAccepted) ...[
                  PrimaryButton(
                    text: loc.onTheWay,
                    onPressed: () => _markInTransit(order.id),
                  ),
                ] else if (isDriver && order.isOnTheWay) ...[
                  PrimaryButton(
                    text: loc.delivered,
                    onPressed: () => _markDelivered(order.id),
                  ),
                ],
                
                      const SizedBox(height: 16),
                      
                      // Track Order Button - Only show map for accepted/on_the_way orders
                      if (order.isAccepted || order.isOnTheWay) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Show map with driver location
                              _showDriverLocationMap(order);
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: Text(loc.trackDriver),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                
                      // WhatsApp Support Button for Merchants
                      if (isMerchant) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _contactSupport(order.id),
                            icon: Icon(Icons.support_agent, color: const Color(0xFF25D366)),
                            label: Text(loc.contactSupport),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF25D366),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await _showConfirmDialog(
      loc.cancelOrder,
      loc.cancelOrderConfirm,
    );
    
    if (confirmed) {
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.cancelOrder(orderId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderCancelled),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    }
  }

  Future<void> _repostOrder(String orderId, double currentDeliveryFee) async {
    final loc = AppLocalizations.of(context);
    // Check credit limit first
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.balance <= walletProvider.creditLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.insufficientBalanceRepost),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Get order details including vehicle type
    final orderProvider = context.read<OrderProvider>();
    final order = orderProvider.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );
    
    final merchantId = order.merchantId;
    if (merchantId == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(loc.error),
            content: Text(loc.merchantDataError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.ok),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Check for online drivers WITHOUT active orders (repost requirement)
    final availabilityResult = await DriverAvailabilityService.checkFreeDriversOnly(
      vehicleType: order.vehicleType ?? 'motorbike',
    );

    if (!availabilityResult.available) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(loc.noDriversAvailable),
            content: Text(availabilityResult.userMessage(context)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.ok),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    final newDeliveryFee = currentDeliveryFee + 500;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.replay, color: AppColors.success),
            const SizedBox(width: 8),
            Text(loc.repostOrderTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.repostOrderMessage,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.currentDeliveryFee),
                      Text(
                        '${currentDeliveryFee.toStringAsFixed(0)} ${loc.currencySymbol}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.newDeliveryFee),
                      Text(
                        '${newDeliveryFee.toStringAsFixed(0)} ${loc.currencySymbol}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.repostOrderHint,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.repostOrderTitle),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.repostOrder(orderId, newDeliveryFee);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.repostSuccess),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderProvider.error ?? loc.repostError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _assignDriver(String orderId) async {
    final loc = AppLocalizations.of(context);
    // In a real app, this would show a list of available drivers
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.driverAssignedSoon),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    final loc = AppLocalizations.of(context);
    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.acceptOrder(orderId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.orderAccepted),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await _showConfirmDialog(
      loc.rejectOrder,
      loc.rejectOrderConfirm,
    );
    
    if (confirmed) {
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.rejectOrder(orderId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderRejected),
            backgroundColor: AppColors.warning,
          ),
        );
        context.pop();
      }
    }
  }

  Future<void> _markPickedUp(String orderId) async {
    final loc = AppLocalizations.of(context);
    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.markOrderOnTheWay(orderId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pickupConfirmed),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _markInTransit(String orderId) async {
    final loc = AppLocalizations.of(context);
    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.markOrderDelivered(orderId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.deliveryStarted),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _markDelivered(String orderId) async {
    final loc = AppLocalizations.of(context);
    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.markOrderDelivered(orderId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.deliveryConfirmed),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final loc = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _contactSupport(String orderId) async {
    final loc = AppLocalizations.of(context);
    try {
      const phoneNumber = '+964771234567'; // Replace with actual support number
      final message = '${loc.supportMessageTemplate}${orderId.substring(0, 8)}';
      final url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';
      
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.whatsappOpenFailed),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.whatsappError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDriverLocationMap(dynamic order) {
    // Navigate to the order tracking screen which shows driver location on map
    context.go('/merchant-dashboard/order-tracking/${order.id}');
  }

  String _formatDateTime(DateTime dateTime) {
    // Convert from UTC to Baghdad time (GMT+3)
    final baghdadTime = dateTime.toUtc().add(const Duration(hours: 3));
    
    // Format date
    final dateFormatter = DateFormat('yyyy/MM/dd');
    final dateStr = dateFormatter.format(baghdadTime);
    
    // Format time in 12-hour format
    int hour = baghdadTime.hour;
    final minute = baghdadTime.minute.toString().padLeft(2, '0');
    final loc = AppLocalizations.of(context);
    String period = loc.amShort;
    
    if (hour >= 12) {
      period = loc.pmShort;
      if (hour > 12) {
        hour = hour - 12;
      }
    } else if (hour == 0) {
      hour = 12;
    }
    
    return '$dateStr ${hour}:$minute $period';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'assigned':
        return Icons.assignment;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'unassigned':
        return Icons.assignment_late;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'assigned':
        return AppColors.primary;
      case 'accepted':
        return AppColors.success;
      case 'on_the_way':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'unassigned':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getStatusText(String status) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'pending':
        return loc.statusPending;
      case 'assigned':
        return loc.statusAssigned;
      case 'accepted':
        return loc.statusAccepted;
      case 'on_the_way':
        return loc.statusOnTheWay;
      case 'delivered':
        return loc.statusDelivered;
      case 'cancelled':
        return loc.statusCancelled;
      case 'unassigned':
        return loc.statusUnassigned;
      case 'rejected':
        return loc.statusRejected;
      default:
        return loc.statusUnknown;
    }
  }
}

class _OrderProgressIndicator extends StatelessWidget {
  final String status;

  const _OrderProgressIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final steps = [
      {'status': 'pending', 'label': loc.statusCreated, 'icon': Icons.add_circle_outline},
      {'status': 'assigned', 'label': loc.statusAssigned, 'icon': Icons.assignment_outlined},
      {'status': 'accepted', 'label': loc.statusAccepted, 'icon': Icons.check_circle_outline},
      {'status': 'on_the_way', 'label': loc.statusOnTheWay, 'icon': Icons.local_shipping_outlined},
      {'status': 'delivered', 'label': loc.statusDelivered, 'icon': Icons.done_all},
    ];

    final currentStepIndex = steps.indexWhere((step) => step['status'] == status);
    final activeIndex = currentStepIndex >= 0 ? currentStepIndex : 0;

    return Column(
      children: [
        // Horizontal Progress Bar
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isActive = index <= activeIndex;
            final isLast = index == steps.length - 1;
            final isCurrent = index == activeIndex;

            return Expanded(
              child: Row(
                children: [
                  // Step Circle
                  Container(
                    width: isCurrent ? 36 : 28,
                    height: isCurrent ? 36 : 28,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? AppColors.primary : Colors.grey.shade400,
                        width: isCurrent ? 3 : 2,
                      ),
                      boxShadow: isCurrent ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      step['icon'] as IconData,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      size: isCurrent ? 20 : 16,
                    ),
                  ),
                  // Connecting Line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isActive && index < activeIndex 
                              ? AppColors.primary 
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 12),
        
        // Labels
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isActive = index <= activeIndex;
            final isCurrent = index == activeIndex;

            return Expanded(
              child: Text(
                step['label'] as String,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isActive 
                      ? (isCurrent ? AppColors.primary : AppColors.textPrimary)
                      : AppColors.textTertiary,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  fontSize: isCurrent ? 11 : 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final dynamic item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          Text(
            '${item.quantity} × ${item.price.toStringAsFixed(0)} د.ع',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${item.totalPrice.toStringAsFixed(0)} د.ع',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// Modern widget classes for the redesigned order details screen

class _ModernInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _ModernInfoCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ModernInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ModernInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderProofGallery extends StatefulWidget {
  final String orderId;
  const _OrderProofGallery({required this.orderId});
  @override
  State<_OrderProofGallery> createState() => _OrderProofGalleryState();
}

class _OrderProofGalleryState extends State<_OrderProofGallery> {
  bool _loading = true;
  List<_ProofItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final provider = context.read<OrderProvider>();
      final rows = await provider.getOrderProofs(widget.orderId);
      final List<_ProofItem> items = [];
      for (final r in rows) {
        final path = r['storage_path'] as String;
        final url = await Supabase.instance.client.storage
            .from('order_proofs')
            .createSignedUrl(path, 60 * 10); // 10 minutes
        items.add(_ProofItem(url: url, createdAt: DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now()));
      }
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(),
      ));
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(AppLocalizations.of(context).noImagesUploadedOrder),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final it = _items[i];
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(it.url, fit: BoxFit.contain),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(it.url, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _ProofItem {
  final String url;
  final DateTime createdAt;
  _ProofItem({required this.url, required this.createdAt});
}
class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color iconColor;

  const _LocationRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
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
              const SizedBox(height: 4),
              Text(
                address,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernOrderItem extends StatelessWidget {
  final dynamic item;

  const _ModernOrderItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
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
                  item.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} × ${item.price.toStringAsFixed(0)} د.ع',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.totalPrice.toStringAsFixed(0)} د.ع',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(0)} د.ع',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
            fontSize: isTotal ? 18 : 16,
          ),
        ),
      ],
    );
  }
}
