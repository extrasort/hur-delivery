import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// FlutterFire Notification Service
/// 
/// Modern notification service using:
/// - Firebase Cloud Messaging (FCM) for push notifications
/// - Flutter Local Notifications for reliable delivery
/// - Supabase for token management and backend integration
/// - Background message handling
/// - Token refresh management
/// - Permission handling
class FlutterFireNotificationService {
  static final FlutterFireNotificationService _instance = FlutterFireNotificationService._internal();
  factory FlutterFireNotificationService() => _instance;
  FlutterFireNotificationService._internal();

  static FirebaseMessaging? _messaging;
  static FlutterLocalNotificationsPlugin? _localNotifications;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static String? _fcmToken;
  static bool _isInitialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('\n═══════════════════════════════════════');
    print('🔥 INITIALIZING FLUTTERFIRE NOTIFICATIONS');
    print('═══════════════════════════════════════');

    try {
      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;
      
      // Initialize local notifications
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      // Request permissions
      await _requestPermissions();
      
      // Configure local notifications
      await _configureLocalNotifications();
      
      // Configure message handlers
      await _configureMessageHandlers();
      
      _isInitialized = true;
      
      print('✅ FlutterFire notification service initialized successfully');
      print('✅ Ready for token generation after authentication');
      print('═══════════════════════════════════════\n');
      
    } catch (e) {
      print('❌ FlutterFire notification initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize with token generation (call after user authentication)
  static Future<void> initializeWithToken() async {
    print('\n═══════════════════════════════════════');
    print('🔥 INITIALIZING WITH TOKEN GENERATION');
    print('═══════════════════════════════════════');

    try {
      // Ensure service is initialized first
      if (!_isInitialized) {
        print('⚠️ Service not initialized, initializing first...');
        await initialize();
      }
      
      // Force refresh FCM token to ensure it's current
      await _refreshFCMToken();
      
      print('✅ FCM token generated and saved');
      print('✅ Token: ${_fcmToken?.substring(0, 20)}...');
      print('═══════════════════════════════════════\n');
      
    } catch (e) {
      print('❌ FCM token generation failed: $e');
      rethrow;
    }
  }

  /// Force refresh FCM token and save to database
  static Future<void> _refreshFCMToken() async {
    print('🔄 Force refreshing FCM token...');
    print('   _messaging is null: ${_messaging == null}');
    
    if (_messaging == null) {
      print('❌ Firebase messaging not initialized');
      return;
    }
    
    try {
      // Delete old token to force refresh
      await _messaging!.deleteToken();
      print('✅ Old FCM token deleted');
      
      // Get new token
      await _getFCMToken();
      
      print('✅ FCM token refreshed successfully');
    } catch (e) {
      print('❌ Failed to refresh FCM token: $e');
      print('❌ Error type: ${e.runtimeType}');
      // Fallback to regular token generation
      await _getFCMToken();
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    print('🔐 Requesting notification permissions...');
    
    // Request FCM permissions
    final settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // Enable for iOS critical alerts
      provisional: false,
      sound: true,
    );
    
    print('FCM Permission status: ${settings.authorizationStatus}');
    
    // Request Android permissions
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  /// Configure local notifications
  static Future<void> _configureLocalNotifications() async {
    print('🔧 Configuring local notifications...');
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  static Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;
    
    final androidPlugin = _localNotifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;

    // Critical channel for order assignments (MAXIMUM priority)
    final criticalChannel = AndroidNotificationChannel(
      'critical_orders',
      'طلبات عاجلة',
      description: 'إشعارات الطلبات العاجلة - أولوية قصوى',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF0000FF),
      showBadge: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // Strong vibration
    );

    // Custom sound channel for driver assignment tone
    final assignmentSoundChannel = AndroidNotificationChannel(
      'assignment_sound',
      'نغمة تعيين الطلب',
      description: 'قناة بصوت مخصص لتعيين الطلب للسائق',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF0000FF),
      showBadge: false,
    );

    // High priority channel for regular notifications
    final highChannel = AndroidNotificationChannel(
      'hur_delivery_channel',
      'طلبات التوصيل',
      description: 'إشعارات طلبات التوصيل',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF00FF00),
      showBadge: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
    );

    // FCM channel for push notifications (FOREGROUND OPTIMIZED)
    final fcmChannel = AndroidNotificationChannel(
      'fcm_channel',
      'إشعارات Firebase',
      description: 'إشعارات Firebase Cloud Messaging - تظهر دائماً',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF0000FF),
      showBadge: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
    );

