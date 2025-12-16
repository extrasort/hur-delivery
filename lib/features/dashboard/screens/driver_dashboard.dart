import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart' as ip;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/state_of_the_art_map_widget.dart';
import '../../../core/providers/location_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/widgets/header_notification.dart';
import '../../../core/constants/app_constants.dart' as constants;
import '../../../core/services/order_redirect_service.dart';
import '../../../core/services/neighborhood_labels_service.dart';
import '../../../core/providers/announcement_provider.dart';
import '../../../core/providers/system_status_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../shared/widgets/maintenance_mode_dialog.dart';
import '../widgets/state_of_the_art_navigation.dart';
// Removed legacy map/annotation systems
import '../../driver/widgets/simple_location_update_widget.dart';
import '../../../core/services/driver_location_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/localization/app_localizations.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with WidgetsBindingObserver {
  bool _isOnline = false;
  bool _showSidebar = false;
  Timer? _locationTimer;
  Timer? _driverLocationTimer;
  Timer? _statusCheckTimer;
  RealtimeChannel? _onlineStatusChannel;
  bool _hasLocationAlwaysPermission = false;
  
  // Order cards swipe functionality
  PageController? _orderCardsPageController;
  int _currentOrderIndex = 0;
  String? _lastOrderListHash; // To detect order list changes
  
  // Enhanced route management (removed legacy managers)
  List<OrderModel>? _cachedActiveOrders; // Cache orders to prevent flickering
  bool _isOrderCardExpanded = true; // Track if order card is expanded
  
  // Navigation buttons state
  bool _showNavigationButtons = false;
  double? _targetLatitude;
  double? _targetLongitude;
  GlobalKey<StateOfTheArtMapWidgetState>? _mapWidgetKey;
  String?
      _expandedAddressCardId; // Track which address card is expanded (pickup/dropoff)
  
  // Geocoding cache to prevent excessive API calls
  final Map<String, String?> _geocodedAddresses = {};
  
  void _refreshMapRoute([OrderModel? order]) {
    final mapState = _mapWidgetKey?.currentState;
    if (mapState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapState.forceRefreshActiveOrder(order);
      });
    }
  }

  /// Get geocoded address with caching to prevent excessive API calls
  /// This solves the issue of making thousands of geocoding requests per hour
  Future<String?> _getGeocodedAddress(
    String orderId,
    double latitude,
    double longitude,
    bool isPickup,
  ) async {
    final key = '${orderId}_${isPickup ? 'pickup' : 'delivery'}';
    
    // Return cached address if available
    if (_geocodedAddresses.containsKey(key)) {
      return _geocodedAddresses[key];
    }
    
    // Fetch and cache the address
    final address = await GeocodingService.reverseGeocode(latitude, longitude);
    if (mounted) {
      _geocodedAddresses[key] = address;
    }
    return address;
  }

  Future<void> _openSupportChat() async {
      if (!mounted) return;
    context.push('/driver/messages');
  }

  String? _getFocusedOrderId(
      OrderProvider orderProvider, AuthProvider authProvider) {
    final driverId = authProvider.user?.id;
    if (driverId == null) return null;
    final activeOrders = orderProvider.getAllActiveOrdersForDriver(driverId);
    if (activeOrders.isEmpty) {
      return null;
    }
    var index = _currentOrderIndex;
    if (index < 0) index = 0;
    if (index >= activeOrders.length) {
      index = activeOrders.length - 1;
    }
    final order = activeOrders[index];
    return order.id;
  }

  Widget _buildSupportShortcut({bool onPrimaryBackground = false}) {
    final backgroundColor =
        onPrimaryBackground ? Colors.white.withOpacity(0.15) : Colors.white;
    final iconColor = onPrimaryBackground ? Colors.white : AppColors.primary;
    final border = onPrimaryBackground
        ? Border.all(color: Colors.white.withOpacity(0.5))
        : null;
    final boxShadow = onPrimaryBackground
        ? <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _openSupportChat,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: border,
            shape: BoxShape.circle,
            boxShadow: boxShadow,
          ),
          child: Icon(
                Icons.support_agent,
                color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          _showSidebar ? Icons.home_rounded : Icons.menu_rounded,
          color: AppColors.primary,
          size: 28,
        ),
        onPressed: () {
          setState(() {
            _showSidebar = !_showSidebar;
          });
        },
      ),
    );
  }

  Widget _buildOnlineToggleButton() {
    const toggleWidth = 100.0; // Increased for better text visibility
    const toggleHeight = 42.0; // Taller for better aesthetics

    const horizontalPadding = 4.0;
    const verticalPadding = 4.0;
    final innerWidth = toggleWidth - (horizontalPadding * 2);
    final innerHeight = toggleHeight - (verticalPadding * 2);
    final knobSize = innerHeight;
    final highlightWidth = innerWidth / 2;

    final loc = AppLocalizations.of(context);

    return Container(
      constraints: BoxConstraints(
        minWidth: toggleWidth,
        maxWidth: toggleWidth,
        minHeight: toggleHeight,
        maxHeight: toggleHeight,
      ),
      width: toggleWidth,
      height: toggleHeight,
      child: GestureDetector(
        onTap: () async {
          final systemStatus = context.read<SystemStatusProvider>();
          final authProvider = context.read<AuthProvider>();
          var newStatus = !_isOnline;

          if (newStatus && !systemStatus.isSystemEnabled) {
            MaintenanceModeDialog.show(context, 'driver');
            return;
          }

          if (!newStatus) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: Text(loc.confirmGoOfflineTitle),
                  content: Text(loc.confirmGoOfflineMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(loc.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(loc.confirm),
                    ),
                  ],
                );
              },
            );

            if (confirm != true) {
              return;
            }
          }

          if (newStatus) {
            final ok = await _showBackgroundLocationDisclosureAndRequest();
            if (!ok) return;
          }

          setState(() {
            _isOnline = newStatus;
          });

          try {
            await authProvider.setOnlineStatus(newStatus);

            if (newStatus) {
              final locationProvider = context.read<LocationProvider>();
              if (!locationProvider.isTracking) {
                locationProvider.startLocationTracking();
              }

              _startLocationTracking();
              _startDriverLocationTracking();
              _updateDriverLocation();

              if (authProvider.user != null) {
                final np = context.read<NotificationProvider>();
                await np.startBackgroundNotifications(
                  authProvider.user!.id,
                  authProvider.user!.role,
                  driverName: authProvider.user!.name,
                );
              }
            } else {
              // When going offline:
              // 1. Stop background database updates
              _stopLocationTracking();

              // 2. Keep foreground location tracking for map display
              // (LocationProvider continues running for visual display when app is open)
              print('ℹ️ Driver offline: Stopped background updates, keeping foreground location for map display');

              // 3. Stop background notifications
              if (authProvider.user != null) {
                final np = context.read<NotificationProvider>();
                await np.stopBackgroundNotifications();
              }
            }
          } catch (e) {
            final message = e.toString();
            final loc = AppLocalizations.of(context);
            if (message.contains('SYSTEM_DISABLED') ||
                message.contains(loc.maintenanceMode)) {
              setState(() => _isOnline = false);
              if (mounted) {
                MaintenanceModeDialog.show(context, 'driver');
              }
            } else {
              print('❌ Error toggling online status: $e');
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(toggleHeight / 2),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubicEmphasized,
          width: toggleWidth,
          height: toggleHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isOnline
                  ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                  : [const Color(0xFF78909C), const Color(0xFF546E7A)],
            ),
            borderRadius: BorderRadius.circular(toggleHeight / 2),
            boxShadow: [
              BoxShadow(
                color: (_isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF78909C))
                    .withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
          ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: SizedBox.expand(
          child: Stack(
                  clipBehavior: Clip.hardEdge,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                      left:
                          _isOnline ? innerWidth - highlightWidth : 0,
                top: 0,
                bottom: 0,
                child: Container(
                        width: highlightWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                          borderRadius:
                              BorderRadius.circular(toggleHeight / 2),
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      alignment: _isOnline
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Text(
                              _isOnline ? loc.connected : loc.notAvailable,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                      left: _isOnline
                          ? innerWidth - knobSize
                          : 0,
                      top: 0,
                      bottom: 0,
                child: Container(
                        width: knobSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: _isOnline
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350),
                      size: 16,
                    ),
                  ),
                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Wait for permission dialog to resolve before initializing
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('🚀 Driver Dashboard initializing...');
        
        // Stop order redirect service since driver is now on dashboard
        OrderRedirectService.stopMonitoring();
        print('✅ Order redirect service stopped (driver on dashboard)');
        
        // Check location permission FIRST
        await _checkLocationAlwaysPermission();
        
        if (!_hasLocationAlwaysPermission) {
          print('⚠️ Location permission not granted, showing dialog...');
          // Show blocking dialog - initialization will happen after permission granted
          _showLocationPermissionDialog();
          return; // STOP HERE - wait for permission
        }
        
        // Permission already granted, proceed with initialization
        print('✅ Permission already granted, initializing...');
        await _initializeDashboardWithPermission();
      } catch (e) {
        print('❌ Error initializing dashboard: $e');
        // Don't crash - just log error
      }
    });
  }
  
  // Separate initialization method to reuse after permission granted
  Future<void> _initializeDashboardWithPermission() async {
    try {
      print('🔧 Starting dashboard initialization...');
      
      // Initialize providers
      await context.read<OrderProvider>().initialize();
      
      print('✅ OrderProvider initialized');
      
      // Initialize location provider and wait for first GPS fix
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.initialize();
      
      print('✅ LocationProvider initialized');
      
      // Set up callback to update database when location changes
      locationProvider.onLocationUpdate = (position) {
        // Update database when location changes via stream (only if online)
        if (_isOnline) {
          print(
              '🔄 Location stream updated: ${position.latitude}, ${position.longitude}');
          _updateDriverLocation();
        } else {
          print(
              'ℹ️ Location updated but driver is offline - skipping database update');
        }
      };
      
      // Start location tracking immediately
      locationProvider.startLocationTracking();
      
      print('📍 Location tracking started, waiting for first GPS fix...');
      
      // Wait for first GPS fix (up to 5 seconds)
      int attempts = 0;
      while (locationProvider.currentPosition == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        print('   ⏳ Waiting for GPS... attempt $attempts/10');
      }
      
      if (locationProvider.currentPosition != null) {
        print(
            '✅ First GPS position obtained: ${locationProvider.currentPosition!.latitude}, ${locationProvider.currentPosition!.longitude}');
      } else {
        print('⚠️ GPS fix not obtained after 5 seconds, continuing anyway...');
      }
      
      // Immediately update driver location to database
      await _updateDriverLocation();
      
      print('✅ Initial location update complete');
      
      // Force immediate update from database
      await _updateDriverLocationFromDatabase();
      
      // Additional update to ensure marker appears
      await Future.delayed(const Duration(milliseconds: 500));
      await _updateDriverLocation();
      
      print('✅ Secondary location updates complete');
      
      // Initialize online status first
      _initializeOnlineStatus();
      _subscribeToOnlineStatus();
      _startStatusCheckTimer();
      
      // Only start location tracking if driver is already online
      if (_isOnline) {
        print('✅ Driver is online - starting location tracking timers');
        _startLocationTracking();
        _startDriverLocationTracking();
      } else {
        print(
            'ℹ️ Driver is offline - location tracking timers will start when driver goes online');
        // Still initialize LocationProvider for map display
        final locationProvider = context.read<LocationProvider>();
        locationProvider.startLocationTracking();
      }
      
      print('✅ Dashboard initialization complete!');
      print('📍 Current position: ${locationProvider.currentPosition}');
      
      // Force UI rebuild to show map with marker
      if (mounted) {
        setState(() {
          print('🔄 UI rebuilt with location marker');
        });
        
        // Initialize system status checking
        await context.read<SystemStatusProvider>().initialize();
        
        // Initialize announcement checker (checks every 5 seconds)
        final authProvider = context.read<AuthProvider>();
        if (authProvider.user != null) {
          await context.read<AnnouncementProvider>().initialize(
            userRole: 'driver',
            userId: authProvider.user!.id,
            context: context,
          );
          
          // Check system status and show dialog if disabled
          final systemStatus = context.read<SystemStatusProvider>();
          if (!systemStatus.isSystemEnabled) {
            // Force driver offline if system is disabled
            if (_isOnline) {
              setState(() {
                _isOnline = false;
              });
              await authProvider.setOnlineStatus(false);
            }
            MaintenanceModeDialog.show(context, 'driver');
          }
        }
      }
      
      // AGGRESSIVE: Keep trying to update location for 10 seconds
      int retryCount = 0;
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        retryCount++;
        if (retryCount > 10 || !mounted) {
          timer.cancel();
          return;
        }
        
        print('🔄 Post-init location update #$retryCount');
        await _updateDriverLocation();
        await _updateDriverLocationFromDatabase();
        
        if (locationProvider.currentPosition != null) {
          print(
              '   ✅ Location confirmed: ${locationProvider.currentPosition!.latitude}, ${locationProvider.currentPosition!.longitude}');
        }
      });
    } catch (e) {
      print('❌ Error in dashboard initialization: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  void _initializeOnlineStatus() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      setState(() {
        _isOnline = authProvider.user!.isOnline;
      });
    }
  }

  void _subscribeToOnlineStatus() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;

    // Subscribe to realtime updates for this driver's online status
    _onlineStatusChannel = Supabase.instance.client
        .channel('driver_online_status_${authProvider.user!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: authProvider.user!.id,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final isOnline = newData['is_online'] as bool? ?? false;
            
            print(
                '🔄 Online status changed in database: $isOnline (current UI: $_isOnline)');
            
            // If database says offline but UI says online, update UI
            if (!isOnline && _isOnline) {
              setState(() {
                _isOnline = false;
              });
              // Stop location tracking when going offline
              _stopLocationTracking();
              print(
                  '⚠️ Driver went offline (from realtime) - stopped location updates');
              // Notification handled via push notification system
              // No in-app snackbar needed
            } else if (isOnline && !_isOnline) {
              // Sync if database says online but UI says offline
              setState(() {
                _isOnline = true;
              });
              // Start location tracking when going online
              _startLocationTracking();
              _startDriverLocationTracking();
              _updateDriverLocation(); // Immediate update
              print(
                  '✅ Driver went online (from realtime) - started location updates');
            }
          },
        )
        .subscribe();
    
    print(
        '✅ Subscribed to online status updates for driver ${authProvider.user!.id}');
  }

  void _startStatusCheckTimer() {
    _statusCheckTimer?.cancel();
    
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;
    
    // Check database status every second
    _statusCheckTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // Fetch current status from database
        final response = await Supabase.instance.client
            .from('users')
            .select('is_online')
            .eq('id', authProvider.user!.id)
            .single();
        
        final dbIsOnline = response['is_online'] as bool? ?? false;
        
        // Update UI if status differs from database
        if (dbIsOnline != _isOnline) {
          setState(() {
            _isOnline = dbIsOnline;
          });
          print(
              '🔄 Status synced from database: ${dbIsOnline ? "Online" : "Offline"}');
        }
      } catch (e) {
        print('⚠️ Error checking online status: $e');
      }
    });
    
    print('✅ Started status check timer (every 1 second)');
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final orderProvider = context.read<OrderProvider>();
      final authProvider = context.read<AuthProvider>();
      
      final loc = AppLocalizations.of(context);
      if (authProvider.user == null) {
        showHeaderNotification(
          context,
          title: loc.notLoggedIn,
          message: loc.mustLoginFirst,
          type: NotificationType.error,
        );
        return;
      }

      final success = await orderProvider.acceptOrder(orderId);
      
      // Clear cached orders to force immediate refresh and update route
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
        });
        
        // Trigger rebuild to ensure map updates route
        // Map will update automatically through coordinate change detection
      }
      
      if (success && mounted) {
        showHeaderNotification(
          context,
          title: loc.accepted,
          message: loc.orderAcceptedSuccessMessage,
          type: NotificationType.success,
        );
      } else if (mounted) {
        showHeaderNotification(
          context,
          title: loc.error,
          message: orderProvider.error ?? loc.errorAcceptingOrder,
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.errorInOperation,
          type: NotificationType.error,
        );
      }
    }
  }
  
  Future<void> _rejectOrder(String orderId) async {
    try {
      final orderProvider = context.read<OrderProvider>();
      final authProvider = context.read<AuthProvider>();
      
      final loc = AppLocalizations.of(context);
      if (authProvider.user == null) {
        showHeaderNotification(
          context,
          title: loc.notLoggedIn,
          message: loc.mustLoginFirst,
          type: NotificationType.error,
        );
        return;
      }

      print('🚫 Rejecting order $orderId');
      
      // STEP 1: Clear map annotations BEFORE rejecting
      print('🧹 STEP 1: Clearing routes and markers for rejected order');
      try {
        await StateOfTheArtNavigation().clearAll();
      } catch (_) {}
      
      // STEP 2: Reject the order
      final success = await orderProvider.rejectOrder(orderId);
      
      if (!success) {
        if (mounted) {
          showHeaderNotification(
            context,
            title: loc.error,
            message: orderProvider.error ?? loc.errorRejectingOrder,
            type: NotificationType.error,
          );
        }
        return;
      }
      
      // STEP 3: Clear annotations again after rejection
      print('🧹 STEP 3: Post-rejection clearing');
      try {
        await StateOfTheArtNavigation().clearAll();
      } catch (_) {}
      
      // STEP 4: Force immediate removal from local state
      print('🧹 STEP 4: Removing order from local state');
      if (mounted) {
        orderProvider.removeOrderFromLocalState(orderId);
      }
      
      // STEP 5: Clear cached orders to force refresh
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
        });
      }
      
      // STEP 6: Show success message
      if (mounted) {
        showHeaderNotification(
          context,
          title: loc.rejected,
          message: loc.orderRejectedSuccessMessage,
          type: NotificationType.warning,
        );
      }
      
      print('✅ Order $orderId rejected successfully and annotations cleared');
    } catch (e) {
      print('❌ Error rejecting order: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.errorInOperation,
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildSwipeableOrderCards(List<OrderModel> orders) {
    // Generate hash including BOTH order IDs AND statuses to detect changes
    final currentHash = orders.map((o) => '${o.id}_${o.status}').join(',');
    
    // Initialize or reinitialize PageController when orders change
    if (_lastOrderListHash != currentHash ||
        _orderCardsPageController == null) {
      print('🔄 Order list changed - reinitializing PageController');
      print('   Old hash: $_lastOrderListHash');
      print('   New hash: $currentHash');
      
      _lastOrderListHash = currentHash;
      
      // Clear geocoding cache when orders change to avoid stale addresses
      _geocodedAddresses.clear();
      print(
          '🗺️ Cleared geocoding cache (${_geocodedAddresses.length} entries)');
      
      // Find index of first pending order (if only one exists)
      final pendingOrders = orders.where((o) => o.status == 'pending').toList();
      int initialPage = 0;
      
      if (pendingOrders.length == 1) {
        // Auto-scroll to the single pending order
        initialPage = orders.indexOf(pendingOrders.first);
        print('🎯 Auto-scrolling to pending order at index $initialPage');
      }
      
      // Ensure index is within bounds
      if (initialPage >= orders.length) {
        initialPage = 0;
      }
      
      _currentOrderIndex = initialPage;
      _orderCardsPageController?.dispose();
      _orderCardsPageController = PageController(
        initialPage: initialPage,
        viewportFraction:
            orders.length > 1 ? 0.88 : 1.0, // Show more of edges (12%)
        keepPage: true, // Keep the page between rebuilds
      );

      if (orders.isNotEmpty) {
        _refreshMapRoute(orders[_currentOrderIndex]);
      }
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact sizing - only enough for content
        final screenHeight = MediaQuery.of(context).size.height;
        final collapsedHeight = 60.0; // Fixed height for collapsed card
        
        // Check if current order is pending - raise height by 5% if so
        final currentOrder = _currentOrderIndex < orders.length 
            ? orders[_currentOrderIndex] 
            : null;
        final isPendingOrder = currentOrder?.status == 'pending';
        final baseExpandedHeight = screenHeight * 0.515; // 51.5% base height (increased by 7% from 47.15%)
        final maxExpandedHeight = isPendingOrder
            ? baseExpandedHeight + (screenHeight * 0.05) // Add 5% for pending orders
            : baseExpandedHeight; // Keep base height for other statuses
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timeout countdown pill - above the card for pending/assigned orders
            if (currentOrder != null && 
                (currentOrder.status == 'pending' ||
                    currentOrder.status == 'assigned'))
              _buildTimeoutCountdownPill(currentOrder),
            
            // Enhanced page indicator with better visibility - BEFORE the card
            if (orders.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      size: 16,
                      color: _currentOrderIndex > 0 
                          ? AppColors.primary 
                          : AppColors.textTertiary.withOpacity(0.3),
                    ),
                    SizedBox(width: context.rs(8)),
                    ...List.generate(
                      orders.length,
                      (index) => Container(
                        margin: EdgeInsets.symmetric(horizontal: context.rs(3)),
                        width: _currentOrderIndex == index
                            ? context.rs(24)
                            : context.rs(8),
                        height: context.rs(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentOrderIndex == index
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.25),
                          boxShadow: _currentOrderIndex == index
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(width: context.rs(8)),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: _currentOrderIndex < orders.length - 1
                          ? AppColors.primary 
                          : AppColors.textTertiary.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
                child: Builder(
                builder: (context) {
                  final pageView = PageView.builder(
                      key: ValueKey('order_cards_pageview_$currentHash'),
                      controller: _orderCardsPageController,
                      itemCount: orders.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentOrderIndex = index;
                        });
                        print(
                            '📄 Switched to order card $index: ${orders[index].id}');
                        _refreshMapRoute(orders[index]);
                      },
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: orders.length > 1 ? 8.0 : 0.0,
                          ),
                          child: RepaintBoundary(
                            key: ValueKey(
                                'order_card_${order.id}_${order.status}'),
                            child: _buildOrderCard(order),
                          ),
                        );
                      },
                  );

                  return _isOrderCardExpanded
                      ? ClipRect(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxExpandedHeight,
                            ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 400),
                              opacity: 1.0,
                              child: pageView,
                            ),
                          ),
                        )
                      : SizedBox(
                          height: collapsedHeight,
                          child: ClipRect(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 400),
                              opacity: 1.0,
                              child: pageView,
                    ),
                  ),
                        );
                },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';
    
    // Get vehicle type icon
    final loc = AppLocalizations.of(context);
    IconData vehicleIcon = Icons.two_wheeler;
    String vehicleText = loc.motorbikeLabel;
    if (order.vehicleType == 'car') {
      vehicleIcon = Icons.directions_car;
      vehicleText = loc.car;
    } else if (order.vehicleType == 'truck') {
      vehicleIcon = Icons.local_shipping;
      vehicleText = loc.truck;
    }

    return GestureDetector(
      onTap: () {
        // Allow tapping collapsed card to expand
        if (!_isOrderCardExpanded) {
          setState(() {
            _isOrderCardExpanded = true;
          });
          // Ensure route and pins are created when card expands
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                // Force Consumer rebuild to update map widget
              });
            }
          });
        }
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        child: _isOrderCardExpanded 
            ? _buildExpandedCard(order, vehicleIcon, vehicleText)
            : _buildCollapsedCard(order),
      ),
    );
  }

  // Collapsed card - Teal blue floating card
  Widget _buildCollapsedCard(dynamic order) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary, // Teal blue
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ), // Rounded top corners only
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.keyboard_arrow_up,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // Expanded card - Modern design inspired by provided template (Compact version)
  Widget _buildExpandedCard(
      dynamic order, IconData vehicleIcon, String vehicleText) {
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';
    final double routeDistanceMeters = LocationService.calculateDistance(
      order.pickupLatitude,
      order.pickupLongitude,
      order.deliveryLatitude,
      order.deliveryLongitude,
    );
    final String formattedRouteDistance =
        LocationService.getFormattedDistance(routeDistanceMeters);
    
    final card = GestureDetector(
      onTap: () {
        // Close expanded address card if any when clicking on the card
        if (_expandedAddressCardId != null) {
          setState(() {
            _expandedAddressCardId = null;
            _showNavigationButtons = false;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary, // Teal blue background
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ), // Rounded top corners only (bottom sheet style)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle bar - Enhanced for easier collapse
          GestureDetector(
            onTap: () {
              setState(() {
                _isOrderCardExpanded = false;
              });
            },
            onVerticalDragEnd: (details) {
              // Collapse when dragged down (reduced threshold for easier use)
              if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 150) {
                setState(() {
                  _isOrderCardExpanded = false;
                });
              }
            },
              behavior: HitTestBehavior.opaque,
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                width: double.infinity,
              child: Column(
                children: [
                  Container(
                      width: 50,
                      height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                    const SizedBox(height: 3),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withOpacity(0.6),
                      size: 18,
                  ),
                ],
              ),
            ),
          ),
            
            // Ready countdown banner (if set by merchant)
            _buildReadyCountdownBanner(order),
            
            // Content area - all content visible, no scrolling
            _buildPaymentSummarySection(order),
            SizedBox(height: context.rs(4)),
            _buildAddressSection(order),
          Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 4),
              child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            SizedBox(height: context.rs(4)),
            _buildResponsiveActionButtons(order),
            
            // Action buttons at the bottom (always visible)
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
            child: Padding(
                padding: context.rp(horizontal: 16, vertical: 10),
                child: (order.status == 'pending' || order.status == 'assigned') &&
                        !isAccepted
                    ? _buildPendingOrderButtons(order)
                    : _buildMainActionButton(order),
              ),
            ),
          ],
                      ),
    ),
  );

    if (!isPending) {
      return card;
                    }

    return Column(
      mainAxisSize: MainAxisSize.min,
                      children: [
        _buildDistanceChip(formattedRouteDistance),
        card,
        ],
  );
}
  
  Widget _buildCompactInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: context.rp(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(context.rs(8)),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: context.ri(16)),
          SizedBox(width: context.rs(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ResponsiveText(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: context.rf(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: context.rs(2)),
                ResponsiveText(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: context.rf(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModernAddressRow(
      {required IconData icon,
      required Color iconColor,
      required String address,
      required dynamic order,
      required bool isPickup}) {
    return InkWell(
      onTap: () {
        // Navigate to pickup or dropoff when clicking on the address row
        _openInMaps(order, isPickup: isPickup);
      },
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProminentAddressCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String label,
    required String address,
    required dynamic order,
    required bool isPickup,
  }) {
    final cardId = '${order.id}_${isPickup ? 'pickup' : 'dropoff'}';
    final isExpanded = _expandedAddressCardId == cardId;
    final double contentHeight = context.rs(80);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openInMaps(order, isPickup: isPickup),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: context.rp(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(context.rs(12)),
              border: Border.all(
                color: isExpanded
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white.withOpacity(0.2),
                width: isExpanded ? 1.5 : 1,
              ),
            ),
            child: SizedBox(
              height: contentHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    key: ValueKey('${cardId}_address'),
                    duration: const Duration(milliseconds: 200),
                    opacity: isExpanded ? 0.0 : 1.0,
                    child: _buildAddressInfo(
                      icon: icon,
                      iconColor: iconColor,
                      label: label,
                      address: address,
                      height: contentHeight,
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !isExpanded,
                    child: AnimatedOpacity(
                      key: ValueKey('${cardId}_nav'),
                      duration: const Duration(milliseconds: 200),
                      opacity: isExpanded ? 1.0 : 0.0,
                      child: _buildNavigationButtonsInCard(contentHeight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAddressInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: context.rp(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(context.rs(10)),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: context.ri(28),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResponsiveText(
                  label,
                  style: TextStyle(
                    fontSize: context.rf(12),
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: context.rs(4)),
                ResponsiveText(
                  address,
                  style: TextStyle(
                    fontSize: context.rf(15),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.6),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtonsInCard(double height) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavigationButton(
            assetPath: 'assets/icons/googlemaps.png',
            fallbackColor: const Color(0xFF4285F4),
            icon: Icons.map,
            onTap: () {
              if (_targetLatitude != null && _targetLongitude != null) {
                _openGoogleMaps(_targetLatitude!, _targetLongitude!);
              }
            },
          ),
          SizedBox(width: context.rs(16)),
          _buildNavigationButton(
            assetPath: 'assets/icons/waze.png',
            fallbackColor: const Color(0xFF33CCFF),
            icon: Icons.navigation,
            onTap: () {
              if (_targetLatitude != null && _targetLongitude != null) {
                _openWaze(_targetLatitude!, _targetLongitude!);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required String assetPath,
    required Color fallbackColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.rs(56),
        height: context.rs(56),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(context.rs(14)),
          border: Border.all(
            color: Colors.white.withOpacity(0.28),
            width: 1,
          ),
        ),
        child: Center(
          child: Container(
            width: context.rs(36),
            height: context.rs(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.rs(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rs(10)),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: fallbackColor,
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: context.ri(18),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummarySection(dynamic order) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.isTablet ? 20.0 : 14.0,
        vertical: context.rs(6),
      ),
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: Colors.white.withOpacity(0.9),
                size: context.ri(18),
              ),
              SizedBox(width: context.rs(8)),
              ResponsiveText(
                'رقم الطلب: #${order.id.substring(0, 8)}',
                style: TextStyle(
                  fontSize: context.rf(14),
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rs(14)),
          Row(
        children: [
          Expanded(
                child: _buildFeeSummaryTile(
                  icon: Icons.local_shipping_rounded,
                  accentColor: Colors.orangeAccent,
              label: 'رسوم التوصيل',
                  amount:
                      '${order.deliveryFee.toStringAsFixed(0)} د.ع',
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
                child: _buildFeeSummaryTile(
                  icon: Icons.storefront_rounded,
                  accentColor: Colors.greenAccent,
                  label: 'قيمة الطلب',
                  amount:
                      '${order.totalAmount.toStringAsFixed(0)} د.ع',
                ),
            ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeSummaryTile({
    required IconData icon,
    required Color accentColor,
    required String label,
    required String amount,
  }) {
    return Container(
      padding: context.rp(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.9),
            accentColor.withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rs(16)),
        border: Border.all(
          color: accentColor.withOpacity(0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: context.rs(44),
            height: context.rs(44),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(context.rs(12)),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: context.ri(22),
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ResponsiveText(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: context.rf(12),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: context.rs(4)),
                ResponsiveText(
                  amount,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rf(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceChip(String distanceText) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.isTablet ? 24.0 : 16.0,
        vertical: context.rs(6),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(14),
          vertical: context.rs(10),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(context.rs(20)),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.route_outlined,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: context.rs(6)),
            Text(
              'المسافة: $distanceText',
              style: TextStyle(
                color: Colors.white,
                fontSize: context.rf(13),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Format ready countdown in Arabic format (س for hours, د for minutes, ث for seconds)
  // Format examples: "2س 15د" (2h 15m), "45د 30ث" (45m 30s), "30ث" (30s)
  String _formatReadyCountdownArabic(int seconds) {
    if (seconds <= 0) return 'الآن';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    final List<String> parts = [];
    
    if (hours > 0) {
      parts.add('${hours}س');
      if (minutes > 0) {
        parts.add('${minutes}د');
      }
      // Don't show seconds when hours are present
    } else if (minutes > 0) {
      parts.add('${minutes}د');
      if (secs > 0) {
        parts.add('${secs}ث');
      }
    } else if (secs > 0) {
      // Only seconds
      parts.add('${secs}ث');
    }
    
    return parts.isEmpty ? 'الآن' : parts.join(' ');
  }

  // Build ready countdown banner widget
  Widget _buildReadyCountdownBanner(dynamic order) {
    // Only show if order has ready_at time
    if (order.readyAt == null) {
      return const SizedBox.shrink();
    }
    
    // Get initial seconds until ready
    final initialSeconds = order.secondsUntilReady;
    
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(
        const Duration(seconds: 1),
        (i) {
          final readyAt = order.readyAt;
          if (readyAt == null) return 0;
          final now = DateTime.now();
          final difference = readyAt.difference(now);
          final seconds = difference.inSeconds;
          return seconds > 0 ? seconds : 0;
        },
      ).takeWhile((seconds) => seconds >= 0),
      initialData: initialSeconds,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? initialSeconds;
        final isReady = seconds <= 0;
        
        // Ready banner (green)
        if (isReady) {
          return Container(
            margin: EdgeInsets.symmetric(
              horizontal: context.isTablet ? 20.0 : 14.0,
              vertical: context.rs(8),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(16),
              vertical: context.rs(12),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade500,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(context.rs(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: context.ri(20),
                ),
                SizedBox(width: context.rs(8)),
                Text(
                  '✅ الطلب جاهز الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rf(15),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }
        
        // Countdown banner (orange)
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: context.isTablet ? 20.0 : 14.0,
            vertical: context.rs(8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(16),
            vertical: context.rs(12),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade600,
                Colors.orange.shade500,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(context.rs(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: Colors.white,
                size: context.ri(20),
              ),
              SizedBox(width: context.rs(8)),
              Text(
                '⏰ جاهز بعد ${_formatReadyCountdownArabic(seconds)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.rf(15),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressSection(dynamic order) {
    return GestureDetector(
      onTap: () {
        if (_expandedAddressCardId != null) {
          setState(() {
            _expandedAddressCardId = null;
            _showNavigationButtons = false;
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isTablet ? 22.0 : 14.0,
          vertical: context.rs(4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalGap = context.rs(12);

            Widget buildPickupCard() {
              return GestureDetector(
                onTap: () {},
                child: FutureBuilder<String?>(
                  future: _getGeocodedAddress(
                    order.id,
                    order.pickupLatitude,
                    order.pickupLongitude,
                    true,
                  ),
                  builder: (context, snapshot) {
                    final pickupAddress =
                        (snapshot.hasData && snapshot.data != null)
                            ? snapshot.data!
                            : order.pickupAddress;
                    return _buildProminentAddressCard(
                      icon: Icons.store_mall_directory_rounded,
                      iconColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      label: 'التاجر',
                      address: pickupAddress,
                      order: order,
                      isPickup: true,
                    );
                  },
                ),
              );
            }

            Widget buildDropoffCard() {
              return GestureDetector(
                onTap: () {},
                child: FutureBuilder<String?>(
                  future: _getGeocodedAddress(
                    order.id,
                    order.deliveryLatitude,
                    order.deliveryLongitude,
                    false,
                  ),
                  builder: (context, snapshot) {
                    final dropoffAddress =
                        (snapshot.hasData && snapshot.data != null)
                            ? snapshot.data!
                            : order.deliveryAddress;
                    return _buildProminentAddressCard(
                      icon: Icons.location_on_rounded,
                      iconColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      label: 'العميل',
                      address: dropoffAddress,
                      order: order,
                      isPickup: false,
                    );
                  },
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildPickupCard()),
                SizedBox(width: horizontalGap),
                Expanded(child: buildDropoffCard()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderStatChip({
    required String label,
    required String value,
    Color? backgroundColor,
    Color? borderColor,
    Color? labelColor,
    Color? valueColor,
    IconData? icon,
    Color? iconColor,
  }) {
    final bg = backgroundColor ?? Colors.white.withOpacity(0.18);
    final border = borderColor ?? Colors.white.withOpacity(0.22);
    final labelTextColor = labelColor ?? Colors.white70;
    final valueTextColor = valueColor ?? Colors.white;

    return Container(
      padding: context.rp(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: context.ri(18),
              color: iconColor ?? valueTextColor,
            ),
            SizedBox(width: context.rs(8)),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveText(
                label,
                style: TextStyle(
                  color: labelTextColor,
                  fontSize: context.rf(11), // Increased from 10
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: context.rs(2)),
              ResponsiveText(
                value,
                style: TextStyle(
                  color: valueTextColor,
                  fontSize: context.rf(16), // Increased from 13
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color, // Solid color for contrast
            radius: context.rs(26),
            child: Icon(icon, color: Colors.white, size: context.ri(28)),
          ),
          SizedBox(height: context.rs(6)),
          ResponsiveText(
            label,
            style: TextStyle(
              fontSize: context.rf(13),
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Responsive layout for action buttons: wraps to next line on small widths
  Widget _buildResponsiveActionButtons(dynamic order) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: context.rs(10),
        runSpacing: context.rs(8),
        children: [
          _buildModernActionButton(
            icon: Icons.business,
            label: 'التاجر',
            color: Colors.orangeAccent,
            onTap: () => _callMerchant(order.merchantId),
          ),
          _buildModernActionButton(
            icon: Icons.person,
            label: 'العميل',
            color: Colors.teal,
            onTap: () => _callCustomer(order.customerPhone, order.customerName),
          ),
          _buildModernActionButton(
            icon: Icons.navigation_rounded,
            label: 'الموقع',
            color: Colors.blueAccent,
            onTap: () => _openInMaps(order),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrderButtons(dynamic order) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: _buildAcceptButtonWithLongPress(order),
              ),
              SizedBox(height: context.rs(8)),
              SizedBox(
                width: double.infinity,
                child: _buildRejectButton(order),
              ),
            ],
          );
        }

    return Row(
      children: [
        // Accept button - 80% width with long press
        Expanded(
          flex: 80,
          child: _buildAcceptButtonWithLongPress(order),
        ),
        SizedBox(width: context.rs(8)),
        // Reject button - 20% width
        Expanded(
          flex: 20,
          child: _buildRejectButton(order),
        ),
      ],
        );
      },
    );
  }

  Widget _buildAcceptButtonWithLongPress(dynamic order) {
    return _AcceptButtonWithLongPress(
      orderId: order.id,
      onAccept: () => _acceptOrder(order.id),
    );
  }

  Widget _buildRejectButton(dynamic order) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.red.shade600, // Solid red background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton(
        onPressed: () => _rejectOrder(order.id),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: const Text(
          'رفض',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton(dynamic order) {
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';
    
    String buttonText;
    VoidCallback? onPressed;
    List<Color> gradientColors;
    Color shadowColor;
    
    if (isAccepted) {
      buttonText = 'تم استلام الطلب';
      onPressed = () => _markOrderOnTheWay(order.id);
      gradientColors = [Colors.orangeAccent, Colors.deepOrange];
      shadowColor = Colors.orangeAccent;
    } else if (isOnTheWay) {
      buttonText = 'تم التوصيل';
      onPressed = () => _ensureOrderProofThenDeliver(order);
      gradientColors = [Colors.green, Colors.teal];
      shadowColor = Colors.green;
    } else {
      buttonText = 'اكتمل الطلب';
      onPressed = null;
      gradientColors = [Colors.grey, Colors.grey];
      shadowColor = Colors.grey;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          buttonText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _ensureOrderProofThenDeliver(dynamic order) async {
    final orderProvider = context.read<OrderProvider>();
    
    print('🔍 Checking if order ${order.id} has proof...');
    final hasProof = await orderProvider.hasOrderProof(order.id);
    print('📸 Order ${order.id} proof status: $hasProof');
    
    if (hasProof) {
      print('✅ Proof exists, proceeding to mark as delivered...');
      // INSTANT CLEAR: Clear annotations immediately before marking as delivered
      print('🧹 INSTANT CLEAR: Clearing annotations before delivery (proof exists)');
      StateOfTheArtNavigation().clearAll().catchError((e) {
        print('⚠️ Error in instant clear: $e');
      });
      StateOfTheArtNavigation().clearOrder(order.id).catchError((e) {
        print('⚠️ Error clearing specific order: $e');
      });
      
      // Proof exists, proceed with delivery confirmation
      await _markOrderDelivered(order.id);
      return;
    }

    print('⚠️ No proof found, showing upload dialog...');
    if (!mounted) return;
    
    // No proof exists, show upload dialog
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      isDismissible: false, // Prevent dismissal without completing action
      enableDrag: false, // Prevent accidental dismissal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return PopScope(
          canPop: false, // Prevent back button dismissal
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: _OrderProofUploader(
              orderId: order.id,
              onUploaded: () async {
                print('📸 ========================================');
                print('📸 ORDER PROOF UPLOADED CALLBACK TRIGGERED');
                print('📸 Order ID: ${order.id}');
                print('📸 Time: ${DateTime.now()}');
                print('📸 ========================================');
                
                try {
                  // INSTANT CLEAR: Clear annotations immediately when proof is uploaded
                  print('🧹 INSTANT CLEAR: Clearing annotations (proof uploaded)');
                  StateOfTheArtNavigation().clearAll().catchError((e) {
                    print('⚠️ Error in instant clear: $e');
                  });
                  StateOfTheArtNavigation().clearOrder(order.id).catchError((e) {
                    print('⚠️ Error clearing specific order: $e');
                  });
                  
                  // CRITICAL: Mark as delivered FIRST, then close the bottom sheet
                  // Skip confirmation dialog since uploading proof is the confirmation
                  print('🚚 Marking order as delivered with skip confirmation...');
                  await _markOrderDelivered(order.id, skipConfirmation: true);
                  print('✅ Order marked as delivered successfully');
                  
                  // Close the bottom sheet
                  print('🚪 Closing bottom sheet...');
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  print('✅ Bottom sheet closed');
                } catch (e) {
                  print('❌ Error in onUploaded callback: $e');
                  // Still close the bottom sheet even if there's an error
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  // Show error notification
                  if (mounted) {
                    showHeaderNotification(
                      context,
                      title: 'خطأ',
                      message: 'تم رفع الصورة لكن فشل تحديث حالة الطلب. حاول الضغط على زر التسليم مرة أخرى.',
                      type: NotificationType.error,
                      duration: const Duration(seconds: 5),
                    );
                  }
                }
              },
              onCancel: () {
                // Allow cancellation - close the bottom sheet
                if (Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressRow(
      {required IconData icon,
      required String label,
      required String address,
      bool isPickup = false,
      required dynamic order}) {
    // Match pin colors: Teal for pickup, Orange for dropoff
    final addressColor = isPickup ? AppColors.primary : AppColors.warning;
    
    return InkWell(
      onTap: () {
        // Navigate to pickup or dropoff when clicking anywhere on the address row
        _openInMaps(order, isPickup: isPickup);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: addressColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: addressColor.withOpacity(0.2), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: addressColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: addressColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Quick navigation button indicator
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: addressColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.navigation,
                          color: addressColor,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailRow(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactOrderDetailRow(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 16,
        ),
        SizedBox(width: context.rs(8)),
        Text(
          '$label: ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeoutCountdownPill(dynamic order) {
    return _TimeoutCountdownPill(order: order);
  }

  Widget _buildCountdownTimer(String orderId) {
    // Get timeout from OrderProvider (from order_timeout_state table)
    final orderProvider = context.watch<OrderProvider>();
    final remainingSeconds = orderProvider.getTimeoutRemaining(orderId) ?? 0;
    
    final progress = remainingSeconds / 30.0;
    final Color timerColor = remainingSeconds <= 10 
        ? Colors.red.shade300 
        : remainingSeconds <= 20 
            ? Colors.orange.shade300 
            : Colors.white;
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          // Countdown text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$remainingSeconds',
                style: TextStyle(
                  color: timerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.0,
                ),
              ),
              Text(
                'ثا',
                style: TextStyle(
                  color: timerColor.withOpacity(0.8),
                  fontSize: 9,
                  height: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReadyCountdown(int seconds) {
    if (seconds <= 0) return 'الآن';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}س ${minutes}د';
    } else if (minutes > 0) {
      return '${minutes}د ${secs}ث';
    } else {
      return '${secs}ث';
    }
  }

  String _formatReadyCountdownWestern(int seconds) {
    if (seconds <= 0) return '00:00';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildActionButtons(dynamic order) {
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';

    if (isPending || isAssigned) {
      // Show Accept/Reject buttons for pending/assigned orders
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _acceptOrder(order.id),
              icon: const Icon(Icons.check, size: 18),
              label: Text(AppLocalizations.of(context).acceptOrder),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectOrder(order.id),
              icon: const Icon(Icons.close, size: 18),
              label: Text(AppLocalizations.of(context).rejectOrder),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Show action buttons for other statuses
      return Column(
        children: [
          // Primary action button
          if (isAccepted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderOnTheWay(order.id),
                icon: const Icon(Icons.directions_car, size: 18),
                label: Text(AppLocalizations.of(context).startDelivery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ] else if (isOnTheWay) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderDelivered(order.id),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(AppLocalizations.of(context).markDelivered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Secondary action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callMerchant(order.merchantId),
                  icon: const Icon(Icons.business, size: 16),
                  label: Text(AppLocalizations.of(context).merchantButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _callCustomer(order.customerPhone, order.customerName),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(AppLocalizations.of(context).customerButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(order),
                  icon: const Icon(Icons.map, size: 16),
                  label: Text(AppLocalizations.of(context).mapButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildCompactActionButtons(dynamic order) {
    final isPending = order.status == 'pending';
    final isAssigned = order.status == 'assigned';
    final isAccepted = order.status == 'accepted';
    final isOnTheWay = order.status == 'on_the_way';

    if (isPending || isAssigned) {
      // Bigger Accept/Reject buttons
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () => _acceptOrder(order.id),
              icon: const Icon(Icons.check_circle, size: 22),
              label: const Text('قبول الطلب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                shadowColor: AppColors.success.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () => _rejectOrder(order.id),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('رفض',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                backgroundColor: AppColors.error.withOpacity(0.05),
              ),
            ),
          ),
        ],
      );
    } else {
      // Compact action buttons for accepted/on_the_way orders
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Action Buttons
          Row(
            children: [
              // Call Merchant
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callMerchant(order.merchantId),
                  icon: const Icon(Icons.business, size: 18),
                  label: const Text('التاجر',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    backgroundColor: AppColors.primary.withOpacity(0.05),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              // Call Customer
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _callCustomer(order.customerPhone, order.customerName),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('العميل',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: BorderSide(color: AppColors.success, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    backgroundColor: AppColors.success.withOpacity(0.05),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              // Open in Maps
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(order),
                  icon: const Icon(Icons.map, size: 18),
                  label: Text(AppLocalizations.of(context).mapButton,
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    backgroundColor: AppColors.warning.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
          // Primary Action Button
          if (isAccepted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderOnTheWay(order.id),
                icon: const Icon(Icons.local_shipping, size: 20),
                label: Text(AppLocalizations.of(context).pickedUpStartDelivery,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
            ),
          ] else if (isOnTheWay) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markOrderDelivered(order.id),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('تم التسليم',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  shadowColor: AppColors.success.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ],
      );
    }
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'assigned':
        return Icons.assignment;
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.directions_car;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'unassigned':
        return Icons.assignment_late;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  String _getOrderStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'assigned':
        return 'تم التخصيص';
      case 'accepted':
        return 'تم القبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      case 'unassigned':
        return 'غير مخصص';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير معروف';
    }
  }

  Future<void> _markOrderOnTheWay(String orderId) async {
    try {
      await context.read<OrderProvider>().markOrderOnTheWay(orderId);
      
      // Clear cached orders to force immediate refresh
      if (mounted) {
        // legacy order card manager removed
        setState(() {
          _cachedActiveOrders = null;
        });
        
        showHeaderNotification(
          context,
          title: 'في الطريق',
          message: 'تم بدء التوصيل للعميل',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'حدث خطأ في العملية',
          type: NotificationType.error,
        );
      }
    }
  }
  
  Future<void> _markOrderDelivered(String orderId, {bool skipConfirmation = false}) async {
    // Show confirmation dialog (unless skipped - e.g., when proof was already uploaded)
    bool confirmed = skipConfirmation;
    
    if (!skipConfirmation) {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).confirmDelivery),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'هل قمت بتسليم الطلب للعميل؟',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    SizedBox(width: context.rs(8)),
                    Expanded(
                      child: Text(
                        'تأكد من استلام العميل للطلب قبل التأكيد',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return TextButton(
              onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    loc.cancel,
                    style: const TextStyle(fontSize: 16),
              ),
                );
              },
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'تم التسليم',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
      ) ?? false;
    }

    // Only proceed if confirmed
    if (!confirmed) {
      print('❌ Delivery not confirmed by user');
      return;
    }
    
    print('✅ Delivery confirmed (skipConfirmation: $skipConfirmation)');

    // INSTANT CLEAR: Clear annotations IMMEDIATELY when user confirms
    // Fire-and-forget async clear - don't wait for it
    print('🧹 INSTANT CLEAR: Clearing annotations immediately (fire-and-forget)');
    StateOfTheArtNavigation().clearAll().catchError((e) {
      print('⚠️ Error in instant clear: $e');
    });
    _mapWidgetKey?.currentState?.forceClearAnnotations();
    
    // Also clear specific order annotations immediately
    try {
      final nav = StateOfTheArtNavigation();
      // Clear this specific order's markers and route
      nav.clearOrder(orderId).catchError((e) {
        print('⚠️ Error clearing specific order: $e');
      });
    } catch (e) {
      print('⚠️ Error in order-specific clear: $e');
    }

    try {
      print('🚚 ===========================================');
      print('🚚 MARKING ORDER AS DELIVERED');
      print('🚚 Order ID: $orderId');
      print('🚚 Time: ${DateTime.now()}');
      print('🚚 ===========================================');
      
      // STEP 1: Clear map annotations AGAIN (async) to ensure everything is cleared
      print('🧹 STEP 1: ASYNC CLEARING ROUTES AND MARKERS');
      try {
        await StateOfTheArtNavigation().clearAll();
        if (_mapWidgetKey?.currentState != null) {
          await _mapWidgetKey!.currentState!.forceClearAnnotations();
        }
      } catch (_) {}
      
      // STEP 2: Mark order as delivered
      final success = await context.read<OrderProvider>().markOrderDelivered(orderId);
      
      if (!success) {
        // If delivery marking failed, show error and don't continue cleanup
        print('❌ Failed to mark order as delivered');
        
        // Get the specific error message from OrderProvider
        final errorMessage = context.read<OrderProvider>().error;
        print('🔍 Specific error from provider: $errorMessage');
        
        if (mounted) {
          // Show detailed error dialog for debugging
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).deliveryError),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'فشل تحديث حالة الطلب:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SelectableText(
                      errorMessage ?? 'خطأ غير معروف',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                          size: 16, 
                          color: Colors.amber.shade700
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يرجى أخذ لقطة شاشة وإرسالها للدعم الفني',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context).ok),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // STEP 3: Clear annotations again immediately after to catch any stragglers
      print('🧹 STEP 3: POST-DELIVERY CLEARING');
      try {
        // Clear all annotations
        await StateOfTheArtNavigation().clearAll();
        // Also clear this specific order
        await StateOfTheArtNavigation().clearOrder(orderId);
      } catch (e) {
        print('⚠️ Error in post-delivery clear: $e');
      }
      
      // STEP 4: Force immediate removal from local state
      print('🧹 STEP 4: REMOVING ORDER FROM LOCAL STATE');
      if (mounted) {
        final orderProvider = context.read<OrderProvider>();
        // The subscription will handle the removal, but we force a manual removal for immediate effect
        // This prevents any visual lag while waiting for the subscription to update
        orderProvider.removeOrderFromLocalState(orderId);
      }
      
      // STEP 5: Clear cached orders and force map refresh
      print('🧹 STEP 5: CLEARING CACHED ORDERS AND REFRESHING MAP');
      if (mounted) {
        setState(() {
          _cachedActiveOrders = null;
          // Force map to rebuild and clear all annotations
        });
      
        // Force map widget refresh immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
            try {
              StateOfTheArtNavigation().clearAll();
              // Note: StateOfTheArtNavigation().clearAll() already handles all route/marker clearing
            } catch (e) {
              print('⚠️ Error in post-frame clear: $e');
            }
          }
        });
      }
        
      showHeaderNotification(
        context,
        title: 'تم التسليم',
        message: 'تم تسليم الطلب بنجاح',
        type: NotificationType.success,
      );
      
      print('✅ Order delivery process complete - route cleared');
    } catch (e) {
      print('❌ Error marking order as delivered: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'حدث خطأ في العملية',
          type: NotificationType.error,
        );
      }
    }
  }

  void _callMerchant(String merchantId) async {
    // Fetch merchant details from users table
    try {
      print('📞 Fetching merchant details for: $merchantId');
      
      final merchantResponse = await Supabase.instance.client
          .from('users')
          .select('id, phone, name, store_name')
          .eq('id', merchantId)
          .maybeSingle();
      
      if (merchantResponse == null) {
        print(
            '⚠️ Merchant not found in database (merchant may have been deleted)');
        if (mounted) {
    showHeaderNotification(
      context,
      title: 'تنبيه',
      message: 'معلومات التاجر غير متوفرة',
      type: NotificationType.warning,
    );
        }
        return;
      }
      
      final merchantName = merchantResponse['store_name'] ??
          merchantResponse['name'] ??
          'التاجر';
      final merchantPhone = merchantResponse['phone'] as String;
      
      print('✅ Merchant found: $merchantName - $merchantPhone');
      
      if (mounted) {
        _showContactDialog(
          context: context,
          name: merchantName,
          phone: merchantPhone,
          title: 'الاتصال بالتاجر',
          icon: Icons.store,
          color: AppColors.primary,
        );
      }
    } catch (e) {
      print('❌ Error fetching merchant: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'فشل جلب بيانات التاجر',
          type: NotificationType.error,
        );
      }
    }
  }

  void _callCustomer(String customerPhone, String customerName) {
    _showContactDialog(
      context: context,
      name: customerName,
      phone: customerPhone,
      title: 'الاتصال بالعميل',
      icon: Icons.person,
      color: AppColors.success,
    );
  }

  void _callPhone(String phone, String name) {
    _showContactDialog(
      context: context,
      name: name,
      phone: phone,
      title: 'الاتصال',
      icon: Icons.phone,
      color: AppColors.primary,
    );
  }

  void _showContactDialog({
    required BuildContext context,
    required String name,
    required String phone,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  color.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color,
                  ),
                ),          
          const SizedBox(height: 12),
                
                // Title
                Text(
                  title,
                  style: AppTextStyles.heading3.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Name
                Text(
                  name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                
                // Phone number
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone,
                        size: 18,
                        color: color,
                      ),
                      SizedBox(width: context.rs(8)),
                      Text(
                        phone,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Column(
                  children: [
                    // Call on Cellular
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: phone != 'غير متوفر'
                            ? () {
                          Navigator.of(dialogContext).pop();
                          _makePhoneCall(phone);
                              }
                            : null,
                        icon: const Icon(Icons.phone, size: 20),
                        label: Text(AppLocalizations.of(context).callViaPhone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Call on WhatsApp
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: phone != 'غير متوفر'
                            ? () {
                          Navigator.of(dialogContext).pop();
                          _callOnWhatsApp(phone);
                              }
                            : null,
                        icon: const Icon(Icons.call, size: 20),
                        label: Text(AppLocalizations.of(context).callViaWhatsapp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF25D366), // WhatsApp green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Message on WhatsApp
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: phone != 'غير متوفر'
                            ? () {
                          Navigator.of(dialogContext).pop();
                          _messageOnWhatsApp(phone, name);
                              }
                            : null,
                        icon: const Icon(Icons.chat, size: 20),
                        label: Text(AppLocalizations.of(context).whatsappMessage),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(
                              color: Color(0xFF25D366), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledForegroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    
                    // Show helpful message if phone not available
                    if (phone == 'غير متوفر') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.warning, size: 20),
                            SizedBox(width: context.rs(8)),
                            Expanded(
                              child: Text(
                                'معلومات التاجر غير متوفرة في النظام',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),          
          const SizedBox(height: 12),
                
                // Cancel button
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                        loc.cancel,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
    showHeaderNotification(
      context,
      title: 'خطأ',
      message: 'لا يمكن إجراء المكالمة',
      type: NotificationType.error,
    );
      }
    }
  }

  Future<void> _callOnWhatsApp(String phone) async {
    // Remove any non-digit characters and ensure it starts with country code
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+964$cleanPhone'; // Add Iraq country code if missing
    }
    
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'لا يمكن فتح واتساب',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _messageOnWhatsApp(String phone, String name) async {
    // Remove any non-digit characters and ensure it starts with country code
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+964$cleanPhone'; // Add Iraq country code if missing
    }
    
    final loc = AppLocalizations.of(context);
    final message = loc.driverWhatsappMessage(name);
    final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'لا يمكن فتح واتساب',
          type: NotificationType.error,
        );
      }
    }
  }

  void _openInMaps(dynamic order, {bool? isPickup}) async {
    // Determine location based on isPickup parameter or order status
    double latitude;
    double longitude;
    String cardId;
    
    if (isPickup != null) {
      // Explicitly specified
      if (isPickup) {
        latitude = order.pickupLatitude;
        longitude = order.pickupLongitude;
        cardId = '${order.id}_pickup';
      } else {
        latitude = order.deliveryLatitude;
        longitude = order.deliveryLongitude;
        cardId = '${order.id}_dropoff';
      }
    } else if (order.status == 'pending' ||
        order.status == 'assigned' ||
        order.status == 'accepted') {
      // Go to pickup location (store)
      latitude = order.pickupLatitude;
      longitude = order.pickupLongitude;
      cardId = '${order.id}_pickup';
    } else {
      // Go to delivery location (customer)
      latitude = order.deliveryLatitude;
      longitude = order.deliveryLongitude;
      cardId = '${order.id}_dropoff';
    }
    
    // Refocus map on the location
    if (_mapWidgetKey?.currentState != null) {
      _mapWidgetKey!.currentState!.refocusCamera(latitude, longitude);
    }
    
    // Toggle navigation buttons inside the address card
    setState(() {
      if (_expandedAddressCardId == cardId) {
        // Close if already expanded
        _expandedAddressCardId = null;
        _showNavigationButtons = false;
      } else {
        // Expand the clicked card
        _expandedAddressCardId = cardId;
        _showNavigationButtons = true;
        _targetLatitude = latitude;
        _targetLongitude = longitude;
      }
    });
  }

  void _openGoogleMaps(double latitude, double longitude) async {
    try {
      // Validate coordinates
      if (latitude.isNaN ||
          longitude.isNaN ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        throw Exception('إحداثيات غير صالحة');
      }
      
      print('📍 Opening Google Maps with: $latitude, $longitude');
      
      // Try multiple Google Maps URLs in order of preference
      final urls = [
        // Native Android Google Maps app with navigation
        'google.navigation:q=$latitude,$longitude&mode=d',
        // Alternative native app URL
        'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
        // Universal URL that opens in app if installed, otherwise browser
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
      ];
      
      bool opened = false;
      for (final url in urls) {
        try {
          final uri = Uri.parse(url);
          print('   Trying: $url');
          
          // For custom schemes (google.navigation, comgooglemaps), try to launch directly
          if (url.startsWith('google.navigation:') ||
              url.startsWith('comgooglemaps://')) {
            try {
              final launched =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (launched) {
                print('   ✅ Opened successfully with: $url');
                opened = true;
                break;
              }
            } catch (e) {
              print('   ❌ Failed: $e');
              continue; // Try next URL
            }
          } else {
            // For https URLs, check first then launch
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('   ✅ Opened successfully with: $url');
              opened = true;
              break;
            }
          }
        } catch (e) {
          print('   ❌ Failed: $e');
          continue; // Try next URL
        }
      }
      
      if (!opened && mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'لا يمكن فتح خرائط جوجل',
          type: NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Google Maps error: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'فشل فتح خرائط جوجل',
          type: NotificationType.error,
        );
      }
    }
  }

  void _openWaze(double latitude, double longitude) async {
    try {
      // Validate coordinates
      if (latitude.isNaN ||
          longitude.isNaN ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        throw Exception('إحداثيات غير صالحة');
      }
      
      print('🗺️ Opening Waze with: $latitude, $longitude');
      
      // Try multiple Waze URLs in order of preference
      final urls = [
        // Waze app URL with navigation
        'waze://?ll=$latitude,$longitude&navigate=yes',
        // Alternative Waze format
        'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
        // Web fallback with direct coordinates
        'https://www.waze.com/ul?ll=$latitude,$longitude&navigate=yes&zoom=17',
      ];
      
      bool opened = false;
      for (final url in urls) {
        try {
          final uri = Uri.parse(url);
          print('   Trying: $url');
          
          // For waze:// scheme, try to launch directly
          if (url.startsWith('waze://')) {
            try {
              final launched =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (launched) {
                print('   ✅ Opened successfully with: $url');
                opened = true;
                break;
              }
            } catch (e) {
              print('   ❌ Failed: $e');
              continue; // Try next URL
            }
          } else {
            // For https URLs, check first then launch
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('   ✅ Opened successfully with: $url');
              opened = true;
              break;
            }
          }
        } catch (e) {
          print('   ❌ Failed: $e');
          continue; // Try next URL
        }
      }
      
      if (!opened && mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'لا يمكن فتح تطبيق ويز',
          type: NotificationType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Waze error: $e');
      if (mounted) {
        showHeaderNotification(
          context,
          title: 'خطأ',
          message: 'فشل فتح تطبيق ويز',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _driverLocationTimer?.cancel();
    _statusCheckTimer?.cancel();
    _onlineStatusChannel?.unsubscribe();
    context.read<AnnouncementProvider>().stopChecking();
    _orderCardsPageController?.dispose();
    context.read<LocationProvider>().stopLocationTracking();
    _geocodedAddresses.clear(); // Clear geocoding cache
    
    // Cleanup enhanced route manager
    // legacy route manager removed
    
    // Cleanup order card manager
    // legacy order card manager removed
    
    // Note: Don't stop persistent service on dispose - it should keep running in background
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('🔄 App lifecycle changed to $state');
    
    // When app is detached (swiped away from recent apps), set driver offline
    // Note: We don't trigger on 'paused' as that happens when switching apps temporarily
    if (state == AppLifecycleState.detached) {
      print('   Setting driver offline');
      _setDriverOfflineOnAppClose();
    } 
    // When app is resumed, ensure UI is stable - don't clear cache
    else if (state == AppLifecycleState.resumed) {
      print('   App resumed - maintaining cached orders for stability');
      // Don't clear _cachedActiveOrders - this prevents flickering
      // The Consumer will update with fresh data naturally
    }
  }

  Future<void> _setDriverOfflineOnAppClose() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null && _isOnline) {
        await authProvider.setOnlineStatus(false);
        print('✅ Driver set to offline due to app close');
      }
    } catch (e) {
      print('❌ Error setting driver offline: $e');
    }
  }

  Future<void> _checkLocationAlwaysPermission() async {
    final status = await Permission.locationAlways.status;
    setState(() {
      _hasLocationAlwaysPermission = status.isGranted;
    });
    print(
        '📍 Location Always Permission: ${status.isGranted ? "✅ Granted" : "❌ Not Granted"}');
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dismissing with back button
        child: AlertDialog(
          title: const Text(
            'إذن الموقع مطلوب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 64,
                color: AppColors.primary,
              ),          
          const SizedBox(height: 12),
              Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Text(
                loc.locationPermissionDriverLong,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              );
            },
              ),
              const SizedBox(height: 12),
              const Text(
                'هذا يسمح لك بـ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.locationPermissionExplanation,
                textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14),
                  );
                },
              ),          
          const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Text(
                      loc.pleaseAllowAlways,
                  textAlign: TextAlign.center,
                      style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Request permission
                final status = await Permission.locationAlways.request();
                
                if (!status.isGranted) {
                  // Open app settings
                  await openAppSettings();
                }
                
                // Re-check permission after a delay
                await Future.delayed(const Duration(seconds: 1));
                await _checkLocationAlwaysPermission();
                
                // If still not granted, show dialog again
                if (!_hasLocationAlwaysPermission) {
                  _showLocationPermissionDialog();
                } else {
                  // Permission granted, initialize dashboard using shared method
                  print(
                      '✅ Permission granted! Starting full initialization...');
                  await _initializeDashboardWithPermission();
                  
                  // Map will update automatically through coordinate change detection
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: ui.Size(double.infinity, 48),
              ),
              child: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.openSettings,
                    style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showBackgroundLocationDisclosureAndRequest() async {
    bool accepted = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).backgroundLocationPermissionTitle,
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.location_on, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).backgroundLocationExplanation,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return TextButton(
            onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel),
              );
            },
          ),
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return ElevatedButton(
            onPressed: () {
              accepted = true;
              Navigator.pop(context);
            },
                child: Text(loc.agree),
              );
            },
          ),
        ],
      ),
    );
    if (!accepted) return false;
    // Request background location and notification permissions
    final locAlways = await Permission.locationAlways.request();
    if (!locAlways.isGranted) {
      _showLocationPermissionDialog();
      return false;
    }
    final notif = await Permission.notification.request();
    return notif.isGranted;
  }

  // Countdown is now handled by order_timeout_state table
  // No local timer needed - just display the value from database

  void _startLocationTracking() {
    // Cancel existing timers if any
    _locationTimer?.cancel();
    _driverLocationTimer?.cancel();
    
    // Start continuous location tracking
    context.read<LocationProvider>().startLocationTracking();
    
    // Update location every 3 seconds - ONLY when driver is online
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Only update if driver is online
      if (_isOnline && mounted) {
        _updateDriverLocation();
      }
    });
    
    print('✅ Location tracking timers started (will only update when online)');
  }

  void _startDriverLocationTracking() {
    // Update driver location every 3 seconds from database - ONLY when driver is online
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Only update if driver is online
      if (_isOnline && mounted) {
        _updateDriverLocationFromDatabase();
      }
    });
    
    print(
        '✅ Driver location tracking timer started (will only update when online)');
  }

  void _stopLocationTracking() {
    // Stop background database update timers
    _locationTimer?.cancel();
    _locationTimer = null;
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;
    
    // IMPORTANT: DO NOT stop LocationProvider tracking
    // Keep LocationProvider running for foreground map display even when offline
    // This allows the driver to see their location on the map while app is open
    // Only background database updates are stopped
    
    print('✅ Location tracking timers stopped (foreground location still active for map display)');
  }

  Future<void> _updateDriverLocation() async {
    // Only update if driver is online
    if (!_isOnline) {
      print('ℹ️ Skipping location update - driver is offline');
      return;
    }
    
    try {
      print('🔄 _updateDriverLocation called...');
      final locationProvider = context.read<LocationProvider>();
      final authProvider = context.read<AuthProvider>();
      
      // Get current location
      print('   📍 Getting current location from GPS...');
      final position = await locationProvider.getCurrentLocation();
      
      if (position != null && authProvider.user != null && _isOnline) {
        print(
            '   ✅ GPS position obtained: ${position.latitude}, ${position.longitude}');
        
        // Update location in database (with full GPS data)
        print('   💾 Saving to database...');
        final updateResult = await authProvider.updateUserLocation(
          position.latitude,
          position.longitude,
          accuracy: position.accuracy,
          heading: position.heading,
          speed: position.speed,
        );
        
        if (updateResult) {
          print(
              '   ✅ Driver location updated in DB: ${position.latitude}, ${position.longitude}');
        } else {
          print('   ❌ Failed to update driver location in DB');
          print('   ❌ AuthProvider error: ${authProvider.error}');
        }
        print(
            '   📡 LocationProvider currentPosition: ${locationProvider.currentPosition}');
      } else {
        print(
            '   ❌ Cannot update: position=$position, user=${authProvider.user != null}');
      }
    } catch (e) {
      print('❌ Error updating driver location: $e');
      print('   Stack: ${StackTrace.current}');
    }
  }

  Future<void> _updateDriverLocationFromDatabase() async {
    try {
      print('🔄 _updateDriverLocationFromDatabase called...');
      final authProvider = context.read<AuthProvider>();
      final locationProvider = context.read<LocationProvider>();
      
      if (authProvider.user != null) {
        print('   📥 Fetching user data from database...');
        // Fetch latest user data from database
        await authProvider.refreshUser();
        
        // Update location provider with database location
        if (authProvider.user?.latitude != null &&
            authProvider.user?.longitude != null) {
          print(
              '   ✅ Got DB location: ${authProvider.user!.latitude}, ${authProvider.user!.longitude}');
          
          // Create a mock Position object from database coordinates
          final dbPosition = _createMockPosition(
            authProvider.user!.latitude!,
            authProvider.user!.longitude!,
          );
          
          // Update location provider's current position
          locationProvider.updateCurrentPosition(dbPosition);
          
          print('   ✅ LocationProvider updated with DB location');
          print(
              '   📡 LocationProvider currentPosition: ${locationProvider.currentPosition}');
        } else {
          print(
              '   ⚠️ No location in database: lat=${authProvider.user?.latitude}, lng=${authProvider.user?.longitude}');
        }
      } else {
        print('   ❌ No user logged in');
      }
    } catch (e) {
      print('❌ Error updating driver location from database: $e');
      print('   Stack: ${StackTrace.current}');
    }
  }

  // Helper method to create mock Position from database coordinates
  dynamic _createMockPosition(double latitude, double longitude) {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Check auth state - redirect if not authenticated
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return WillPopScope(
      onWillPop: () async {
        // If sidebar is open, close it instead of exiting
        if (_showSidebar) {
          setState(() {
            _showSidebar = false;
          });
          return false;
        }
        // Otherwise, allow normal back behavior
        return true;
      },
      child: Scaffold(
      backgroundColor: AppColors.primary, // Hur teal background
      body: Stack(
        children: [
          // HIGHEST Z-INDEX: Simple location update notification system
          if (authProvider.user?.id != null)
            SimpleLocationUpdateWidget(
              driverId: authProvider.user!.id!,
              onLocationUpdate: (orderId, lat, lng) {
                  print(
                      '📍 Driver received location update for order $orderId: $lat, $lng');
                _handleLocationUpdate();
              },
            ),
          
          // Full Map Screen with Mapbox
          Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // Show map ONLY if permission is granted
                if (!_hasLocationAlwaysPermission)
                  // Show loading while waiting for permission
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),          
          const SizedBox(height: 12),
                        Text(
                          'في انتظار إذن الموقع...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                // Interactive Map with Order Details
                else if (kIsWeb)
                  _WebMapWidget()
                else
                  Consumer3<LocationProvider, AuthProvider, OrderProvider>(
                      builder: (context, locationProvider, authProvider,
                          orderProvider, child) {
                      // Debug: Log whenever Consumer rebuilds
                      print('🔄 Map Consumer rebuilt');
                        print(
                            '   Location: ${locationProvider.currentPosition}');
                      print('   User: ${authProvider.user?.id}');
                      
                      // Get driver's current location
                      double centerLat = 33.3152; // Baghdad default
                      double centerLng = 44.3661;
                      
                      if (locationProvider.currentPosition != null) {
                          centerLat =
                              locationProvider.currentPosition!.latitude;
                          centerLng =
                              locationProvider.currentPosition!.longitude;
                          print(
                              '   Using current position: $centerLat, $centerLng');
                        } else if (authProvider.user?.latitude != null &&
                            authProvider.user?.longitude != null) {
                        centerLat = authProvider.user!.latitude!;
                        centerLng = authProvider.user!.longitude!;
                      }
                      
                      // Get currently visible order (based on page index) - DIRECT from provider, NO CACHE
                      final driverId = authProvider.user?.id;
                      OrderModel? currentlyVisibleOrder;
                      List<dynamic> allOrders = [];
                      
                      if (driverId != null) {
                        // Get fresh orders directly - don't use cache
                          allOrders = orderProvider
                              .getAllActiveOrdersForDriver(driverId);
                          print(
                              '🗺️ Map Consumer: ${allOrders.length} active orders for driver $driverId');
                        
                        // If no orders, clear the index immediately
                        if (allOrders.isEmpty) {
                          if (_currentOrderIndex != 0) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _currentOrderIndex = 0;
                              });
                            });
                          }
                          print('   ⚠️ No orders - passing null to map');
                        } else if (_currentOrderIndex < allOrders.length) {
                            currentlyVisibleOrder =
                                allOrders[_currentOrderIndex];
                            print(
                                '   Passing order ${currentlyVisibleOrder?.id} to map');
                        } else {
                          // Index out of bounds, reset it
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _currentOrderIndex = 0;
                            });
                          });
                            print(
                                '   ⚠️ Index out of bounds - passing null to map');
                        }
                      }
                      
                      // Create driver location map for widget
                        final driverLocationMap = locationProvider
                                    .currentPosition !=
                                null
                          ? {
                                'latitude':
                                    locationProvider.currentPosition!.latitude,
                                'longitude':
                                    locationProvider.currentPosition!.longitude,
                            }
                            : (authProvider.user?.latitude != null &&
                                    authProvider.user?.longitude != null)
                              ? {
                                  'latitude': authProvider.user!.latitude,
                                  'longitude': authProvider.user!.longitude,
                                }
                              : null;
                      
                      print('   Passing to map widget: $driverLocationMap');
                      
                      // Extract all active order IDs for cleanup purposes
                      final allActiveOrderIds = allOrders
                          .map((order) => order is OrderModel ? order.id : null)
                          .where((id) => id != null)
                          .cast<String>()
                          .toList();
                      
                      print('   All active order IDs: $allActiveOrderIds');
                      
                      return StateOfTheArtMapWidget(
                          key: _mapWidgetKey ??=
                              GlobalKey<StateOfTheArtMapWidgetState>(),
                          centerLat: centerLat,
                          centerLng: centerLng,
                          activeOrder: currentlyVisibleOrder,
                          driverLocation: driverLocationMap,
                          isOrderCardExpanded: _isOrderCardExpanded,
                          allActiveOrderIds: allActiveOrderIds,
                          onCameraMoved: (_lat, _lng) {
                            // Don't close buttons on map interaction - let them persist
                            // They will only close when user clicks elsewhere or taps the same card again
                          },
                      );
                    },
                  ),
              ],
            ),
          ),

          // Status Bar Background - Provides contrast for system icons
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top,
              color: AppColors.primary,
            ),
          ),

          // Order Cards - Swipeable when driver has multiple orders
          Consumer2<OrderProvider, AuthProvider>(
            builder: (context, orderProvider, authProvider, _) {
              final driverId = authProvider.user?.id;
              if (driverId == null) {
                return const SizedBox.shrink();
              }

              // Get ALL active orders for this driver
                final activeOrders =
                    orderProvider.getAllActiveOrdersForDriver(driverId);

              // Generate stable hash to avoid unnecessary rebuilds (ID + status only)
                final ordersHash =
                    activeOrders.map((o) => '${o.id}_${o.status}').join(',');

              // Use orders directly (legacy order card manager removed)
              final ordersToShow = activeOrders;
              
              // Update cache in background without causing rebuilds
              if (_cachedActiveOrders == null || 
                    _cachedActiveOrders!
                            .map((o) => '${o.id}_${o.status}')
                            .join(',') !=
                        ordersHash) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _cachedActiveOrders = activeOrders;
                    });
                  }
                });
              }
              
                print(
                    '📦 Order Card Consumer: ${ordersToShow.length} active orders for driver $driverId (cached: ${_cachedActiveOrders != null})');

              // If no orders, return immediately
              if (ordersToShow.isEmpty) {
                print('   No orders - hiding order cards');
                return const SizedBox.shrink();
              }
              
              // Clamp current index without async setState to avoid flicker
              if (_currentOrderIndex >= ordersToShow.length) {
                  _currentOrderIndex =
                      ordersToShow.isEmpty ? 0 : ordersToShow.length - 1;
              }

              return Stack(
                children: [
                  // Navigation buttons above order card
                  // Navigation buttons removed - now integrated into countdown timer
                  // Order cards - positioned at bottom, extended by 5%
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                    child: RepaintBoundary(
                      key: ValueKey('order_cards_container_$ordersHash'),
                      child: _buildSwipeableOrderCards(ordersToShow),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Bottom Navigation Bar (moved from Scaffold property to Stack for z-ordering)
          Consumer2<OrderProvider, AuthProvider>(
            builder: (context, orderProvider, authProvider, _) {
              final driverId = authProvider.user?.id;
                final hasActiveOrders = driverId != null &&
                    orderProvider
                        .getAllActiveOrdersForDriver(driverId)
                        .isNotEmpty;
                final currentOrderId =
                    _getFocusedOrderId(orderProvider, authProvider);
              
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: hasActiveOrders
                    ? const SizedBox.shrink() // Hide footer when has active orders
                    : SafeArea(
                        top: false,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          height: 80,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                            ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                                _buildSupportShortcut(onPrimaryBackground: true),
                                Expanded(
                                  child: Center(
                                    child: _buildOnlineToggleButton(),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  _showSidebar
                                      ? Icons.home_rounded
                                      : Icons.menu_rounded,
                                  color: Colors.white.withOpacity(0.85),
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showSidebar = !_showSidebar;
                                  });
                                },
                                  padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                              ],
                              ),
                          ),
                        ),
                      ),
              );
              },
            ),
          
          Consumer2<OrderProvider, AuthProvider>(
            builder: (context, orderProvider, authProvider, _) {
              final driverId = authProvider.user?.id;
              final hasActiveOrders = driverId != null &&
                    orderProvider
                        .getAllActiveOrdersForDriver(driverId)
                        .isNotEmpty;
              if (!hasActiveOrders) {
                return const SizedBox.shrink();
              }
              return Stack(
                children: [
                  // Support button in top left
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 10,
                    child: _buildSupportShortcut(onPrimaryBackground: false),
                  ),
                  // Sidebar toggle button in top right
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 10,
                    child: _buildSidebarToggleButton(),
                  ),
                ],
              );
            },
          ),
          
          // Sidebar (when open) - Modern Design matching Merchant (Above Everything)
          if (_showSidebar)
            Positioned.fill(
              child: Consumer2<OrderProvider, AuthProvider>(
                builder: (context, orderProvider, authProvider, _) {
                  final user = authProvider.user;
                    final currentOrderId =
                        _getFocusedOrderId(orderProvider, authProvider);

                  return Material(
                    type: MaterialType.transparency,
                    child: GestureDetector(
                      onTap: () => setState(() => _showSidebar = false),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                              onTap:
                                  () {}, // Prevent closing when tapping sidebar
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              width: MediaQuery.of(context).size.width * 0.75,
                              transform: Matrix4.translationValues(
                                  _showSidebar
                                      ? 0
                                      : MediaQuery.of(context).size.width *
                                          0.75,
                                0,
                                0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(-4, 0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Profile Header (matching merchant design)
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                          MediaQuery.of(context).padding.top +
                                              20,
                                        20,
                                        20,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.primary.withOpacity(0.7)
                                            ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                        children: [
                                          // Support button removed - already available in menu items below
                                          CircleAvatar(
                                            radius: 35,
                                            backgroundColor: Colors.white,
                                            child: Icon(
                                              Icons.delivery_dining,
                                              size: 35,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Builder(
                                            builder: (context) {
                                              final loc = AppLocalizations.of(context);
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                          Text(
                                                    user?.name ?? loc.notSpecified,
                                                    style: AppTextStyles.heading3.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                                    user?.phone ?? loc.notSpecified,
                                                    style: AppTextStyles.bodyMedium.copyWith(
                                                      color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4
                                                    ),
                                            decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                                      loc.driver,
                                                      style: AppTextStyles.bodySmall.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Menu Items
                                    Expanded(
                                      child: ListView(
                                        padding: EdgeInsets.zero,
                                        children: [
                                          Builder(
                                            builder: (context) {
                                              final loc = AppLocalizations.of(context);
                                              return Column(
                                        children: [
                                          _SidebarItem(
                                            icon: Icons.edit_outlined,
                                                    title: loc.editProfile,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                              context.push('/driver/profile');
                                            },
                                          ),
                                          _SidebarItem(
                                            icon: Icons.list_alt,
                                                    title: loc.driverOrders,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                              context.push('/driver/orders');
                                            },
                                          ),
                                          _SidebarItem(
                                            icon: Icons.analytics_outlined,
                                                    title: loc.driverEarnings,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                                      context.push('/driver/earnings');
                                            },
                                          ),
                                          _SidebarItem(
                                            icon: Icons.help_outline,
                                                    title: loc.helpSupport,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                                _openSupportChat();
                                            },
                                          ),
                                          _SidebarItem(
                                            icon: Icons.settings_outlined,
                                                    title: loc.settings,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                                      context.push('/driver/settings');
                                            },
                                          ),
                                          _SidebarItem(
                                            icon: Icons.privacy_tip_outlined,
                                                    title: loc.privacyPolicy,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                                      context.push('/driver/privacy-policy');
                                            },
                                          ),
                                          _SidebarItem(
                                            icon: Icons.description_outlined,
                                                    title: loc.termsAndConditions,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                                      context.push('/driver/terms-conditions');
                                            },
                                          ),
                                          const Divider(),
                                          _SidebarItem(
                                            icon: Icons.logout,
                                                    title: loc.logout,
                                            onTap: () {
                                                      setState(() => _showSidebar = false);
                                                      context.read<AuthProvider>().logout();
                                              context.go('/');
                                            },
                                            isDestructive: true,
                                          ),
                                        ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Aggressive route clearing for completed orders
  void _aggressiveRouteClear() {
    print('🚨 AGGRESSIVE ROUTE CLEAR - Multiple attempts');
    
    // Clear through route manager
    // legacy route manager removed
    
    // Single clear is sufficient - no need for multiple delayed clears
  }
  
  /// Show location update popup to driver when coordinates change
  void _showLocationUpdatePopupToDriver(dynamic order) {
    if (order == null) return;
    print('📍 Showing location update popup for order: ${order.id}');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Text(
                'العميل أرسل موقعه',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم تحديث موقع العميل - لا حاجة للاتصال',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${AppLocalizations.of(context).customerLabelColon}${order.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${AppLocalizations.of(context).merchantLabelColon}${order.merchantName ?? AppLocalizations.of(context).notSpecified}'),
                      Text('${AppLocalizations.of(context).addressLabel}${order.deliveryAddress}'),
                      const SizedBox(height: 8),
                      Text(
                        'الموقع الجديد: ${order.deliveryLatitude.toStringAsFixed(6)}, ${order.deliveryLongitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).close),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).mapUpdated),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context).understood),
            ),
          ],
        );
      },
    );
  }

  /// Handle location update - simplified
  Future<void> _handleLocationUpdate() async {
    print('🔄 Handling location update - refreshing order data...');
    
    try {
      // Clear existing routes and markers
      // legacy route manager removed
      
      // Refresh order provider to get updated coordinates
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.initialize();
      
      // Recalculate route for current active order (if any)
      final driverId = context.read<AuthProvider>().user?.id;
      if (driverId != null) {
        final activeOrders =
            orderProvider.getAllActiveOrdersForDriver(driverId);
        if (activeOrders.isNotEmpty) {
          final currentOrder = activeOrders.first;
          // Ask navigation system to recompute route and dropoff marker
          await StateOfTheArtNavigation()
              .recalculateRouteForOrder(currentOrder);
        }
      }
      
      print('✅ Location update handled - map will update automatically');
    } catch (e) {
      print('❌ Error handling location update: $e');
    }
  }

  /// Apply strict route clearing based on current order card coordinates
  Future<void> _applyStrictRouteClearing() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final orderProvider = context.read<OrderProvider>();
      final driverId = authProvider.user?.id;
      
      if (driverId == null) {
        print('🧹 No driver ID - clearing all routes');
        // legacy route manager removed
        return;
      }
      
      final activeOrders = orderProvider.getAllActiveOrdersForDriver(driverId);
      if (activeOrders.isEmpty) {
        print('🧹 No active orders - clearing all routes');
        // legacy route manager removed
        return;
      }
      
      final currentOrder = activeOrders.first;
      print(
          '🔍 Recalculating route after customer location update for order ${currentOrder.id}');
      
      // Trigger state-of-the-art navigation to rebuild route using updated delivery coords
      // The map widget listens to activeOrder changes; here we just ensure it's up-to-date
      setState(() {
        // noop: forces rebuild so StateOfTheArtMapWidget re-reads activeOrder from provider
      });
    } catch (e) {
      print('❌ Error applying strict route clearing: $e');
    }
  }
  
  /// Recreate pins and routes after location update (legacy method)
  Future<void> _recreatePinsAndRoutesAfterLocationUpdate() async {
    print('🔄 Recreating pins and routes after location update');
    
    try {
      // Force refresh of the order provider to get updated locations
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.initialize();
      
      print('📍 Order provider refreshed after location update');
      
      // Get current active order with updated location
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.user?.id;
      
      if (driverId != null) {
        final activeOrders =
            orderProvider.getAllActiveOrdersForDriver(driverId);
        if (activeOrders.isNotEmpty) {
          final currentOrder = activeOrders.first;
          print('📍 Found active order: ${currentOrder.id}');
          print(
              '📍 Updated delivery location: ${currentOrder.deliveryLatitude}, ${currentOrder.deliveryLongitude}');
          
          // Clear existing route and markers first
          print('🧹 Clearing existing route and markers...');
          // legacy route manager removed
          
          // Clearing is immediate - no delay needed
          
          // Map will update automatically through coordinate change detection
          print(
              '🔄 Map will update automatically through coordinate change detection');
          
          print('✅ Route recreation triggered for updated location');
        } else {
          print('📍 No active orders found after location update');
        }
      } else {
        print('📍 No driver ID found');
      }
    } catch (e) {
      print('❌ Error recreating pins and routes: $e');
    }
  }
}

// Top-level bottom sheet widget for uploading order proof
class _OrderProofUploader extends StatefulWidget {
  final String orderId;
  final Future<void> Function() onUploaded; // Changed from VoidCallback to support async
  final VoidCallback? onCancel; // Optional cancel callback
  const _OrderProofUploader({
    required this.orderId, 
    required this.onUploaded,
    this.onCancel,
  });
  @override
  State<_OrderProofUploader> createState() => _OrderProofUploaderState();
}

class _OrderProofUploaderState extends State<_OrderProofUploader> {
  bool _uploading = false;
  ip.XFile? _picked;
  Uint8List? _previewBytes;

  Future<void> _pick(ip.ImageSource source) async {
    final picker = ip.ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _picked = file;
        _previewBytes = bytes;
      });
    }
  }

  Future<void> _upload() async {
    if (_picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = _previewBytes ?? await _picked!.readAsBytes();
      final ok = await context.read<OrderProvider>().uploadOrderProof(
        orderId: widget.orderId,
        fileBytes: bytes,
        contentType: 'image/jpeg',
        fileName: _picked!.name,
      );
      if (!mounted) return;
      if (ok) {
        print('✅ Order proof uploaded successfully, calling onUploaded callback...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoUploadedSuccess)),
        );
        // CRITICAL: Await the callback to ensure delivery is marked before continuing
        await widget.onUploaded();
        print('✅ onUploaded callback completed');
      } else {
        print('❌ Order proof upload failed');
        final err = context.read<OrderProvider>().error ?? 'فشل رفع الصورة';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      print('❌ Error during order proof upload: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).errorColon}$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'صورة إثبات التسليم',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        
        // Instructions container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'تعليمات مهمة قبل التسليم:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                number: '1',
                text: 'اعرض حالة الطلب للعميل على التطبيق',
                icon: Icons.smartphone,
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                number: '2',
                text: 'تأكد من استلام العميل للطلب كاملاً',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                number: '3',
                text: 'التقط صورة واضحة للطلب مع العميل',
                icon: Icons.photo_camera,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Camera button
        if (_previewBytes == null)
          ElevatedButton.icon(
            onPressed: _uploading ? null : () => _pick(ip.ImageSource.camera),
            icon: const Icon(Icons.photo_camera, size: 28),
            label: const Text(
              'التقط صورة الآن',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        
        // Preview and upload
        if (_previewBytes != null)
          Column(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(_previewBytes!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () {
                              setState(() {
                                _picked = null;
                                _previewBytes = null;
                              });
                            },
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context).retakePhoto),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _uploading || _picked == null ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_uploading ? 'جاري الرفع...' : 'تأكيد وإنهاء'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        
        const SizedBox(height: 16),
        
        // Cancel button
        if (widget.onCancel != null)
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return TextButton.icon(
            onPressed: _uploading ? null : widget.onCancel,
            icon: const Icon(Icons.close),
                label: Text(loc.cancelAndClose),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
              );
            },
          ),
      ],
    );
  }
  
  Widget _buildInstructionStep({
    required String number,
    required String text,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
                    icon,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
                  ),
      title: Text(
                    title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
        color: isDestructive ? AppColors.error : AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

class _InteractiveMapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final dynamic activeOrder;
  final dynamic driverLocation;
  final int currentOrderIndex;
  final List<dynamic> allActiveOrders;
  final bool isOrderCardExpanded;

  const _InteractiveMapWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.activeOrder,
    this.driverLocation,
    required this.currentOrderIndex,
    required this.allActiveOrders,
    this.isOrderCardExpanded = false,
  });

  @override
  State<_InteractiveMapWidget> createState() => _InteractiveMapWidgetState();
}

class _InteractiveMapWidgetState extends State<_InteractiveMapWidget> {
  MapboxMap? _mapboxMap;
  String? _mapboxAccessToken;
  final StateOfTheArtNavigation _navigationSystem = StateOfTheArtNavigation();
  
  // Legacy bulletproof manager removed
  bool _isInitialized = false;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _driverMarker;
  bool _customIconsLoaded = false;

  @override
  void initState() {
    super.initState();
    _mapboxAccessToken = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    if (_mapboxAccessToken == null || _mapboxAccessToken!.isEmpty) {
      _mapboxAccessToken =
          'pk.eyJ1IjoibW9oYW1tZWRzYWRlcSIsImEiOiJjbWNybzlrYmQwcHo2MmtyMms5c3FheDgxIn0.H3pL2ByqWsDNllY8NuT-Hw';
    }
    print('🗺️ Legacy bulletproof map widget removed');
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    print('🗺️ Map created');
    
    // CRITICAL: Hide labels FIRST before anything else to prevent race condition
    await NeighborhoodLabelsService.simplifyMapStyle(mapboxMap);
    
    // Start aggressive label hiding timer to continuously hide labels
    NeighborhoodLabelsService.startLabelHidingTimer(mapboxMap);
    
    // Set up listener to continuously hide labels when style loads
    NeighborhoodLabelsService.setupLabelHidingListener(mapboxMap);
    
    // Create point annotation manager for driver marker
    try {
      _pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      print('✅ Point annotation manager created');
    } catch (e) {
      print('⚠️ Error creating point annotation manager: $e');
    }
    
    // Load custom icons (driver marker)
    await _loadCustomIcons();
    
    // Initialize navigation system (routes + annotations)
    try {
      final initialized =
          await _navigationSystem.initialize(mapboxMap);
      if (initialized) {
        print('✅ Navigation system ready inside map widget');
        if (widget.activeOrder != null) {
          await _navigationSystem
              .setActiveOrder(widget.activeOrder as OrderModel);
        } else {
          await _navigationSystem.clearAll();
        }
      } else {
        print('⚠️ Navigation system failed to initialize');
      }
    } catch (e) {
      print('❌ Error initializing navigation system: $e');
    }
    
    // Add neighborhood labels (use a separate manager or reuse the existing one)
    try {
      if (_pointAnnotationManager != null) {
        // Neighborhood labels removed
      }
    } catch (e) {
      print('⚠️ Error adding neighborhood labels to driver map: $e');
    }
    
    // Update driver marker if location is available
    if (widget.driverLocation != null) {
      await _updateDriverMarker();
    }
    
    _isInitialized = true;
  }

  @override
  void didUpdateWidget(_InteractiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle order changes
    if (widget.activeOrder?.id != oldWidget.activeOrder?.id) {
      _handleOrderChange();
    }
    
    // Handle driver location changes
    if (widget.driverLocation != oldWidget.driverLocation) {
      _updateDriverMarker();
    }
  }

  void _handleOrderChange() {
    if (widget.activeOrder != null && _isInitialized) {
      _setActiveOrder();
    } else if (widget.activeOrder == null && _isInitialized) {
      _clearAllAnnotations();
    }
  }

  Future<void> _setActiveOrder() async {
    if (widget.activeOrder == null || !_isInitialized) return;
    
    try {
      if (widget.activeOrder is OrderModel) {
        await _navigationSystem
            .setActiveOrder(widget.activeOrder as OrderModel);
      }
      print('✅ Active order set - ${widget.activeOrder!.id}');
    } catch (e) {
      print('❌ Bulletproof: Error setting active order: $e');
    }
  }

  Future<void> _clearAllAnnotations() async {
    if (!_isInitialized) return;
    
    try {
      await _navigationSystem.clearAll();
      // Remove driver marker
      if (_driverMarker != null && _pointAnnotationManager != null) {
        await _pointAnnotationManager!.delete(_driverMarker!);
        _driverMarker = null;
      }
      print('🧹 All annotations cleared');
    } catch (e) {
      print('❌ Bulletproof: Error clearing annotations: $e');
    }
  }

  Future<void> _loadCustomIcons() async {
    if (_mapboxMap == null || _customIconsLoaded) return;
    
    try {
      // Load driver location marker (blue circle with black arrowhead)
      final driverBikeBytes = await _createBikeIcon();
      await _mapboxMap!.style.addStyleImage(
        'driver-bike',
        1.0,
        MbxImage(width: 96, height: 96, data: driverBikeBytes),
        false,
        [],
        [],
        null,
      );
      
      _customIconsLoaded = true;
      print('✅ Custom icons loaded (driver bike marker)');
    } catch (e) {
      print('❌ Error loading custom icons: $e');
    }
  }

  Future<Uint8List> _createBikeIcon({double? heading}) async {
    // Create a blue circle with black arrowhead inside pointing in the direction of movement
    // HIGH RESOLUTION (3x scale)
    const double iconSize = 96.0; // 32 * 3
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final center = Offset(iconSize / 2, iconSize / 2);
    final radius = iconSize / 2 - 6; // Smaller border
    
    // Draw blue circle background
    final blueCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, blueCirclePaint);
    
    // Draw blue circle border (white outline for visibility)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, borderPaint);
    
    // Draw arrowhead inside the circle pointing in the direction of movement
    // Arrowhead is a triangle pointing upward (north) by default
    // We'll rotate it based on heading if available
    final arrowSize = radius * 0.6; // Arrow takes up 60% of circle radius
    final arrowPath = Path();
    
    // Arrowhead points upward (north) - triangle pointing up
    final arrowTop = Offset(center.dx, center.dy - arrowSize);
    final arrowBottomLeft =
        Offset(center.dx - arrowSize * 0.5, center.dy + arrowSize * 0.3);
    final arrowBottomRight =
        Offset(center.dx + arrowSize * 0.5, center.dy + arrowSize * 0.3);
    
    arrowPath.moveTo(arrowTop.dx, arrowTop.dy);
    arrowPath.lineTo(arrowBottomLeft.dx, arrowBottomLeft.dy);
    arrowPath.lineTo(arrowBottomRight.dx, arrowBottomRight.dy);
    arrowPath.close();
    
    // Rotate arrow if heading is available
    if (heading != null && !heading.isNaN && !heading.isInfinite) {
      // Heading is in degrees, where 0 = North, 90 = East, etc.
      // We need to convert to radians and adjust for canvas rotation (canvas uses clockwise, heading is typically clockwise from North)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(
          (heading * 3.14159265359 / 180.0)); // Convert degrees to radians
      canvas.translate(-center.dx, -center.dy);
    }
    
    // Draw arrowhead in black for visibility on blue background
    final arrowPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);
    
    if (heading != null) {
      canvas.restore();
    }
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    print(
        '✅ Driver location marker created (blue circle with black arrowhead${heading != null ? ', heading: $heading°' : ''})');
    return byteData!.buffer.asUint8List();
  }

  Future<void> _updateDriverMarker() async {
    if (_pointAnnotationManager == null ||
        widget.driverLocation == null ||
        _mapboxMap == null ||
        !_customIconsLoaded) return;
    
    try {
      // Extract location coordinates
      double? lat;
      double? lng;
      double? heading;
      
      if (widget.driverLocation is Map) {
        lat = widget.driverLocation['latitude'] as double?;
        lng = widget.driverLocation['longitude'] as double?;
        heading = widget.driverLocation['heading'] as double?;
      } else {
        try {
          lat = widget.driverLocation.latitude;
          lng = widget.driverLocation.longitude;
          heading = widget.driverLocation.heading;
        } catch (e) {
          print('❌ Cannot access coordinates from driverLocation: $e');
          return;
        }
      }
      
      if (lat == null || lng == null) {
        print('⚠️ Invalid driver location coordinates');
        return;
      }
      
      // Get heading/bearing from driver location if available
      
      // Remove old marker
      if (_driverMarker != null) {
        try {
          await _pointAnnotationManager!.delete(_driverMarker!);
        } catch (e) {
          print('⚠️ Error deleting old driver marker: $e');
        }
      }
      
      // If heading is available and has changed, recreate the icon with new rotation
      // Otherwise use the default icon
      if (heading != null && !heading.isNaN && !heading.isInfinite) {
        // Create icon with specific heading
        final driverIconBytes = await _createBikeIcon(heading: heading);
        // Update the style image
        await _mapboxMap!.style.addStyleImage(
          'driver-bike',
          1.0,
          MbxImage(width: 96, height: 96, data: driverIconBytes),
          false,
          [],
          [],
          null,
        );
      }
      
      // Add new marker with white circle + arrowhead icon
      _driverMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(lng, lat),
          ),
          iconImage:
              'driver-bike', // Blue circle with black arrowhead (high-res 96x96)
          iconSize: 0.2, // Scale to 1/5 for smaller size (19px)
        ),
      );
      print(
          '✅ Driver location marker updated (blue circle with black arrowhead${heading != null ? ', heading: $heading°' : ''})');
    } catch (e) {
      print('❌ Error updating driver marker: $e');
    }
  }

  @override
  void dispose() {
    // Clean up marker (fire and forget - dispose shouldn't be async)
    if (_driverMarker != null && _pointAnnotationManager != null) {
      _pointAnnotationManager!.delete(_driverMarker!).catchError((_) {
        // Ignore errors during dispose
      });
    }
    try {
      _navigationSystem.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          child: MapWidget(
            key: const ValueKey("driver_map_widget"),
          cameraOptions: CameraOptions(
              center: Point(
                  coordinates: Position(widget.centerLng, widget.centerLat)),
              zoom: 15.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: (_) async {
            // Hide labels again after style is fully loaded (more reliable)
            if (_mapboxMap != null) {
              print('🔄 Style loaded, aggressively hiding all labels...');
              await NeighborhoodLabelsService.simplifyMapStyle(_mapboxMap!);
              // Also start the timer if not already running
              NeighborhoodLabelsService.startLabelHidingTimer(_mapboxMap!);
            }
          },
        ),
        ),
        // Floating Navigation Button - Moves with order card
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          bottom: widget.isOrderCardExpanded 
              ? 120.0 // When expanded, sit above expanded card (estimated height)
              : 80.0, // When collapsed, sit above collapsed card (60px + margin)
          right: MediaQuery.of(context).size.width * 0.04,
          child: _FloatingNavigationButton(
            mapboxMap: _mapboxMap,
            activeOrder: widget.activeOrder,
            driverLocation: widget.driverLocation,
          ),
        ),
      ],
    );
  }
}

class _FloatingNavigationButton extends StatefulWidget {
  final MapboxMap? mapboxMap;
  final dynamic activeOrder;
  final dynamic driverLocation;

  const _FloatingNavigationButton({
    this.mapboxMap,
    this.activeOrder,
    this.driverLocation,
  });

  @override
  State<_FloatingNavigationButton> createState() =>
      _FloatingNavigationButtonState();
}

class _FloatingNavigationButtonState extends State<_FloatingNavigationButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    // Always toggle the navigation list (removed direct navigation logic)
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _navigateToLocation(double lat, double lng, String locationName) {
    if (widget.mapboxMap == null) return;

    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16.0,
        bearing: 0.0, // Reset to north like a compass
      ),
      MapAnimationOptions(duration: 1000),
    );

    // Close the expanded menu (only if it's expanded)
    if (_isExpanded) {
      _toggleExpansion();
    }
  }

  void _navigateToDriverLocation() {
    if (widget.driverLocation == null) return;
    
    try {
      // Extract lat/lng safely
      double? lat;
      double? lng;
      
      if (widget.driverLocation is Map) {
        lat = widget.driverLocation['latitude'];
        lng = widget.driverLocation['longitude'];
      } else {
        try {
          lat = widget.driverLocation.latitude;
          lng = widget.driverLocation.longitude;
        } catch (e) {
          print('❌ Cannot access coordinates: $e');
          return;
        }
      }
      
      if (lat != null && lng != null) {
        _navigateToLocation(lat, lng, 'موقعك الحالي');
      }
    } catch (e) {
      print('❌ Error in _navigateToDriverLocation: $e');
    }
  }

  void _navigateToStoreLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.pickupLatitude,
        widget.activeOrder.pickupLongitude,
        'موقع المتجر',
      );
    }
  }

  void _navigateToDeliveryLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.deliveryLatitude,
        widget.activeOrder.deliveryLongitude,
        'موقع التوصيل',
      );
    }
  }

  /// Check if customer has provided GPS location
  bool _hasCustomerProvidedGps() {
    if (widget.activeOrder == null) return false;
    // Check if customer_location_provided is true
    return widget.activeOrder.customerLocationProvided == true;
  }

  /// Get delivery button label with GPS indication
  String _getDeliveryButtonLabel() {
    if (_hasCustomerProvidedGps()) {
      return 'التوصيل 📍';
    }
    return 'التوصيل';
  }

  void _showFullRoute() {
    if (widget.mapboxMap == null || widget.activeOrder == null) return;

    print('📹 Overview: Showing full route...');
    
    // Get coordinates
    final pickupLat = widget.activeOrder.pickupLatitude;
    final pickupLng = widget.activeOrder.pickupLongitude;
    final deliveryLat = widget.activeOrder.deliveryLatitude;
    final deliveryLng = widget.activeOrder.deliveryLongitude;
    
    // Calculate bounds
    final minLat = pickupLat < deliveryLat ? pickupLat : deliveryLat;
    final maxLat = pickupLat > deliveryLat ? pickupLat : deliveryLat;
    final minLng = pickupLng < deliveryLng ? pickupLng : deliveryLng;
    final maxLng = pickupLng > deliveryLng ? pickupLng : deliveryLng;
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;
    
    // Calculate center between pickup and delivery
    final centerLat = (pickupLat + deliveryLat) / 2;
    final centerLng = (pickupLng + deliveryLng) / 2;
    
    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat + latPadding;
    final lngDiff = maxLng - minLng + lngPadding;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 13.0;
    if (maxDiff > 0.1) {
      zoom = 11.0;
    } else if (maxDiff > 0.05) {
      zoom = 12.0;
    } else if (maxDiff > 0.02) {
      zoom = 13.0;
    } else {
      zoom = 14.0;
    }

    // Animate to show full route
    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        bearing: 0.0, // Reset to north
      ),
      MapAnimationOptions(duration: 1500),
    );
    
    print('✅ Overview: Camera set to show full route at zoom $zoom');

    // Close the expanded menu
    _toggleExpansion();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded menu items
        if (_isExpanded) ...[
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.scale(
                scale: _animation.value,
                child: Opacity(
                  opacity: _animation.value,
                  child: Column(
                    children: [
                      // Show full route - only if there's an active order
                      if (widget.activeOrder != null) ...[
                        _buildNavButton(
                          icon: Icons.route,
                          label: 'عرض المسار',
                          onTap: _showFullRoute,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        // Navigate to store
                        _buildNavButton(
                          icon: Icons.store,
                          label: 'المتجر',
                          onTap: _navigateToStoreLocation,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        // Navigate to delivery with GPS indication
                        _buildNavButton(
                          icon: Icons.flag,
                          label: _getDeliveryButtonLabel(),
                          onTap: _navigateToDeliveryLocation,
                          color: AppColors.success,
                          hasGpsIndicator: _hasCustomerProvidedGps(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Navigate to driver location - always available
                      if (widget.driverLocation != null)
                        _buildNavButton(
                          icon: Icons.my_location,
                          label: 'موقعك',
                          onTap: _navigateToDriverLocation,
                          color: AppColors.warning,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        // Main floating button - ALWAYS VISIBLE
        FloatingActionButton(
          onPressed: _toggleExpansion,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Icon(_isExpanded ? Icons.close : Icons.navigation),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool hasGpsIndicator = false,
  }) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0, // Remove elevation completely to prevent gray overlay
          shadowColor:
              Colors.transparent, // Remove shadow to prevent gray overlay
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasGpsIndicator) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.gps_fixed,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebMapWidget extends StatefulWidget {
  @override
  _WebMapWidgetState createState() => _WebMapWidgetState();
}

class _WebMapWidgetState extends State<_WebMapWidget> {
  double _zoom = 15.0;
  double _centerLat = 33.3152; // Baghdad default
  double _centerLng = 44.3661;
  bool _showControls = false;
  String _locationStatus = 'جاري تحديد الموقع...';
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, AuthProvider>(
      builder: (context, locationProvider, authProvider, child) {
        final currentPosition = locationProvider.currentPosition;
        final user = authProvider.user;
        
        // Update map center with driver's actual location
        if (currentPosition != null) {
          _centerLat = currentPosition.latitude;
          _centerLng = currentPosition.longitude;
          _locationStatus = 'موقعك الحالي';
        } else if (user?.latitude != null && user?.longitude != null) {
          _centerLat = user!.latitude!;
          _centerLng = user!.longitude!;
          _locationStatus = 'آخر موقع معروف';
        } else {
          _locationStatus = 'جاري تحديد الموقع...';
        }
        
        return Stack(
          children: [
            // Interactive Map with Real Mapbox Integration
            Container(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Interactive Mapbox Map
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 4.0,
                      onInteractionStart: (details) {
                        // Handle interaction start
                      },
                      onInteractionUpdate: (details) {
                        // Handle interaction update
                      },
                      onInteractionEnd: (details) {
                        // Handle interaction end
                      },
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                              'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/${_centerLng},${_centerLat},${_zoom.toInt()},0/800x600?access_token=pk.eyJ1IjoibW9oYW1tZWRzYWRlcSIsImEiOiJjbWNybzlrYmQwcHo2MmtyMms5c3FheDgxIn0.H3pL2ByqWsDNllY8NuT-Hw',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Driver location marker - Always visible and responsive
                  if (currentPosition != null ||
                      (user?.latitude != null && user?.longitude != null))
                    Positioned(
                      left: MediaQuery.of(context).size.width / 2 -
                          (MediaQuery.of(context).size.width *
                              0.08), // Responsive center
                      top: MediaQuery.of(context).size.height / 2 -
                          (MediaQuery.of(context).size.width *
                              0.08), // Responsive center
                      child: Container(
                        width: MediaQuery.of(context).size.width *
                            0.16, // Responsive size
                        height: MediaQuery.of(context).size.width *
                            0.16, // Responsive size
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: MediaQuery.of(context).size.width *
                                0.008, // Responsive border
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: MediaQuery.of(context).size.width *
                              0.08, // Responsive icon
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Status overlay
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: context.rs(8)),
                    Expanded(
                      child: Text(
                          _locationStatus,
                        style: const TextStyle(
                          fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ),
                  ],
                ),
              ),
            ),
            
            // My Location Button
            Positioned(
              bottom: 100,
              right: 20,
              child: Column(
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        final locationProvider = context.read<LocationProvider>();
                        if (locationProvider.currentPosition != null) {
                          setState(() {
                          _centerLat =
                              locationProvider.currentPosition!.latitude;
                          _centerLng =
                              locationProvider.currentPosition!.longitude;
                          });
                          _transformationController.value = Matrix4.identity();
                        }
                      },
                      backgroundColor: AppColors.success,
                    elevation: 12,
                    mini: false,
                      child: Icon(
                        Icons.my_location,
                        color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.06,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// Accept button with 3-second long press and haptic feedback
class _AcceptButtonWithLongPress extends StatefulWidget {
  final String orderId;
  final VoidCallback onAccept;

  const _AcceptButtonWithLongPress({
    required this.orderId,
    required this.onAccept,
  });

  @override
  State<_AcceptButtonWithLongPress> createState() =>
      _AcceptButtonWithLongPressState();
}

class _AcceptButtonWithLongPressState extends State<_AcceptButtonWithLongPress> 
    with SingleTickerProviderStateMixin {
  Timer? _pressTimer;
  double _progress = 0.0;
  bool _isPressed = false;
  int _lastHapticStep = -1;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startPress() {
    if (_isPressed) return;
    
    setState(() {
      _isPressed = true;
      _progress = 0.0;
      _lastHapticStep = -1;
    });
    _animationController.forward();
    HapticFeedback.mediumImpact();

    const duration = Duration(seconds: 1);
    const interval = Duration(milliseconds: 50);
    final steps = duration.inMilliseconds / interval.inMilliseconds;
    final increment = 1.0 / steps;

    _pressTimer = Timer.periodic(interval, (timer) {
      if (mounted) {
        setState(() {
          _progress += increment;
          
          // Haptic feedback every 0.5 seconds (6 steps = 0.3s, we want every 0.5s = 10 steps)
          final currentStep =
              (timer.tick * interval.inMilliseconds / 500).floor();
          if (currentStep > _lastHapticStep && currentStep < 6) {
            _lastHapticStep = currentStep;
            HapticFeedback.selectionClick();
          }
          
          if (_progress >= 1.0) {
            _progress = 1.0;
            timer.cancel();
            _completePress();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    _animationController.reverse();
    if (mounted) {
      setState(() {
        _isPressed = false;
        _progress = 0.0;
      });
    }
  }

  void _completePress() {
    _pressTimer?.cancel();
    HapticFeedback.heavyImpact();
    widget.onAccept();
    if (mounted) {
      setState(() {
        _isPressed = false;
        _progress = 0.0;
      });
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startPress(),
      onTapUp: (_) => _cancelPress(),
      onTapCancel: _cancelPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Progress indicator overlay
                  if (_isPressed)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progress,
                          heightFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.2),
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Button content
                  Center(
                    child: Text(
                      _isPressed 
                          ? '${(1 - (_progress * 1)).ceil()}...' 
                          : 'قبول الطلب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: _isPressed
                            ? [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Timeout countdown pill widget that updates in real-time
class _TimeoutCountdownPill extends StatefulWidget {
  final dynamic order;

  const _TimeoutCountdownPill({
    required this.order,
  });

  @override
  State<_TimeoutCountdownPill> createState() => _TimeoutCountdownPillState();
}

class _TimeoutCountdownPillState extends State<_TimeoutCountdownPill> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateRemainingSeconds();
    // Update every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemainingSeconds();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateRemainingSeconds() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final newRemaining = orderProvider.getTimeoutRemaining(widget.order.id) ?? 
        widget.order.timeoutRemainingSeconds ??
        0;
    
    if (mounted && newRemaining != _remainingSeconds) {
      setState(() {
        _remainingSeconds = newRemaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();
    
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString = minutes > 0 
        ? '${minutes}:${seconds.toString().padLeft(2, '0')}'
        : '$seconds';
    
    final Color pillColor = _remainingSeconds <= 10 
        ? Colors.red.shade400 
        : _remainingSeconds <= 20 
            ? Colors.orange.shade400 
            : AppColors.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: pillColor.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: context.rs(8)),
          Text(
            'الوقت المتبقي: $timeString',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
