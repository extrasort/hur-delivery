import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/neighborhood_labels_service.dart';
import '../../../core/localization/app_localizations.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.title,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  List<PointAnnotation> _neighborhoodLabels = [];
  double _currentLatitude = AppConstants.defaultLatitude;
  double _currentLongitude = AppConstants.defaultLongitude;
  String _selectedAddress = '';

  @override
  void initState() {
    super.initState();
    _selectedAddress = AppLocalizations.of(context).moveMapSelectLocation;
    // Always use user's current location when opening the map
    _setToCurrentLocation();
  }
  
  Future<void> _setToCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });
        
        // Update map camera to user location if map is ready
        if (_mapboxMap != null) {
          _mapboxMap?.flyTo(
            CameraOptions(
              center: Point(
                coordinates: Position(position.longitude, position.latitude),
              ),
              zoom: 15.0,
            ),
            MapAnimationOptions(duration: 500),
          );
          // Update location after animation
          Future.delayed(const Duration(milliseconds: 600), () {
            _updateLocationFromCamera();
          });
        }
      }
    } catch (e) {
      print('Could not get current location: $e');
      // Fallback to Baghdad default
      if (mounted) {
        setState(() {
          _currentLatitude = AppConstants.defaultLatitude;
          _currentLongitude = AppConstants.defaultLongitude;
        });
      }
    }
  }

  void _updateLocationFromCamera() async {
    if (_mapboxMap == null) return;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;
      
      final lat = center.coordinates.lat.toDouble();
      final lng = center.coordinates.lng.toDouble();
      
      final loc = AppLocalizations.of(context);
      setState(() {
        _currentLatitude = lat;
        _currentLongitude = lng;
        _selectedAddress = loc.gettingAddress;
      });
      
      // Reverse geocode to get address
      final address = await GeocodingService.reverseGeocode(lat, lng);
      
      if (mounted) {
        setState(() {
          _selectedAddress = address ?? loc.locationSelected;
        });
      }
    } catch (e) {
      print('Error getting camera position: $e');
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      
      // Update location after animation
      Future.delayed(const Duration(milliseconds: 1100), () {
        _updateLocationFromCamera();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).cannotGetCurrentLocation),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'latitude': _currentLatitude,
      'longitude': _currentLongitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Map
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  _currentLongitude,
                  _currentLatitude,
                ),
              ),
              zoom: 13.0,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: (MapboxMap mapboxMap) async {
              _mapboxMap = mapboxMap;
              
              // CRITICAL: Hide labels FIRST before anything else to prevent race condition
              await NeighborhoodLabelsService.simplifyMapStyle(mapboxMap);
              
              // Start aggressive label hiding timer to continuously hide labels
              NeighborhoodLabelsService.startLabelHidingTimer(mapboxMap);
              
              // Set up listener to continuously hide labels when style loads
              NeighborhoodLabelsService.setupLabelHidingListener(mapboxMap);
              
          // Create annotation manager (neighborhood labels removed)
          _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
              
              _updateLocationFromCamera();
            },
            onCameraChangeListener: (cameraChangedEventData) {
              // Update location when camera movement ends
              _updateLocationFromCamera();
            },
          ),

          // Center Pin (Fixed at screen center)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pin icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                // Pin shadow/point
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Instructions Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
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
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).moveMapToSelect,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            right: 16,
            top: 120,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _goToMyLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).myLocation,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              width: double.infinity,
              height: 60, // Increased height
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _confirmLocation,
                icon: const Icon(Icons.check, color: Colors.white, size: 22),
                label: Text(
                  AppLocalizations.of(context).confirmLocation,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Added padding
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
