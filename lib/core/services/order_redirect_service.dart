import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

/// Global Order Redirect Service
/// 
/// Monitors for new active orders assigned to drivers and redirects them
/// to the dashboard ONCE per new order (not repeatedly)
class OrderRedirectService {
  static Timer? _monitorTimer;
  static String? _currentDriverId;
  static String? _lastSeenOrderId;
  static bool _isMonitoring = false;
  static BuildContext? _context;

  /// Start monitoring for new orders (for drivers only)
  static Future<void> startMonitoring(BuildContext context, String driverId) async {
    _context = context;
    _currentDriverId = driverId;
    
    if (_isMonitoring) {
      print('ℹ️ Order redirect service already monitoring');
      return;
    }
    
    print('\n═══════════════════════════════════════');
    print('🔔 STARTING ORDER REDIRECT SERVICE');
    print('═══════════════════════════════════════');
    print('Driver ID: $driverId');
    
    // Load last seen order from storage
    await _loadLastSeenOrder();
    
    // Start monitoring every 3 seconds
    _isMonitoring = true;
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkForNewOrders();
    });
    
    print('✅ Order redirect service started (checking every 3 seconds)');
    print('═══════════════════════════════════════\n');
  }

  /// Load last seen order from SharedPreferences
  static Future<void> _loadLastSeenOrder() async {
    try {
      if (_currentDriverId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      _lastSeenOrderId = prefs.getString('last_seen_order_id_$_currentDriverId');
      
      if (_lastSeenOrderId != null) {
        print('📋 Last seen order loaded: $_lastSeenOrderId');
      } else {
        print('📋 No previous order found in storage');
      }
    } catch (e) {
      print('❌ Error loading last seen order: $e');
    }
  }

  /// Check for new orders
  static Future<void> _checkForNewOrders() async {
    if (_currentDriverId == null || _context == null) return;
    
    try {
      // Get current active order (most recent)
      final response = await Supabase.instance.client
          .from('orders')
          .select('id, status, created_at')
          .eq('driver_id', _currentDriverId!)
          .inFilter('status', ['assigned', 'accepted', 'on_the_way'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      // No active orders
      if (response == null) {
        return;
      }
      
      final currentOrderId = response['id'] as String;
      final orderStatus = response['status'] as String;
      
      // Check if this is a NEW order (different from last seen)
      if (_lastSeenOrderId != currentOrderId) {
        print('\n🚨 NEW ORDER DETECTED!');
        print('═══════════════════════════════════════');
        print('Order ID: $currentOrderId');
        print('Status: $orderStatus');
        print('Last seen: $_lastSeenOrderId');
        
        // Only redirect for newly ASSIGNED orders (not accepted/on_the_way)
        if (orderStatus == 'assigned') {
          print('🎯 Redirecting driver to dashboard...');
          
          // Mark as seen BEFORE redirecting to prevent loops
          _lastSeenOrderId = currentOrderId;
          await _saveLastSeenOrder(currentOrderId);
          
          // Redirect to dashboard
          if (_context != null && _context!.mounted) {
            _context!.go('/driver-dashboard');
            print('✅ Driver redirected to dashboard');
          }
        } else {
          // For accepted/on_the_way, just mark as seen (driver already knows about it)
          _lastSeenOrderId = currentOrderId;
          await _saveLastSeenOrder(currentOrderId);
          print('ℹ️ Order marked as seen (status: $orderStatus)');
        }
        
        print('═══════════════════════════════════════\n');
      }
    } catch (e) {
      print('❌ Error checking for new orders: $e');
    }
  }

  /// Save last seen order to SharedPreferences
  static Future<void> _saveLastSeenOrder(String orderId) async {
    try {
      if (_currentDriverId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_seen_order_id_$_currentDriverId', orderId);
      print('💾 Last seen order saved: $orderId');
    } catch (e) {
      print('❌ Error saving last seen order: $e');
    }
  }

  /// Update context (call when navigating)
  static void updateContext(BuildContext context) {
    _context = context;
  }

  /// Stop monitoring
  static void stopMonitoring() {
    print('🛑 Stopping order redirect service');
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    _context = null;
    _currentDriverId = null;
    _lastSeenOrderId = null;
  }

  /// Check if currently monitoring
  static bool get isMonitoring => _isMonitoring;
}


