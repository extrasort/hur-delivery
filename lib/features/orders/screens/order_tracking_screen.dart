import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/neighborhood_labels_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/route_cache_service.dart';
import '../../../core/localization/app_localizations.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Timer? _driverLocationTimer;
  Map<String, dynamic>? _driverLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().initialize();
      _startDriverLocationTracking();
    });
  }

  @override
  void dispose() {
    _driverLocationTimer?.cancel();
    super.dispose();
  }

  void _startDriverLocationTracking() {
    // Fetch driver location every 3 seconds
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchDriverLocation();
    });
    // Initial fetch
    _fetchDriverLocation();
  }

  Future<void> _fetchDriverLocation() async {
    final order = context.read<OrderProvider>().getOrderById(widget.orderId);
    if (order == null || order.driverId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('driver_locations')
          .select()
          .eq('driver_id', order.driverId!)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _driverLocation = response;
        });
      }
    } catch (e) {
      print('Error fetching driver location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon:
                Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            AppLocalizations.of(context).trackDriver,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          final order = orderProvider.getOrderById(widget.orderId);

          if (order == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Stack(
            children: [
              // Full-screen Map
              _TrackingMapWidget(
                order: order,
                driverLocation: _driverLocation,
              ),

              // Status overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(order.status),
                        _getStatusColor(order.status).withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(order.status),
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.statusDisplay,
                                  style: AppTextStyles.heading3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (order.driverName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${AppLocalizations.of(context).merchantLabel}: ${order.driverName}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (order.driverPhone != null &&
                          order.driverPhone!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Call driver
                              // Implement call functionality
                            },
                            icon: const Icon(Icons.phone, color: Colors.white),
                            label: Text(
                                '${AppLocalizations.of(context).callTitle} ${AppLocalizations.of(context).merchantLabel}',
                                style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'assigned':
      case 'accepted':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'assigned':
      case 'accepted':
        return AppColors.statusAccepted;
      case 'on_the_way':
        return AppColors.statusInProgress;
      case 'delivered':
        return AppColors.statusCompleted;
      case 'cancelled':
      case 'rejected':
        return AppColors.statusCancelled;
      default:
        return AppColors.textTertiary;
    }
  }
}

// Map Widget for Real-Time Driver Tracking
class _TrackingMapWidget extends StatefulWidget {
  final dynamic order;
  final Map<String, dynamic>? driverLocation;

  const _TrackingMapWidget({
    required this.order,
    this.driverLocation,
  });

  @override
  State<_TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<_TrackingMapWidget> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  PointAnnotation? _driverMarker;
  PointAnnotation? _pickupMarker;
  PointAnnotation? _dropoffMarker;
  PolylineAnnotation? _routePolyline;
  List<PointAnnotation> _neighborhoodLabels = [];

  bool _isMapReady = false;
  bool _customIconsLoaded = false;

  @override
  void initState() {
    super.initState();
    print('🗺️ Tracking map widget initialized');
  }

  @override
  void didUpdateWidget(_TrackingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isMapReady) {
      // Update driver marker ONLY if location actually changed
      final oldLat = oldWidget.driverLocation?['latitude'];
      final oldLng = oldWidget.driverLocation?['longitude'];
      final newLat = widget.driverLocation?['latitude'];
      final newLng = widget.driverLocation?['longitude'];

      if (newLat != null &&
          newLng != null &&
          (newLat != oldLat || newLng != oldLng)) {
        print(
            '📍 Driver location changed: ($oldLat, $oldLng) → ($newLat, $newLng)');
        _updateDriverMarker();
      }
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    print('🗺️ Map created, initializing...');

    // CRITICAL: Hide labels FIRST before anything else to prevent race condition
    await NeighborhoodLabelsService.simplifyMapStyle(mapboxMap);

    // Start aggressive label hiding timer to continuously hide labels
    NeighborhoodLabelsService.startLabelHidingTimer(mapboxMap);

    // Set up listener to continuously hide labels when style loads
    NeighborhoodLabelsService.setupLabelHidingListener(mapboxMap);

    // Add custom icons
    await _loadCustomIcons();

    // Create annotation managers
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    _polylineAnnotationManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();

    // Neighborhood labels removed

    setState(() {
      _isMapReady = true;
    });

    // Add markers and route
    await _setupMapContent();

    print('✅ Tracking map ready with neighborhood labels');
  }

  Future<void> _loadCustomIcons() async {
    if (_customIconsLoaded || _mapboxMap == null) return;

    try {
      // Load driver location marker (blue circle with black arrowhead)
      // Create with default heading (0° = North) for initial load
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

      // Load pickup pin icon with number "1" (same as driver dashboard) - High Resolution
      final pickupPinBytes =
          await _createNumberedPinIcon(AppColors.primary, '1');
      await _mapboxMap!.style.addStyleImage(
        'pickup-pin',
        1.0,
        MbxImage(width: 120, height: 165, data: pickupPinBytes),
        false,
        [],
        [],
        null,
      );

      // Load dropoff pin icon with number "2" (same as driver dashboard) - High Resolution
      final dropoffPinBytes =
          await _createNumberedPinIcon(AppColors.success, '2');
      await _mapboxMap!.style.addStyleImage(
        'dropoff-pin',
        1.0,
        MbxImage(width: 120, height: 165, data: dropoffPinBytes),
        false,
        [],
        [],
        null,
      );

      _customIconsLoaded = true;
      print('✅ Custom icons loaded (bike + numbered pins)');
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

  Future<Uint8List> _createNumberedPinIcon(Color color, String number) async {
    // Create a beautiful PIN icon with number inside - HIGH RESOLUTION (3x scale)
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.5 // 3.5 * 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Pin head (larger circle to accommodate number) - SCALED 3x
    final circleCenter = const Offset(60, 51); // (20, 17) * 3
    final circleRadius = 42.0; // 14.0 * 3

    // Draw circle with white outline
    canvas.drawCircle(circleCenter, circleRadius, strokePaint);
    canvas.drawCircle(circleCenter, circleRadius, fillPaint);

    // Draw pin stem (narrow line from circle to point) - SCALED 3x
    final stemPath = Path()
      ..moveTo(60, circleCenter.dy + circleRadius - 3) // (20, ...) * 3
      ..lineTo(60, 150); // 50 * 3

    final stemStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24.0 // 8.0 * 3
      ..strokeCap = StrokeCap.round;

    final stemPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0 // 5.0 * 3
      ..strokeCap = StrokeCap.round;

    // Draw stem with white outline then color
    canvas.drawPath(stemPath, stemStrokePaint);
    canvas.drawPath(stemPath, stemPaint);

    // Draw pin point (filled circle at bottom) - SCALED 3x
    canvas.drawCircle(const Offset(60, 150), 12.0,
        Paint()..color = Colors.white); // (20, 50, 4.0) * 3
    canvas.drawCircle(const Offset(60, 150), 9.0,
        Paint()..color = color); // (20, 50, 3.0) * 3

    // Draw NUMBER inside the circle head - SCALED 3x
    final textPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 60, // 20 * 3
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - textPainter.width / 2,
        circleCenter.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(120, 165); // (40, 55) * 3
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _setupMapContent() async {
    if (!_isMapReady || !_customIconsLoaded) return;

    // Add pickup marker
    await _addPickupMarker();

    // Add delivery marker
    await _addDeliveryMarker();

    // Add driver marker if location available
    if (widget.driverLocation != null) {
      await _updateDriverMarker();
    }

    // Calculate and show route
    await _addRoute();

    // Fit camera to show all markers
    _fitCameraToContent();
  }

  Future<void> _addPickupMarker() async {
    if (_pointAnnotationManager == null) return;

    try {
      _pickupMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              widget.order.pickupLongitude,
              widget.order.pickupLatitude,
            ),
          ),
          iconImage: 'pickup-pin',
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      print('✅ Pickup marker added');
    } catch (e) {
      print('❌ Error adding pickup marker: $e');
    }
  }

  Future<void> _addDeliveryMarker() async {
    if (_pointAnnotationManager == null) return;

    try {
      _dropoffMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              widget.order.deliveryLongitude,
              widget.order.deliveryLatitude,
            ),
          ),
          iconImage: 'dropoff-pin',
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      print('✅ Delivery marker added');
    } catch (e) {
      print('❌ Error adding delivery marker: $e');
    }
  }

  Future<void> _updateDriverMarker() async {
    if (_pointAnnotationManager == null ||
        widget.driverLocation == null ||
        _mapboxMap == null) return;

    try {
      // Get heading/bearing from driver location if available
      final heading = widget.driverLocation!['heading'] as double?;

      // Remove old marker
      if (_driverMarker != null) {
        await _pointAnnotationManager!.delete(_driverMarker!);
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
            coordinates: Position(
              widget.driverLocation!['longitude'],
              widget.driverLocation!['latitude'],
            ),
          ),
          iconImage:
              'driver-bike', // Blue circle with black arrowhead (high-res 96x96)
          iconSize: 0.33, // Scale to 1/3 for original size with 3x resolution
        ),
      );
      print(
          '✅ Driver location marker updated (blue circle with black arrowhead${heading != null ? ', heading: $heading°' : ''})');
    } catch (e) {
      print('❌ Error updating driver marker: $e');
    }
  }

  Future<void> _addRoute() async {
    if (_polylineAnnotationManager == null) return;

    final accessToken = AppConstants.mapboxAccessToken;
    if (accessToken.isEmpty) {
      print('⚠️ Mapbox access token missing; skipping route generation.');
      return;
    }

    try {
      final cachedRoute = await RouteCacheService.getCachedRoute(
        orderId: widget.order.id,
        pickupLat: widget.order.pickupLatitude,
        pickupLng: widget.order.pickupLongitude,
        dropoffLat: widget.order.deliveryLatitude,
        dropoffLng: widget.order.deliveryLongitude,
      );

      List<Position> routePositions = [];

      if (cachedRoute != null && cachedRoute.isNotEmpty) {
        routePositions =
            cachedRoute.map((pair) => Position(pair[0], pair[1])).toList();
        print('✅ Loaded route for order ${widget.order.id} from cache');
      } else {
        final coordinatesPath =
            '${widget.order.pickupLongitude},${widget.order.pickupLatitude};'
            '${widget.order.deliveryLongitude},${widget.order.deliveryLatitude}';

        final uri = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinatesPath'
          '?geometries=geojson&overview=full&access_token=$accessToken',
        );

        // Mirrors the official Mapbox cURL example:
        // curl "https://api.mapbox.com/directions/v5/mapbox/driving/{pickup_lng},{pickup_lat};{dropoff_lng},{dropoff_lat}?geometries=geojson&overview=full&access_token=YOUR_TOKEN"
        final response = await http.get(uri);

        if (response.statusCode != 200) {
          print(
            '❌ Mapbox Directions failed (${response.statusCode}): ${response.body}',
          );
          return;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes == null || routes.isEmpty) {
          print(
              '⚠️ Mapbox Directions returned no routes for ${widget.order.id}');
          return;
        }

        final geometry = routes.first['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List?;
        if (coordinates == null || coordinates.isEmpty) {
          print(
              '⚠️ Mapbox Directions returned empty geometry for ${widget.order.id}');
          return;
        }

        final coordinatePairs = coordinates.map<List<double>>((coord) {
          final list = (coord as List).cast<num>();
          return [list[0].toDouble(), list[1].toDouble()];
        }).toList();

        routePositions =
            coordinatePairs.map((pair) => Position(pair[0], pair[1])).toList();

        await RouteCacheService.cacheRoute(
          orderId: widget.order.id,
          pickupLat: widget.order.pickupLatitude,
          pickupLng: widget.order.pickupLongitude,
          dropoffLat: widget.order.deliveryLatitude,
          dropoffLng: widget.order.deliveryLongitude,
          coordinates: coordinatePairs,
        );

        print(
            '✅ Route calculated via Mapbox Directions for order ${widget.order.id}');
      }

      if (routePositions.isEmpty) return;

      if (_routePolyline != null) {
        await _polylineAnnotationManager!.delete(_routePolyline!);
        _routePolyline = null;
      }

      _routePolyline = await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: routePositions),
          lineColor: AppColors.primary.value,
          lineWidth: 4.0,
        ),
      );
      print('✅ Route added to tracking map for order ${widget.order.id}');
    } catch (e) {
      print('❌ Error adding route: $e');
    }
  }

  void _fitCameraToContent() {
    if (_mapboxMap == null) return;

    try {
      // Center camera between pickup and delivery
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
              coordinates: Position(
            (widget.order.pickupLongitude + widget.order.deliveryLongitude) / 2,
            (widget.order.pickupLatitude + widget.order.deliveryLatitude) / 2,
          )),
          zoom: 13.0,
          padding: MbxEdgeInsets(
            top: 100,
            left: 50,
            bottom: 200,
            right: 50,
          ),
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      print('❌ Error fitting camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('merchant_tracking_map'),
      cameraOptions: CameraOptions(
        center: Point(
            coordinates: Position(
          widget.order.pickupLongitude,
          widget.order.pickupLatitude,
        )),
        zoom: 13.0,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      textureView: true,
      onMapCreated: _onMapCreated,
      onScrollListener: (_) {},
      onStyleLoadedListener: (_) {
        print('✅ Style loaded');
      },
    );
  }
}

// Map-only tracking view - Removed all unnecessary card widgets
