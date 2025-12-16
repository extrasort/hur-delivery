import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_manager.dart';
import '../services/background_service.dart';
import '../constants/app_constants.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  final Set<String> _shownNotificationIds = {}; // Track which notifications we've already shown
  DateTime? _initializationTime; // Track when provider was initialized to filter old notifications
  RealtimeChannel? _notificationChannel; // Persistent realtime channel

  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get unreadNotifications => 
      _notifications.where((n) => n['is_read'] == false).toList();
  int get unreadCount => unreadNotifications.length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize notifications
  Future<void> initialize() async {
    _isLoading = true;
    
    // Set initialization time - use UTC for consistency with database
    _initializationTime = DateTime.now().toUtc();
    print('📅 NotificationProvider initialized at: $_initializationTime (UTC)');
    
    notifyListeners();

    try {
      await _loadNotifications();
      await _subscribeToNotifications();
      
      // Start background service conditionally
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final userRole = await _getUserRole(currentUser.id);
        if (userRole == 'driver') {
          final isOnline = await _getUserOnlineStatus(currentUser.id);
          if (isOnline) {
            await startBackgroundNotifications(currentUser.id, userRole);
          }
        } else {
          await startBackgroundNotifications(currentUser.id, userRole);
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error initializing notifications: $e');
      // Don't crash - just log the error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get user role from database
  Future<String> _getUserRole(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      return response['role'] as String? ?? 'driver';
    } catch (e) {
      print('Error getting user role: $e');
      return 'driver';
    }
  }

  Future<bool> _getUserOnlineStatus(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('is_online')
          .eq('id', userId)
          .single();
      return (response['is_online'] as bool?) ?? false;
    } catch (e) {
      print('Error getting user online status: $e');
      return false;
    }
  }
  
  // Start background notifications
  Future<void> startBackgroundNotifications(String userId, String userRole, {String? driverName}) async {
    try {
      await BackgroundService.start(
        userId,
        userRole,
        AppConstants.supabaseUrl,
        AppConstants.supabaseAnonKey,
        driverName: driverName,
      );
      print('✅ Background notifications started');
    } catch (e) {
      print('Error starting background notifications: $e');
    }
  }
  
  // Stop background notifications
  Future<void> stopBackgroundNotifications() async {
    try {
      await BackgroundService.stop();
      print('✅ Background notifications stopped');
    } catch (e) {
      print('Error stopping background notifications: $e');
    }
  }

  // Load notifications from database
  Future<void> _loadNotifications() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('No current user - skipping notification load');
        return;
      }

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = List<Map<String, dynamic>>.from(response);
      print('Loaded ${_notifications.length} notifications');
    } catch (e) {
      _error = e.toString();
      print('Error loading notifications: $e');
      // Don't throw - just log
      _notifications = [];
    }
  }

  // Subscribe to real-time notification updates using persistent channel
  Future<void> _subscribeToNotifications() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Unsubscribe from previous channel if exists
      await _notificationChannel?.unsubscribe();

      print('📡 Setting up persistent realtime channel for notifications...');

      // Create a persistent realtime channel with WebSocket
      _notificationChannel = Supabase.instance.client
          .channel('notifications_${currentUser.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: currentUser.id,
            ),
            callback: (payload) async {
              print('🔔 Realtime INSERT notification received!');
              final notification = payload.newRecord;
              final notificationId = notification['id'] as String;
              final createdAtStr = notification['created_at'] as String;
              final createdAt = DateTime.parse(createdAtStr).toUtc();
              
              print('⏰ Notification created at: $createdAt (UTC)');
              print('⏰ App initialized at: $_initializationTime (UTC)');
              print('⏰ Time difference: ${createdAt.difference(_initializationTime!).inSeconds}s');
              
              // Show if not already shown (primary check)
              // AND created after initialization (prevents spam on reconnect)
              if (!_shownNotificationIds.contains(notificationId)) {
                // If created within last 5 minutes, show it (catches edge cases)
                final now = DateTime.now().toUtc();
                final ageInSeconds = now.difference(createdAt).inSeconds;
                
                if (ageInSeconds < 300) { // Less than 5 minutes old
                  _shownNotificationIds.add(notificationId);
                  print('📬 Showing notification: ${notification['title']} (age: ${ageInSeconds}s)');
                  await _showLocalNotification(notification);
                  
                  // Reload notifications list
                  await _loadNotifications();
                } else {
                  print('⏭️ Skipping old notification (age: ${ageInSeconds}s)');
                }
              } else {
                print('⏭️ Skipping duplicate notification: $notificationId');
              }
            },
          )
          .subscribe();

      print('✅ Realtime channel subscribed successfully');
      
      // Also set up periodic refresh as fallback (every 10 seconds)
      _startPeriodicRefresh(currentUser.id);
      
    } catch (e) {
      _error = e.toString();
      print('❌ Error subscribing to notifications: $e');
    }
  }

  // Periodic refresh as fallback (checks for missed notifications)
  void _startPeriodicRefresh(String userId) {
    Future.delayed(const Duration(seconds: 10), () async {
      if (_notificationChannel != null) {
        // Check for any unread notifications we might have missed
        try {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            final response = await Supabase.instance.client
                .from('notifications')
                .select()
                .eq('user_id', currentUser.id)
                .eq('is_read', false)
                .order('created_at', ascending: false)
                .limit(10);

            for (var notification in response) {
              final notificationId = notification['id'] as String;
              
              // If we haven't shown this notification yet, show it now
              if (!_shownNotificationIds.contains(notificationId)) {
                final createdAtStr = notification['created_at'] as String;
                final createdAt = DateTime.parse(createdAtStr).toUtc();
                final now = DateTime.now().toUtc();
                final ageInSeconds = now.difference(createdAt).inSeconds;
                
                // Only show if less than 5 minutes old
                if (ageInSeconds < 300) {
                  print('🔍 Periodic check found missed notification: ${notification['title']}');
                  _shownNotificationIds.add(notificationId);
                  await _showLocalNotification(notification);
                }
              }
            }
          }
        } catch (e) {
          print('Error in periodic refresh: $e');
        }
        
        await _loadNotifications();
        _startPeriodicRefresh(userId); // Continue periodic refresh
      }
    });
  }

  // Cleanup on dispose
  @override
  void dispose() {
    _notificationChannel?.unsubscribe();
    super.dispose();
  }

  // Show local notification using NotificationService
  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    final type = notification['type'] as String;
    final title = notification['title'] as String;
    final body = notification['body'] as String;
    final orderId = notification['data']?['order_id'] as String?;
    
    try {
      // TODO: Fix notification handling - temporarily disabled due to signature mismatches
      print('📱 Would send notification type: $type');
      /*
      switch (type) {
        case 'order_assigned':
        case 'order_accepted':
        case 'order_rejected':
        case 'order_status_update':
        case 'order_delivered':
        case 'order_cancelled':
        default:
          // Notifications handled by FCM directly
          break;
      }
      */
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      // Update local list
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', currentUser.id)
          .eq('is_read', false);

      // Update local list
      for (var notification in _notifications) {
        notification['is_read'] = true;
        notification['read_at'] = DateTime.now().toIso8601String();
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

