import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_manager.dart';
import 'foreground_service.dart';

/// Background service that keeps the app alive and listens for notifications
/// Integrates with foreground service for driver mode
class BackgroundService {
  static RealtimeChannel? _notificationChannel; // Persistent realtime channel
  static RealtimeChannel? _orderChannel; // Persistent realtime channel for orders
  static DateTime? _startTime; // Track when service started to filter old notifications
  static final Set<String> _processedNotificationIds = {}; // Track processed notifications globally
  static bool _isRunning = false;
  static bool _useForegroundService = false;
  
  /// Initialize background service
  static Future<void> initialize() async {
    print('📱 Background service initialized');
    // Initialize foreground service as well
    await ForegroundServiceManager.initialize();
  }
  
  /// Start background service (call when driver goes online)
  /// For drivers, this will start a foreground service for reliability
  static Future<void> start(String userId, String userRole, String supabaseUrl, String supabaseKey, {String? driverName}) async {
    if (_isRunning) {
      print('⚠️ Background service already running');
      return;
    }
    
    print('🔄 Starting background service for user: $userId ($userRole)');
    _isRunning = true;
    
    // Store credentials for reconnection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_role', userRole);
    await prefs.setBool('service_running', true);
    
    // Record start time to filter out old notifications - use UTC
    _startTime = DateTime.now().toUtc();
    await prefs.setString('service_start_time', _startTime!.toIso8601String());
    print('📅 Service start time: $_startTime (UTC)');
    
    // For drivers, use foreground service for maximum reliability
    if (userRole == 'driver') {
      _useForegroundService = true;
      final started = await ForegroundServiceManager.startService(
        userId: userId,
        driverName: driverName ?? 'السائق',
      );
      
      if (started) {
        print('✅ Foreground service started for driver');
      } else {
        print('⚠️ Foreground service failed to start, falling back to background mode');
        _useForegroundService = false;
      }
    }
    
    // Start real-time subscriptions (works for both foreground and background)
    _subscribeToNotifications(userId);
    if (userRole == 'driver') {
      _subscribeToOrders(userId);
    }
    
    print('✅ Background service started successfully');
  }
  
  /// Stop background service (call when driver goes offline or logs out)
  static Future<void> stop() async {
    print('🛑 Stopping background service');
    _isRunning = false;
    
    // Stop foreground service if it was running
    if (_useForegroundService) {
      await ForegroundServiceManager.stopService();
      _useForegroundService = false;
    }
    
    // Clear stored credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.setBool('service_running', false);
    await prefs.remove('service_start_time');
    
    // Unsubscribe from realtime channels
    await _notificationChannel?.unsubscribe();
    await _orderChannel?.unsubscribe();
    _notificationChannel = null;
    _orderChannel = null;
    _startTime = null;
    _processedNotificationIds.clear();
    
    print('✅ Background service stopped');
  }
  
  /// Update foreground service notification with new order
  static Future<void> updateWithNewOrder({
    required String orderId,
    required String customerName,
    required String pickupAddress,
  }) async {
    if (_useForegroundService) {
      await ForegroundServiceManager.showNewOrder(
        orderId: orderId,
        customerName: customerName,
        pickupAddress: pickupAddress,
      );
    }
  }
  
  /// Update foreground service notification when order is in progress
  static Future<void> updateWithOrderInProgress({
    required String customerName,
    required String deliveryAddress,
  }) async {
    if (_useForegroundService) {
      await ForegroundServiceManager.showOrderInProgress(
        customerName: customerName,
        deliveryAddress: deliveryAddress,
      );
    }
  }
  
  /// Reset foreground service to idle state
  static Future<void> resetToIdle() async {
    if (_useForegroundService) {
      await ForegroundServiceManager.resetToIdle();
    }
  }
  
  /// Subscribe to notifications using persistent realtime channel
  static void _subscribeToNotifications(String userId) {
    // Unsubscribe from previous channel
    _notificationChannel?.unsubscribe();
    
    print('📡 Setting up persistent realtime channel for notifications...');
    print('🕐 Will only show notifications created after: $_startTime');
    
    // Create persistent realtime channel with WebSocket
    _notificationChannel = Supabase.instance.client
        .channel('bg_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('🔔 Realtime notification INSERT received!');
            final notification = payload.newRecord;
            final notificationId = notification['id'] as String;
            final createdAtStr = notification['created_at'] as String;
            final createdAt = DateTime.parse(createdAtStr).toUtc();
            
            print('⏰ Notification created at: $createdAt (UTC)');
            print('⏰ Service started at: $_startTime (UTC)');
            
            // Only show if not already processed
            if (!_processedNotificationIds.contains(notificationId)) {
              // If created within last 5 minutes, show it
              final now = DateTime.now().toUtc();
              final ageInSeconds = now.difference(createdAt).inSeconds;
              
              if (ageInSeconds < 300) { // Less than 5 minutes old
                print('📬 Showing notification: ${notification['title']} (age: ${ageInSeconds}s)');
                _processedNotificationIds.add(notificationId);
                _showNotificationFromData(notification);
              } else {
                print('⏭️ Skipping old notification (age: ${ageInSeconds}s)');
              }
            } else {
              print('⏭️ Skipping duplicate notification: $notificationId');
            }
          },
        )
        .subscribe(
          (status, error) {
            if (status == 'SUBSCRIBED') {
              print('✅ Background notification channel subscribed successfully');
            } else if (status == 'CHANNEL_ERROR') {
              print('❌ Background notification channel error: $error');
            } else if (status == 'TIMED_OUT') {
              print('⚠️ Background notification channel timed out, retrying...');
              // Retry subscription
              Future.delayed(const Duration(seconds: 5), () {
                if (_isRunning) {
                  _subscribeToNotifications(userId);
                }
              });
            }
          },
        );
  }
  
  /// Subscribe to orders using persistent realtime channel (for drivers)
  static void _subscribeToOrders(String driverId) {
    // Unsubscribe from previous channel
    _orderChannel?.unsubscribe();
    
    print('📡 Setting up persistent realtime channel for orders...');
    
    // Create persistent realtime channel for order updates
    _orderChannel = Supabase.instance.client
        .channel('bg_orders_$driverId')
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
            print('📦 Realtime order UPDATE received!');
            final order = payload.newRecord;
            
            // Check if order was just assigned
            if (order['driver_id'] == driverId && 
                order['status'] == 'pending' &&
                order['driver_assigned_at'] != null) {
              print('🚨 Order assigned to driver!');
              // TODO: Fix notification - disabled for now
              // NotificationManager calls handled by FCM directly
            }
          },
        )
        .subscribe(
          (status, error) {
            if (status == 'SUBSCRIBED') {
              print('✅ Background order channel subscribed successfully');
            } else if (status == 'CHANNEL_ERROR') {
              print('❌ Background order channel error: $error');
            } else if (status == 'TIMED_OUT') {
              print('⚠️ Background order channel timed out, retrying...');
              Future.delayed(const Duration(seconds: 5), () {
                if (_isRunning) {
                  _subscribeToOrders(driverId);
                }
              });
            }
          },
        );
  }
  
  /// Show notification from database notification data
  static Future<void> _showNotificationFromData(Map<String, dynamic> notification) async {
    // TODO: Fix notification method signatures - temporarily disabled
    // Notifications are handled by FCM directly via edge function
    print('📱 Notification received: ${notification['type']}');
  }
}

