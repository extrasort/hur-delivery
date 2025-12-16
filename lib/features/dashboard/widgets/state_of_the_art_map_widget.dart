import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/services/neighborhood_labels_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';
import 'state_of_the_art_navigation.dart';

/// State-of-the-art map widget with best practices
class StateOfTheArtMapWidget extends StatefulWidget {
  final OrderModel? activeOrder;
  final dynamic driverLocation;
  final double centerLat;
  final double centerLng;
  final bool isOrderCardExpanded;
  final Function(double lat, double lng)? onCameraMoved; // Callback when map is interacted with
  final List<String>? allActiveOrderIds; // All active order IDs for the driver (for cleanup)

  const StateOfTheArtMapWidget({
    Key? key,
    this.activeOrder,
    this.driverLocation,
    required this.centerLat,
    required this.centerLng,
    this.isOrderCardExpanded = false,
    this.onCameraMoved,
    this.allActiveOrderIds,
  }) : super(key: key);

  @override
  State<StateOfTheArtMapWidget> createState() => StateOfTheArtMapWidgetState();
}

class StateOfTheArtMapWidgetState extends State<StateOfTheArtMapWidget> {
  MapboxMap? _mapboxMap;
  final StateOfTheArtNavigation _navigationSystem = StateOfTheArtNavigation();
  bool _isMapReady = false;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _driverMarker;
  bool _customIconsLoaded = false;
  Timer? _driverMarkerRetryTimer;
  bool _isCreatingMarker = false; // Prevent concurrent marker creation
  double? _lastDriverLat;
  double? _lastDriverLng;
  double? _lastDriverHeading;
  Timer? _driverMarkerUpdateTimer; // Debounce marker updates
  bool _isProgrammaticCameraMove = false; // Track programmatic camera moves
  bool _shouldApplyActiveOrder = false; // Queue order until map ready
  OrderModel? _queuedOrder;
  String? _lastActiveOrderId; // Track last active order ID to detect changes

