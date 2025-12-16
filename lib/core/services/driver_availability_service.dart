import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_manager.dart';
import '../localization/app_localizations.dart';

class DriverAvailabilityResult {
  final bool available;
  final String reason;
  final int freeDriverCount;
  final int sameMerchantDriverCount;
  final bool fromFallback;

  const DriverAvailabilityResult({
    required this.available,
    required this.reason,
    this.freeDriverCount = 0,
    this.sameMerchantDriverCount = 0,
    this.fromFallback = false,
  });

  factory DriverAvailabilityResult.fromJson(
    Map<String, dynamic> json, {
    bool fromFallback = false,
  }) {
    return DriverAvailabilityResult(
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String? ?? 'unknown',
      freeDriverCount: json['free_driver_count'] is int
          ? json['free_driver_count'] as int
          : int.tryParse('${json['free_driver_count'] ?? 0}') ?? 0,
      sameMerchantDriverCount: json['same_merchant_driver_count'] is int
          ? json['same_merchant_driver_count'] as int
          : int.tryParse('${json['same_merchant_driver_count'] ?? 0}') ?? 0,
      fromFallback: fromFallback,
    );
  }

  bool get allowsMultiAssignment =>
      available && reason == 'same_merchant_driver_available';

  // Get localized user message
  String userMessage(BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (reason) {
      case 'free_driver_available':
        return loc.freeDriverAvailable;
      case 'same_merchant_driver_available':
        return loc.sameMerchantDriverAvailable;
      case 'no_driver_available':
        return loc.noDriverAvailable;
      case 'fallback_no_online_drivers':
        return loc.fallbackNoOnlineDrivers;
      case 'fallback_exception':
        return loc.fallbackException;
      default:
        return loc.unknownAvailability;
    }
  }
}

class DriverAvailabilityService {
  DriverAvailabilityService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const List<String> _activeStatuses = [
    'pending',
    'assigned',
    'accepted',
    'on_the_way',
  ];

  static Future<DriverAvailabilityResult> checkAvailability({
    required String merchantId,
    required String vehicleType,
  }) async {
    final normalizedVehicleType = _normalizeVehicleType(vehicleType);
    final params = <String, dynamic>{
      'p_vehicle_type': normalizedVehicleType,
      'p_merchant_id': merchantId,
    };

    try {
      final response = await _client.rpc(
        'validate_driver_availability_for_merchant',
        params: params,
      );
      if (response is Map<String, dynamic>) {
        return DriverAvailabilityResult.fromJson(response);
      }
    } catch (error, stackTrace) {
      ErrorManager.analyzeError(error, stackTrace);
      debugPrint('⚠️ validate_driver_availability_for_merchant RPC failed: $error');
    }

    return _fallbackCheck(
      merchantId: merchantId,
      vehicleType: normalizedVehicleType,
    );
  }

