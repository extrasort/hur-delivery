import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/responsive_screen_wrapper.dart';
import '../../../shared/models/scheduled_order_model.dart';
import '../../../core/widgets/header_notification.dart';
import '../../orders/widgets/merchant_order_card.dart';
import '../../wallet/widgets/wallet_balance_widget.dart';
import '../../wallet/widgets/credit_limit_guard.dart';
import '../../wallet/screens/wallet_screen.dart';
import 'merchant_analytics_screen.dart';
import 'dart:async';
import '../../../core/providers/announcement_provider.dart';
import '../../../core/providers/system_status_provider.dart';
import '../../../shared/widgets/maintenance_mode_dialog.dart';
import '../../../core/localization/app_localizations.dart';
// Removed legacy stable_order_card_manager import

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<OrderProvider>().initialize();
        
        // Initialize system status checking
        await context.read<SystemStatusProvider>().initialize();
        
        // Initialize wallet
        final authProvider = context.read<AuthProvider>();
        if (authProvider.user != null) {
          await context.read<WalletProvider>().initialize(authProvider.user!.id);
          
          // Initialize announcement checker (checks every 5 seconds)
          if (mounted) {
            await context.read<AnnouncementProvider>().initialize(
              userRole: 'merchant',
              userId: authProvider.user!.id,
              context: context,
            );
          }
          
          // Check system status and show dialog if disabled
          if (mounted) {
            final systemStatus = context.read<SystemStatusProvider>();
            if (!systemStatus.isSystemEnabled) {
              MaintenanceModeDialog.show(context, 'merchant');
            }
          }
        }
      } catch (e) {
        print('Error initializing merchant dashboard: $e');
        // Don't crash - just log error
      }
    });
  }

  @override
  void dispose() {
    // Stop announcement checking when leaving dashboard
    context.read<AnnouncementProvider>().stopChecking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check auth state - redirect if not authenticated
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const WalletBalanceWidget(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.push('/merchant-dashboard/notifications');
            },
          ),
          // Support button removed from header - now in footer
        ],
      ),
      drawer: _buildDrawer(context, authProvider),
      body: CreditLimitGuard(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _OrdersTab(),
            const WalletScreen(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/merchant-dashboard/create-order');
            },
            borderRadius: BorderRadius.circular(32),
            child: const Center(
              child: Icon(Icons.add_rounded, size: 32, color: Colors.white),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          clipBehavior: Clip.antiAlias,
          color: AppColors.primary,
          elevation: 8,
          child: Directionality(
            textDirection: TextDirection.ltr,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                  // Support button
                Expanded(
                  child: _buildFooterButton(
                      icon: Icons.support_agent,
                      label: loc.support,
                      isSelected: false,
                      onTap: () => _openSupportChat(context),
                  ),
                ),
                // Voice order button
                Expanded(
                  child: _buildFooterButton(
                    icon: Icons.mic_rounded,
                    label: loc.voice,
                    isSelected: false,
                    onTap: () => context.push('/merchant-dashboard/create-order?page=3'),
                  ),
                ),
                // Spacer for FAB
                const SizedBox(width: 40),
                // Wallet button
                Expanded(
                  child: _buildFooterButton(
                    icon: Icons.account_balance_wallet_rounded,
                    label: loc.wallet,
                    isSelected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                  // Home button
                Expanded(
                  child: _buildFooterButton(
                      icon: Icons.home_rounded,
                      label: loc.home,
                      isSelected: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
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

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildDrawer(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    
    return Drawer(
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              context.rs(20),
              context.rs(60),
              context.rs(20),
              context.rs(20),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: context.rs(35),
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: context.ri(35),
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: context.rs(12)),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        ResponsiveText(
                          user?.name ?? loc.notSpecified,
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                          ).responsive(context),
                        ),
                        SizedBox(height: context.rs(4)),
                        ResponsiveText(
                          user?.phone ?? loc.notSpecified,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ).responsive(context),
                        ),
                        SizedBox(height: context.rs(8)),
                        Container(
                          padding: context.rp(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(context.rs(12)),
                          ),
                          child: ResponsiveText(
                            loc.merchantLabel,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ).responsive(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        _buildDrawerItem(
                          icon: Icons.edit_outlined,
                          title: loc.editProfile,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/edit-profile');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.notifications_outlined,
                          title: loc.notifications,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/notifications');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.analytics_outlined,
                          title: loc.analytics,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const MerchantAnalyticsScreen(),
                              ),
                            );
                          },
                        ),
                        // Support removed from drawer - now in footer
                        _buildDrawerItem(
                          icon: Icons.settings_outlined,
                          title: loc.settings,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/settings');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.privacy_tip_outlined,
                          title: loc.privacyPolicy,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/privacy-policy');
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.description_outlined,
                          title: loc.termsAndConditions,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/merchant-dashboard/terms-conditions');
                          },
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return _buildDrawerItem(
                  icon: Icons.logout,
                      title: loc.logout,
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                  isDestructive: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDestructive ? AppColors.error : AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

// Simple elegant order button
class _OrdersTab extends StatefulWidget {
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            tabs: [
              Tab(text: AppLocalizations.of(context).activeOrders),
              Tab(text: AppLocalizations.of(context).completedOrders),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ActiveOrdersList(),
              _CompletedOrdersList(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveOrdersList extends StatefulWidget {
  @override
  State<_ActiveOrdersList> createState() => _ActiveOrdersListState();
}

class _ActiveOrdersListState extends State<_ActiveOrdersList> {
  Timer? _refreshTimer;
  OrderProvider? _orderProvider;

  @override
  void initState() {
    super.initState();
    
    // Refresh every 5 seconds to keep orders live and updated
    // Note: Real-time subscription handles instant updates, this is just a backup
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _orderProvider != null && !_orderProvider!.isLoading) {
        // Fetch fresh data from the database (only if not already loading)
        _orderProvider!.refreshOrders();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        // Store reference to provider for timer callback
        _orderProvider = orderProvider;
        if (orderProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orderProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: context.ri(64), color: AppColors.error),
                SizedBox(height: context.rs(16)),
                ResponsiveText(
                  orderProvider.error!,
                  style: AppTextStyles.bodyLarge.responsive(context),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.rs(16)),
                ElevatedButton(
                  onPressed: () => orderProvider.refreshOrders(),
                  child: Text(AppLocalizations.of(context).retryAction),
                ),
              ],
            ),
          );
        }

        // Get all active orders (including rejected and those with ready countdown)
        final allActiveOrders = orderProvider.orders
            .where((order) => order.status != 'delivered' && 
                             order.status != 'cancelled')
            .toList()
          ..sort((a, b) {
            // Sort by ready_at first (orders not ready yet come first)
            if (a.readyAt != null && b.readyAt == null) return -1;
            if (a.readyAt == null && b.readyAt != null) return 1;
            if (a.readyAt != null && b.readyAt != null) {
              return a.readyAt!.compareTo(b.readyAt!);
            }
            // Then by creation time
            return b.createdAt.compareTo(a.createdAt);
          });

        // Use orders directly (legacy stable order card manager removed)
        final activeOrders = allActiveOrders;

        if (activeOrders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon - Watermark Style
                  Opacity(
                    opacity: 0.15,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: MediaQuery.of(context).size.width * 0.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/icons/icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              size: MediaQuery.of(context).size.width * 0.3,
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Text(
                        loc.noCurrentOrders,
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textTertiary,
                    ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => orderProvider.refreshOrders(),
          child: ListView.builder(
            padding: ResponsiveHelper.getResponsivePadding(context, horizontal: 16, vertical: 16),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              
              // Add action buttons for rejected orders
              if (order.status == 'rejected') {
                return MerchantOrderCard(
                  key: ValueKey('${order.id}_${order.status}_rejected'),
                  order: order,
                  actionButtons: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelOrder(order.id, orderProvider),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(AppLocalizations.of(context).cancel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Consumer<WalletProvider>(
                            builder: (context, walletProvider, _) {
                              final canRepost = walletProvider.balance > walletProvider.creditLimit;
                              return ElevatedButton.icon(
                                onPressed: canRepost 
                                    ? () => _repostOrder(order.id, order.deliveryFee, orderProvider)
                                    : null,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(AppLocalizations.of(context).repostOrder),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRepost ? Colors.orange.shade600 : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              
              return MerchantOrderCard(
                key: ValueKey('${order.id}_${order.status}'),
                order: order,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _cancelOrder(String orderId, OrderProvider orderProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).cancelOrderTitle),
        content: Text(AppLocalizations.of(context).cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).goBack),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context).cancelOrderAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await orderProvider.updateOrderStatus(orderId, 'cancelled');
      if (mounted) {
        showHeaderNotification(
          context,
          title: success ? 'تم الإلغاء' : 'خطأ',
          message: success ? 'تم إلغاء الطلب بنجاح' : 'فشل إلغاء الطلب',
          type: success ? NotificationType.success : NotificationType.error,
        );
      }
    }
  }

  Future<int> _checkOnlineDrivers() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('is_online', true);
      
      return response.length;
    } catch (e) {
      print('Error checking online drivers: $e');
      return 0;
    }
  }

  Future<void> _repostOrder(String orderId, double currentFee, OrderProvider orderProvider) async {
    // Check credit limit first
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.balance <= walletProvider.creditLimit) {
      showHeaderNotification(
        context,
        title: 'رصيد غير كافٍ',
        message: 'يرجى شحن محفظتك أولاً لإعادة نشر الطلب',
        type: NotificationType.warning,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    
    // Get order details including vehicle type
    final order = orderProvider.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );
    
    final merchantId = order.merchantId;
    if (merchantId == null) {
      showHeaderNotification(
        context,
        title: 'خطأ في البيانات',
        message: 'لا يمكن تحديد التاجر لهذا الطلب. يرجى تحديث الصفحة والمحاولة مرة أخرى.',
        type: NotificationType.error,
      );
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
            title: Row(
              children: [
                Icon(Icons.warning, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).noDriversAvailableTitle),
              ],
            ),
            content: Text(
              availabilityResult.userMessage(context),
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).ok),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    final newFee = currentFee + 500;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: ResponsiveText(AppLocalizations.of(context).repostOrderTitle, style: TextStyle(fontSize: context.rf(18))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveText(AppLocalizations.of(context).repostOrderMessage, style: TextStyle(fontSize: context.rf(16))),
            SizedBox(height: context.rs(12)),
            Container(
              padding: context.rp(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(context.rs(8)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).currentFees),
                      Text(
                        '${currentFee.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).newFees),
                      Text(
                        '${newFee.toStringAsFixed(0)} د.ع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).goBack),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text(AppLocalizations.of(context).repostAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await orderProvider.repostOrder(orderId, newFee);
      if (mounted) {
        showHeaderNotification(
          context,
          title: success ? 'نجحت العملية' : 'خطأ',
          message: success 
              ? 'تم إعادة نشر الطلب بنجاح' 
              : 'فشل إعادة نشر الطلب',
          type: success ? NotificationType.success : NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }
}

class _CompletedOrdersList extends StatefulWidget {
  @override
  State<_CompletedOrdersList> createState() => _CompletedOrdersListState();
}

class _CompletedOrdersListState extends State<_CompletedOrdersList> {
  
  Future<void> _cancelOrder(String orderId, OrderProvider orderProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).cancelOrderTitle),
        content: Text(AppLocalizations.of(context).cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).goBack),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context).cancelOrderAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await orderProvider.cancelOrder(orderId);
    }
  }

  Future<void> _repostOrder(String orderId, double currentFee, OrderProvider orderProvider) async {
    // Get order details including vehicle type
    final order = orderProvider.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );
    
    final merchantId = order.merchantId;
    if (merchantId == null) {
      showHeaderNotification(
        context,
        title: 'خطأ في البيانات',
        message: 'لا يمكن تحديد التاجر لهذا الطلب. يرجى تحديث الصفحة والمحاولة مرة أخرى.',
        type: NotificationType.error,
      );
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
            title: Row(
              children: [
                Icon(Icons.warning, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).noDriversAvailableTitle),
              ],
            ),
            content: Text(
              availabilityResult.userMessage(context),
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).ok),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    final newFee = currentFee + 500;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).repostOrderTitle),
        content: Text(AppLocalizations.of(context).repostOrderNewFee(newFee.toStringAsFixed(0))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text(AppLocalizations.of(context).repostButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await orderProvider.repostOrder(orderId, newFee);
      if (mounted) {
        showHeaderNotification(
          context,
          title: success ? 'نجحت العملية' : 'خطأ',
          message: success 
              ? 'تم إعادة نشر الطلب بنجاح' 
              : 'فشل إعادة نشر الطلب',
          type: success ? NotificationType.success : NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        if (orderProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Get completed orders and sort by newest first
        final completedOrders = orderProvider.orders
            .where((order) => order.status == 'delivered' || 
                             order.status == 'cancelled')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (completedOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Text(
                      loc.noPastOrders,
                  style: AppTextStyles.heading3.copyWith(color: AppColors.textTertiary),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => orderProvider.refreshOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedOrders.length,
            itemBuilder: (context, index) {
              final order = completedOrders[index];
              
              // Add repost button for rejected orders in completed tab too
              if (order.status == 'rejected') {
                return MerchantOrderCard(
                  key: ValueKey('${order.id}_${order.status}_rejected_completed'),
                  order: order,
                  actionButtons: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelOrder(order.id, orderProvider),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(AppLocalizations.of(context).cancel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Consumer<WalletProvider>(
                            builder: (context, walletProvider, _) {
                              final canRepost = walletProvider.balance > walletProvider.creditLimit;
                              return ElevatedButton.icon(
                                onPressed: canRepost 
                                    ? () => _repostOrder(order.id, order.deliveryFee, orderProvider)
                                    : null,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(AppLocalizations.of(context).repostOrder),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRepost ? Colors.orange.shade600 : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              
              return MerchantOrderCard(
                key: ValueKey('${order.id}_${order.status}_completed'),
                order: order,
              );
            },
          ),
        );
      },
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  String _selectedTimePeriod = 'all'; // all, today, week, month
  String _selectedStatus = 'all'; // all, delivered, cancelled, rejected

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        print('📊 Merchant Analytics - Building...');
        print('📦 Total orders: ${orderProvider.orders.length}');
        
        try {
          // Filter orders by time period
          print('🔄 Starting time filter...');
          final filteredByTime = _filterOrdersByTimePeriod(orderProvider.orders);
          print('📅 After time filter: ${filteredByTime.length}');
          
          // Filter by status
          print('🔄 Starting status filter...');
          final filteredOrders = _selectedStatus == 'all' 
              ? filteredByTime
              : filteredByTime.where((o) => o.status == _selectedStatus).toList();
          print('🏷️  After status filter: ${filteredOrders.length}');

          // Calculate statistics
          print('🧮 Calculating statistics...');
          final stats = _calculateStatistics(filteredByTime);
          print('✅ Stats calculated: $stats');

          print('🎨 Building UI...');
          return Container(
            color: AppColors.surfaceVariant,
            child: SingleChildScrollView(
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
              
              // Status Breakdown
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.ordersByStatus,
                style: AppTextStyles.heading3,
                  );
                },
              ),
              const SizedBox(height: 12),
              
              _buildStatusFilter(),
              
              const SizedBox(height: 16),
              
              _buildStatusBreakdown(stats),
              
              const SizedBox(height: 24),
              
              // Financial Summary
              _buildFinancialSummary(stats),
              
              const SizedBox(height: 24),
              
              // Recent Orders Preview
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.recentOrders,
                style: AppTextStyles.heading3,
                  );
                },
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
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return Text(
                          loc.noOrdersInPeriod,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                        );
                      },
                    ),
                  ),
                )
              else
                ...filteredOrders.take(5).map((order) => _buildRecentOrderItem(order)),
              ],
            ),
          ),
        );
        } catch (e, stackTrace) {
          print('❌ ERROR building merchant analytics UI: $e');
          print('📍 Stack trace: $stackTrace');
          return Container(
            color: AppColors.surfaceVariant,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return Text(
                          loc.errorLoadingStats,
                      style: AppTextStyles.heading3,
                        );
                      },
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
            ),
          );
        }
      },
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

  Map<String, dynamic> _calculateStatistics(List orders) {
    final totalOrders = orders.length;
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
    final totalRevenue = deliveredOrders.fold(0.0, (sum, order) => sum + order.grandTotal);
    final totalDeliveryFees = deliveredOrders.fold(0.0, (sum, order) => sum + order.deliveryFee);

    // Calculate success rate
    final successRate = totalOrders > 0 
        ? (deliveredOrders.length / totalOrders * 100) 
        : 0.0;

    return {
      'totalOrders': totalOrders,
      'deliveredOrders': deliveredOrders.length,
      'cancelledOrders': cancelledOrders.length,
      'rejectedOrders': rejectedOrders.length,
      'activeOrders': activeOrders.length,
      'avgDeliveryMinutes': avgDeliveryMinutes,
      'totalRevenue': totalRevenue,
      'totalDeliveryFees': totalDeliveryFees,
      'successRate': successRate,
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
      child: Row(
        children: [
          _buildPeriodChip('all', 'الكل'),
          _buildPeriodChip('today', 'اليوم'),
          _buildPeriodChip('week', 'الأسبوع'),
          _buildPeriodChip('month', 'الشهر'),
        ],
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
      child: Row(
        children: [
          _buildStatusChip('all', 'الكل', Icons.list),
          const SizedBox(width: 8),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Row(
                children: [
                  _buildStatusChip('delivered', loc.deliveredStatus, Icons.check_circle),
          const SizedBox(width: 8),
                  _buildStatusChip('cancelled', loc.cancelledStatus, Icons.cancel),
          const SizedBox(width: 8),
                  _buildStatusChip('rejected', loc.rejectedStatus, Icons.block),
                ],
              );
            },
          ),
        ],
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
                        return _ModernStatCard(
                          title: loc.totalOrders,
                value: stats['totalOrders'].toString(),
                icon: Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                trend: null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
              child: _ModernStatCard(
                title: 'طلبات نشطة',
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
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return _ModernStatCard(
                          title: loc.deliveredLabel,
                value: stats['deliveredOrders'].toString(),
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                subtitle: '${stats['successRate'].toStringAsFixed(1)}% معدل النجاح',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return _ModernStatCard(
                          title: loc.cancelledRejectedLabel,
                value: '${stats['cancelledOrders'] + stats['rejectedOrders']}',
                icon: Icons.cancel_outlined,
                color: AppColors.error,
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
      timeDisplay = '$hours:${minutes.toString().padLeft(2, '0')}';
      timeUnit = 'ساعة';
    } else {
      timeDisplay = minutes.toString();
      timeUnit = 'دقيقة';
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
              Text(
                      'متوسط وقت التوصيل',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'من إنشاء الطلب حتى التسليم',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
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
            Text(
              'بناءً على ${stats['deliveredOrders']} طلب مكتمل',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(Map<String, dynamic> stats) {
    return Builder(
      builder: (context) {
        final loc = AppLocalizations.of(context);
    return Column(
      children: [
        _buildStatusRow(
              loc.deliveredLabel,
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
          'نشطة',
          stats['activeOrders'],
          stats['totalOrders'],
          AppColors.primary,
          Icons.pending_actions,
        ),
      ],
        );
      },
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

  Widget _buildFinancialSummary(Map<String, dynamic> stats) {
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
              Text(
                'الملخص المالي',
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildFinancialRow(
            'إجمالي الإيرادات',
            '${stats['totalRevenue'].toStringAsFixed(0)} د.ع',
          ),
          const SizedBox(height: 12),
          _buildFinancialRow(
            'إجمالي رسوم التوصيل',
            '${stats['totalDeliveryFees'].toStringAsFixed(0)} د.ع',
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صافي الإيرادات',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(stats['totalRevenue'] - stats['totalDeliveryFees']).toStringAsFixed(0)} د.ع',
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

  Widget _buildFinancialRow(String label, String value) {
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
                  order.customerName,
                      style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
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
                '${order.grandTotal.toStringAsFixed(0)} د.ع',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              Text(
                'المجموع الكلي (الطلب + التوصيل)',
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
        return Icons.delivery_dining;
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
        return loc.pendingStatus;
      case 'assigned':
        return loc.assignedStatus;
      case 'accepted':
        return loc.acceptedStatus;
      case 'on_the_way':
        return loc.onTheWayStatus;
      case 'delivered':
        return loc.deliveredStatus;
      case 'cancelled':
        return loc.cancelledStatus;
      case 'rejected':
        return loc.rejectedStatus;
      default:
        return loc.unknownStatus;
    }
  }
}

Future<void> _openSupportChat(BuildContext context) async {
  // Go directly to support conversation - no popup or list
  context.push('/merchant/support');
}
class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.name ?? 'غير محدد',
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? 'غير محدد',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'تاجر',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Menu Items
              _ProfileMenuItem(
                icon: Icons.edit_outlined,
                title: 'تعديل الملف الشخصي',
                onTap: () {
                  context.push('/merchant-dashboard/edit-profile');
                },
              ),
              _ProfileMenuItem(
                icon: Icons.notifications_outlined,
                title: 'الإشعارات',
                onTap: () {
                  context.push('/merchant-dashboard/notifications');
                },
              ),
              // Support removed - now in footer
              _ProfileMenuItem(
                icon: Icons.settings_outlined,
                title: 'الإعدادات',
                onTap: () {
                  context.push('/merchant-dashboard/settings');
                },
              ),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return _ProfileMenuItem(
                icon: Icons.logout,
                    title: loc.logout,
                onTap: () {
                  context.read<AuthProvider>().logout();
                  context.go('/');
                },
                isDestructive: true,
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
        padding: const EdgeInsets.all(16),
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

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? trend;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
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
          Row(
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
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trend!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
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

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
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