    await androidPlugin.createNotificationChannel(criticalChannel);
    await androidPlugin.createNotificationChannel(assignmentSoundChannel);
    await androidPlugin.createNotificationChannel(highChannel);
    await androidPlugin.createNotificationChannel(fcmChannel);
    
    print('✅ Notification channels created');
  }

  /// Play custom assignment sound via a lightweight local notification
  static Future<void> playAssignmentSound() async {
    if (_localNotifications == null) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        'assignment_sound',
        'نغمة تعيين الطلب',
        channelDescription: 'تشغيل صوت مخصص عند تعيين الطلب للسائق',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        onlyAlertOnce: true,
        autoCancel: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: true,
      );
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      // Minimal, transient notification to trigger sound
      await _localNotifications!.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        null,
        null,
        details,
        payload: 'assignment_sound',
      );
    } catch (e) {
      // Fallback: no-op
      print('⚠️ Failed to play assignment sound: $e');
    }
  }

  /// Get FCM token
  static Future<void> _getFCMToken() async {
    print('🎫 Getting FCM token...');
    print('   _messaging is null: ${_messaging == null}');
    
    if (_messaging == null) {
      print('❌ Firebase messaging not initialized');
      return;
    }
    
    try {
      print('   Calling _messaging.getToken()...');
      _fcmToken = await _messaging!.getToken();
      print('   getToken() returned: ${_fcmToken != null ? "non-null" : "null"}');
      
      if (_fcmToken != null) {
        print('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        print('   Full token length: ${_fcmToken!.length}');
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        print('✅ FCM token saved to SharedPreferences');
        
        // Listen for token refresh
        _messaging!.onTokenRefresh.listen((newToken) async {
          print('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
          _fcmToken = newToken;
          await _saveTokenToDatabase();
          print('✅ New FCM token saved to database');
        });
        
        // Save to database immediately
        await _saveTokenToDatabase();
      } else {
        print('❌ FCM token is null - this usually means permissions not granted');
        throw Exception('Failed to get FCM token - likely permission issue');
      }
    } catch (e) {
      print('❌ Failed to get FCM token: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Configure message handlers
  static Future<void> _configureMessageHandlers() async {
    print('📡 Configuring message handlers...');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    
    // Handle terminated app messages
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// Save FCM token to database
  static Future<void> _saveTokenToDatabase() async {
    print('\n💾 ATTEMPTING TO SAVE FCM TOKEN TO DATABASE');
    print('═══════════════════════════════════════');
    
    if (_fcmToken == null) {
      print('❌ Cannot save FCM token: token is null');
      return;
    }
    
    print('✅ FCM token is available: ${_fcmToken!.substring(0, 20)}...');
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      print('🔍 Checking authentication status...');
      print('   User object: $user');
      print('   User ID: ${user?.id}');
      print('   User email: ${user?.email}');
      
      if (user == null) {
        print('❌ Cannot save FCM token: user not authenticated');
        return;
      }
      
      print('✅ User is authenticated, proceeding with database save...');
      
      print('💾 Saving FCM token to database...');
      print('   User ID: ${user.id}');
      print('   FCM Token: ${_fcmToken!.substring(0, 20)}...');
      print('   Platform: ${Platform.isAndroid ? 'android' : 'ios'}');
      
      // ALWAYS delete old tokens for this user first (to prevent duplicates)
      try {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', user.id);
        
        print('✅ Deleted old FCM tokens for user');
      } catch (e) {
        print('⚠️  Failed to delete old tokens (may not exist): $e');
      }
      
      // Insert new token (with ON CONFLICT handling at database level via unique constraint)
      final now = DateTime.now().toIso8601String();
      try {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .insert({
              'user_id': user.id,
              'fcm_token': _fcmToken,
              'platform': Platform.isAndroid ? 'android' : 'ios',
              'created_at': now,
              'updated_at': now,
            });
        
        print('✅ FCM token inserted to database successfully');
        print('   Insert timestamp: $now');
      } catch (e) {
        // If insert fails due to race condition (another instance deleted and inserted),
        // it's okay to ignore - the token is in the database
        if (e.toString().contains('duplicate') || e.toString().contains('409')) {
          print('ℹ️  FCM token already exists (race condition), skipping');
        } else {
          // Re-throw other errors
          throw e;
        }
      }
      
      // Verify the token was saved
      final verifyResult = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('fcm_token, created_at, updated_at')
          .eq('user_id', user.id)
          .single();
      
      print('✅ Token verification complete');
      
    } catch (e) {
      print('❌ Failed to save FCM token: $e');
      print('❌ Error details: ${e.toString()}');
    }
  }

  /// Get device information
  static Future<String> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        return 'Android ${Platform.operatingSystemVersion}';
      } else if (Platform.isIOS) {
        return 'iOS ${Platform.operatingSystemVersion}';
      } else {
        return Platform.operatingSystem;
      }
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Handle foreground messages - ALWAYS SHOW NOTIFICATIONS
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('\n═══════════════════════════════════════');
    print('📨 FOREGROUND MESSAGE RECEIVED (APP ACTIVE)');
    print('═══════════════════════════════════════');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('Message ID: ${message.messageId}');
    print('From: ${message.from}');
    print('Sent Time: ${message.sentTime}');
    print('TTL: ${message.ttl}');
    print('═══════════════════════════════════════\n');
    
    // CRITICAL: Always show local notification even when app is in foreground
    try {
      await _showLocalNotification(message);
      print('✅ Foreground notification displayed successfully');
    } catch (e) {
      print('❌ Failed to show foreground notification: $e');
      // Retry once more
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await _showLocalNotification(message);
        print('✅ Foreground notification displayed on retry');
      } catch (retryError) {
        print('❌ Retry also failed: $retryError');
      }
    }
  }

  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('\n═══════════════════════════════════════');
    print('📨 BACKGROUND MESSAGE RECEIVED');
    print('═══════════════════════════════════════');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('Message ID: ${message.messageId}');
    print('From: ${message.from}');
    print('Sent Time: ${message.sentTime}');
    print('TTL: ${message.ttl}');
    print('═══════════════════════════════════════\n');
    
    // Handle based on message type
    try {
      await _processMessageData(message.data);
      print('✅ Background message processed successfully');
    } catch (e) {
      print('❌ Failed to process background message: $e');
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;
    
    final notification = message.notification;
    if (notification == null) return;
    
    // Determine if this is a critical notification
    final isCritical = message.data['priority'] == 'critical' || 
                      message.data['type'] == 'order_assigned';
    
    final androidDetails = AndroidNotificationDetails(
      isCritical ? 'critical_orders' : 'fcm_channel',
      isCritical ? 'طلبات عاجلة' : 'إشعارات Firebase',
      channelDescription: isCritical 
          ? 'إشعارات الطلبات العاجلة - أولوية قصوى'
          : 'إشعارات Firebase Cloud Messaging',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF0000FF),
      fullScreenIntent: isCritical,
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
        summaryText: 'حُر للتوصيل',
      ),
      visibility: NotificationVisibility.public,
      ongoing: isCritical,
      autoCancel: !isCritical,
      category: AndroidNotificationCategory.alarm,
      // CRITICAL: Ensure notification shows even when app is in foreground
      channelShowBadge: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      timeoutAfter: isCritical ? null : 30000, // Don't auto-dismiss critical notifications
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      // CRITICAL: Ensure notification shows even when app is in foreground
      threadIdentifier: 'hur_delivery_orders',
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    final notificationId = isCritical 
        ? 999999 // Use fixed ID for critical to replace previous
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await _localNotifications!.show(
      notificationId,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
    
    print('📢 Local notification shown: ${notification.title} (Critical: $isCritical)');
  }

  /// Process message data
  static Future<void> _processMessageData(Map<String, dynamic> data) async {
    final messageType = data['type'];
    
    switch (messageType) {
      case 'order_assigned':
        print('📦 Processing order assignment...');
        // Handle order assignment - navigate to order details
        break;
      case 'order_accepted':
        print('✅ Processing order acceptance...');
        // Handle order acceptance
        break;
      case 'order_delivered':
        print('🎉 Processing order delivery...');
        // Handle order delivery
        break;
      case 'order_rejected':
        print('❌ Processing order rejection...');
        // Handle order rejection
        break;
      default:
        print('❓ Unknown message type: $messageType');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _processMessageData(data);
      } catch (e) {
        print('❌ Failed to parse notification payload: $e');
      }
    }
  }

  /// Send test notification
  static Future<void> sendTestNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      RemoteMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data ?? {},
        notification: RemoteNotification(
          title: title,
          body: body,
        ),
      ),
    );
  }

  /// Get current FCM token
  static String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Send FCM notification directly using Firebase Admin SDK
  static Future<bool> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Sending FCM notification directly...');
      print('   Target User: $targetUserId');
      print('   Title: $title');
      print('   Body: $body');
      print('   Data: $data');

      // Get the FCM token for the target user
      final tokenResponse = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('fcm_token, platform')
          .eq('user_id', targetUserId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (tokenResponse == null || tokenResponse['fcm_token'] == null) {
        print('❌ No FCM token found for user: $targetUserId');
        return false;
      }

      final fcmToken = tokenResponse['fcm_token'] as String;
      final platform = tokenResponse['platform'] as String;
      
      print('   FCM Token: ${fcmToken.substring(0, 20)}...');
      print('   Platform: $platform');

      // Send notification using Firebase Cloud Messaging
      await _messaging!.sendMessage(
        to: fcmToken,
        data: (data ?? {}).map((key, value) => MapEntry(key, value.toString())),
      );

      print('✅ FCM notification sent successfully');
      return true;

    } catch (e) {
      print('❌ Failed to send FCM notification: $e');
      return false;
    }
  }

  /// Manually refresh FCM token and save to database
  static Future<bool> refreshFCMToken() async {
    print('\n🔄 MANUAL FCM TOKEN REFRESH');
    print('═══════════════════════════════════════');
    
    try {
      await _refreshFCMToken();
      print('✅ FCM token manually refreshed successfully');
      return true;
    } catch (e) {
      print('❌ Failed to manually refresh FCM token: $e');
      return false;
    }
  }

  /// Check if current FCM token is valid by sending a test notification
  static Future<bool> validateFCMToken() async {
    print('\n🧪 VALIDATING FCM TOKEN');
    print('═══════════════════════════════════════');
    
    if (_fcmToken == null) {
      print('❌ No FCM token available');
      return false;
    }
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return false;
      }
      
      print('📤 Sending test notification to validate token...');
      
      // Send a test notification to ourselves
      final success = await sendNotificationViaEdgeFunction(
        targetUserId: user.id,
        title: '🧪 Test Notification',
        body: 'FCM token validation test',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      if (success) {
        print('✅ FCM token validation successful');
        return true;
      } else {
        print('❌ FCM token validation failed');
        return false;
      }
    } catch (e) {
      print('❌ FCM token validation error: $e');
      return false;
    }
  }

  /// Show a local test notification to verify notification system works
  static Future<void> showTestLocalNotification() async {
    print('\n🧪 SHOWING TEST LOCAL NOTIFICATION');
    print('═══════════════════════════════════════');
    
    try {
      await _showLocalNotification(
        RemoteMessage(
          notification: RemoteNotification(
            title: '🧪 Local Test',
            body: 'This is a local notification test',
          ),
          data: {
            'type': 'test',
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          messageId: 'test-${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      print('✅ Local test notification shown');
    } catch (e) {
      print('❌ Failed to show local test notification: $e');
    }
  }

  /// Check current FCM token status in database
  static Future<Map<String, dynamic>?> getCurrentTokenStatus() async {
    print('\n🔍 CHECKING FCM TOKEN STATUS');
    print('═══════════════════════════════════════');
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return null;
      }
      
      final result = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('*')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (result != null) {
        print('✅ Found FCM token in database:');
        print('   User ID: ${result['user_id']}');
        print('   Token: ${result['fcm_token']?.toString().substring(0, 20)}...');
        print('   Platform: ${result['platform']}');
        print('   Created: ${result['created_at']}');
        print('   Updated: ${result['updated_at']}');
        
        final updatedAt = DateTime.parse(result['updated_at']);
        final now = DateTime.now();
        final diff = now.difference(updatedAt);
        
        print('   Age: ${diff.inMinutes} minutes ago');
        
        return result;
      } else {
        print('❌ No FCM token found in database');
        return null;
      }
    } catch (e) {
      print('❌ Failed to check FCM token status: $e');
      return null;
    }
  }

  /// Send notification using Supabase Edge Function
  static Future<bool> sendNotificationViaEdgeFunction({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Sending notification via Supabase Edge Function...');
      print('   Target User: $targetUserId');
      print('   Title: $title');
      print('   Body: $body');
      print('   Data: $data');

      // Fetch FCM token and platform from database
      print('🔍 Fetching FCM token for user: $targetUserId');
      final fcmTokenResult = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('fcm_token, platform')
          .eq('user_id', targetUserId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (fcmTokenResult == null || fcmTokenResult['fcm_token'] == null) {
        print('❌ No FCM token found for user: $targetUserId');
        return false;
      }

      final fcmToken = fcmTokenResult['fcm_token'] as String;
      final platform = fcmTokenResult['platform'] as String? ?? 'android';

      print('✅ Found FCM token: ${fcmToken.substring(0, 20)}...');
      print('✅ Platform: $platform');

      // Convert all data values to strings for FCM compatibility
      final stringData = data != null 
          ? data.map((key, value) => MapEntry(key, value.toString()))
          : <String, String>{};

      // Call Supabase Edge Function with FCM token and platform
      print('🚀 Calling Edge Function...');
      final response = await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': targetUserId,
          'title': title,
          'body': body,
          'data': stringData,
          'fcm_token': fcmToken,
          'platform': platform,
        },
      );

      print('📨 Edge Function response status: ${response.status}');
      print('📨 Edge Function response data: ${response.data}');

      // Check for success (status 200 or data contains success)
      if (response.status == 200 || 
          (response.data != null && response.data['success'] == true)) {
        print('✅ Edge Function notification sent successfully!');
        return true;
      } else {
        print('❌ Edge Function notification failed!');
        print('   Status: ${response.status}');
        print('   Data: ${response.data}');
        return false;
      }

    } catch (e, stackTrace) {
      print('❌ Failed to send Edge Function notification: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _isInitialized = false;
    print('✅ FlutterFire notification service disposed');
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.messageId}');
  
  // Initialize Supabase in background isolate
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  
  // Process the message
  await FlutterFireNotificationService._handleBackgroundMessage(message);
}
