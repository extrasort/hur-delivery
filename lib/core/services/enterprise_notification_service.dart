import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fcm_service.dart';
import '../constants/app_constants.dart';

/// Enterprise Notification Service
/// 
/// Database-triggered notification system using:
/// - Database triggers on notifications table
/// - Firebase Cloud Messaging (FCM) for push notifications
/// - Supabase Edge Functions for processing
/// - Automatic FCM token management
class EnterpriseNotificationService {
  static bool _isInitialized = false;

  /// Initialize the enterprise notification system
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('\n═══════════════════════════════════════');
    print('🏢 INITIALIZING ENTERPRISE NOTIFICATIONS');
    print('═══════════════════════════════════════');

    try {
      // Initialize FCM service (basic setup)
      await FCMService.initialize();
      
      _isInitialized = true;
      
      print('✅ Enterprise notification system ready');
      print('✅ Database-triggered FCM notifications enabled');
      print('═══════════════════════════════════════\n');
      
    } catch (e) {
      print('❌ Enterprise notification initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize FCM with token generation (call after user authentication)
  static Future<void> initializeWithToken() async {
    print('\n═══════════════════════════════════════');
    print('🏢 INITIALIZING ENTERPRISE NOTIFICATIONS WITH TOKEN');
    print('═══════════════════════════════════════');

    try {
      // Initialize FCM with token generation
      await FCMService.initializeWithToken();
      
      print('✅ Enterprise notification system ready with FCM token');
      print('✅ Database-triggered push notifications enabled');
      print('═══════════════════════════════════════\n');
      
    } catch (e) {
      print('❌ Enterprise notification token initialization failed: $e');
      rethrow;
    }
  }

  /// Dispose the notification service
  static Future<void> dispose() async {
    try {
      await FCMService.dispose();
      _isInitialized = false;
      print('✅ Enterprise notification service disposed');
    } catch (e) {
      print('❌ Error disposing enterprise notification service: $e');
    }
  }

  /// Insert notification into database (triggers FCM automatically)
  static Future<void> _insertNotificationToDatabase({
    required String userId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'body': body,
            'type': type,
            'data': data,
            'created_at': DateTime.now().toIso8601String(),
          });
      
      print('✅ Notification inserted into database: $title');
    } catch (e) {
      print('❌ Failed to insert notification into database: $e');
      rethrow;
    }
  }

  /// Send notification to driver when order is assigned
  static Future<void> notifyOrderAssignedToDriver({
    required String orderId,
    required String driverId,
    required String customerName,
    required String pickupLocation,
    required String deliveryLocation,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: driverId,
        title: '📦 طلب جديد',
        body: 'تم تعيين طلب جديد لك',
        type: 'order_assigned',
        data: {
          'order_id': orderId,
          'driver_id': driverId,
          'customer_name': customerName,
          'pickup_location': pickupLocation,
          'delivery_location': deliveryLocation,
          'action': 'view_order',
          'priority': 'high',
        },
      );
    } catch (e) {
      print('❌ Failed to send order assigned notification: $e');
      rethrow;
    }
  }

  /// Send notification to merchant when order is accepted
  static Future<void> notifyOrderAcceptedForMerchant({
    required String orderId,
    required String merchantId,
    required String driverName,
    required String estimatedTime,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: merchantId,
        title: '✅ تم قبول الطلب',
        body: 'السائق $driverName قبل الطلب - الوقت المتوقع: $estimatedTime',
        type: 'order_accepted',
        data: {
          'order_id': orderId,
          'merchant_id': merchantId,
          'driver_name': driverName,
          'estimated_time': estimatedTime,
          'action': 'view_order',
          'priority': 'normal',
        },
      );
    } catch (e) {
      print('❌ Failed to send order accepted notification: $e');
      rethrow;
    }
  }

  /// Send notification to merchant when order is on the way
  static Future<void> notifyOrderOnTheWayForMerchant({
    required String orderId,
    required String merchantId,
    required String driverName,
    required String estimatedTime,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: merchantId,
        title: '🚚 في الطريق',
        body: 'السائق $driverName في طريقه إليك - الوصول خلال: $estimatedTime',
        type: 'order_on_the_way',
        data: {
          'order_id': orderId,
          'merchant_id': merchantId,
          'driver_name': driverName,
          'estimated_time': estimatedTime,
          'action': 'view_order',
          'priority': 'normal',
        },
      );
    } catch (e) {
      print('❌ Failed to send order on the way notification: $e');
      rethrow;
    }
  }

  /// Send notification to merchant when order is delivered
  static Future<void> notifyOrderDeliveredForMerchant({
    required String orderId,
    required String merchantId,
    required String driverName,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: merchantId,
        title: '🎉 تم التسليم',
        body: 'تم تسليم الطلب بنجاح بواسطة $driverName',
        type: 'order_delivered',
        data: {
          'order_id': orderId,
          'merchant_id': merchantId,
          'driver_name': driverName,
          'action': 'view_order',
          'priority': 'normal',
        },
      );
    } catch (e) {
      print('❌ Failed to send order delivered notification: $e');
      rethrow;
    }
  }

  /// Send notification to merchant when order is rejected
  static Future<void> notifyOrderRejectedForMerchant({
    required String orderId,
    required String merchantId,
    required String driverName,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: merchantId,
        title: '❌ تم رفض الطلب',
        body: 'السائق $driverName رفض الطلب - جاري البحث عن سائق آخر',
        type: 'order_rejected',
        data: {
          'order_id': orderId,
          'merchant_id': merchantId,
          'driver_name': driverName,
          'action': 'view_order',
          'priority': 'normal',
        },
      );
    } catch (e) {
      print('❌ Failed to send order rejected notification: $e');
      rethrow;
    }
  }

  /// Send notification when all drivers reject an order
  static Future<void> notifyAllDriversRejectedForMerchant({
    required String orderId,
    required String merchantId,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: merchantId,
        title: '⚠️ لا يوجد سائقين متاحين',
        body: 'جميع السائقين رفضوا الطلب - جاري البحث عن سائق آخر',
        type: 'all_drivers_rejected',
        data: {
          'order_id': orderId,
          'merchant_id': merchantId,
          'action': 'view_order',
          'priority': 'high',
        },
      );
    } catch (e) {
      print('❌ Failed to send all drivers rejected notification: $e');
      rethrow;
    }
  }

  /// Send system notification
  static Future<void> sendSystemNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _insertNotificationToDatabase(
        userId: userId,
        title: title,
        body: body,
        type: 'system',
        data: data ?? {},
      );
    } catch (e) {
      print('❌ Failed to send system notification: $e');
      rethrow;
    }
  }

  /// Check if notification service is initialized
  static bool get isInitialized => _isInitialized;
}