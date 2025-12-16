import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/localization/app_localizations.dart';

class MapScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  
  const MapScreen({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  Point? _selectedLocation;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _addInitialMarker();
  }

  void _addInitialMarker() {
    if (_mapboxMap != null) {
      _mapboxMap!.annotations.createPointAnnotationManager().then((manager) {
        _pointAnnotationManager = manager;
        _addMarker(widget.initialLatitude, widget.initialLongitude, AppLocalizations.of(context).yourCurrentLocation);
      });
    }
  }

  void _addMarker(double lat, double lng, String title) {
    if (_pointAnnotationManager != null) {
      _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          textField: title,
          textColor: 0xFF000000,
          textHaloColor: 0xFFFFFFFF,
          textHaloWidth: 2.0,
          iconImage: 'default_marker',
        ),
      );
    }
  }

  void _onMapTapped(Point point) {
    setState(() {
      _selectedLocation = point;
    });
    
    if (_pointAnnotationManager != null) {
      _pointAnnotationManager!.deleteAll();
      _addMarker(
        point.coordinates.lat.toDouble(),
        point.coordinates.lng.toDouble(),
        AppLocalizations.of(context).selectedLocation,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    final position = await locationProvider.getCurrentLocation();
    
    if (position != null && _mapboxMap != null) {
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      
      if (_pointAnnotationManager != null) {
        _pointAnnotationManager!.deleteAll();
        _addMarker(position.latitude, position.longitude, AppLocalizations.of(context).yourCurrentLocation);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).map),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Temporary placeholder for web testing
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              border: Border.all(color: Colors.grey),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Column(
                        children: [
                          Text(
                            loc.map,
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.mapboxIntegrationProgress,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // Return dummy coordinates for testing
                              Navigator.pop(context, Position(widget.initialLongitude, widget.initialLatitude));
                            },
                            child: Text(loc.selectThisLocation),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Location Info Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).tapMapSelectLocation,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Action Buttons
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(AppLocalizations.of(context).myCurrentLocation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedLocation != null
                        ? () {
                            // Handle location selection
                            Navigator.pop(context, _selectedLocation!.coordinates);
                          }
                        : null,
                    icon: const Icon(Icons.check),
                    label: Text(AppLocalizations.of(context).confirmLocation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
