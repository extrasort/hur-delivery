import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../shared/models/order_model.dart';

class MerchantAnalyticsScreen extends StatefulWidget {
  const MerchantAnalyticsScreen({super.key});

  @override
  State<MerchantAnalyticsScreen> createState() => _MerchantAnalyticsScreenState();
}

class _MerchantAnalyticsScreenState extends State<MerchantAnalyticsScreen> {
  String _selectedTimePeriod = 'all'; // all, today, week, month
  String _selectedStatus = 'all'; // all, delivered, cancelled, rejected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          // Filter orders by time period
          final filteredByTime = _filterOrdersByTimePeriod(orderProvider.orders);
          
          // Filter by status
          final filteredOrders = _selectedStatus == 'all' 
              ? filteredByTime
              : filteredByTime.where((o) => o.status == _selectedStatus).toList();

          // Calculate statistics
          final stats = _calculateStatistics(filteredByTime);

          return Container(
            color: AppColors.surfaceVariant,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Period Filter
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildFilterChip(loc.allFilter, 'all'),
                              _buildFilterChip(loc.todayFilter, 'today'),
                              _buildFilterChip(loc.weekFilter, 'week'),
                              _buildFilterChip(loc.monthFilter, 'month'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Statistics Cards
                          _buildStatCard(loc.totalOrdersStat, '${stats['totalOrders']}', Icons.shopping_bag, AppColors.primary),
                          const SizedBox(height: 12),
                          _buildStatCard(loc.completedOrdersStat, '${stats['deliveredOrders']}', Icons.check_circle, AppColors.success),
                          const SizedBox(height: 12),
                          _buildStatCard(loc.cancelledOrdersStat, '${stats['cancelledOrders']}', Icons.cancel, AppColors.error),
                          const SizedBox(height: 12),
                          _buildStatCard(loc.rejectedOrdersStat, '${stats['rejectedOrders']}', Icons.block, AppColors.warning),
                          const SizedBox(height: 12),
                          _buildStatCard(loc.activeOrders, '${stats['activeOrders']}', Icons.pending, AppColors.primary),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Revenue Statistics
                  Text(
                    'إحصائيات الإيرادات',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 12),
                  _buildRevenueCard('إجمالي الطلبات', stats['totalRevenue'], Icons.attach_money, AppColors.success),
                  const SizedBox(height: 12),
                  _buildRevenueCard('رسوم التوصيل', stats['totalDeliveryFees'], Icons.delivery_dining, AppColors.primary),
                  const SizedBox(height: 12),
                  _buildRevenueCard('متوسط قيمة الطلب', stats['avgOrderValue'], Icons.analytics, AppColors.warning),
                  
                  const SizedBox(height: 20),
                  
                  // Performance Metrics
                  Text(
                    'مقاييس الأداء',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard('متوسط وقت التوصيل', '${stats['avgDeliveryTime']} دقيقة', Icons.timer, AppColors.primary),
                  const SizedBox(height: 12),
                  _buildMetricCard('معدل الإكمال', '${stats['completionRate']}%', Icons.trending_up, AppColors.success),
                  const SizedBox(height: 12),
                  _buildMetricCard('معدل الإلغاء', '${stats['cancellationRate']}%', Icons.trending_down, AppColors.error),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedTimePeriod == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTimePeriod = value;
        });
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.heading2.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '${value.toStringAsFixed(0)} د.ع',
                  style: AppTextStyles.heading2.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<OrderModel> _filterOrdersByTimePeriod(List<OrderModel> orders) {
    final now = DateTime.now();
    
    switch (_selectedTimePeriod) {
      case 'today':
        return orders.where((o) {
          final orderDate = o.createdAt;
          return orderDate.year == now.year &&
                 orderDate.month == now.month &&
                 orderDate.day == now.day;
        }).toList();
      
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return orders.where((o) => o.createdAt.isAfter(weekAgo)).toList();
      
      case 'month':
        final monthAgo = now.subtract(const Duration(days: 30));
        return orders.where((o) => o.createdAt.isAfter(monthAgo)).toList();
      
      default: // 'all'
        return orders;
    }
  }

  Map<String, dynamic> _calculateStatistics(List<OrderModel> orders) {
    final deliveredOrders = orders.where((o) => o.status == 'delivered').toList();
    final cancelledOrders = orders.where((o) => o.status == 'cancelled').toList();
    final rejectedOrders = orders.where((o) => o.status == 'rejected').toList();
    final activeOrders = orders.where((o) => 
        o.status != 'delivered' && 
        o.status != 'cancelled'
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

    // Calculate revenue
    final totalRevenue = deliveredOrders.fold<double>(
      0, (sum, o) => sum + o.totalAmount,
    );
    
    final totalDeliveryFees = deliveredOrders.fold<double>(
      0, (sum, o) => sum + o.deliveryFee,
    );

    final avgOrderValue = deliveredOrders.isNotEmpty 
        ? totalRevenue / deliveredOrders.length 
        : 0.0;

    // Calculate rates
    final completionRate = orders.isNotEmpty 
        ? (deliveredOrders.length / orders.length * 100).toInt() 
        : 0;
    
    final cancellationRate = orders.isNotEmpty 
        ? (cancelledOrders.length / orders.length * 100).toInt() 
        : 0;

    return {
      'totalOrders': orders.length,
      'deliveredOrders': deliveredOrders.length,
      'cancelledOrders': cancelledOrders.length,
      'rejectedOrders': rejectedOrders.length,
      'activeOrders': activeOrders.length,
      'totalRevenue': totalRevenue,
      'totalDeliveryFees': totalDeliveryFees,
      'avgOrderValue': avgOrderValue,
      'avgDeliveryTime': avgDeliveryMinutes.toInt(),
      'completionRate': completionRate,
      'cancellationRate': cancellationRate,
    };
  }
}

