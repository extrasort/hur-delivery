import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  String _selectedTimePeriod = 'all';
  String _selectedStatus = 'all';

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
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).earnings),
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
      body: Consumer2<OrderProvider, AuthProvider>(
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

          final driverId = authProvider.user?.id;
          
          print('🎯 Driver Analytics - Driver ID: $driverId');
          print('📦 Total orders in provider: ${orderProvider.orders.length}');
          
          if (driverId == null) {
            print('❌ ERROR: Driver ID is null!');
            return Center(
              child: Text(AppLocalizations.of(context).driverIdNotFound),
            );
          }
          
          // Get driver's orders only
          final driverOrders = orderProvider.orders
              .where((o) => o.driverId == driverId)
              .toList();
          
          print('🚚 Driver orders: ${driverOrders.length}');
          
          // Filter by time period
          print('🔄 Starting time filter...');
          final filteredByTime = _filterOrdersByTimePeriod(driverOrders);
          print('📅 After time filter: ${filteredByTime.length}');
          
          // Filter by status
          print('🔄 Starting status filter...');
          final filteredOrders = _selectedStatus == 'all' 
              ? filteredByTime
              : filteredByTime.where((o) => o.status == _selectedStatus).toList();
          print('🏷️  After status filter: ${filteredOrders.length}');
          
          // Calculate statistics
          print('🧮 Calculating statistics...');
          try {
            final stats = _calculateStatistics(filteredByTime, driverId);
            print('✅ Stats calculated: $stats');
            
            print('🎨 Building UI...');
            return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Period Filter
                _buildTimePeriodFilter(),
                
                const SizedBox(height: 16),
                
                // Key Metrics Cards
                _buildKeyMetricsSection(stats),
                
                const SizedBox(height: 24),
                
                // Average Delivery Time Card (Prominent)
                _buildAverageDeliveryTimeCard(stats),
                
                const SizedBox(height: 24),
                
                // Earnings Summary
                _buildEarningsSummary(stats),
                
                const SizedBox(height: 24),
                
                // Status Breakdown
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.classifyOrdersByStatus,
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 12),
                        _buildStatusFilter(),
                        const SizedBox(height: 16),
                        _buildStatusBreakdown(stats),
                        const SizedBox(height: 24),
                        // Recent Orders Preview
                        Text(
                          loc.recentOrders,
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 12),
                        if (filteredOrders.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                loc.noOrdersInPeriod,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredOrders.take(3).map((order) => _buildRecentOrderItem(order)),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        } catch (e, stackTrace) {
            print('❌ ERROR building driver analytics UI: $e');
            print('📍 Stack trace: $stackTrace');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).errorLoadingStats,
                      style: AppTextStyles.heading3,
                    ),
                    SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  List<dynamic> _filterOrdersByTimePeriod(List orders) {
    final now = DateTime.now();
    
    switch (_selectedTimePeriod) {
      case 'today':
        final todayStart = DateTime(now.year, now.month, now.day);
        return orders.where((o) => o.createdAt.isAfter(todayStart)).toList();
      
      case 'week':
        final weekStart = now.subtract(Duration(days: 7));
        return orders.where((o) => o.createdAt.isAfter(weekStart)).toList();
      
      case 'month':
        final monthStart = now.subtract(Duration(days: 30));
        return orders.where((o) => o.createdAt.isAfter(monthStart)).toList();
      
      default:
        return orders;
    }
  }

  Map<String, dynamic> _calculateStatistics(List orders, String? driverId) {
    final totalOrders = orders.length;
    final deliveredOrders = orders.where((o) => o.status == 'delivered').toList();
    final cancelledOrders = orders.where((o) => o.status == 'cancelled').toList();
    final rejectedOrders = orders.where((o) => o.status == 'rejected').toList();
    final activeOrders = orders.where((o) => 
        o.status != 'delivered' && 
        o.status != 'cancelled' &&
        o.status != 'rejected'
    ).toList();

    // Calculate average delivery time
    double avgDeliveryMinutes = 0;
    if (deliveredOrders.isNotEmpty) {
      double totalMinutes = 0;
      int validOrders = 0;
      
      for (var order in deliveredOrders) {
        if (order.updatedAt != null) {
          final duration = order.updatedAt!.difference(order.createdAt);
          totalMinutes += duration.inMinutes.toDouble();
          validOrders++;
        }
      }
      
      if (validOrders > 0) {
        avgDeliveryMinutes = totalMinutes / validOrders;
      }
    }

    // Calculate earnings (delivery fees for drivers)
    final totalEarnings = deliveredOrders.fold(0.0, (sum, order) => sum + order.deliveryFee);
    final avgEarningsPerOrder = deliveredOrders.isNotEmpty 
        ? totalEarnings / deliveredOrders.length 
        : 0.0;

    // Calculate acceptance rate
    final acceptanceRate = totalOrders > 0 
        ? (deliveredOrders.length / totalOrders * 100) 
        : 0.0;

    return {
      'totalOrders': totalOrders,
      'deliveredOrders': deliveredOrders.length,
      'cancelledOrders': cancelledOrders.length,
      'rejectedOrders': rejectedOrders.length,
      'activeOrders': activeOrders.length,
      'avgDeliveryMinutes': avgDeliveryMinutes,
      'totalEarnings': totalEarnings,
      'avgEarningsPerOrder': avgEarningsPerOrder,
      'acceptanceRate': acceptanceRate,
    };
  }

  Widget _buildTimePeriodFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Row(
            children: [
              _buildPeriodChip('all', loc.all),
              _buildPeriodChip('today', loc.today),
              _buildPeriodChip('week', loc.week),
              _buildPeriodChip('month', loc.month),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedTimePeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimePeriod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Row(
            children: [
              _buildStatusChip('all', loc.all, Icons.list),
              const SizedBox(width: 8),
              _buildStatusChip('delivered', loc.completed, Icons.check_circle),
              const SizedBox(width: 8),
              _buildStatusChip('cancelled', loc.cancelled, Icons.cancel),
              const SizedBox(width: 8),
              _buildStatusChip('rejected', loc.rejected, Icons.block),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, IconData icon) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() => _selectedStatus = value);
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildKeyMetricsSection(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ModernStatCard(
                              title: loc.totalOrders,
                              value: stats['totalOrders'].toString(),
                              icon: Icons.local_shipping_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModernStatCard(
                              title: loc.activeOrders,
                              value: stats['activeOrders'].toString(),
                              icon: Icons.pending_actions,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ModernStatCard(
                              title: loc.delivered,
                              value: stats['deliveredOrders'].toString(),
                              icon: Icons.check_circle_outline,
                              color: AppColors.success,
                              subtitle: '${stats['acceptanceRate'].toStringAsFixed(1)}% ${loc.acceptanceRate}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModernStatCard(
                              title: loc.cancelledRejected,
                              value: '${stats['cancelledOrders'] + stats['rejectedOrders']}',
                              icon: Icons.cancel_outlined,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAverageDeliveryTimeCard(Map<String, dynamic> stats) {
    final avgMinutes = stats['avgDeliveryMinutes'] as double;
    final hours = avgMinutes ~/ 60;
    final minutes = (avgMinutes % 60).round();
    
    String timeDisplay;
    String timeUnit;
    
    if (avgMinutes == 0) {
      timeDisplay = '--';
      timeUnit = '';
    } else if (hours > 0) {
      final loc = AppLocalizations.of(context);
      timeDisplay = '$hours:${minutes.toString().padLeft(2, '0')}';
      timeUnit = loc.hour;
    } else {
      final loc = AppLocalizations.of(context);
      timeDisplay = minutes.toString();
      timeUnit = loc.minute;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
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
                              loc.averageDeliveryTime,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loc.fromAcceptanceToDelivery,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeDisplay,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (timeUnit.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    timeUnit,
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          if (stats['deliveredOrders'] > 0) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return Text(
                  loc.basedOnCompleted(stats['deliveredOrders']),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsSummary(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success,
            AppColors.success.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.earningsSummary,
                        style: AppTextStyles.heading3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  const SizedBox(height: 20),
                  _buildEarningsRow(
                    loc.totalEarnings,
                    '${stats['totalEarnings'].toStringAsFixed(0)} ${loc.currencySymbol}',
                  ),
                  const SizedBox(height: 12),
                  _buildEarningsRow(
                    loc.averageEarningsPerOrder,
                    '${stats['avgEarningsPerOrder'].toStringAsFixed(0)} ${loc.currencySymbol}',
                  ),
                ],
              );
            },
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).completedOrdersLabel,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${stats['deliveredOrders']}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(Map<String, dynamic> stats) {
    return Column(
      children: [
        Builder(
          builder: (context) {
            final loc = AppLocalizations.of(context);
            return Column(
              children: [
                _buildStatusRow(
                  loc.deliveredStatus,
                  stats['deliveredOrders'],
                  stats['totalOrders'],
                  AppColors.success,
                  Icons.check_circle,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  loc.cancelledStatus,
                  stats['cancelledOrders'],
                  stats['totalOrders'],
                  AppColors.error,
                  Icons.cancel,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  loc.rejectedStatus,
                  stats['rejectedOrders'],
                  stats['totalOrders'],
                  AppColors.warning,
                  Icons.block,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  loc.activeStatus,
                  stats['activeOrders'],
                  stats['totalOrders'],
                  AppColors.primary,
                  Icons.pending_actions,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, int count, int total, Color color, IconData icon) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count طلب',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerRight,
                  widthFactor: percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrderItem(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(order.status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(order.status),
              color: _getStatusColor(order.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).orderHash(order.id),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusText(order.status),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.deliveryFee.toStringAsFixed(0)} د.ع',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              Text(
                AppLocalizations.of(context).deliveryFeesLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
      case 'assigned':
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
      case 'assigned':
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
      case 'rejected':
        return loc.statusRejected;
      default:
        return loc.statusUnknown;
    }
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
