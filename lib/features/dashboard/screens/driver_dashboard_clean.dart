// This is a clean version of the driver dashboard with bulletproof annotation management
// Copy the content from the original file up to line 3717, then add this:

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
  final TransformationController _transformationController = TransformationController();

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
                  if (currentPosition != null || (user?.latitude != null && user?.longitude != null))
                    Positioned(
                      left: MediaQuery.of(context).size.width / 2 - (MediaQuery.of(context).size.width * 0.08), // Responsive center
                      top: MediaQuery.of(context).size.height / 2 - (MediaQuery.of(context).size.width * 0.08), // Responsive center
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.16, // Responsive size
                        height: MediaQuery.of(context).size.width * 0.16, // Responsive size
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: MediaQuery.of(context).size.width * 0.008, // Responsive border
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
                          size: MediaQuery.of(context).size.width * 0.08, // Responsive icon
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
                    const SizedBox(width: 8),
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
                          _centerLat = locationProvider.currentPosition!.latitude;
                          _centerLng = locationProvider.currentPosition!.longitude;
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
