import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'event_notification_service.dart';

/// Simple Persistent Service - Keeps app alive and polls for orders
/// 
/// Uses foreground service + HTTP polling (no complex Supabase streams)
/// Guaranteed to work in background.
class SimplePersistentService {
  static bool _isRunning = false;

  /// Start the persistent service
  static Future<bool> start({
    required String userId,
    required String supabaseUrl,
    required String supabaseKey,
    required String userRole,
    required String userName,
  }) async {
    if (_isRunning) {
      print('⚠️ Service already running');
      return true;
    }

    print('\n═══════════════════════════════════════');
    print('🚀 STARTING SIMPLE PERSISTENT SERVICE');
    print('═══════════════════════════════════════');
    print('User: $userName ($userRole)');

    // Save credentials to shared preferences for background isolate
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('service_user_id', userId);
    await prefs.setString('service_supabase_url', supabaseUrl);
    await prefs.setString('service_supabase_key', supabaseKey);
    await prefs.setString('service_user_role', userRole);
    await prefs.setString('service_user_name', userName);
    await prefs.setStringList('service_notified_orders', []);

    // Initialize foreground task
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'simple_persistent',
        channelName: 'خدمة التوصيل النشطة',
        channelDescription: 'تبقيك متصل وجاهز لاستلام الطلبات',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(3000), // Poll every 3 seconds
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Start service
    await FlutterForegroundTask.startService(
      notificationTitle: '🟢 متصل - جاهز لاستلام الطلبات',
      notificationText: 'الخدمة نشطة',
      callback: startCallback,
    );

    _isRunning = true;
    print('✅ Simple persistent service started');
    print('═══════════════════════════════════════\n');
    return true;
  }

  /// Stop the service
  static Future<bool> stop() async {
    if (!_isRunning) return true;

    print('🛑 Stopping simple persistent service...');
    
    await FlutterForegroundTask.stopService();
    
    // Clear preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('service_user_id');
    await prefs.remove('service_supabase_url');
    await prefs.remove('service_supabase_key');
    await prefs.remove('service_user_role');
    await prefs.remove('service_user_name');
    await prefs.remove('service_notified_orders');

    _isRunning = false;
    print('✅ Service stopped\n');
    return true;
  }
}

/// Callback entry point
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SimpleTaskHandler());
}

/// Background task handler with HTTP polling
class SimpleTaskHandler extends TaskHandler {
  int _tickCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🔄 Simple task handler started');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    _tickCount++;
    
    print('💓 Tick $_tickCount: ${timestamp.toString().substring(11, 19)}');

    // Poll for new orders every tick (every 3 seconds)
    await _checkForNewOrders();
  }

  Future<void> _checkForNewOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('service_user_id');
      final supabaseUrl = prefs.getString('service_supabase_url');
      final supabaseKey = prefs.getString('service_supabase_key');
      final userRole = prefs.getString('service_user_role');
      final notifiedOrders = prefs.getStringList('service_notified_orders') ?? [];

      if (userId == null || supabaseUrl == null || supabaseKey == null) {
        print('❌ Missing credentials in background');
        return;
      }

      if (userRole != 'driver') {
        return; // Only drivers need background polling
      }

      // HTTP request to check for pending orders assigned to this driver
      final url = '$supabaseUrl/rest/v1/orders?driver_id=eq.$userId&status=eq.pending&select=id,customer_name';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      );

      if (response.statusCode == 200) {
        final orders = jsonDecode(response.body) as List;
        
        for (var order in orders) {
          final orderId = order['id'] as String;
          
          // Check if we already notified for this order
          if (!notifiedOrders.contains(orderId)) {
            print('🔔🔔🔔 NEW ORDER FOUND IN POLLING: $orderId');
            
            // Add to notified list
            notifiedOrders.add(orderId);
            await prefs.setStringList('service_notified_orders', notifiedOrders);
            
            // Show notification
            await EventNotificationService.onOrderAssignedToDriver(
              orderId: orderId,
              currentUserId: userId,
              assignedDriverId: userId,
            );
            
            // Update persistent notification
            FlutterForegroundTask.updateService(
              notificationTitle: '📦 طلب جديد!',
              notificationText: 'لديك طلب جديد - افتح التطبيق',
            );
          }
        }
      }
    } catch (e) {
      print('❌ Polling error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🛑 Simple task handler destroyed');
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🔘 Button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    print('👆 Notification tapped - launching app');
    FlutterForegroundTask.launchApp('/');
  }
}

