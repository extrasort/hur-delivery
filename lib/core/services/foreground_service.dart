import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_manager.dart';

/// Foreground service callback - runs in isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DeliveryTaskHandler());
}

/// Task handler for delivery driver foreground service
class DeliveryTaskHandler extends TaskHandler {
  String _status = "online"; // online, busy, paused
  int _eventCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('✅ Foreground service started at $timestamp');
    _status = "online";
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _eventCount++;
    print('⏱️ Repeat event #$_eventCount at $timestamp | Status: $_status');
    
    // Keep connection alive by pinging database every event
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        client
            .from('users')
            .select('id')
            .eq('id', client.auth.currentUser!.id)
            .limit(1);
      }
    } catch (e) {
      print('⚠️ Keepalive ping failed: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🛑 Foreground service destroyed at $timestamp');
  }

  @override
  void onButtonPressed(String id) {
    print('🔘 Button pressed: $id');
    
    if (id == 'pause') {
      _status = "paused";
      print('⏸️ Driver paused');

      FlutterForegroundTask.updateService(
        notificationTitle: 'موقف - متوقف مؤقتاً',
        notificationText: 'اضغط لاستئناف استقبال الطلبات',
        notificationButtons: [
          const NotificationButton(id: 'resume', text: '▶️ استئناف'),
          const NotificationButton(id: 'offline', text: '⏹ غير متصل'),
        ],
      );
    } else if (id == 'resume') {
      _status = "online";
      print('▶️ Driver resumed');

      FlutterForegroundTask.updateService(
        notificationTitle: 'متصل - جاهز للطلبات',
        notificationText: 'في انتظار طلبات جديدة',
        notificationButtons: [
          const NotificationButton(id: 'pause', text: '⏸ توقف مؤقت'),
          const NotificationButton(id: 'offline', text: '⏹ غير متصل'),
        ],
      );
    } else if (id == 'offline') {
      print('🛑 Going offline - stopping service');
      _status = "offline";
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // Open app when notification is tapped
    print('📱 Notification tapped - launching app');
    FlutterForegroundTask.launchApp('/');
  }
}

/// Foreground Service Manager
class ForegroundServiceManager {
  static bool _isRunning = false;
  static ReceivePort? _receivePort;

  /// Initialize foreground service
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hur_delivery_foreground',
        channelName: 'خدمة التوصيل',
        channelDescription: 'خدمة تشغيل في الخلفية لاستقبال طلبات التوصيل',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // 30 seconds
      ),
    );
  }

  /// Start foreground service when driver goes online
  static Future<bool> startService({
    required String userId,
    required String driverName,
  }) async {
    if (_isRunning) {
      print('⚠️ Foreground service already running');
      return false;
    }

    // Request notification permission
    final permissionStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (permissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Start the foreground service
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'متصل - جاهز للطلبات',
        notificationText: 'في انتظار طلبات جديدة',
        notificationButtons: [
          const NotificationButton(id: 'pause', text: '⏸ توقف مؤقت'),
          const NotificationButton(id: 'offline', text: '⏹ غير متصل'),
        ],
        callback: startCallback,
      );

      _isRunning = true;
      
      // Start receiving data from service
      _receivePort = FlutterForegroundTask.receivePort;
      _receivePort?.listen((data) {
        print('📨 Data from service: $data');
      });
      
      print('✅ Foreground service started successfully');
      return true;
    } catch (e) {
      print('❌ Failed to start foreground service: $e');
      return false;
    }
  }

  /// Update notification to show new order
  static Future<void> showNewOrder({
    required String orderId,
    required String customerName,
    required String pickupAddress,
  }) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: '🆕 طلب جديد من $customerName',
      notificationText: 'الاستلام من: $pickupAddress',
      notificationButtons: [
        NotificationButton(id: 'accept_$orderId', text: '✅ قبول'),
        NotificationButton(id: 'reject_$orderId', text: '❌ رفض'),
      ],
    );
  }

  /// Update notification when order is accepted
  static Future<void> showOrderInProgress({
    required String customerName,
    required String deliveryAddress,
  }) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: '🚚 توصيل جاري - $customerName',
      notificationText: 'التوصيل إلى: $deliveryAddress',
      notificationButtons: [
        const NotificationButton(id: 'navigate', text: '🗺 توجيه'),
        const NotificationButton(id: 'complete', text: '✅ تم التسليم'),
      ],
    );
  }

  /// Reset to idle state (waiting for orders)
  static Future<void> resetToIdle() async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: 'متصل - جاهز للطلبات',
      notificationText: 'في انتظار طلبات جديدة',
      notificationButtons: [
        const NotificationButton(id: 'pause', text: '⏸ توقف مؤقت'),
        const NotificationButton(id: 'offline', text: '⏹ غير متصل'),
      ],
    );
  }

  /// Update notification to show driver is busy
  static Future<void> showBusy() async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: '⏳ مشغول',
      notificationText: 'يتم معالجة الطلب الحالي',
      notificationButtons: [
        const NotificationButton(id: 'offline', text: '⏹ غير متصل'),
      ],
    );
  }

  /// Stop foreground service when driver goes offline
  static Future<bool> stopService() async {
    if (!_isRunning) {
      print('⚠️ Foreground service not running');
      return false;
    }

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
      _receivePort?.close();
      _receivePort = null;
      print('✅ Foreground service stopped');
      return true;
    } catch (e) {
      print('❌ Failed to stop foreground service: $e');
      return false;
    }
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Get current status
  static bool get isServiceRunning => _isRunning;
}

