import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/localization/app_localizations.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Don't call initialize() here - it causes instability
    // OrderProvider is already initialized and listening to real-time updates
    // Just use the existing data from the provider
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).myOrders),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OrderProvider>().refreshOrders();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Row(
                        children: [
                          _buildFilterChip('all', loc.all, Icons.list),
                          const SizedBox(width: 8),
                          _buildFilterChip('pending', loc.pending, Icons.pending),
                          const SizedBox(width: 8),
                          _buildFilterChip('accepted', loc.accepted, Icons.check_circle),
                          const SizedBox(width: 8),
                          _buildFilterChip('delivered', loc.completed, Icons.done_all),
                          const SizedBox(width: 8),
                          _buildFilterChip('cancelled', loc.cancelled, Icons.cancel),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: Consumer2<OrderProvider, AuthProvider>(
              builder: (context, orderProvider, authProvider, _) {
                if (orderProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (orderProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          orderProvider.error!,
                          style: AppTextStyles.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => orderProvider.refreshOrders(),
                          child: Text(AppLocalizations.of(context).retry),
                        ),
                      ],
                    ),
                  );
                }

                final orders = _filterOrders(orderProvider.orders, _selectedFilter);
                final driverId = authProvider.user?.id;

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(_selectedFilter),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order, driverId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? Colors.white : AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, String? driverId) {
    final isAssignedToMe = order.driverId == driverId;
    final canAccept = order.status == 'pending' && !isAssignedToMe;
    final canComplete = order.status == 'accepted' && isAssignedToMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: Colors.white,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${loc.orderNumber}${order.id.substring(0, 8)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _getStatusText(order.status),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: _getStatusColor(order.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          loc.orderPrice,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)} ${loc.currencySymbol}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Order Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${loc.customerLabel}: ${order.customerName ?? ''}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                            const SizedBox(height: 8),
                            // Pickup Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.fromLabel(order.pickupAddress),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Delivery Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.toLabel(order.deliveryAddress),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Order Time
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.orderTimeLabel(_formatDateTime(order.createdAt)),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (order.notes != null && order.notes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.notesLabel,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.notes!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
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

          // Action Buttons
          if (canAccept || canComplete)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  if (canAccept) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptOrder(order.id),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(AppLocalizations.of(context).acceptOrder),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectOrder(order.id),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(AppLocalizations.of(context).reject),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ] else if (canComplete) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _completeOrder(order.id),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(AppLocalizations.of(context).completeOrder),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders, String filter) {
    switch (filter) {
      case 'pending':
        return orders.where((order) => order.status == 'pending').toList();
      case 'accepted':
        return orders.where((order) => order.status == 'accepted' || order.status == 'on_the_way').toList();
      case 'delivered':
        return orders.where((order) => order.status == 'delivered').toList();
      case 'cancelled':
        return orders.where((order) => order.status == 'cancelled').toList();
      default:
        return orders;
    }
  }

  String _getEmptyMessage(String filter) {
    final loc = AppLocalizations.of(context);
    switch (filter) {
      case 'pending':
        return loc.noPendingOrders;
      case 'accepted':
        return loc.noAcceptedOrders;
      case 'delivered':
        return loc.noCompletedOrders;
      case 'cancelled':
        return loc.noCancelledOrders;
      default:
        return loc.noOrders;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
      case 'on_the_way':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.directions_car;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'pending':
        return loc.pending;
      case 'accepted':
        return loc.accepted;
      case 'on_the_way':
        return loc.inTransit;
      case 'delivered':
        return loc.delivered;
      case 'cancelled':
        return loc.cancelled;
      case 'rejected':
        return loc.rejected;
      default:
        return loc.unknown;
    }
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

  Future<void> _acceptOrder(String orderId) async {
    try {
      await context.read<OrderProvider>().updateOrderStatus(orderId, 'accepted');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderAcceptedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      await context.read<OrderProvider>().updateOrderStatus(orderId, 'cancelled');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderRejectedSuccess),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      await context.read<OrderProvider>().updateOrderStatus(orderId, 'completed');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderCompletedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
