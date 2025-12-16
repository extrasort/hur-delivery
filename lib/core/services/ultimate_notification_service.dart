import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Ultimate Notification Service - Rebuilt from scratch for 100% reliability
/// 
/// Design Principles:
/// 1. KISS (Keep It Simple, Stupid) - No over-engineering
/// 2. Direct subscription - No intermediate layers
/// 3. Immediate delivery - No filtering initially
/// 4. Extensive logging - Debug everything
/// 5. Fail-safe fallbacks - Multiple delivery paths
class UltimateNotificationService {
  static final UltimateNotificationService _instance = UltimateNotificationService._internal();
  factory UltimateNotificationService() => _instance;
  UltimateNotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static RealtimeChannel? _channel;
  static Timer? _heartbeatTimer;
  static Timer? _pollingTimer;
  static final Set<String> _deliveredIds = {};
  static String? _currentUserId;
  static bool _isInitialized = false;
  static DateTime? _lastCheck;

  /// Initialize the notification system
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Already initialized');
      return;
    }

    print('═══════════════════════════════════════');
    print('🚀 ULTIMATE NOTIFICATION SERVICE');
    print('═══════════════════════════════════════');

    // Step 1: Request permissions
    await _requestPermissions();

    // Step 2: Initialize local notifications
    await _initializeLocalNotifications();

    // Step 3: Create notification channels
    await _createChannels();

    _isInitialized = true;
    print('✅ Ultimate Notification Service initialized');
    print('═══════════════════════════════════════\n');
  }

  /// Request all necessary permissions
  static Future<void> _requestPermissions() async {
    print('📋 Requesting permissions...');

    // Notification permission
    final notifStatus = await Permission.notification.request();
    print('  Notification: ${notifStatus.isGranted ? "✅" : "❌"}');

    // Battery optimization exemption not requested for Play policy compliance
  }

  /// Initialize local notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    print('🔧 Initializing local notifications...');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        print('👆 Notification tapped: ${response.payload}');
      },
    );

    print('  ✅ Local notifications ready');
  }

  /// Create notification channels with maximum priority
  static Future<void> _createChannels() async {
    print('📢 Creating notification channels...');

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      print('  ⚠️ Android plugin not available');
      return;
    }

    // Ultra-critical channel for driver orders
    const ultraChannel = AndroidNotificationChannel(
      'ultra_critical',
      'طلبات عاجلة',
      description: 'إشعارات فورية للطلبات',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(ultraChannel);
    print('  ✅ Ultra-critical channel created');
  }

  /// Start listening for notifications for a specific user
  static Future<void> startListening(String userId) async {
    if (!_isInitialized) {
      print('❌ Not initialized. Call initialize() first.');
      return;
    }

    if (_currentUserId == userId && _channel != null) {
      print('⚠️ Already listening for user: $userId');
      return;
    }

    print('\n═══════════════════════════════════════');
    print('👂 STARTING TO LISTEN');
    print('═══════════════════════════════════════');
    print('User ID: $userId');

    _currentUserId = userId;
    await _stopListening(); // Clean up any existing subscription

    // Create realtime channel - subscribe to ALL notifications table changes
    _channel = Supabase.instance.client
        .channel('ultimate_notifications_$userId')
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
            print('\n🔥🔥🔥 POSTGRES CHANGE EVENT RECEIVED 🔥🔥🔥');
            print('Event Type: ${payload.eventType}');
            print('Table: ${payload.table}');
            print('Schema: ${payload.schema}');
            print('Raw Payload: ${payload.toString()}');
            _onNotificationReceived(payload);
          },
        )
        .subscribe((status, error) {
          print('\n📡 SUBSCRIPTION STATUS CHANGED: $status');
          if (error != null) {
            print('❌ ERROR: $error');
          }
          
          if (status == 'SUBSCRIBED') {
            print('✅ REALTIME CHANNEL ACTIVE');
            print('✅ Listening for user: $userId');
            print('✅ Table: notifications');
            print('✅ Event: INSERT');
            print('═══════════════════════════════════════\n');
          } else if (status == 'CHANNEL_ERROR') {
            print('❌ CHANNEL ERROR: $error');
            _retrySubscription(userId);
          } else if (status == 'TIMED_OUT') {
            print('⏱️ CHANNEL TIMEOUT - Retrying...');
            _retrySubscription(userId);
          } else if (status == 'CLOSED') {
            print('🚪 CHANNEL CLOSED - Reconnecting...');
            _retrySubscription(userId);
          }
        });

    // Start heartbeat (checks connection every 5 seconds)
    _startHeartbeat();
    
    // Start polling as fallback (checks database every 3 seconds)
    _startPolling();
  }

  /// Stop listening for notifications
  static Future<void> _stopListening() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
      print('🛑 Stopped listening');
    }
  }

  /// Callback when notification is received via realtime
  static void _onNotificationReceived(PostgresChangePayload payload) {
    print('\n🔔🔔🔔 NOTIFICATION RECEIVED 🔔🔔🔔');
    print('Time: ${DateTime.now()}');

    try {
      final data = payload.newRecord;
      final notificationId = data['id'] as String;
      final title = data['title'] as String;
      final body = data['body'] as String;
      final type = data['type'] as String?;
      final createdAt = data['created_at'] as String;

      print('📋 Details:');
      print('  ID: $notificationId');
      print('  Title: $title');
      print('  Body: $body');
      print('  Type: $type');
      print('  Created: $createdAt');

      // Check if already delivered
      if (_deliveredIds.contains(notificationId)) {
        print('  ⏭️ Already delivered - skipping');
        return;
      }

      // Mark as delivered
      _deliveredIds.add(notificationId);

      // Show notification IMMEDIATELY
      _showLocalNotification(
        title: title,
        body: body,
        payload: notificationId,
        isCritical: type == 'order_assigned',
      );

      print('✅ NOTIFICATION DELIVERED\n');
    } catch (e, stack) {
      print('❌ ERROR processing notification: $e');
      print('Stack trace: $stack');
    }
  }

  /// Show local notification with maximum priority
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    bool isCritical = false,
  }) async {
    print('📱 Showing local notification...');

    final androidDetails = AndroidNotificationDetails(
      'ultra_critical',
      'طلبات عاجلة',
      channelDescription: 'إشعارات فورية للطلبات',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      enableLights: true,
      ledColor: const Color(0xFF0000FF),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'حُر للتوصيل',
      ),
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: isCritical,
      ongoing: isCritical,
      autoCancel: !isCritical,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );

    print('  ✅ Local notification shown (ID: $notificationId)');
  }

  /// Retry subscription after timeout
  static void _retrySubscription(String userId) {
    Future.delayed(const Duration(seconds: 5), () {
      if (_currentUserId == userId) {
        print('🔄 Retrying subscription...');
        startListening(userId);
      }
    });
  }

  /// Polling as fallback - checks database for new notifications
  static void _startPolling() {
    _lastCheck = DateTime.now().toUtc();
    _pollingTimer?.cancel();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_currentUserId == null) {
        print('⚠️ Polling: No user ID');
        return;
      }

      try {
        // Query for unread notifications created after last check
        final response = await Supabase.instance.client
            .from('notifications')
            .select()
            .eq('user_id', _currentUserId!)
            .eq('is_read', false)
            .gte('created_at', _lastCheck!.toIso8601String())
            .order('created_at', ascending: true);

        if (response.isNotEmpty) {
          print('🔍 POLLING FOUND ${response.length} NEW NOTIFICATION(S)');
          
          for (var notification in response) {
            final notificationId = notification['id'] as String;
            
            if (!_deliveredIds.contains(notificationId)) {
              print('📬 Delivering via polling: ${notification['title']}');
              
              _deliveredIds.add(notificationId);
              await _showLocalNotification(
                title: notification['title'] as String,
                body: notification['body'] as String,
                payload: notificationId,
                isCritical: notification['type'] == 'order_assigned',
              );
            }
          }
        }
        
        _lastCheck = DateTime.now().toUtc();
      } catch (e) {
        print('❌ Polling error: $e');
      }
    });
    
    print('✅ Polling started (every 3 seconds as fallback)');
  }

  /// Heartbeat to monitor connection health
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_channel != null) {
        print('💓 Heartbeat: Connection alive');
      } else {
        print('💔 Heartbeat: Connection dead - reconnecting...');
        if (_currentUserId != null) {
          startListening(_currentUserId!);
        }
      }
    });
  }

  /// Stop everything
  static Future<void> stop() async {
    print('🛑 Stopping Ultimate Notification Service...');
    await _stopListening();
    _currentUserId = null;
    _deliveredIds.clear();
    print('✅ Stopped\n');
  }

  /// Test notification (for debugging)
  static Future<void> sendTestNotification() async {
    print('🧪 Sending test notification...');
    await _showLocalNotification(
      title: '🧪 Test Notification',
      body: 'If you see this, the notification system works!',
      payload: 'test',
      isCritical: true,
    );
  }

  /// Get connection status
  static String getStatus() {
    if (!_isInitialized) return '❌ Not initialized';
    if (_channel == null) return '⚠️ Not listening';
    if (_currentUserId == null) return '⚠️ No user';
    return '✅ Active for user: $_currentUserId';
  }
}