  @override
  void initState() {
    super.initState();
    print('🚀 State-of-the-Art Map: Initializing...');
    
    // If driver location is already available, schedule marker creation
    // This handles the case where location is available before map is created
    if (widget.driverLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && widget.driverLocation != null && _customIconsLoaded && _pointAnnotationManager != null) {
            print('📍 Driver location available in initState, will create marker...');
            _updateDriverMarker();
          }
        });
      });
    }
  }

  @override
  void didUpdateWidget(StateOfTheArtMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if active order changed
    if (widget.activeOrder?.id != oldWidget.activeOrder?.id) {
      _handleOrderChange();
    }
    
    // Check if the list of all active orders changed (to clean up orphaned annotations)
    final oldOrderIdsString = oldWidget.allActiveOrderIds?.join(',') ?? '';
    final newOrderIdsString = widget.allActiveOrderIds?.join(',') ?? '';
    if (oldOrderIdsString != newOrderIdsString && _isMapReady) {
      print('🔄 State-of-the-Art Map: Active orders list changed, cleaning up orphaned annotations');
      _cleanupOrphanedAnnotations();
    }

    // Driver location changed: update driver marker IMMEDIATELY (remove _isMapReady check)
    // Check if location actually changed (not just reference)
    bool locationChanged = false;
    if (widget.driverLocation != oldWidget.driverLocation) {
      if (widget.driverLocation == null || oldWidget.driverLocation == null) {
        locationChanged = true;
      } else {
        // Compare coordinates
        double? newLat, newLng, oldLat, oldLng;
        if (widget.driverLocation is Map) {
          newLat = widget.driverLocation['latitude'] as double?;
          newLng = widget.driverLocation['longitude'] as double?;
        }
        if (oldWidget.driverLocation is Map) {
          oldLat = oldWidget.driverLocation['latitude'] as double?;
          oldLng = oldWidget.driverLocation['longitude'] as double?;
        }
        locationChanged = (newLat != oldLat || newLng != oldLng);
      }
    }
    
    if (locationChanged) {
      // Debounce marker updates to prevent flickering
      _driverMarkerUpdateTimer?.cancel();
      _driverMarkerUpdateTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          _updateDriverMarker();
        }
      });
    }
  }

  void _handleOrderChange() {
    final currentOrderId = widget.activeOrder?.id;
    final lastOrderId = _lastActiveOrderId;
    
    // Detect order change
    if (currentOrderId != lastOrderId) {
      print('🔄 State-of-the-Art Map: Order changed from $lastOrderId to $currentOrderId');
      _lastActiveOrderId = currentOrderId;
      
      // Clear orphaned annotations when order changes
      if (_isMapReady) {
        _cleanupOrphanedAnnotations();
      }
    }
    
    if (widget.activeOrder != null) {
      _queuedOrder = widget.activeOrder;
      if (_isMapReady) {
        _setActiveOrder(widget.activeOrder!);
      } else {
        _shouldApplyActiveOrder = true;
      }
    } else {
      _shouldApplyActiveOrder = false;
      _queuedOrder = null;
      if (_isMapReady) {
        _clearAllAnnotations();
      }
    }
  }
  
  /// Clean up annotations for orders that are no longer active
  Future<void> _cleanupOrphanedAnnotations() async {
    try {
      // Use the provided list of all active order IDs, or fall back to current order
      final activeOrderIds = widget.allActiveOrderIds ?? 
          (widget.activeOrder != null ? [widget.activeOrder!.id] : <String>[]);
      
      print('🧹 State-of-the-Art Map: Cleaning up annotations, keeping: $activeOrderIds');
      
      // Clear annotations for orders not in the active list
      await _navigationSystem.clearOrphanedAnnotations(activeOrderIds);
    } catch (e) {
      print('❌ State-of-the-Art Map: Error cleaning up orphaned annotations: $e');
    }
  }

  Future<void> _setActiveOrder(OrderModel order) async {
    _queuedOrder = order;

    if (!_isMapReady) {
      _shouldApplyActiveOrder = true;
      return;
    }

    try {
      await _navigationSystem.setActiveOrder(order);
      print('✅ State-of-the-Art Map: Active order set - ${order.id}');

      if (!mounted) return;

      if (widget.activeOrder != null && widget.activeOrder!.id == order.id) {
        _overviewFullRoute(order);
      } else if (widget.activeOrder != null && widget.activeOrder!.id != order.id) {
        _queuedOrder = widget.activeOrder;
        // Active order changed while we were processing; apply the new one immediately
        _applyPendingOrder();
      } else if (widget.activeOrder == null) {
        // Order removed while processing, ensure map is cleared
        _clearAllAnnotations();
      }
      _shouldApplyActiveOrder = false;
      _queuedOrder = null;
    } catch (e) {
      print('❌ State-of-the-Art Map: Error setting active order: $e');
    }
  }

  Future<void> forceRefreshActiveOrder([OrderModel? overrideOrder]) async {
    final targetOrder = overrideOrder ?? widget.activeOrder;
    if (targetOrder == null) {
      print('⚠️ State-of-the-Art Map: forceRefreshActiveOrder called with null order');
      return;
    }

    _queuedOrder = targetOrder;

    if (!_isMapReady) {
      _shouldApplyActiveOrder = true;
      return;
    }

    try {
      await _navigationSystem.setActiveOrder(targetOrder);
      if (mounted) {
        _overviewFullRoute(targetOrder);
      }
    } catch (e) {
      print('❌ State-of-the-Art Map: forceRefreshActiveOrder failed: $e');
    }
  }

  // Public method to refocus camera on a specific location
  void refocusCamera(double latitude, double longitude, {double zoom = 16.0}) {
    if (_mapboxMap == null) return;
    
    // Set flag to prevent onCameraMoved from triggering
    _isProgrammaticCameraMove = true;
    
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
        bearing: 0.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
    
    // Reset flag after animation completes
    Future.delayed(const Duration(milliseconds: 1100), () {
      _isProgrammaticCameraMove = false;
    });
  }

  /// Public hook so parent widgets can force-clear annotations immediately
  Future<void> forceClearAnnotations() async {
    await _clearAllAnnotations();
  }

  void _overviewFullRoute([OrderModel? order]) {
    if (_mapboxMap == null) return;

    final targetOrder = order ?? widget.activeOrder;
    if (targetOrder == null) return;

    final pickupLat = targetOrder.pickupLatitude;
    final pickupLng = targetOrder.pickupLongitude;
    final deliveryLat = targetOrder.deliveryLatitude;
    final deliveryLng = targetOrder.deliveryLongitude;

    final centerLat = (pickupLat + deliveryLat) / 2;
    final centerLng = (pickupLng + deliveryLng) / 2;

    // Calculate distance to determine optimal zoom
    final latDiff = (pickupLat - deliveryLat).abs();
    final lngDiff = (pickupLng - deliveryLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    // Improved zoom calculation with padding to show both pins clearly
    double zoom = 13.0;
    if (maxDiff > 0.2) zoom = 10.0; // Very far apart
    else if (maxDiff > 0.1) zoom = 11.0;
    else if (maxDiff > 0.05) zoom = 12.0;
    else zoom = 13.0;

    // Use flyTo with animation to smoothly refocus on the route
    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        bearing: 0.0,
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 1500), // Slightly longer for smoother transition
    );
    
    print('🗺️ Map refocused to show route: center=$centerLat,$centerLng, zoom=$zoom');
  }

  Future<void> _clearAllAnnotations() async {
    if (!_isMapReady) return;
    
    try {
      await _navigationSystem.clearAll();
      print('🧹 State-of-the-Art Map: All annotations cleared');
    } catch (e) {
      print('❌ State-of-the-Art Map: Error clearing annotations: $e');
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    try {
      print('🗺️ State-of-the-Art Map: Map created, initializing...');
      
      // Disable compass
      try {
        await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
        print('✅ Compass disabled');
      } catch (e) {
        print('⚠️ Error disabling compass: $e');
      }
      
      // Create point annotation manager for driver marker
      try {
        _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        print('✅ Point annotation manager created');
      } catch (e) {
        print('⚠️ Error creating point annotation manager: $e');
      }
      
      // Hide labels - do not block annotations; run in parallel to avoid delaying pins/route
      unawaited(NeighborhoodLabelsService.simplifyMapStyle(mapboxMap));
      
      // Start aggressive label hiding timer to continuously hide labels
      NeighborhoodLabelsService.startLabelHidingTimer(mapboxMap);
      
      // Set up listener to continuously hide labels when style loads
      NeighborhoodLabelsService.setupLabelHidingListener(mapboxMap);
      
      // Load custom icons and create marker IMMEDIATELY (in parallel if possible)
      // Create marker as soon as icons are loaded, don't wait for anything else
      _loadCustomIcons().then((_) {
        // Icons loaded - create marker immediately if location is available
        if (widget.driverLocation != null && mounted) {
          print('📍 Driver location available, creating marker IMMEDIATELY...');
          _updateDriverMarker();
        }
      });
      
      // Initialize the state-of-the-art navigation system (in parallel)
      // Don't block marker creation on this
      _navigationSystem.initialize(mapboxMap).then((success) {
        if (success && mounted) {
          _isMapReady = true;
          print('✅ State-of-the-Art Map: Map ready and navigation system initialized');
          
          // Ensure marker is created once navigation is ready
          if (widget.driverLocation != null && _driverMarker == null) {
            print('📍 Navigation ready, ensuring driver marker exists...');
            _updateDriverMarker();
          }
          
          _applyPendingOrder();
        } else if (!success && mounted) {
          print('⚠️ Navigation system initialization failed, retrying immediately...');
          // Retry initialization immediately (no delay)
          _navigationSystem.initialize(_mapboxMap!).then((retrySuccess) {
            if (retrySuccess && mounted) {
              _isMapReady = true;
              _applyPendingOrder();
            }
          });
        }
      });
      
      // Also try creating marker immediately (fire and forget)
      if (widget.driverLocation != null) {
        // Try once immediately (might work if icons are already loaded)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.driverLocation != null) {
            _updateDriverMarker();
          }
        });
      }
    } catch (e) {
      print('❌ State-of-the-Art Map: Error in _onMapCreated: $e');
    }
  }

  Future<void> _loadCustomIcons() async {
    if (_mapboxMap == null || _customIconsLoaded) return;
    
    try {
      // Load driver location marker (blue circle with black arrowhead) - HIGH RES
      final driverBikeBytes = await _createBikeIcon();
      await _mapboxMap!.style.addStyleImage(
        'driver-bike',
        1.0,
        MbxImage(width: 144, height: 144, data: driverBikeBytes),
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

  void _applyPendingOrder() {
    if (!_isMapReady) return;

    final orderToApply = widget.activeOrder ?? _queuedOrder;

    if (orderToApply != null) {
      _setActiveOrder(orderToApply);
    } else if (_shouldApplyActiveOrder) {
      _shouldApplyActiveOrder = false;
      _clearAllAnnotations();
    }
  }

  Future<Uint8List> _createBikeIcon({double? heading}) async {
    // Create a blue circle with Material Icons.navigation rendered inside
    // HIGH RESOLUTION (3x scale) to prevent flickering
    const double iconSize = 144.0; // 48 * 3 for high resolution
    const double arrowIconSize = 90.0; // 30 * 3 for high resolution
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final center = Offset(iconSize / 2, iconSize / 2);
    final radius = iconSize / 2 - 4; // Leave room for white rim
    
    // Draw blue circle background
    final blueCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, blueCirclePaint);
    
    // Draw white rim/border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, borderPaint);
    
    // Render Material Icons.navigation directly using TextPainter
    // This ensures it matches the button icon exactly
    final iconData = Icons.navigation;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          fontSize: arrowIconSize,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    
    // If heading is provided, rotate the canvas before drawing the icon
    if (heading != null && !heading.isNaN && !heading.isInfinite) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((heading * 3.14159265359 / 180.0));
      canvas.translate(-center.dx, -center.dy);
    }
    
    // Draw the icon centered in the circle
    final iconOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);
    
    if (heading != null) {
      canvas.restore();
    }
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    // Cache icon to prevent flickering - reuse same bytes if heading hasn't changed
    
    print('✅ Driver location marker created (blue circle with Material navigation icon${heading != null ? ', heading: $heading°' : ''})');
    return byteData!.buffer.asUint8List();
  }

  Future<void> _updateDriverMarker() async {
    // Prevent concurrent marker creation
    if (_isCreatingMarker) {
      print('⚠️ Marker creation already in progress, skipping...');
      return;
    }
    
    _isCreatingMarker = true;
    
    try {
      // Check prerequisites
      if (_mapboxMap == null) {
        print('⚠️ Cannot update driver marker: map not initialized');
        return;
      }
      
      if (widget.driverLocation == null) {
        print('⚠️ Cannot update driver marker: no location available');
        return;
      }
      
      if (_pointAnnotationManager == null) {
        print('⚠️ Cannot update driver marker: point annotation manager not created');
        // Try to create it
        try {
          _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
          print('✅ Point annotation manager created on-demand');
        } catch (e) {
          print('❌ Failed to create point annotation manager: $e');
          return;
        }
      }
      
      // Load icons if not loaded yet (load synchronously for instant creation)
      if (!_customIconsLoaded) {
        print('⏳ Icons not loaded, loading now...');
        await _loadCustomIcons();
        if (!_customIconsLoaded) {
          print('❌ Failed to load custom icons');
          return;
        }
      }
      
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
      
      // Check if position changed significantly (threshold: ~10 meters)
      const double threshold = 0.0001; // ~10 meters
      bool positionChanged = false;
      bool headingChanged = false;
      
      if (_lastDriverLat != null && _lastDriverLng != null) {
        final latDiff = (lat! - _lastDriverLat!).abs();
        final lngDiff = (lng! - _lastDriverLng!).abs();
        positionChanged = latDiff > threshold || lngDiff > threshold;
      } else {
        positionChanged = true; // First time
      }
      
      // Check heading change (threshold: 15 degrees)
      if (_lastDriverHeading != null && heading != null) {
        final headingDiff = (heading! - _lastDriverHeading!).abs();
        headingChanged = headingDiff > 15.0;
      } else if (heading != null) {
        headingChanged = true; // First time with heading
      }
      
      // Only update if position or heading changed significantly
      if (!positionChanged && !headingChanged && _driverMarker != null) {
        print('📍 Driver marker position/heading unchanged significantly, skipping update');
        return;
      }
      
      // Update last known values
      _lastDriverLat = lat;
      _lastDriverLng = lng;
      if (heading != null) {
        _lastDriverHeading = heading;
      }
      
      // Delete old marker only if it exists
      if (_driverMarker != null) {
        try {
          await _pointAnnotationManager!.delete(_driverMarker!);
          _driverMarker = null;
          print('✅ Old driver marker removed for position update');
        } catch (e) {
          print('⚠️ Error removing old driver marker: $e');
          // Continue to create new marker
        }
      }
      
      // If heading is available and has changed, recreate the icon with new rotation
      // Otherwise use the default icon
      if (heading != null && !heading.isNaN && !heading.isInfinite) {
        // Create icon with specific heading
        final driverIconBytes = await _createBikeIcon(heading: heading);
        // Update the style image - HIGH RES
        await _mapboxMap!.style.addStyleImage(
          'driver-bike',
          1.0,
          MbxImage(width: 144, height: 144, data: driverIconBytes),
          false,
          [],
          [],
          null,
        );
      }
      
      // Ensure icon exists before creating marker
      bool iconExists = false;
      try {
        await _mapboxMap!.style.getStyleImage('driver-bike');
        iconExists = true;
        print('✅ Verified driver-bike icon exists in style');
      } catch (iconError) {
        print('⚠️ driver-bike icon not in style, adding it now...');
        // Create and add the icon
        final driverIconBytes = heading != null && !heading.isNaN && !heading.isInfinite
            ? await _createBikeIcon(heading: heading)
            : await _createBikeIcon();
        try {
          await _mapboxMap!.style.addStyleImage(
            'driver-bike',
            1.0,
            MbxImage(width: 144, height: 144, data: driverIconBytes),
            false,
            [],
            [],
            null,
          );
          iconExists = true;
          print('✅ driver-bike icon added to style');
        } catch (addError) {
          print('❌ Failed to add driver-bike icon: $addError');
        }
      }
      
      if (!iconExists) {
        print('❌ Cannot create marker: driver-bike icon not available');
        return;
      }
      
      // Add new marker with blue circle + black arrowhead icon
      try {
        _driverMarker = await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(lng, lat),
            ),
            iconImage: 'driver-bike', // Blue circle with white arrowhead and white rim
            iconSize: 0.20,  // Smaller size (0.27 * 0.75 ≈ 0.20) for better visibility
          ),
        );
        print('✅ Driver location marker created successfully (blue circle with white arrowhead${heading != null ? ', heading: $heading°' : ''}) at ($lat, $lng)');
        print('   Marker ID: ${_driverMarker?.id}');
        print('   Icon size: 0.8');
      } catch (createError) {
        print('❌ Failed to create driver marker annotation: $createError');
        print('   Error details: ${createError.toString()}');
        print('   Stack trace: ${StackTrace.current}');
        rethrow;
      }
    } catch (e) {
      print('❌ Error updating driver marker: $e');
    } finally {
      _isCreatingMarker = false;
    }
  }

  @override
  void dispose() {
    // Cancel retry timer
    _driverMarkerRetryTimer?.cancel();
    _driverMarkerRetryTimer = null;
    
    // Cancel marker update timer
    _driverMarkerUpdateTimer?.cancel();
    _driverMarkerUpdateTimer = null;
    
    // Clean up marker
    if (_driverMarker != null && _pointAnnotationManager != null) {
      _pointAnnotationManager!.delete(_driverMarker!);
    }
    _navigationSystem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if driver marker should be created but isn't - try IMMEDIATELY
    if (widget.driverLocation != null && _driverMarker == null && _mapboxMap != null) {
      // Try to create immediately on every build if missing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.driverLocation != null && _driverMarker == null) {
          print('🔍 Driver marker missing in build(), creating NOW...');
          _updateDriverMarker();
        }
      });
    }
    
    return Stack(
      children: [
        // Main Mapbox Map
        MapWidget(
          key: const ValueKey("state_of_the_art_map_widget"),
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(widget.centerLng, widget.centerLat)),
            zoom: 15.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: (_) async {
            // Hide labels again after style is fully loaded (more reliable)
            if (_mapboxMap != null) {
              await NeighborhoodLabelsService.simplifyMapStyle(_mapboxMap!);
            }
          },
          onCameraChangeListener: (cameraChangedEventData) {
            // Notify parent when map is interacted with (but not for programmatic moves)
            if (widget.onCameraMoved != null && !_isProgrammaticCameraMove) {
              final center = cameraChangedEventData.cameraState.center;
              widget.onCameraMoved!(center.coordinates.lat.toDouble(), center.coordinates.lng.toDouble());
            }
          },
        ),
        // Floating Navigation Button - Moves with order card
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          bottom: widget.isOrderCardExpanded 
              ? 120.0  // When expanded, sit above expanded card (estimated height)
              : 80.0,  // When collapsed, sit above collapsed card (60px + margin)
          right: MediaQuery.of(context).size.width * 0.04,
          child: _StateOfTheArtNavigationButton(
            mapboxMap: _mapboxMap,
            activeOrder: widget.activeOrder,
            driverLocation: widget.driverLocation,
          ),
        ),
        // Removed status indicator monitor
      ],
    );
  }

  Widget _buildStatusIndicator() {
    final status = _navigationSystem.getStatus();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                status['initialized'] ? Icons.check_circle : Icons.error,
                color: status['initialized'] ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'State-of-the-Art Navigation',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${status['initialized'] ? 'Ready' : 'Not Ready'}',
            style: TextStyle(
              fontSize: 10,
              color: status['initialized'] ? Colors.green : Colors.red,
            ),
          ),
          Text(
            'Markers: ${status['markers']}, Routes: ${status['routes']}',
            style: const TextStyle(fontSize: 10),
          ),
          if (status['currentOrderId'] != null)
            Text(
              'Order: ${status['currentOrderId']}',
              style: const TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }
}