  static Future<DriverAvailabilityResult> _fallbackCheck({
    required String merchantId,
    required String? vehicleType,
  }) async {
    try {
      var query = _client
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('is_online', true);

      if (vehicleType != null) {
        query = query.eq('vehicle_type', vehicleType);
      }

      final onlineDriversResponse = await query;

      final driverIds = (onlineDriversResponse as List<dynamic>)
          .map((driver) => driver['id'] as String?)
          .whereType<String>()
          .toList();

      if (driverIds.isEmpty) {
        return DriverAvailabilityResult(
          available: false,
          reason: 'fallback_no_online_drivers',
          fromFallback: true,
        );
      }

      final activeOrdersResponse = await _client
          .from('orders')
          .select('driver_id, merchant_id, status')
          .inFilter('driver_id', driverIds)
          .inFilter('status', _activeStatuses);

      final Map<String, List<String>> ordersByDriver = {};
      for (final raw in activeOrdersResponse as List<dynamic>) {
        final driverId = raw['driver_id'] as String?;
        if (driverId == null) continue;
        final merchant = raw['merchant_id'] as String?;
        ordersByDriver.putIfAbsent(driverId, () => <String>[]);
        if (merchant != null) {
          ordersByDriver[driverId]!.add(merchant);
        }
      }

      final Set<String> busyDrivers = ordersByDriver.keys.toSet();
      final Set<String> onlineDriverSet = driverIds.toSet();
      final Set<String> freeDrivers = onlineDriverSet.difference(busyDrivers);

      if (freeDrivers.isNotEmpty) {
        return DriverAvailabilityResult(
          available: true,
          reason: 'free_driver_available',
          freeDriverCount: freeDrivers.length,
          sameMerchantDriverCount: 0,
          fromFallback: true,
        );
      }

      int sameMerchantDriverCount = 0;
      for (final entry in ordersByDriver.entries) {
        if (!onlineDriverSet.contains(entry.key)) continue;
        final merchants = entry.value.where((m) => m.isNotEmpty).toSet();
        if (merchants.isEmpty) continue;
        if (merchants.length == 1 && merchants.first == merchantId) {
          sameMerchantDriverCount++;
        }
      }

      if (sameMerchantDriverCount > 0) {
        return DriverAvailabilityResult(
          available: true,
          reason: 'same_merchant_driver_available',
          freeDriverCount: 0,
          sameMerchantDriverCount: sameMerchantDriverCount,
          fromFallback: true,
        );
      }

      return DriverAvailabilityResult(
        available: false,
        reason: 'no_driver_available',
        fromFallback: true,
      );
    } catch (error, stackTrace) {
      ErrorManager.analyzeError(error, stackTrace);
      debugPrint('⚠️ Driver availability fallback failed: $error');
      return DriverAvailabilityResult(
        available: false,
        reason: 'fallback_exception',
        fromFallback: true,
      );
    }
  }

  static String? _normalizeVehicleType(String? vehicleType) {
    final value = vehicleType?.trim().toLowerCase();
    if (value == null || value.isEmpty || value == 'any') {
      return null;
    }
    if (value == 'motorcycle') return 'motorbike';
    return value;
  }

  /// Check for online drivers without active orders (for repost functionality)
  /// This bypasses the RPC and directly queries for free drivers
  static Future<DriverAvailabilityResult> checkFreeDriversOnly({
    required String? vehicleType,
  }) async {
    try {
      final normalizedVehicleType = _normalizeVehicleType(vehicleType);
      
      // Get all online drivers
      var query = _client
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('is_online', true)
          .eq('manual_verified', true);

      if (normalizedVehicleType != null) {
        query = query.eq('vehicle_type', normalizedVehicleType);
      }

      final onlineDriversResponse = await query;

      final driverIds = (onlineDriversResponse as List<dynamic>)
          .map((driver) => driver['id'] as String?)
          .whereType<String>()
          .toList();

      if (driverIds.isEmpty) {
        return DriverAvailabilityResult(
          available: false,
          reason: 'fallback_no_online_drivers',
          fromFallback: true,
        );
      }

      // Get drivers with active orders
      final activeOrdersResponse = await _client
          .from('orders')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .inFilter('status', _activeStatuses);

      final Set<String> busyDriverIds = {};
      for (final raw in activeOrdersResponse as List<dynamic>) {
        final driverId = raw['driver_id'] as String?;
        if (driverId != null) {
          busyDriverIds.add(driverId);
        }
      }

      // Calculate free drivers
      final Set<String> onlineDriverSet = driverIds.toSet();
      final Set<String> freeDrivers = onlineDriverSet.difference(busyDriverIds);

      if (freeDrivers.isNotEmpty) {
        return DriverAvailabilityResult(
          available: true,
          reason: 'free_driver_available',
          freeDriverCount: freeDrivers.length,
          sameMerchantDriverCount: 0,
          fromFallback: true,
        );
      }

      return DriverAvailabilityResult(
        available: false,
        reason: 'no_driver_available',
        fromFallback: true,
      );
    } catch (error, stackTrace) {
      ErrorManager.analyzeError(error, stackTrace);
      debugPrint('⚠️ Check free drivers failed: $error');
      return DriverAvailabilityResult(
        available: false,
        reason: 'fallback_exception',
        fromFallback: true,
      );
    }
  }
}

