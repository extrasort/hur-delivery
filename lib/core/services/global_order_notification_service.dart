import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'flutterfire_notification_service.dart';

/// Global In-App Order Notification Service
/// 
/// Shows overlay notifications for order updates when user is anywhere in the app
/// - Works on all screens (not just dashboard)
/// - Plays sound and vibrates
/// - Shows visual banner
/// - One notification per order event
class GlobalOrderNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static RealtimeChannel? _driverOrderChannel;
  static RealtimeChannel? _merchantOrderChannel;
  static String? _currentUserId;
  static String? _currentUserRole;
  static bool _isMonitoring = false;
  static final Set<String> _shownNotifications = {};

  /// Initialize the service for a user
  static Future<void> initialize({
    required String userId,
    required String userRole,
  }) async {
    if (_isMonitoring) {
      print('ℹ️ Global notification service already running');
      return;
    }

    _currentUserId = userId;
    _currentUserRole = userRole;

    print('\n═══════════════════════════════════════');
    print('🔔 STARTING GLOBAL ORDER NOTIFICATION SERVICE');
    print('═══════════════════════════════════════');
    print('User ID: $userId');
    print('Role: $userRole');

    if (userRole == 'driver') {
      await _startDriverMonitoring(userId);
    } else if (userRole == 'merchant') {
      await _startMerchantMonitoring(userId);
    }

    _isMonitoring = true;
    print('✅ Global notification service started');
    print('═══════════════════════════════════════\n');
  }

  /// Start monitoring for driver
  static Future<void> _startDriverMonitoring(String driverId) async {
    print('👨‍✈️ Setting up driver order monitoring...');

    _driverOrderChannel = Supabase.instance.client
        .channel('global_driver_orders_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            _handleDriverOrderUpdate(payload);
          },
        )
        .subscribe();

    print('✅ Driver order monitoring active');
  }

  /// Start monitoring for merchant
  static Future<void> _startMerchantMonitoring(String merchantId) async {
    print('👨‍💼 Setting up merchant order monitoring...');

    _merchantOrderChannel = Supabase.instance.client
        .channel('global_merchant_orders_$merchantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: merchantId,
          ),
          callback: (payload) {
            _handleMerchantOrderUpdate(payload);
          },
        )
        .subscribe();

    print('✅ Merchant order monitoring active');
  }

  /// Handle driver order updates
  static void _handleDriverOrderUpdate(PostgresChangePayload payload) {
    final orderData = payload.newRecord;
    final orderId = orderData['id'] as String?;
    final status = orderData['status'] as String?;
    final oldRecord = payload.oldRecord;
    final oldStatus = oldRecord?['status'] as String?;

    if (orderId == null || status == null) return;

    // Create unique notification key for this event
    final notificationKey = '${orderId}_${oldStatus}_to_$status';

    // Skip if already shown
    if (_shownNotifications.contains(notificationKey)) {
      return;
    }

    print('\n🔔 Driver order update detected:');
    print('   Order ID: $orderId');
    print('   Status: $oldStatus → $status');

    // Determine notification based on status change
    String? title;
    String? message;
    Color? color;
    IconData? icon;

    if (status == 'assigned' && oldStatus != 'assigned') {
      title = '🎯 طلب جديد';
      message = 'تم تعيين طلب جديد لك';
      color = Colors.blue;
      icon = Icons.assignment;
      // Play custom assignment sound even if app is in foreground
      FlutterFireNotificationService.playAssignmentSound();
    } else if (status == 'accepted') {
      title = '✅ تم القبول';
      message = 'تم قبول الطلب بنجاح';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'on_the_way') {
      title = '🚗 في الطريق';
      message = 'الطلب في طريقه للتسليم';
      color = Colors.orange;
      icon = Icons.local_shipping;
    } else if (status == 'delivered') {
      title = '🎉 تم التسليم';
      message = 'تم تسليم الطلب بنجاح';
      color = Colors.green;
      icon = Icons.done_all;
    } else if (status == 'rejected' || status == 'cancelled') {
      title = '❌ ملغي';
      message = 'تم إلغاء الطلب';
      color = Colors.red;
      icon = Icons.cancel;
    }

    if (title != null && message != null) {
      _shownNotifications.add(notificationKey);
      _showOverlayNotification(
        title: title,
        message: message,
        color: color ?? Colors.blue,
        icon: icon ?? Icons.notifications,
      );
    }
  }

  /// Handle merchant order updates
  static void _handleMerchantOrderUpdate(PostgresChangePayload payload) {
    final orderData = payload.newRecord;
    final orderId = orderData['id'] as String?;
    final status = orderData['status'] as String?;
    final oldRecord = payload.oldRecord;
    final oldStatus = oldRecord?['status'] as String?;

    if (orderId == null || status == null) return;

    // Create unique notification key
    final notificationKey = '${orderId}_${oldStatus}_to_$status';

    // Skip if already shown
    if (_shownNotifications.contains(notificationKey)) {
      return;
    }

    print('\n🔔 Merchant order update detected:');
    print('   Order ID: $orderId');
    print('   Status: $oldStatus → $status');

    // Determine notification
    String? title;
    String? message;
    Color? color;
    IconData? icon;

    if (status == 'assigned') {
      title = '👨‍✈️ تم تعيين سائق';
      message = 'تم تعيين سائق لطلبك';
      color = Colors.blue;
      icon = Icons.person;
    } else if (status == 'accepted') {
      title = '✅ قبل السائق';
      message = 'السائق قبل الطلب';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'on_the_way') {
      title = '🚗 في الطريق';
      message = 'السائق في طريقه للتسليم';
      color = Colors.orange;
      icon = Icons.local_shipping;
    } else if (status == 'delivered') {
      title = '🎉 تم التسليم';
      message = 'تم تسليم الطلب بنجاح';
      color = Colors.green;
      icon = Icons.done_all;
    } else if (status == 'rejected') {
      title = '❌ رفض السائق';
      message = 'السائق رفض الطلب - جاري البحث عن سائق آخر';
      color = Colors.red;
      icon = Icons.cancel;
    }

    if (title != null && message != null) {
      _shownNotifications.add(notificationKey);
      _showOverlayNotification(
        title: title,
        message: message,
        color: color ?? Colors.blue,
        icon: icon ?? Icons.notifications,
      );
    }
  }

  /// Show overlay notification banner
  static void _showOverlayNotification({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      print('⚠️ No context available for overlay notification');
      return;
    }

    print('📢 Showing overlay notification: $title');

    // Haptic feedback (vibration)
    try {
      HapticFeedback.heavyImpact();
      // Double vibration for emphasis
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('⚠️ Could not trigger haptic feedback: $e');
    }

    // Show overlay banner
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _NotificationBanner(
        title: title,
        message: message,
        color: color,
        icon: icon,
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }

  /// Stop monitoring
  static Future<void> stop() async {
    print('🛑 Stopping global order notification service');
    
    await _driverOrderChannel?.unsubscribe();
    await _merchantOrderChannel?.unsubscribe();
    
    _driverOrderChannel = null;
    _merchantOrderChannel = null;
    _currentUserId = null;
    _currentUserRole = null;
    _isMonitoring = false;
    _shownNotifications.clear();
    
    print('✅ Global notification service stopped');
  }

  /// Clear notification history (e.g., on logout)
  static void clearHistory() {
    _shownNotifications.clear();
    print('🧹 Notification history cleared');
  }
}

/// Notification Banner Widget
class _NotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _NotificationBanner({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Start exit animation after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color,
                        widget.color.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