/// State-of-the-art navigation button
class _StateOfTheArtNavigationButton extends StatefulWidget {
  final MapboxMap? mapboxMap;
  final dynamic activeOrder;
  final dynamic driverLocation;

  const _StateOfTheArtNavigationButton({
    this.mapboxMap,
    this.activeOrder,
    this.driverLocation,
  });

  @override
  State<_StateOfTheArtNavigationButton> createState() => _StateOfTheArtNavigationButtonState();
}

class _StateOfTheArtNavigationButtonState extends State<_StateOfTheArtNavigationButton>
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
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    if (_isExpanded) {
      _toggleExpansion();
    }
  }

  void _navigateToDriverLocation() {
    if (widget.driverLocation == null) return;
    
    try {
      double? lat;
      double? lng;
      
      if (widget.driverLocation is Map) {
        lat = widget.driverLocation['latitude'];
        lng = widget.driverLocation['longitude'];
      } else {
        lat = widget.driverLocation.latitude;
        lng = widget.driverLocation.longitude;
      }
      
      if (lat != null && lng != null) {
        // Driver marker is now handled by the map widget directly with white circle arrowhead
        // StateOfTheArtNavigation().updateDriverLocation(lat, lng); // DISABLED
        _navigateToLocation(lat, lng, AppLocalizations.of(context).yourCurrentLocationLabel);
      }
    } catch (e) {
      print('❌ Error navigating to driver location: $e');
    }
  }

  void _navigateToStoreLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.pickupLatitude,
        widget.activeOrder.pickupLongitude,
        AppLocalizations.of(context).storeLocation,
      );
    }
  }

  void _navigateToDeliveryLocation() {
    if (widget.activeOrder != null) {
      _navigateToLocation(
        widget.activeOrder.deliveryLatitude,
        widget.activeOrder.deliveryLongitude,
        AppLocalizations.of(context).deliveryLocation,
      );
    }
  }

  void _showFullRoute() {
    if (widget.mapboxMap == null || widget.activeOrder == null) return;

    final pickupLat = widget.activeOrder.pickupLatitude;
    final pickupLng = widget.activeOrder.pickupLongitude;
    final deliveryLat = widget.activeOrder.deliveryLatitude;
    final deliveryLng = widget.activeOrder.deliveryLongitude;
    
    final centerLat = (pickupLat + deliveryLat) / 2;
    final centerLng = (pickupLng + deliveryLng) / 2;
    
    widget.mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 13.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1500),
    );

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
                      // Show full route
                      if (widget.activeOrder != null) ...[
                        Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Column(
                              children: [
                                _buildNavButton(
                                  icon: Icons.route,
                                  label: loc.showRoute,
                                  onTap: _showFullRoute,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                // Navigate to store
                                _buildNavButton(
                                  icon: Icons.store,
                                  label: loc.store,
                                  onTap: _navigateToStoreLocation,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                // Navigate to delivery
                                _buildNavButton(
                                  icon: Icons.flag,
                                  label: loc.delivery,
                                  onTap: _navigateToDeliveryLocation,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                // Navigate to driver location
                                if (widget.driverLocation != null)
                                  _buildNavButton(
                                    icon: Icons.my_location,
                                    label: loc.yourLocation,
                                    onTap: _navigateToDriverLocation,
                                    color: Colors.orange,
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        // Main floating button
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
          elevation: 0,
          shadowColor: Colors.transparent,
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
          ],
        ),
      ),
    );
  }
}
