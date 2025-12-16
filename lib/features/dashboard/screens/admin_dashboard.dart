import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/announcement_provider.dart';
import '../../../core/localization/app_localizations.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<OrderProvider>().initialize();
      
      // Initialize announcement checker (checks every 5 seconds)
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null && mounted) {
        await context.read<AnnouncementProvider>().initialize(
          userRole: 'admin',
          userId: authProvider.user!.id,
          context: context,
        );
      }
    });
  }

  @override
  void dispose() {
    context.read<AnnouncementProvider>().stopChecking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.dashboardAdminTitle),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Text(loc.profile),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text(loc.settings),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text(loc.logout),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _OverviewTab(),
          _UsersTab(),
          _OrdersTab(),
          _AnalyticsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            label: loc.overview,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            label: loc.users,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt),
            label: loc.orders,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics_outlined),
            label: loc.analytics,
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      context.go('/');
    }
  }
}

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final orders = orderProvider.orders;
        final activeOrders = orderProvider.activeOrders;
        final completedOrders = orderProvider.completedOrders;

        return SingleChildScrollView(
          padding: ResponsiveHelper.getResponsivePadding(context, horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return _StatCard(
                          title: loc.totalOrders,
                          value: orders.length.toString(),
                          icon: Icons.shopping_cart_outlined,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return _StatCard(
                          title: loc.activeOrders,
                          value: activeOrders.length.toString(),
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.warning,
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return _StatCard(
                          title: loc.completedOrders,
                          value: completedOrders.length.toString(),
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return _StatCard(
                          title: loc.totalSales,
                          value: '${completedOrders.fold(0.0, (sum, order) => sum + order.grandTotal).toStringAsFixed(0)} ${loc.currencySymbol}',
                          icon: Icons.attach_money_outlined,
                          color: AppColors.secondary,
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Recent Activity
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.recentActivity,
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 12),
                      if (orders.isEmpty)
                        Container(
                          padding: ResponsiveHelper.getResponsivePadding(context, horizontal: 32, vertical: 32),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              loc.noOrdersYet,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      else
                        ...orders.take(5).map((order) => _ActivityItem(order: order)).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Management Cards
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return _UserCard(
                      title: loc.merchantsLabel,
                      count: 0, // Would be fetched from API
                      icon: Icons.store_outlined,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return _UserCard(
                      title: loc.driversLabel,
                      count: 0, // Would be fetched from API
                      icon: Icons.delivery_dining_outlined,
                      color: AppColors.secondary,
                    );
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return _UserCard(
                      title: loc.customersLabel,
                      count: 0, // Would be fetched from API
                      icon: Icons.people_outline,
                      color: AppColors.success,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return _UserCard(
                      title: loc.pendingApprovalLabel,
                      count: 0, // Would be fetched from API
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.warning,
                    );
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // User Actions
          Text(
                'إدارة المستخدمين',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 12),
              
              _UserActionCard(
                title: 'مراجعة طلبات التسجيل',
                subtitle: 'مراجعة وموافقة على طلبات التسجيل الجديدة',
                icon: Icons.approval_outlined,
                color: AppColors.warning,
                onTap: () {
                  // Handle pending registrations
                },
              ),
              
              _UserActionCard(
                title: 'إدارة التجار',
                subtitle: 'عرض وإدارة قائمة التجار',
                icon: Icons.store_outlined,
                color: AppColors.primary,
                onTap: () {
                  // Handle merchants management
                },
              ),
              
              _UserActionCard(
                title: 'إدارة السائقين',
                subtitle: 'عرض وإدارة قائمة السائقين',
                icon: Icons.delivery_dining_outlined,
                color: AppColors.secondary,
                onTap: () {
                  // Handle drivers management
                },
              ),
              
              _UserActionCard(
                title: 'إدارة العملاء',
                subtitle: 'عرض وإدارة قائمة العملاء',
                icon: Icons.people_outline,
                color: AppColors.success,
                onTap: () {
                  // Handle customers management
                },
              ),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        if (orderProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final orders = orderProvider.orders;

        return RefreshIndicator(
          onRefresh: () => orderProvider.refreshOrders(),
          child: ListView.builder(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Padding(
                padding: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                child: _AdminOrderCard(order: order),
              );
            },
          ),
        );
      },
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليلات النظام',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 16),
          
          // Analytics Cards
          _AnalyticsCard(
            title: 'نمو الطلبات',
            subtitle: 'زيادة 15% هذا الشهر',
            value: '+15%',
            icon: Icons.trending_up,
            color: AppColors.success,
          ),
          
          const SizedBox(height: 12),
          
          _AnalyticsCard(
            title: 'معدل الإنجاز',
            subtitle: '95% من الطلبات مكتملة',
            value: '95%',
            icon: Icons.check_circle,
            color: AppColors.primary,
          ),
          
          const SizedBox(height: 12),
          
          _AnalyticsCard(
            title: 'رضا العملاء',
            subtitle: '4.8/5 تقييم متوسط',
            value: '4.8',
            icon: Icons.star,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const Spacer(),
                Text(
                  value,
                  style: AppTextStyles.heading3.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _UserCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: AppTextStyles.heading2.copyWith(
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UserActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 8)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppColors.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final dynamic order;

  const _ActivityItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 8)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.shopping_cart,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          'طلب جديد من ${order.customerName}',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${order.grandTotal.toStringAsFixed(0)} د.ع',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Text(
          _formatTime(order.createdAt),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}د';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}س';
    } else {
      return '${difference.inDays}يوم';
    }
  }
}

class _AdminOrderCard extends StatelessWidget {
  final dynamic order;

  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'طلب #${order.id.substring(0, 8)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveSpacing(context, 8), vertical: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Builder(
                    builder: (context) => Text(
                      _getStatusText(order.status, context),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'العميل: ${order.customerName}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'المبلغ: ${order.grandTotal.toStringAsFixed(0)} د.ع',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'assigned':
        return AppColors.primary;
      case 'accepted':
        return AppColors.success;
      case 'picked_up':
        return AppColors.secondary;
      case 'in_transit':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getStatusText(String status, BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (status) {
      case 'pending':
        return loc.pending;
      case 'assigned':
        return loc.statusAssigned;
      case 'accepted':
        return loc.accepted;
      case 'picked_up':
        return loc.pickedUp;
      case 'in_transit':
        return loc.statusOnTheWay;
      case 'delivered':
        return loc.delivered;
      case 'cancelled':
        return loc.cancelled;
      default:
        return loc.unknown;
    }
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: AppTextStyles.heading3.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
