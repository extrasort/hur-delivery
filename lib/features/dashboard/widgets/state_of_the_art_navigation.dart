import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../shared/models/order_model.dart';
import '../../../core/services/neighborhood_labels_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/route_cache_service.dart';

/// State-of-the-art navigation system using best practices
class StateOfTheArtNavigation {
  static final StateOfTheArtNavigation _instance =
      StateOfTheArtNavigation._internal();
  factory StateOfTheArtNavigation() => _instance;
  StateOfTheArtNavigation._internal();

  // Core managers
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _pointManager;
  CircleAnnotationManager? _circleManager;
  MapboxMap? _mapboxMap;

  // State
  bool _isInitialized = false;
  String? _currentOrderId;

  // Annotations
  final Map<String, PolylineAnnotation> _routes = {};
  final Map<String, PointAnnotation> _markers = {};
  List<PointAnnotation> _neighborhoodLabels = [];

  /// Initialize the state-of-the-art system
  Future<bool> initialize(MapboxMap mapboxMap) async {
    try {
      print('🚀 State-of-the-Art: Initializing navigation system...');

      _mapboxMap = mapboxMap;

      // Create annotation managers and prepare pins in parallel for instant loading
      await Future.wait([
        _mapboxMap!.annotations
            .createPolylineAnnotationManager()
            .then((m) => _polylineManager = m),
        _mapboxMap!.annotations
            .createPointAnnotationManager()
            .then((m) => _pointManager = m),
        _mapboxMap!.annotations
            .createCircleAnnotationManager()
            .then((m) => _circleManager = m),
        _prepareSquarePinImages(), // Prepare pins in parallel
      ]);

      print('✅ State-of-the-Art: Annotation managers and pins ready');

      _isInitialized = true;
      print(
          '✅ State-of-the-Art: Navigation system initialized successfully - ready for instant annotations');
      return true;
    } catch (e) {
      print('❌ State-of-the-Art: Initialization failed: $e');
      // Retry once immediately (no delay)
      try {
        await Future.wait([
          _mapboxMap!.annotations
              .createPolylineAnnotationManager()
              .then((m) => _polylineManager = m),
          _mapboxMap!.annotations
              .createPointAnnotationManager()
              .then((m) => _pointManager = m),
          _mapboxMap!.annotations
              .createCircleAnnotationManager()
              .then((m) => _circleManager = m),
          _prepareSquarePinImages(),
        ]);
        _isInitialized = true;
        print('✅ State-of-the-Art: Navigation system initialized on retry');
        return true;
      } catch (retryError) {
        print(
            '❌ State-of-the-Art: Initialization retry also failed: $retryError');
        return false;
      }
    }
  }

  /// Set active order with state-of-the-art navigation
  Future<void> setActiveOrder(OrderModel order) async {
    print('🎯 State-of-the-Art: Setting active order ${order.id}');

    // If not initialized, wait very briefly - initialization should be nearly instant
    if (!_isInitialized) {
      print('⚠️ State-of-the-Art: Not initialized, waiting briefly...');
      // Wait up to 300ms only - initialization should be instant
      int retries = 0;
      while (!_isInitialized && retries < 6) {
        await Future.delayed(const Duration(milliseconds: 50));
        retries++;
      }
      if (!_isInitialized) {
        print(
            '⚠️ State-of-the-Art: Not yet initialized, proceeding anyway (will retry)');
        // Don't return - proceed anyway, annotations will be created when ready
      } else {
        print(
            '✅ State-of-the-Art: Initialization completed, proceeding with order');
      }
    }

    try {
      // Clear previous order
      if (_currentOrderId != null && _currentOrderId != order.id) {
        await _clearOrder(_currentOrderId!);
      }

      _currentOrderId = order.id;

      // Create markers IMMEDIATELY and synchronously - await them to ensure they appear instantly
      // Create both markers in parallel for faster loading
      await Future.wait([
        _createPickupMarker(order),
        _createDropoffMarker(order),
      ]);
      print('✅ State-of-the-Art: Pickup and dropoff markers created instantly');

      // Create route immediately and await it so it appears instantly
      await _createRoute(order);
      print('✅ State-of-the-Art: Route created for order ${order.id}');

      print('✅ State-of-the-Art: Order ${order.id} set successfully');
    } catch (e) {
      print('❌ State-of-the-Art: Error setting order: $e');
    }
  }

