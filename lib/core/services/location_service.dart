import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Initialize location service
  static Future<void> initialize() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Check location permission
    final permission = await _checkLocationPermission();
    if (!permission) {
      throw Exception('Location permission denied');
    }
  }

  // Check location permission
  static Future<bool> _checkLocationPermission() async {
    final status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      return false;
    }
    
    return false;
  }

  // Get current position
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Get position stream
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  // Calculate distance between two points
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Calculate bearing between two points
  static double calculateBearing(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  // Check if location is within radius
  static bool isWithinRadius(
    double centerLat, double centerLon,
    double targetLat, double targetLon,
    double radiusInMeters,
  ) {
    final distance = calculateDistance(centerLat, centerLon, targetLat, targetLon);
    return distance <= radiusInMeters;
  }

  // Get formatted distance
  static String getFormattedDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} م';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} كم';
    }
  }

  // Get formatted duration
  static String getFormattedDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}س ${duration.inMinutes % 60}د';
    } else {
      return '${duration.inMinutes}د';
    }
  }

  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  // Open app settings
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
}
