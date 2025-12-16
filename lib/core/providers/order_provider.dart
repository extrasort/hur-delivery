import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/order_model.dart';
import '../constants/app_constants.dart';
import '../services/flutterfire_notification_service.dart';
import '../services/notification_manager.dart';
import '../services/error_manager.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _error;
  Timer? _autoRejectTimer;
  Timer? _timeoutStateUpdateTimer;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _timeoutStatesSubscription;
  
  // Map of order_id -> remaining_seconds from order_timeout_state table
  Map<String, int> _timeoutStates = {};
  
  // Set of order IDs that have timed out (to prevent flickering)
  final Set<String> _timedOutOrders = {};

  // Cache user role to avoid repeated DB queries
  String? _cachedUserRole;
  DateTime? _roleCacheTime;
  static const _roleCacheExpiry = Duration(minutes: 5);

  List<OrderModel> get orders => _orders;
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Get timeout remaining seconds for an order
  int? getTimeoutRemaining(String orderId) {
    return _timeoutStates[orderId];
  }

  // Filtered orders by status
  List<OrderModel> get pendingOrders => _orders.where((o) => o.isPending).toList();
  List<OrderModel> get activeOrders => _orders.where((o) => o.isActive).toList();
  List<OrderModel> get completedOrders => _orders.where((o) => o.isCompleted).toList();
  
  // Get active order for driver (assigned and not completed)
  OrderModel? getActiveOrderForDriver(String driverId) {
    final activeOrders = getAllActiveOrdersForDriver(driverId);
    return activeOrders.firstOrNull;
  }

  // Get ALL active orders for a driver (for swipeable cards)
  List<OrderModel> getAllActiveOrdersForDriver(String driverId) {
    print('🔍 getAllActiveOrdersForDriver called for driver: $driverId');
    print('   Total orders in provider: ${_orders.length}');
    print('   Timed out orders set: ${_timedOutOrders.length} entries: $_timedOutOrders');
    
    final activeOrders = _orders
        .where((order) {
          // Filter basic conditions
          if (order.driverId != driverId) return false;
          if (order.status == 'delivered' || 
              order.status == 'cancelled' || 
              order.status == 'rejected') return false;
          
          // Filter out pending orders with zero or negative countdown
          if (order.status == 'pending' && 
              order.driverId != null && 
              order.driverAssignedAt != null) {
            
            // Parse assignment time to check if this is a recent assignment
            DateTime assignedAt;
            try {
              assignedAt = order.driverAssignedAt is DateTime 
                  ? order.driverAssignedAt as DateTime
                  : DateTime.parse(order.driverAssignedAt!.toString());
            } catch (e) {
              print('⚠️  Could not parse driver_assigned_at for order ${order.id}');
              return true; // Keep the order if we can't parse
            }
            
            final elapsed = DateTime.now().difference(assignedAt).inSeconds;
            
            // Check if this assignment is fresh (assigned within last 5 seconds)
            // This handles reposted orders or new assignments
            final isFreshAssignment = elapsed <= 5;
            
            // If already marked as timed out BUT has fresh assignment, it's a new order - remove from set
            if (_timedOutOrders.contains(order.id)) {
              if (isFreshAssignment) {
                _timedOutOrders.remove(order.id);
                print('✨ Order ${order.id} is freshly assigned (${elapsed}s ago) - REMOVED from timeout list, showing order');
              } else {
                // Not a fresh assignment, this is the old timed out order
                print('⏱️  Order ${order.id} marked as timed out - staying filtered (elapsed: ${elapsed}s)');
                return false;
              }
            }
            
            final remainingSeconds = _timeoutStates[order.id];
            
            // If countdown is 0 or less, mark as timed out and filter out (expired)
            if (remainingSeconds != null && remainingSeconds <= 0) {
              _timedOutOrders.add(order.id);
              print('⏱️  Filtering out order ${order.id} - countdown expired (${remainingSeconds}s) - MARKED');
              return false;
            }
            
            // Also check time-based calculation as backup
            if (elapsed >= 30) {
              _timedOutOrders.add(order.id);
              print('⏱️  Filtering out order ${order.id} - time expired (${elapsed}s elapsed) - MARKED');
              return false;
            }
          }
          
          // Clean up timed out orders set if order is no longer pending
          if (order.status != 'pending' && _timedOutOrders.contains(order.id)) {
            _timedOutOrders.remove(order.id);
            print('🧹 Cleaned up timed out marker for order ${order.id} (status: ${order.status})');
          }
          
          return true;
        })
        .toList()
      ..sort((a, b) {
        // Sort by priority: pending first, then by creation time
        if (a.status == 'pending' && b.status != 'pending') return -1;
        if (a.status != 'pending' && b.status == 'pending') return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    
    if (activeOrders.isNotEmpty) {
      print('🎯 Driver $driverId has ${activeOrders.length} active order(s)');
      for (var order in activeOrders) {
        print('  📦 Order ${order.id}: status=${order.status}, driver_id=${order.driverId}');
      }
    } else {
      print('📭 Driver $driverId has no active orders');
      // Log all orders for debugging
      print('📋 All orders for debugging:');
      for (var order in _orders) {
        print('  📦 Order ${order.id}: status=${order.status}, driver_id=${order.driverId}');
      }
    }
    
    return activeOrders;
  }

  // Get pending orders available for drivers
  List<OrderModel> getPendingOrdersForDrivers() {
    return _orders
        .where((order) => order.status == 'pending' && order.driverId == null)
        .toList();
  }

  // Initialize orders
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadOrders();
      await _subscribeToOrders();
      await _subscribeToTimeoutStates();
      _startAutoRejectTimer();
      _startTimeoutStateUpdater();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Subscribe to order_timeout_state table for real-time countdown values
  Future<void> _subscribeToTimeoutStates() async {
    try {
      await _timeoutStatesSubscription?.cancel();
      _timeoutStatesSubscription = Supabase.instance.client
          .from('order_timeout_state')
          .stream(primaryKey: ['order_id'])
          .listen((data) {
        print('⏱️  Timeout states received: ${data.length} entries');
        
        // Update timeout states map
        _timeoutStates.clear();
        for (var state in data) {
          final orderId = state['order_id'] as String;
          final remaining = state['remaining_seconds'] as int;
          
          _timeoutStates[orderId] = remaining;
          
          if (remaining <= 10) {
            print('   ⏰ Order $orderId: $remaining seconds');
          }
        }
        
        notifyListeners();
      });
      
      print('✅ Subscribed to order_timeout_state table');
    } catch (e) {
      print('❌ Error subscribing to timeout states: $e');
    }
  }
  
  // Call database function every 1 second to update timeout states
  void _startTimeoutStateUpdater() {
    _timeoutStateUpdateTimer?.cancel();
    _timeoutStateUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // Update all timeout states in database
        await Supabase.instance.client.rpc('update_order_timeout_states');
      } catch (e) {
        // Silence errors to prevent log spam
      }
    });
    print('✅ Timeout state updater started (calls DB every 1 second)');
  }

  // Start auto-reject timer (database polling)
  void _startAutoRejectTimer() {
    // Cancel existing timer if any
    _autoRejectTimer?.cancel();
    
    // Check for expired orders every 5 seconds
    _autoRejectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Use error manager for automatic retry and recovery
      await ErrorManager.safeExecute(
        operation: () async {
          print('⏰ Checking for expired orders...');
          
          // Call database function to check and process expired orders
          // Error manager will handle retries and session refresh automatically
          final result = await Supabase.instance.client.rpc('app_check_expired_orders');
          print('✅ Auto-reject check completed. Result: $result');
          
          // Always refresh orders to ensure UI is up-to-date
          print('🔄 Refreshing orders after auto-reject check...');
          await _loadOrders();
        },
        operationName: 'auto-reject-check',
        isCritical: false, // Non-critical - can fail silently
      );
    });
    print('✅ Auto-reject timer started (checks every 5 seconds)');
  }

  // Stop auto-reject timer
  void stopAutoRejectTimer() {
    _autoRejectTimer?.cancel();
    _autoRejectTimer = null;
  }

  @override
  void dispose() {
    stopAutoRejectTimer();
    _timeoutStateUpdateTimer?.cancel();
    super.dispose();
  }

  // Refresh orders manually
  Future<void> refreshOrders() async {
    await ErrorManager.safeExecute(
      operation: () => _loadOrders(),
      operationName: 'refresh-orders',
      isCritical: false,
    );
  }

  // Refresh a specific order (useful for coordinate updates)
  Future<void> refreshOrder(String orderId) async {
    try {
      print('🔄 Refreshing order $orderId...');
      
      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            items:order_items(*),
            driver:users!driver_id(name, phone),
            merchant:users!merchant_id(name, phone, store_name)
          ''')
          .eq('id', orderId)
          .single();

      if (response != null) {
        // Process the order data
        final orderData = response;
        
        // Extract driver info
        if (orderData['driver'] != null && orderData['driver'] is Map) {
          orderData['driver_name'] = orderData['driver']['name'];
          orderData['driver_phone'] = orderData['driver']['phone'];
        }
        
        // Extract merchant info
        if (orderData['merchant'] != null && orderData['merchant'] is Map) {
          orderData['merchant_name'] = orderData['merchant']['store_name'] ?? orderData['merchant']['name'];
          orderData['merchant_phone'] = orderData['merchant']['phone'];
        }
        
        // Log coordinate validation but don't auto-fix
        final deliveryLat = orderData['delivery_latitude'];
        final deliveryLng = orderData['delivery_longitude'];
        if (deliveryLat == null || deliveryLng == null || 
            deliveryLat < 29.0 || deliveryLat > 37.0 || 
            deliveryLng < 38.0 || deliveryLng > 49.0) {
          print('⚠️ Order $orderId has invalid coordinates: $deliveryLat, $deliveryLng');
          print('📝 Coordinates will be validated by database, not auto-fixed by client');
        }
        
        // Ensure numeric delivery coords
        if (orderData['delivery_latitude'] == null || orderData['delivery_longitude'] == null) {
          orderData['delivery_latitude'] = orderData['delivery_latitude'] ?? 0.0;
          orderData['delivery_longitude'] = orderData['delivery_longitude'] ?? 0.0;
        }
        // Create updated order model
        final updatedOrder = OrderModel.fromJson(orderData);
        
        // Find and update the order in the list
        final orderIndex = _orders.indexWhere((o) => o.id == orderId);
        if (orderIndex != -1) {
          _orders[orderIndex] = updatedOrder;
          print('✅ Order $orderId refreshed with coordinates: ${updatedOrder.deliveryLatitude}, ${updatedOrder.deliveryLongitude}');
        }
        
        // Update current order if it's the same
        if (_currentOrder?.id == orderId) {
          _currentOrder = updatedOrder;
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error refreshing order $orderId: $e');
    }
  }

  // Load orders from database
  Future<void> _loadOrders() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Get user role - try multiple sources to avoid unnecessary DB queries
      String? userRole;
      
      // METHOD 1: Check cache first (if valid)
      if (_cachedUserRole != null && 
          _roleCacheTime != null && 
          DateTime.now().difference(_roleCacheTime!) < _roleCacheExpiry) {
        userRole = _cachedUserRole;
        print('✅ Using cached role: $userRole');
      } else {
        // METHOD 2: Try to get from auth user metadata (no DB query)
        userRole = currentUser.userMetadata?['role'] as String? ??
            currentUser.appMetadata?['role'] as String?;

        // METHOD 3: Try to infer from cached auth provider/user model if available
        if ((userRole == null || userRole.isEmpty) && _orders.isNotEmpty) {
          final hasDriverOrder =
              _orders.any((order) => order.driverId == currentUser.id);
          if (hasDriverOrder) {
            userRole = 'driver';
          }
        }

        // METHOD 4: If still unknown, fall back to safe default without hitting DB
        if (userRole == null || userRole.isEmpty) {
          print(
              '⚠️ User role not found in metadata/cache - defaulting to merchant to avoid network fetch');
          userRole = null; // let default below handle final value
        } else {
          // Cache the role from metadata/inference
          _cachedUserRole = userRole;
          _roleCacheTime = DateTime.now();
        }
      }
      
      // Default to 'merchant' if role still unknown (safer default for merchant dashboard)
      if (userRole == null || userRole.isEmpty) {
        _cachedUserRole = 'merchant';
        _roleCacheTime = DateTime.now();
      }
      final effectiveRole = userRole ?? 'merchant';

      List<Map<String, dynamic>> response = [];

      // Retry logic for connection reset errors
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount <= maxRetries) {
        try {
          if (effectiveRole == 'driver') {
            // For drivers, show all orders assigned to them (including completed ones)
            // This allows them to see their history in the orders sidebar
        response = await Supabase.instance.client
            .from('orders')
            .select('''
              *,
              items:order_items(*),
              driver:users!driver_id(name, phone),
              merchant:users!merchant_id(name, phone, store_name)
            ''')
            .eq('driver_id', currentUser.id)
                .inFilter('status', ['pending','accepted','on_the_way','delivered','cancelled'])
                .order('created_at', ascending: false)
                .limit(100) // Limit to last 100 orders for performance
                .timeout(
                  const Duration(seconds: 15),
                  onTimeout: () {
                    print('⚠️ Orders query timeout');
                    return <Map<String, dynamic>>[];
                  },
                );
      } else {
        // For merchants, get their orders
        // We'll calculate timeout_remaining_seconds in Dart after fetching
        response = await Supabase.instance.client
            .from('orders')
            .select('''
              *,
              items:order_items(*),
              driver:users!driver_id(name, phone)
            ''')
            .eq('merchant_id', currentUser.id)
                .order('created_at', ascending: false)
                .timeout(
                  const Duration(seconds: 15),
                  onTimeout: () {
                    print('⚠️ Orders query timeout');
                    return <Map<String, dynamic>>[];
                  },
                );
          }
          
          // Success - break out of retry loop
          break;
        } catch (e) {
          final errorString = e.toString().toLowerCase();
          final isConnectionError = errorString.contains('connection reset') ||
                                   errorString.contains('connection refused') ||
                                   errorString.contains('socket') ||
                                   errorString.contains('network') ||
                                   errorString.contains('timeout');
          
          retryCount++;
          
          if (isConnectionError && retryCount <= maxRetries) {
            print('⚠️ Connection error loading orders (attempt $retryCount/$maxRetries): $e');
            // Exponential backoff: wait 1s, 2s, 4s
            await Future.delayed(Duration(seconds: 1 << (retryCount - 1)));
            continue; // Retry
          } else {
            // Not a connection error, or max retries reached
            print('❌ Error loading orders: $e');
            rethrow; // Let outer catch handle it
          }
        }
      }
      
      // If all retries failed, use empty list
      if (response.isEmpty && retryCount > maxRetries) {
        print('⚠️ All retry attempts failed - using empty order list');
        response = [];
      }
      
      // Process response to flatten driver and merchant info and calculate timeout
      _orders = response.map((order) {
        // Debug logging
        print('📦 Order ${order['id']}: driver_id=${order['driver_id']}, driver=${order['driver']}, merchant=${order['merchant']}');
        
        // Validate and fix delivery coordinates
        final deliveryLat = order['delivery_latitude'];
        final deliveryLng = order['delivery_longitude'];
        if (deliveryLat == null || deliveryLng == null || 
            deliveryLat < 29.0 || deliveryLat > 37.0 || 
            deliveryLng < 38.0 || deliveryLng > 49.0) {
          print('⚠️ Order ${order['id']} has invalid delivery coordinates: $deliveryLat, $deliveryLng');
          print('   Customer: ${order['customer_name']}, Address: ${order['delivery_address']}');
          
          // Log invalid coordinates but don't auto-fix
          print('⚠️ Order has invalid coordinates: ${order['delivery_latitude']}, ${order['delivery_longitude']}');
          print('📝 Coordinates will be validated by database, not auto-fixed by client');
        }
        
        // Extract driver info
        if (order['driver'] != null && order['driver'] is Map) {
          order['driver_name'] = order['driver']['name'];
          order['driver_phone'] = order['driver']['phone'];
          print('✅ Added driver info: ${order['driver_name']} - ${order['driver_phone']}');
        } else if (order['driver_id'] != null) {
          print('⚠️ Order has driver_id but no driver data loaded');
        }
        
        // Extract merchant info
        if (order['merchant'] != null && order['merchant'] is Map) {
          order['merchant_name'] = order['merchant']['store_name'] ?? order['merchant']['name'];
          order['merchant_phone'] = order['merchant']['phone'];
          print('✅ Added merchant info: ${order['merchant_name']} - ${order['merchant_phone']}');
        } else {
          print('⚠️ Order has merchant_id but no merchant data loaded');
        }
        
        // Calculate timeout_remaining_seconds for pending orders with driver assigned
        if (order['status'] == 'pending' && 
            order['driver_id'] != null && 
            order['driver_assigned_at'] != null) {
          try {
            final assignedAtStr = order['driver_assigned_at'] as String;
            final assignedAt = DateTime.parse(assignedAtStr);
            final now = DateTime.now().toUtc();
            final assignedAtUtc = assignedAt.toUtc();
            final elapsed = now.difference(assignedAtUtc).inSeconds;
            final remaining = 30 - elapsed;
            final remainingClamped = remaining.clamp(0, 30);
            
            order['timeout_remaining_seconds'] = remainingClamped;
            
            print('');
            print('═══════════════════════════════════════════════════════');
            print('⏱️  TIMEOUT CALCULATION for order ${order['id']}');
            print('───────────────────────────────────────────────────────');
            print('   driver_assigned_at (string): $assignedAtStr');
            print('   driver_assigned_at (parsed): $assignedAt');
            print('   driver_assigned_at (UTC)   : $assignedAtUtc');
            print('   NOW() (UTC)                : $now');
            print('   Elapsed seconds            : $elapsed');
            print('   Formula: 30 - $elapsed     : $remaining');
            print('   Clamped (0-30)            : $remainingClamped');
            print('═══════════════════════════════════════════════════════');
            print('');
          } catch (e) {
            print('❌ Error calculating timeout: $e');
            order['timeout_remaining_seconds'] = null;
          }
        }
        
        // Ensure delivery coords are numeric (avoid nulls/strings causing UI issues)
        if (order['delivery_latitude'] == null || order['delivery_longitude'] == null) {
          order['delivery_latitude'] = order['delivery_latitude'] ?? 0.0;
          order['delivery_longitude'] = order['delivery_longitude'] ?? 0.0;
        }
        return OrderModel.fromJson(order);
      }).toList();
      
      // Clean up timed out orders set - remove IDs that no longer exist in orders
      final currentOrderIds = _orders.map((o) => o.id).toSet();
      final timedOutToRemove = _timedOutOrders.where((id) => !currentOrderIds.contains(id)).toList();
      for (var id in timedOutToRemove) {
        _timedOutOrders.remove(id);
        print('🧹 Removed non-existent order $id from timed out set');
      }

    } catch (e) {
      _error = e.toString();
    }
  }

  // Subscribe to real-time order updates
  Future<void> _subscribeToOrders() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Get user role to determine subscription filter
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .single();

      final userRole = userResponse['role'] as String;

      if (userRole == 'driver') {
        // For drivers, ensure single realtime subscription
        await _ordersSubscription?.cancel();
        _ordersSubscription = Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .listen((data) async {
          
          // Process each order and fetch items if needed
          final List<OrderModel> processedOrders = [];
          
          for (var orderData in data) {
            // Check if this order is relevant to this driver
            final driverId = orderData['driver_id'];
            final status = orderData['status'];
            final orderId = orderData['id'];
            final driverAssignedAt = orderData['driver_assigned_at'];
            
            
            // 🔔 TRIGGER NOTIFICATION: Order newly assigned to this driver
            if (driverId != null && driverId == currentUser.id && status == 'pending') {
              // Check if this is a NEW assignment (not already in our list with this driver)
              final existingOrder = _orders.where((o) => o.id == orderId).firstOrNull;
              final isNewAssignment = existingOrder == null || existingOrder.driverId != currentUser.id;
              
              if (isNewAssignment) {
                // 🔔 NOTIFICATION NOW HANDLED BY DATABASE TRIGGER
                // Database trigger (trigger_notify_driver_assignment) automatically
                // creates notification when driver_id is set on an order
                // App-side notification call disabled to prevent duplicates
                print('ℹ️  New driver assignment detected - database trigger will send notification');
              }
            }
            
          // IMPORTANT: Include ONLY orders assigned to this driver with allowed statuses
          if (driverId == currentUser.id &&
              (status == 'pending' || status == 'accepted' || status == 'on_the_way')) {
              
              
              // Fetch order items if not included
              if (orderData['items'] == null) {
                try {
                  final items = await Supabase.instance.client
                      .from('order_items')
                      .select()
                      .eq('order_id', orderData['id']);
                  orderData['items'] = items;
                } catch (e) {
                  print('Error fetching items for order: $e');
                  orderData['items'] = [];
                }
              }
              
              // Calculate timeout_remaining_seconds if order is pending with driver assigned
              // Formula: 30 - (NOW() - driver_assigned_at)
              if (orderData['status'] == 'pending' && 
                  orderData['driver_id'] != null && 
                  orderData['driver_assigned_at'] != null) {
                try {
                  final assignedAtStr = orderData['driver_assigned_at'] as String;
                  final assignedAt = DateTime.parse(assignedAtStr);
                  final now = DateTime.now().toUtc();
                  final assignedAtUtc = assignedAt.toUtc();
                  final elapsed = now.difference(assignedAtUtc).inSeconds;
                  final remaining = 30 - elapsed;
                  final remainingClamped = remaining.clamp(0, 30);
                  
                  orderData['timeout_remaining_seconds'] = remainingClamped;
                  
                  print('');
                  print('═══════════════════════════════════════════════════════');
                  print('⏱️  TIMEOUT CALCULATION for order ${orderData['id']}');
                  print('───────────────────────────────────────────────────────');
                  print('   driver_assigned_at (string): $assignedAtStr');
                  print('   driver_assigned_at (parsed): $assignedAt');
                  print('   driver_assigned_at (UTC)   : $assignedAtUtc');
                  print('   NOW() (UTC)                : $now');
                  print('   Difference                 : ${now.difference(assignedAtUtc)}');
                  print('   Elapsed seconds            : $elapsed');
                  print('   Formula: 30 - $elapsed     : $remaining');
                  print('   Clamped (0-30)            : $remainingClamped');
                  print('═══════════════════════════════════════════════════════');
                  print('');
                  
                  if (remaining < 0) {
                    print('⚠️  WARNING: Remaining is NEGATIVE ($remaining)');
                    print('⚠️  This order should have been auto-rejected already!');
                  }
                  if (remaining > 30) {
                    print('⚠️  WARNING: Remaining is > 30 seconds ($remaining)');
                    print('⚠️  This suggests driver_assigned_at is in the FUTURE!');
                  }
                  
                } catch (e) {
                  print('❌ Error calculating timeout: $e');
                  print('❌ driver_assigned_at value: ${orderData['driver_assigned_at']}');
                  orderData['timeout_remaining_seconds'] = null;
                }
              } else {
                orderData['timeout_remaining_seconds'] = null;
              }
              
              // Ensure numeric delivery coords
              if (orderData['delivery_latitude'] == null || orderData['delivery_longitude'] == null) {
                orderData['delivery_latitude'] = orderData['delivery_latitude'] ?? 0.0;
                orderData['delivery_longitude'] = orderData['delivery_longitude'] ?? 0.0;
              }
              processedOrders.add(OrderModel.fromJson(orderData));
            }
          }
          
      // Update orders list (de-duplicate by ID and prefer latest status)
      final Map<String, OrderModel> byId = {};
      for (final o in processedOrders) {
        byId[o.id] = o;
      }
      _orders = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          print('📊 Driver orders update: ${_orders.length} orders processed');
          print('   Orders for driver $currentUser.id:');
          for (var o in _orders.where((o) => o.driverId == currentUser.id)) {
            print('     - ${o.id}: status=${o.status}, assigned_at=${o.driverAssignedAt}');
          }
          
          // Clean up timed out orders set - remove IDs that no longer exist
          final currentOrderIds = _orders.map((o) => o.id).toSet();
          final timedOutToRemove = _timedOutOrders.where((id) => !currentOrderIds.contains(id)).toList();
          for (var id in timedOutToRemove) {
            _timedOutOrders.remove(id);
            print('🧹 Removed non-existent order $id from timed out set (driver subscription update)');
          }
          print('   Timed out orders after cleanup: $_timedOutOrders');
          
          notifyListeners();
        });
      } else {
        // For merchants, listen to their orders with complete data loading
        print('👨‍💼 Setting up merchant realtime subscription for user: ${currentUser.id}');
        Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('merchant_id', currentUser.id)
            .listen(
          (data) async {
          print('📦 Merchant real-time update: ${data.length} orders received');
          print('   Update time: ${DateTime.now()}');
          
          // Process each order and fetch related data
          final List<OrderModel> processedOrders = [];
          
          for (var orderData in data) {
            final orderId = orderData['id'];
            
            // Fetch order items if not included
            if (orderData['items'] == null) {
              try {
                final items = await Supabase.instance.client
                    .from('order_items')
                    .select()
                    .eq('order_id', orderId);
                orderData['items'] = items;
              } catch (e) {
                print('❌ Error fetching items for order $orderId: $e');
                orderData['items'] = [];
              }
            }
            
            // Fetch driver info if order has a driver assigned
            if (orderData['driver_id'] != null && orderData['driver'] == null) {
              try {
                final driverData = await Supabase.instance.client
                    .from('users')
                    .select('name, phone')
                    .eq('id', orderData['driver_id'])
                    .single();
                
                orderData['driver_name'] = driverData['name'];
                orderData['driver_phone'] = driverData['phone'];
                print('✅ Loaded driver info for order $orderId: ${driverData['name']}');
              } catch (e) {
                print('⚠️ Error fetching driver info for order $orderId: $e');
              }
            }
            
            // Calculate timeout for pending orders with driver assigned
            if (orderData['status'] == 'pending' && 
                orderData['driver_id'] != null && 
                orderData['driver_assigned_at'] != null) {
              try {
                final assignedAtStr = orderData['driver_assigned_at'] as String;
                final assignedAt = DateTime.parse(assignedAtStr);
                final now = DateTime.now().toUtc();
                final assignedAtUtc = assignedAt.toUtc();
                final elapsed = now.difference(assignedAtUtc).inSeconds;
                final remaining = 30 - elapsed;
                final remainingClamped = remaining.clamp(0, 30);
                
                orderData['timeout_remaining_seconds'] = remainingClamped;
              } catch (e) {
                print('❌ Error calculating timeout: $e');
                orderData['timeout_remaining_seconds'] = null;
              }
            }
            
            processedOrders.add(OrderModel.fromJson(orderData));
          }
          
          // Detect status changes for notifications and logging
          for (var newOrder in processedOrders) {
            final existingOrder = _orders.where((o) => o.id == newOrder.id).firstOrNull;
            
            if (existingOrder != null && existingOrder.status != newOrder.status) {
              print('📢 Order ${newOrder.id} status changed: ${existingOrder.status} → ${newOrder.status}');
              
             // 🔔 NOTIFICATIONS NOW HANDLED BY DATABASE TRIGGERS
             // Database triggers automatically create notifications for:
             // - Order accepted → trigger_notify_order_accepted
             // - Order on the way → trigger_notify_order_on_the_way
             // - Order delivered → trigger_notify_order_delivered
             // - Order rejected → trigger_notify_order_rejected
             // App-side notification calls disabled to prevent duplicates
             if (newOrder.status == AppConstants.statusAccepted && existingOrder.status == AppConstants.statusPending) {
               print('ℹ️  Order accepted - database trigger will send notification');
             } else if (newOrder.status == AppConstants.statusOnTheWay) {
               print('ℹ️  Order on the way - database trigger will send notification');
             } else if (newOrder.status == AppConstants.statusDelivered) {
               print('ℹ️  Order delivered - database trigger will send notification');
             } else if (newOrder.status == AppConstants.statusRejected) {
               print('ℹ️  Order rejected - database trigger will send notification');
             }
            } else if (existingOrder == null) {
              print('🆕 New order detected: ${newOrder.id} with status ${newOrder.status}');
            }
          }
          
          // Update orders and sort by creation date (de-duplicate)
          final Map<String, OrderModel> byId = {};
          for (final o in processedOrders) {
            byId[o.id] = o;
          }
          _orders = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          // Clean up timed out orders set - remove IDs that no longer exist
          final currentOrderIds = _orders.map((o) => o.id).toSet();
          final timedOutToRemove = _timedOutOrders.where((id) => !currentOrderIds.contains(id)).toList();
          for (var id in timedOutToRemove) {
            _timedOutOrders.remove(id);
            print('🧹 Removed non-existent order $id from timed out set (subscription update)');
          }
          
          print('✅ Merchant orders updated: ${_orders.length} total');
          print('   Status breakdown:');
          for (var status in ['pending', 'assigned', 'accepted', 'on_the_way', 'delivered', 'cancelled', 'rejected']) {
            final count = _orders.where((o) => o.status == status).length;
            if (count > 0) print('      $status: $count');
          }
          
          notifyListeners();
        },
        onError: (error) {
          print('❌ Merchant realtime subscription error: $error');
          // Try to resubscribe after error
          Future.delayed(const Duration(seconds: 3), () {
            _subscribeToOrders();
          });
        },
      );
      
      print('✅ Merchant realtime subscription initialized');
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  // Create new order
  Future<bool> createOrder({
    required String customerName,
    required String customerPhone,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String deliveryAddress,
    required double deliveryLatitude,
    required double deliveryLongitude,
    double totalAmount = 0.0,
    double deliveryFee = 0.0,
    String? notes,
    String? vehicleType, // Optional: 'motorbike' (default), 'car', or 'truck'
    DateTime? readyAt, // When order will be ready for pickup
    int? readyCountdown, // Minutes until ready
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'المستخدم غير مسجل الدخول';
        return false;
      }

      // Prepare order data
      final orderData = <String, dynamic>{
        'merchant_id': currentUser.id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'delivery_address': deliveryAddress,
        'delivery_latitude': deliveryLatitude,
        'delivery_longitude': deliveryLongitude,
        'total_amount': totalAmount,
        'delivery_fee': deliveryFee,
        'notes': (notes != null && notes.isNotEmpty) ? notes : null,
        'vehicle_type': vehicleType ?? 'motorbike', // Default to motorbike
        'status': AppConstants.statusPending,
      };
      
      // Add optional fields only if they have values
      if (readyAt != null) {
        orderData['ready_at'] = readyAt.toIso8601String();
      }
      if (readyCountdown != null) {
        orderData['ready_countdown'] = readyCountdown;
      }
      
      // Log the data being sent for debugging
      print('📝 Creating order with data:');
      print('   merchant_id: ${orderData['merchant_id']}');
      print('   customer_name: ${orderData['customer_name']}');
      print('   customer_phone: ${orderData['customer_phone']}');
      print('   vehicle_type: ${orderData['vehicle_type']}');
      print('   status: ${orderData['status']}');
      print('   ready_at: ${orderData['ready_at']}');
      print('   ready_countdown: ${orderData['ready_countdown']}');
      
      // Create order (wrap with ErrorManager to capture DB errors)
      final orderResponse = await ErrorManager.safeExecute<Map<String, dynamic>>(
        operationName: 'create-order',
        isCritical: true,
        operation: () async {
          return await Supabase.instance.client
              .from('orders')
              .insert(orderData)
              .select()
              .single();
        },
      );
      if (orderResponse == null) {
        _error = _error ?? 'حدث خطأ في إنشاء الطلب. يرجى المحاولة مرة أخرى.';
        return false;
      }

      // Optimistically add order to local state for instant feedback
      try {
        final createdOrder = OrderModel.fromJson(orderResponse);
        _orders = [createdOrder, ..._orders];
        notifyListeners();
      } catch (e) {
        print('⚠️ Failed to parse created order: $e');
      }

      // Fire-and-forget refresh + notification (don't block UI)
      unawaited(_loadOrders());
      unawaited(_sendMerchantNotification(() async {
        final success = await NotificationManager.notifyMerchantOrderCreated(
          merchantId: currentUser.id,
          orderId: orderResponse['id'],
          customerName: customerName,
          totalAmount: totalAmount,
          deliveryFee: deliveryFee,
        );
        print('✅ Order created notification sent: $success');
      }));

      return true;
    } catch (e, stackTrace) {
      // Log detailed error information
      print('❌ Error creating order:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      
      // Check if error is due to system being disabled
      final errorString = e.toString();
      if (errorString.contains('SYSTEM_DISABLED') || errorString.contains('وضع الصيانة')) {
        _error = 'النظام حالياً في وضع الصيانة. لا يمكن إنشاء طلبات جديدة.';
      } else {
        // Extract more detailed error message
        String detailedError = errorString;
        if (e.toString().contains('PostgrestException')) {
          // Try to extract the actual error message from Supabase
          try {
            final match = RegExp(r'message: (.+?)(?:,|$)').firstMatch(errorString);
            if (match != null) {
              detailedError = match.group(1) ?? errorString;
            }
          } catch (_) {
            // If parsing fails, use original error
          }
        }
        _error = detailedError.isNotEmpty ? detailedError : 'حدث خطأ في إنشاء الطلب. يرجى المحاولة مرة أخرى.';
        print('   User-friendly error: $_error');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }

      // Get order details for notification
      final order = getOrderById(orderId);
      final merchantId = order?.merchantId;

      // Use database function for proper validation and permissions
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'update-order-status',
        isCritical: true,
        operation: () async {
          try {
            // Call the database function (returns JSON)
            final functionResult = await Supabase.instance.client.rpc(
              'update_order_status',
              params: {
                'p_order_id': orderId,
                'p_new_status': status,
                'p_user_id': currentUser.id,
              },
            );
            
            print('🔍 Update order status response: $functionResult');
            print('🔍 Response type: ${functionResult.runtimeType}');
            
            // Function now returns JSON with success flag
            if (functionResult is Map) {
              if (functionResult['success'] == true) {
                print('✅ Order status updated successfully');
                return true;
              } else {
                // Function returned error details
                final error = functionResult['error'] ?? 'UNKNOWN_ERROR';
                final message = functionResult['message'] ?? 'Failed to update order status';
                print('❌ Update failed: $error - $message');
                print('   Full response: $functionResult');
                _error = message;
                return false;
              }
            }
            
            // Unexpected response format
            print('⚠️ Unexpected response format: $functionResult');
            _error = 'Unexpected response from server';
            return false;
          } catch (e) {
            // Exception occurred
            print('❌ Exception updating order status: $e');
            print('   Exception type: ${e.runtimeType}');
            if (e is PostgrestException) {
              print('   Postgrest code: ${e.code}');
              print('   Postgrest message: ${e.message}');
              print('   Postgrest details: ${e.details}');
              print('   Postgrest hint: ${e.hint}');
            }
            throw e;
          }
          
          // Fallback: Direct update with verification
          final response = await Supabase.instance.client
              .from('orders')
              .update({
                'status': status,
                'updated_at': DateTime.now().toIso8601String(),
                // Set picked_up_at when status changes to on_the_way
                if (status == 'on_the_way') 'picked_up_at': DateTime.now().toIso8601String(),
                // Set delivered_at when status changes to delivered
                if (status == 'delivered') 'delivered_at': DateTime.now().toIso8601String(),
              })
              .eq('id', orderId)
              .select();
          
          // Verify the update actually happened
          if (response.isEmpty) {
            throw Exception('Order not found or update failed - no rows updated');
          }
          
          // Verify the status was actually updated
          final updatedOrder = response.first;
          if (updatedOrder['status'] != status) {
            throw Exception('Status update failed - status mismatch. Expected: $status, Got: ${updatedOrder['status']}');
          }
          
          return true;
        },
        defaultValue: false,
      );
      if (ok != true) {
        _error = _error ?? 'تعذر تحديث حالة الطلب.';
        return false;
      }

      // NOTE: Merchant notifications are handled in _processOrderUpdate method
      // to avoid duplicate notifications

      // Update local order
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
      }

      // Update current order if it's the same
      if (_currentOrder?.id == orderId) {
        _currentOrder = _currentOrder!.copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Assign order to driver
  Future<bool> assignOrderToDriver(String orderId, String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Update order with driver (keep status as 'pending' to trigger auto-reject timer)
      await Supabase.instance.client
          .from('orders')
          .update({
            'driver_id': driverId,
            // Keep status as 'pending' - this triggers the driver_assigned_at timestamp
            // Driver must accept within 30 seconds or will be auto-rejected
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Create assignment record
      await Supabase.instance.client
          .from('order_assignments')
          .insert({
            'order_id': orderId,
            'driver_id': driverId,
            'status': 'pending',
            'assigned_at': DateTime.now().toIso8601String(),
            'timeout_at': DateTime.now()
                .add(const Duration(minutes: AppConstants.orderTimeoutMinutes))
                .toIso8601String(),
          });

      // Load updated orders
      await _loadOrders();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accept order (driver)
  Future<bool> acceptOrder(String orderId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;

      // Get order details for notification
      final order = getOrderById(orderId);
      final merchantId = order?.merchantId;

      // Call database function to accept order (handles history tracking)
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'driver-accept-order',
        isCritical: true,
        operation: () async {
          await Supabase.instance.client.rpc('driver_accept_order', params: {
            'p_order_id': orderId,
            'p_driver_id': currentUser.id,
          });
          return true;
        },
        defaultValue: false,
      );
      if (ok != true) {
        _error = _error ?? 'تعذر قبول الطلب.';
        return false;
      }

           // NOTE: Merchant notification will be sent by _processOrderUpdate method
           // when the order status changes to 'accepted' to avoid duplicates

      // Reload orders
      await _loadOrders();

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // Reject order (driver) - Immediately reassigns to next driver
  Future<bool> rejectOrder(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }

      // Get order details for notification
      final order = getOrderById(orderId);
      final merchantId = order?.merchantId;

      // Call database function to reject and auto-reassign to next driver
      final ok = await ErrorManager.safeExecute<bool>(
        operationName: 'driver-reject-order',
        isCritical: true,
        operation: () async {
          await Supabase.instance.client.rpc('driver_reject_order', params: {
            'p_order_id': orderId,
            'p_driver_id': currentUser.id,
          });
          return true;
        },
        defaultValue: false,
      );
      if (ok != true) {
        _error = _error ?? 'تعذر رفض الطلب.';
        return false;
      }

           // NOTE: Merchant notification will be sent by _processOrderUpdate method
           // when the order status changes to 'rejected' to avoid duplicates

      // Reload orders
      await _loadOrders();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally{
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark order as on the way (being delivered)
  Future<bool> markOrderOnTheWay(String orderId) async {
    return await updateOrderStatus(orderId, AppConstants.statusOnTheWay);
  }

  // Mark order as delivered
  Future<bool> markOrderDelivered(String orderId) async {
    return await updateOrderStatus(orderId, AppConstants.statusDelivered);
  }

  // Cancel order
  Future<bool> cancelOrder(String orderId) async {
    return await updateOrderStatus(orderId, AppConstants.statusCancelled);
  }

  // Upload order proof (driver must upload before delivery completion)
  Future<bool> uploadOrderProof({
    required String orderId,
    required Uint8List fileBytes,
    required String contentType,
    String? fileName,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'User not authenticated';
        return false;
      }
      final name = fileName ?? 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final objectPath = '$orderId/$name';

      // Upload to storage
      await Supabase.instance.client.storage
          .from('order_proofs')
          .uploadBinary(objectPath, fileBytes, fileOptions: FileOptions(contentType: contentType, upsert: true));

      // Record in DB
      await Supabase.instance.client
          .from('order_proofs')
          .insert({
            'order_id': orderId,
            'driver_id': currentUser.id,
            'storage_path': objectPath,
            'content_type': contentType,
            'size_bytes': fileBytes.length,
          });

      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    }
  }

  // Check if order has at least one proof
  Future<bool> hasOrderProof(String orderId) async {
    try {
      final result = await Supabase.instance.client
          .from('order_proofs')
          .select('id')
          .eq('order_id', orderId)
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Fetch proof list for an order
  Future<List<Map<String, dynamic>>> getOrderProofs(String orderId) async {
    try {
      final rows = await Supabase.instance.client
          .from('order_proofs')
          .select('id, storage_path, created_at, content_type, size_bytes')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // Repost rejected order with increased delivery fee
  Future<bool> repostOrder(String orderId, double newDeliveryFee) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'المستخدم غير مسجل الدخول';
        return false;
      }

      print('🔄 Reposting order $orderId with new fee: $newDeliveryFee');

      // Use the database function to repost with vehicle type checking
      final response = await Supabase.instance.client.rpc(
        'repost_order_with_increased_fee',
        params: {
          'p_order_id': orderId,
          'p_merchant_id': currentUser.id,
        },
      );

      print('📦 Repost response: $response');
      print('📦 Response type: ${response.runtimeType}');

      // Handle both boolean (old function) and JSON (new function) responses
      bool success = false;
      String? errorMessage;
      
      if (response is Map<String, dynamic>) {
        // New JSON response
        success = response['success'] as bool? ?? false;

        if (!success) {
          final error = response['error'] as String?;
          final message = response['message'] as String?;

          // Handle specific error types
          if (error == 'no_drivers') {
            final vehicleType = response['vehicle_type'] as String?;
            final vehicleTypeArabic = vehicleType == 'motorcycle' || vehicleType == 'motorbike'
                ? 'دراجة نارية'
                : vehicleType == 'car'
                    ? 'سيارة'
                    : vehicleType == 'truck'
                        ? 'شاحنة'
                        : 'مركبة';
            
            errorMessage = 'لا يوجد سائقي $vehicleTypeArabic متصلين حالياً. يرجى المحاولة لاحقاً.';
          } else {
            errorMessage = message ?? 'فشل إعادة نشر الطلب';
          }

          print('❌ Repost failed: $errorMessage');
          _error = errorMessage;
          return false;
        }

        // Success
        final newFee = response['new_fee'];
        final availableDrivers = response['available_drivers'];
        print('✅ Order $orderId reposted successfully!');
        print('   New fee: $newFee IQD');
        print('   Available drivers: $availableDrivers');
      } else if (response is bool) {
        // Old boolean response (backward compatibility)
        success = response;
        print('✅ Order $orderId reposted (legacy boolean response): $success');
        if (!success) {
          errorMessage = 'فشل إعادة نشر الطلب';
          _error = errorMessage;
          return false;
        }
      } else {
        // Unexpected response type
        print('⚠️ Unexpected response type: ${response.runtimeType}');
        errorMessage = 'استجابة غير متوقعة من الخادم';
        _error = errorMessage;
        return false;
      }

      // Reload orders to get updated list
      await _loadOrders();
      return true;
    } catch (e) {
      print('❌ Error reposting order: $e');
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set current order
  void setCurrentOrder(OrderModel? order) {
    _currentOrder = order;
    notifyListeners();
  }

  // Get order by ID
  OrderModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }


  // Get error message
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('Order not found')) {
      return 'الطلب غير موجود';
    } else if (error.toString().contains('Driver not available')) {
      return 'لا يوجد سائق متاح';
    } else if (error.toString().contains('Order already assigned')) {
      return 'الطلب مخصص بالفعل';
    } else if (error.toString().contains('Invalid status transition')) {
      return 'تغيير الحالة غير صحيح';
    } else {
      return 'حدث خطأ غير متوقع';
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Helper method to send merchant notifications asynchronously
  /// Send merchant notification with proper async/await handling
  /// This ensures notifications are not dropped
  Future<void> _sendMerchantNotification(Future<void> Function() notificationCall) async {
    try {
      await notificationCall();
    } catch (e) {
      print('❌ Merchant notification failed: $e');
    }
  }

  /// Manually remove an order from local state (for immediate UI updates)
  /// This is used when an order is marked as delivered to ensure immediate disappearance
  /// The subscription will also handle removal, but this prevents visual lag
  void removeOrderFromLocalState(String orderId) {
    print('🗑️  Manually removing order $orderId from local state');
    final initialCount = _orders.length;
    _orders.removeWhere((order) => order.id == orderId);
    final finalCount = _orders.length;
    
    if (initialCount != finalCount) {
      print('✅ Order $orderId removed from local state (${initialCount} → ${finalCount} orders)');
      notifyListeners();
    } else {
      print('⚠️  Order $orderId not found in local state (may already be removed)');
    }
  }

}