  /// Prepare and register square pin images with numbers (1, 2)
  Future<void> _prepareSquarePinImages() async {
    try {
      // HIGH RESOLUTION (3x scale) - 48 * 3 = 144px
      const int squareSize = 144; // pinhead size (3x for high resolution)
      const int needleHeight = 36; // pointer height (12 * 3)
      final pickupBytes = await _drawSquarePin(
        number: '1',
        background: const Color(0xFF008C95), // Teal - matches AppColors.primary
        text: Colors.white,
        squareSize: squareSize,
        needleHeight: needleHeight,
      );
      final dropoffBytes = await _drawSquarePin(
        number: '2',
        background:
            const Color(0xFFF59E0B), // Orange - matches AppColors.warning
        text: Colors.white,
        squareSize: squareSize,
        needleHeight: needleHeight,
      );

      // Add to style with correct signature: (name, pixelRatio, sdf, stretchX, stretchY, content, image)
      // HIGH RESOLUTION - 3x scale
      await _mapboxMap!.style.addStyleImage(
        'pin-1',
        1.0,
        MbxImage(
            width: squareSize,
            height: squareSize + needleHeight,
            data: pickupBytes),
        false,
        const <ImageStretches>[],
        const <ImageStretches>[],
        null,
      );

      await _mapboxMap!.style.addStyleImage(
        'pin-2',
        1.0,
        MbxImage(
            width: squareSize,
            height: squareSize + needleHeight,
            data: dropoffBytes),
        false,
        const <ImageStretches>[],
        const <ImageStretches>[],
        null,
      );
    } catch (e) {
      print('❌ State-of-the-Art: Failed preparing square pins: $e');
    }
  }

  /// Draw a square pin with centered number and a small needle underneath
  Future<Uint8List> _drawSquarePin({
    required String number,
    required Color background,
    required Color text,
    required int squareSize,
    required int needleHeight,
  }) async {
    final totalWidth = squareSize;
    final totalHeight = squareSize + needleHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Square background
    final rect =
        Rect.fromLTWH(0, 0, squareSize.toDouble(), squareSize.toDouble());
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final bgPaint = Paint()..color = background;
    canvas.drawRRect(rrect, bgPaint);

    // Needle (triangle) centered at bottom
    final double cx = squareSize / 2.0;
    final double base = squareSize * 0.28; // narrow base
    final Path needle = Path()
      ..moveTo(cx, totalHeight.toDouble())
      ..lineTo(cx - base / 2.0, squareSize.toDouble())
      ..lineTo(cx + base / 2.0, squareSize.toDouble())
      ..close();
    canvas.drawPath(needle, bgPaint);

    // Border around square and needle
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = squareSize * 0.06;
    canvas.drawRRect(rrect, border);
    canvas.drawPath(needle, border);

    // Number text centered inside square
    final textPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w900,
          fontSize: squareSize * 0.46,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: squareSize.toDouble());

