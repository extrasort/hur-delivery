import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'dart:convert';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';

class MerchantNotificationsScreen extends StatefulWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  State<MerchantNotificationsScreen> createState() => _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState extends State<MerchantNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Set Arabic locale for timeago
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      // Update locally
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      // Update locally
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.notificationDeleted),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      // Update locally
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.allMarkedRead),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }
  
  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read
    if (!(notification['is_read'] ?? false)) {
      _markAsRead(notification['id']);
    }
    
    // Get notification data
    final data = notification['data'];
    String? orderId;
    
    // Extract order_id from data
    if (data != null) {
      try {
        // data could be a Map or a JSON string
        Map<String, dynamic> dataMap;
        if (data is String) {
          dataMap = jsonDecode(data);
        } else if (data is Map<String, dynamic>) {
          dataMap = data;
        } else {
          dataMap = Map<String, dynamic>.from(data);
        }
        orderId = dataMap['order_id'] ?? dataMap['orderId'];
      } catch (e) {
        print('Error parsing notification data: $e');
      }
    }
    
    // Navigate based on notification type
    final type = notification['type'] ?? '';
    
    if (orderId != null && orderId.isNotEmpty) {
      // Navigate to order details
      context.push('/merchant-dashboard/order-details/$orderId');
    } else {
      // If no order ID, show a message
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.noOrderLinked),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'driver_assignment':
      case 'order_accepted':
        return Icons.check_circle;
      case 'order_rejected':
        return Icons.cancel;
      case 'order_delivered':
        return Icons.done_all;
      case 'order_timeout':
        return Icons.access_time;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'driver_assignment':
      case 'order_accepted':
        return AppColors.primary;
      case 'order_rejected':
        return AppColors.error;
      case 'order_delivered':
        return AppColors.success;
      case 'order_timeout':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !(n['is_read'] ?? false)).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final loc = AppLocalizations.of(context);
            return Column(
              children: [
                Text(loc.notifications),
                if (unreadCount > 0)
                  Text(
                    loc.unreadCount(unreadCount),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
              ],
            );
          },
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: AppLocalizations.of(context).markAllRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).noNotifications,
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isRead = notification['is_read'] ?? false;
                      final type = notification['type'] ?? 'general';
                      final title = notification['title'] ?? '';
                      final message = notification['message'] ?? '';
                      final createdAt = DateTime.parse(notification['created_at']);

                      return Dismissible(
                        key: Key(notification['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => _deleteNotification(notification['id']),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isRead ? 0 : 2,
                          color: isRead ? Colors.white : AppColors.primary.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _handleNotificationTap(notification),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(type),
                                      color: _getNotificationColor(type),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: AppTextStyles.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          timeago.format(createdAt, locale: 'ar'),
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textTertiary,
                                            fontSize: 11,
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
                      );
                    },
                  ),
                ),
    );
  }
}

