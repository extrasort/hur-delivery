import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DriverLocationService {
  static const String _baseUrl = 'https://bvtoxmmiitznagsbubhg.supabase.co';
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0';

  /// Check for orders where customers have provided location updates
  /// Returns list of orders that need driver attention
  static Future<List<CustomerLocationUpdate>> checkForLocationUpdates() async {
    try {
      print('📍 ===========================================');
      print('📍 DRIVER LOCATION SERVICE - CHECKING UPDATES');
      print('📍 URL: $_baseUrl/functions/v1/check-customer-location-updates');
      print('📍 Time: ${DateTime.now()}');
      print('📍 ===========================================');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/functions/v1/check-customer-location-updates'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _apiKey,
        },
      );

      print('📍 API Response Status: ${response.statusCode}');
      print('📍 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📍 Parsed JSON data: $data');
        
        // Handle different response formats
        List<dynamic> orders = [];
        if (data is List) {
          orders = data;
          print('📍 Response is a List with ${orders.length} items');
        } else if (data is Map) {
          print('📍 Response is a Map with keys: ${data.keys.toList()}');
          if (data.containsKey('orders_with_updates')) {
            orders = data['orders_with_updates'] ?? [];
            print('📍 Found orders_with_updates key with ${orders.length} items');
          } else if (data.containsKey('data')) {
            orders = data['data'] ?? [];
            print('📍 Found data key with ${orders.length} items');
          } else {
            print('📍 No recognized keys found in response');
          }
        }
        
        print('📍 Final orders count: ${orders.length}');
        
        if (orders.isNotEmpty) {
          print('📍 ✅ SUCCESS: Found ${orders.length} orders with location updates:');
          for (int i = 0; i < orders.length; i++) {
            final order = orders[i];
            print('   📍 Order ${i + 1}:');
            print('      ID: ${order['order_id']}');
            print('      Customer: ${order['customer_name']}');
            print('      Phone: ${order['customer_phone']}');
            print('      Address: ${order['delivery_address']}');
            print('      Coordinates: ${order['delivery_latitude']}, ${order['delivery_longitude']}');
            print('      Merchant: ${order['merchant_name']}');
            print('      Status: ${order['status']}');
            print('      Updated: ${order['updated_at']}');
          }
        } else {
          print('📍 No orders with location updates found');
        }
        
        final result = orders.map((order) => CustomerLocationUpdate.fromJson(order)).toList();
        print('📍 Returning ${result.length} CustomerLocationUpdate objects');
        return result;
      } else {
        print('❌ API Error: ${response.statusCode}');
        print('❌ Error Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception in checkForLocationUpdates: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    } finally {
      print('📍 ===========================================');
      print('📍 DRIVER LOCATION SERVICE CHECK COMPLETE');
      print('📍 ===========================================');
    }
  }

  /// Mark that driver has been notified about customer location
  static Future<bool> markDriverNotified(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/functions/v1/mark-driver-notified'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _apiKey,
        },
        body: json.encode({'order_id': orderId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        if (kDebugMode) {
          print('❌ Failed to mark driver as notified: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking driver as notified: $e');
      }
      return false;
    }
  }

  /// Get location update notification message for driver
  static String getLocationUpdateMessage(CustomerLocationUpdate update) {
    return '📍 العميل ${update.customerName} قد أرسل موقعه!\n\n'
           'الطلب: ${update.orderId.substring(0, 8)}...\n'
           'التاجر: ${update.merchantName}\n\n'
           '✅ لا حاجة للاتصال بالعميل - الموقع متوفر الآن';
  }

  static String _formatDateTime(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }
}

class CustomerLocationUpdate {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String merchantName;
  final String status;
  final String createdAt;
  final String updatedAt;

  CustomerLocationUpdate({
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.merchantName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerLocationUpdate.fromJson(Map<String, dynamic> json) {
    return CustomerLocationUpdate(
      orderId: json['order_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLatitude: (json['delivery_latitude'] ?? 0.0).toDouble(),
      deliveryLongitude: (json['delivery_longitude'] ?? 0.0).toDouble(),
      merchantName: json['merchant_name'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'merchant_name': merchantName,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