    final offset = Offset(
      (squareSize - textPainter.width) / 2,
      (squareSize - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalWidth, totalHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Create pickup marker using custom image
  Future<void> _createPickupMarker(OrderModel order) async {
    try {
      final markerId = '${order.id}_pickup';

      print(
          '📍 State-of-the-Art: Creating pickup marker at ${order.pickupLatitude}, ${order.pickupLongitude}');

      // Only remove if marker already exists (prevent flickering)
      if (_markers.containsKey(markerId)) {
        await _removeMarker(markerId);
      }

      // Create marker using custom square-numbered pin (1) - HIGH RES
      final marker = await _pointManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(order.pickupLongitude, order.pickupLatitude),
          ),
          iconImage: 'pin-1',
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: 1000.0,
        ),
      );

      _markers[markerId] = marker;
      print('✅ State-of-the-Art: Pickup marker created');
    } catch (e) {
      print('❌ State-of-the-Art: Error creating pickup marker: $e');
    }
  }

  /// Create dropoff marker using custom image
  Future<void> _createDropoffMarker(OrderModel order) async {
    try {
      final markerId = '${order.id}_dropoff';

      print(
          '📍 State-of-the-Art: Creating dropoff marker at ${order.deliveryLatitude}, ${order.deliveryLongitude}');

      // Only remove if marker already exists (prevent flickering)
      if (_markers.containsKey(markerId)) {
        await _removeMarker(markerId);
      }

      // Create marker using custom square-numbered pin (2) - HIGH RES
      final marker = await _pointManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates:
                Position(order.deliveryLongitude, order.deliveryLatitude),
          ),
          iconImage: 'pin-2',
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: 1000.0,
        ),
      );

      _markers[markerId] = marker;
      print('✅ State-of-the-Art: Dropoff marker created');
    } catch (e) {
      print('❌ State-of-the-Art: Error creating dropoff marker: $e');
    }
  }

  /// Create route using state-of-the-art Directions API
  Future<void> _createRoute(OrderModel order) async {
    try {
      final routeId = '${order.id}_route';

      print('🛣️ State-of-the-Art: Creating route for order ${order.id}');

      // Only remove if route already exists (prevent flickering)
      if (_routes.containsKey(routeId)) {
        await _removeRoute(routeId);
      }

      // Get route coordinates using proper API format
      final coordinates = await _getRouteCoordinates(order);

      if (coordinates.isNotEmpty) {
        print(
            '🛣️ State-of-the-Art: Creating polyline with ${coordinates.length} points');

        final polyline = await _polylineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coordinates),
            lineColor: Colors.blue.value,
            lineWidth: 4.0,
            lineOpacity: 0.8,
          ),
        );

        _routes[routeId] = polyline;
        print('✅ State-of-the-Art: Route created successfully');
      } else {
        print(
            '⚠️ State-of-the-Art: No route coordinates, creating straight line');
        await _createStraightLineRoute(order);
      }
    } catch (e) {
      print('❌ State-of-the-Art: Error creating route: $e');
      await _createStraightLineRoute(order);
    }
  }

  /// Force recalculation of route and dropoff marker for an updated order
  Future<void> recalculateRouteForOrder(OrderModel order) async {
    try {
      if (!_isInitialized || _mapboxMap == null) return;
      _currentOrderId = order.id;
      // Remove existing route and dropoff marker, then recreate
      await _removeRoute('${order.id}_route');
      await _removeMarker('${order.id}_dropoff');
      await _createDropoffMarker(order);
      await _createRoute(order);
    } catch (e) {
      print('❌ State-of-the-Art: Error recalculating route: $e');
    }
  }

  CircleAnnotation? _driverDot;

  /// Update or create the driver's blue dot on the map
  /// NOTE: This is disabled - driver marker is now handled by the map widget directly
  /// with a white circle arrowhead marker instead of a blue dot
  Future<void> updateDriverLocation(double latitude, double longitude) async {
    // DISABLED: Driver marker is now created directly in the map widget
    // as a white circle with arrowhead using PointAnnotation, not CircleAnnotation
    // This prevents the blue dot from appearing and conflicting with the proper marker
    return;
  }

  /// Get route coordinates using state-of-the-art Directions API
  Future<List<Position>> _getRouteCoordinates(OrderModel order) async {
    try {
      final token = AppConstants.mapboxAccessToken;
      if (token.isEmpty) {
        print(
            '⚠️ State-of-the-Art: Mapbox token unavailable, skipping API call.');
        return [];
      }

      final cached = await RouteCacheService.getCachedRoute(
        orderId: order.id,
        pickupLat: order.pickupLatitude,
        pickupLng: order.pickupLongitude,
        dropoffLat: order.deliveryLatitude,
        dropoffLng: order.deliveryLongitude,
      );

      if (cached != null && cached.isNotEmpty) {
        print(
            '✅ State-of-the-Art: Loaded ${cached.length} cached route points for order ${order.id}');
        return cached.map((pair) => Position(pair[0], pair[1])).toList();
      }

      final coordinatesPath =
          '${order.pickupLongitude},${order.pickupLatitude};${order.deliveryLongitude},${order.deliveryLatitude}';
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinatesPath'
        '?alternatives=true&geometries=geojson&language=en&overview=full&steps=true&access_token=$token',
      );

      print(
          '🌐 State-of-the-Art: Calling Mapbox Directions API via cURL equivalent:');
      print('   curl "$uri"');

      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        print(
            '🌐 State-of-the-Art: API Response Status: ${response.statusCode}');

        if (response.statusCode != 200) {
          print(
              '⚠️ State-of-the-Art: Directions API failed: ${response.statusCode} – $responseBody');
          return [];
        }

        final data = json.decode(responseBody) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes == null || routes.isEmpty) {
          print(
              '⚠️ State-of-the-Art: No routes returned for order ${order.id}');
          return [];
        }

        final geometry = routes.first['geometry'];
        List<List<double>> coordinatePairs = [];

        if (geometry is Map && geometry['coordinates'] != null) {
          final coords = geometry['coordinates'] as List;
          coordinatePairs = coords.map<List<double>>((coord) {
            final values = (coord as List).cast<num>();
            return [values[0].toDouble(), values[1].toDouble()];
          }).toList();
        } else if (geometry is String) {
          coordinatePairs = _decodePolyline(geometry);
        }

        if (coordinatePairs.isEmpty) {
          print('⚠️ State-of-the-Art: Empty geometry for order ${order.id}');
          return [];
        }

        await RouteCacheService.cacheRoute(
          orderId: order.id,
          pickupLat: order.pickupLatitude,
          pickupLng: order.pickupLongitude,
          dropoffLat: order.deliveryLatitude,
          dropoffLng: order.deliveryLongitude,
          coordinates: coordinatePairs,
        );

        print(
            '✅ State-of-the-Art: Cached ${coordinatePairs.length} route points for order ${order.id}');
        return coordinatePairs
            .map((pair) => Position(pair[0], pair[1]))
            .toList();
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ State-of-the-Art: API error: $e');
      return [];
    }
  }

  /// Decode polyline geometry into [lng, lat] coordinate pairs.
  List<List<double>> _decodePolyline(String encoded) {
    final coordinates = <List<double>>[];
    int index = 0;
    int latE5 = 0;
    int lngE5 = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      latE5 += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lngE5 += dLng;

      coordinates.add([
        lngE5 / 1e5,
        latE5 / 1e5,
      ]);
    }

    return coordinates;
  }

  /// Create straight line route as fallback
  Future<void> _createStraightLineRoute(OrderModel order) async {
    try {
      final routeId = '${order.id}_route';

      print('📏 State-of-the-Art: Creating straight line route');

      final polyline = await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              Position(order.pickupLongitude, order.pickupLatitude),
              Position(order.deliveryLongitude, order.deliveryLatitude),
            ],
          ),
          lineColor: Colors.blue.value,
          lineWidth: 4.0,
          lineOpacity: 0.8,
        ),
      );

      _routes[routeId] = polyline;
      print('✅ State-of-the-Art: Straight line route created');
    } catch (e) {
      print('❌ State-of-the-Art: Error creating straight line route: $e');
    }
  }

  /// Remove marker
  Future<void> _removeMarker(String markerId) async {
    if (_markers.containsKey(markerId)) {
      try {
        await _pointManager!.delete(_markers[markerId]!);
        _markers.remove(markerId);
        print('🗑️ State-of-the-Art: Marker removed - $markerId');
      } catch (e) {
        print('❌ State-of-the-Art: Error removing marker: $e');
      }
    }
  }

  /// Remove route
  Future<void> _removeRoute(String routeId) async {
    if (_routes.containsKey(routeId)) {
      try {
        await _polylineManager!.delete(_routes[routeId]!);
        _routes.remove(routeId);
        print('🗑️ State-of-the-Art: Route removed - $routeId');
      } catch (e) {
        print('❌ State-of-the-Art: Error removing route: $e');
      }
    }
  }

  /// Clear order (public method for immediate clearing)
  Future<void> clearOrder(String orderId) async {
    try {
      await _removeMarker('${orderId}_pickup');
      await _removeMarker('${orderId}_dropoff');
      await _removeRoute('${orderId}_route');
      
      // Also clear current order ID if it matches
      if (_currentOrderId == orderId) {
        _currentOrderId = null;
      }
      
      print('🧹 State-of-the-Art: Order $orderId cleared');
    } catch (e) {
      print('❌ State-of-the-Art: Error clearing order: $e');
    }
  }
  
  /// Clear order (private method - kept for internal use)
  Future<void> _clearOrder(String orderId) async {
    await clearOrder(orderId);
  }

  /// Clear annotations for orders that are not in the provided active order IDs list
  /// This ensures orphaned annotations are removed when orders lose driver assignment
  Future<void> clearOrphanedAnnotations(List<String> activeOrderIds) async {
    try {
      final activeIdsSet = activeOrderIds.toSet();
      
      // Find markers and routes that belong to orders no longer active
      final markersToRemove = <String>[];
      final routesToRemove = <String>[];
      
      for (final markerId in _markers.keys) {
        // Extract order ID from marker ID (format: orderId_pickup or orderId_dropoff)
        final orderId = markerId.split('_').first;
        if (!activeIdsSet.contains(orderId)) {
          markersToRemove.add(markerId);
        }
      }
      
      for (final routeId in _routes.keys) {
        // Extract order ID from route ID (format: orderId_route)
        final orderId = routeId.split('_').first;
        if (!activeIdsSet.contains(orderId)) {
          routesToRemove.add(routeId);
        }
      }
      
      // Remove orphaned markers
      for (final markerId in markersToRemove) {
        await _removeMarker(markerId);
        print('🧹 State-of-the-Art: Removed orphaned marker - $markerId');
      }
      
      // Remove orphaned routes
      for (final routeId in routesToRemove) {
        await _removeRoute(routeId);
        print('🧹 State-of-the-Art: Removed orphaned route - $routeId');
      }
      
      // Clear current order ID if it's no longer active
      if (_currentOrderId != null && !activeIdsSet.contains(_currentOrderId!)) {
        print('🧹 State-of-the-Art: Current order $_currentOrderId no longer active, clearing');
        _currentOrderId = null;
      }
      
      if (markersToRemove.isNotEmpty || routesToRemove.isNotEmpty) {
        print('🧹 State-of-the-Art: Cleared ${markersToRemove.length} orphaned markers and ${routesToRemove.length} orphaned routes');
      }
    } catch (e) {
      print('❌ State-of-the-Art: Error clearing orphaned annotations: $e');
    }
  }

  /// Clear all annotations (routes + markers) in a single sweep
  Future<void> clearAll() async {
    if (!_isInitialized) {
      print('⚠️ State-of-the-Art: clearAll called before initialization');
      return;
    }
    try {
      // Fast-path manager cleanup (Mapbox docs recommend removing annotations via manager)
      // Ref: https://docs.mapbox.com/ios/maps/api/6.4.1/Classes/MGLMapView.html#//api/name/removeAnnotations: (removeAnnotations removes everything)
      if (_pointManager != null) {
        try {
          await _pointManager!.deleteAll();
        } catch (e) {
          print('⚠️ State-of-the-Art: deleteAll on pointManager failed ($e), falling back to per-marker cleanup');
          for (final marker in _markers.values) {
            try {
              await _pointManager!.delete(marker);
            } catch (inner) {
              print('⚠️ State-of-the-Art: Error deleting marker: $inner');
            }
          }
        }
      }
      if (_polylineManager != null) {
        try {
          await _polylineManager!.deleteAll();
        } catch (e) {
          print('⚠️ State-of-the-Art: deleteAll on polylineManager failed ($e), falling back to per-route cleanup');
          for (final route in _routes.values) {
            try {
              await _polylineManager!.delete(route);
            } catch (inner) {
              print('⚠️ State-of-the-Art: Error deleting route: $inner');
        }
      }
        }
      }
      if (_circleManager != null) {
        try {
          await _circleManager!.deleteAll();
        } catch (e) {
          print('⚠️ State-of-the-Art: deleteAll on circleManager failed ($e)');
      if (_driverDot != null) {
        try {
              await _circleManager!.delete(_driverDot!);
        } catch (_) {}
          }
        }
      }

      _markers.clear();
      _routes.clear();
      _driverDot = null;
      _currentOrderId = null;
      print('🧹 State-of-the-Art: All annotations cleared via manager deleteAll');
    } catch (e) {
      print('❌ State-of-the-Art: Error clearing all: $e');
    }
  }

  /// Get status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'currentOrderId': _currentOrderId,
      'markers': _markers.length,
      'routes': _routes.length,
    };
  }

  /// Dispose
  void dispose() {
    clearAll();
    _isInitialized = false;
    print('🗑️ State-of-the-Art: Disposed');
  }
}
