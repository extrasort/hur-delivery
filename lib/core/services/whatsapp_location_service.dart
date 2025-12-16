import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/env.dart';

class WhatsAppLocationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Send customer location to the server
  static Future<bool> sendCustomerLocation({
    required String orderId,
    required String customerPhone,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      print('📍 Sending customer location for order: $orderId');
      
      // If coordinates not provided, get current location
      if (latitude == null || longitude == null) {
        final position = await _getCurrentLocation();
        latitude = position.latitude;
        longitude = position.longitude;
      }

      print('📍 Coordinates: $latitude, $longitude');

      // Call the edge function to update customer location
      final response = await _supabase.functions.invoke(
        'receive-customer-location',
        body: {
          'order_id': orderId,
          'customer_phone': customerPhone,
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
        },
      );

      if (response.status == 200) {
        print('✅ Customer location sent successfully');
        return true;
      } else {
        print('❌ Failed to send location: ${response.data}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending customer location: $e');
      return false;
    }
  }

  /// Get current location with permissions
  static Future<Position> _getCurrentLocation() async {
    // Check location permissions
    final permission = await Permission.location.request();
    if (permission != PermissionStatus.granted) {
      throw Exception('Location permission denied');
    }

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    return position;
  }

  /// Check if location sharing is available
  static Future<bool> isLocationSharingAvailable() async {
    try {
      // Check permissions
      final permission = await Permission.location.status;
      if (permission != PermissionStatus.granted) {
        return false;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      return serviceEnabled;
    } catch (e) {
      print('❌ Error checking location availability: $e');
      return false;
    }
  }

  /// Request location permissions
  static Future<bool> requestLocationPermissions() async {
    try {
      final permission = await Permission.location.request();
      return permission == PermissionStatus.granted;
    } catch (e) {
      print('❌ Error requesting location permissions: $e');
      return false;
    }
  }

  /// Get formatted address from coordinates
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // You can integrate with a geocoding service here
      // For now, return coordinates as string
      return 'Lat: $latitude, Lng: $longitude';
    } catch (e) {
      print('❌ Error getting address: $e');
      return null;
    }
  }
}
