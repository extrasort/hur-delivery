import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GeocodingService {
  // Reverse geocode using Mapbox Geocoding API v6
  // Returns the most accurate address possible using the new v6 API
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      // Check if we have a Mapbox token
      if (AppConstants.mapboxAccessToken.isEmpty) {
        print('⚠️ Mapbox token not available, returning coordinates');
        return 'الموقع: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      }

      // Use the new v6 API endpoint
      final url = Uri.parse(
        'https://api.mapbox.com/search/geocode/v6/reverse?'
        'longitude=$longitude&'
        'latitude=$latitude&'
        'access_token=${AppConstants.mapboxAccessToken}&'
        'language=ar&'
        'types=address,street,place,locality,neighborhood&'
        'limit=1'
      );

      print('🗺️ Reverse geocoding: lat=$latitude, lng=$longitude');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final feature = data['features'][0];
          final properties = feature['properties'] as Map<String, dynamic>?;
          
          if (properties != null) {
            // Try to get the most detailed address possible
            // Priority: full_address > name + place_formatted > name > place_formatted
            
            final fullAddress = properties['full_address'] as String?;
            if (fullAddress != null && fullAddress.isNotEmpty) {
              print('✅ Reverse geocoded to full_address: $fullAddress');
              return fullAddress;
            }
            
            final name = properties['name'] as String?;
            final placeFormatted = properties['place_formatted'] as String?;
            
            if (name != null && placeFormatted != null) {
              final combined = '$name، $placeFormatted';
              print('✅ Reverse geocoded to name+place: $combined');
              return combined;
            }
            
            if (name != null && name.isNotEmpty) {
              print('✅ Reverse geocoded to name: $name');
              return name;
            }
            
            if (placeFormatted != null && placeFormatted.isNotEmpty) {
              print('✅ Reverse geocoded to place_formatted: $placeFormatted');
              return placeFormatted;
            }
            
            // Try to build from context if available
            final context = properties['context'] as Map<String, dynamic>?;
            if (context != null) {
              final addressParts = <String>[];
              
              // Try to get address components from context
              final addressContext = context['address'] as Map<String, dynamic>?;
              if (addressContext != null) {
                final addressName = addressContext['name'] as String?;
                if (addressName != null && addressName.isNotEmpty) {
                  addressParts.add(addressName);
                }
              }
              
              final streetContext = context['street'] as Map<String, dynamic>?;
              if (streetContext != null) {
                final streetName = streetContext['name'] as String?;
                if (streetName != null && streetName.isNotEmpty && !addressParts.contains(streetName)) {
                  addressParts.add(streetName);
                }
              }
              
              final placeContext = context['place'] as Map<String, dynamic>?;
              if (placeContext != null) {
                final placeName = placeContext['name'] as String?;
                if (placeName != null && placeName.isNotEmpty) {
                  addressParts.add(placeName);
                }
              }
              
              if (addressParts.isNotEmpty) {
                final builtAddress = addressParts.join('، ');
                print('✅ Reverse geocoded to built address: $builtAddress');
                return builtAddress;
              }
            }
          }
        }
      } else {
        print('❌ Reverse geocoding failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
      
      // Fallback to coordinates if geocoding fails
      return 'الموقع: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      
    } catch (e, stackTrace) {
      print('❌ Reverse geocoding error: $e');
      print('Stack trace: $stackTrace');
      // Return coordinates as fallback
      return 'الموقع: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }

  // Forward geocode (search for address) using v6 API
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.trim().isEmpty) return [];
    
    // Check if we have a Mapbox token
    if (AppConstants.mapboxAccessToken.isEmpty) {
      print('⚠️ Mapbox token not available for forward geocoding');
      return [];
    }
    
    try {
      // Use the new v6 API endpoint
      final url = Uri.parse(
        'https://api.mapbox.com/search/geocode/v6/forward?'
        'q=${Uri.encodeComponent(query)}&'
        'access_token=${AppConstants.mapboxAccessToken}&'
        'language=ar&'
        'country=IQ&'  // Limit to Iraq
        'proximity=44.3661,33.3152&'  // Prefer results near Baghdad (longitude,latitude)
        'types=address,street,place,locality,neighborhood&'
        'limit=5'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        
        if (features != null) {
          return features.map((feature) {
            final properties = feature['properties'] as Map<String, dynamic>?;
            final coordinates = properties?['coordinates'] as Map<String, dynamic>?;
            
            final name = properties?['name'] as String? ?? '';
            final placeFormatted = properties?['place_formatted'] as String? ?? '';
            final fullAddress = properties?['full_address'] as String?;
            
            // Prefer full_address, otherwise combine name and place_formatted
            final displayName = fullAddress ?? 
                (name.isNotEmpty && placeFormatted.isNotEmpty 
                    ? '$name، $placeFormatted' 
                    : (name.isNotEmpty ? name : placeFormatted));
            
            final lat = (coordinates?['latitude'] as num?)?.toDouble();
            final lng = (coordinates?['longitude'] as num?)?.toDouble();
            
            return {
              'name': displayName,
              'text': name,
              'latitude': lat,
              'longitude': lng,
            };
          }).where((item) => item['latitude'] != null && item['longitude'] != null).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Forward geocoding error: $e');
      return [];
    }
  }

  // Forward geocode for Najaf specifically (converts written address to coordinates) using v6 API
  static Future<Map<String, dynamic>?> geocodeNajafAddress(String address) async {
    // Check if we have a Mapbox token
    if (AppConstants.mapboxAccessToken.isEmpty) {
      print('⚠️ Mapbox token not available, using Najaf center');
      return {
        'latitude': 32.0039,
        'longitude': 44.3291,
        'address': 'النجف',
        'original_address': address,
      };
    }
    
    try {
      // Ensure address includes Najaf if not mentioned
      String searchQuery = address;
      if (!address.contains('نجف') && !address.toLowerCase().contains('najaf')) {
        searchQuery = '$address، النجف';
      }

      // Najaf coordinates for proximity biasing: 32.0039° N, 44.3291° E
      // Note: v6 API uses longitude,latitude for proximity
      final url = Uri.parse(
        'https://api.mapbox.com/search/geocode/v6/forward?'
        'q=${Uri.encodeComponent(searchQuery)}&'
        'access_token=${AppConstants.mapboxAccessToken}&'
        'language=ar&'
        'country=IQ&'  // Limit to Iraq
        'proximity=44.3291,32.0039&'  // Center on Najaf (longitude,latitude)
        'bbox=44.2,31.9,44.5,32.2&'  // Bounding box around Najaf (minLon,minLat,maxLon,maxLat)
        'types=address,street,place,locality&'
        'limit=1'
      );

      print('🗺️ Geocoding Najaf address (v6): $searchQuery');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        
        if (features != null && features.isNotEmpty) {
          final feature = features[0];
          final properties = feature['properties'] as Map<String, dynamic>?;
          final coordinates = properties?['coordinates'] as Map<String, dynamic>?;
          
          final lat = (coordinates?['latitude'] as num?)?.toDouble();
          final lng = (coordinates?['longitude'] as num?)?.toDouble();
          
          // Get the best available address string
          final fullAddress = properties?['full_address'] as String?;
          final name = properties?['name'] as String?;
          final placeFormatted = properties?['place_formatted'] as String?;
          final formattedAddress = fullAddress ?? 
              (name != null && placeFormatted != null 
                  ? '$name، $placeFormatted' 
                  : (name ?? placeFormatted ?? 'النجف'));
          
          if (lat != null && lng != null) {
            print('✅ Geocoded to: lat=$lat, lng=$lng');
            print('✅ Address: $formattedAddress');
            
            return {
              'latitude': lat,
              'longitude': lng,
              'address': formattedAddress,
              'original_address': address,
            };
          }
        }
      } else {
        print('❌ Najaf geocoding failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
      
      // If geocoding fails, return Najaf center coordinates as fallback
      print('⚠️ Geocoding failed, using Najaf center');
      return {
        'latitude': 32.0039,
        'longitude': 44.3291,
        'address': 'النجف',
        'original_address': address,
      };
      
    } catch (e, stackTrace) {
      print('❌ Najaf geocoding error: $e');
      print('Stack trace: $stackTrace');
      // Return Najaf center as fallback
      return {
        'latitude': 32.0039,
        'longitude': 44.3291,
        'address': 'النجف',
        'original_address': address,
      };
    }
  }

  // Get formatted address with district/city using v6 API
  static Future<Map<String, String>> getFormattedAddress(
    double latitude, 
    double longitude
  ) async {
    // Check if we have a Mapbox token
    if (AppConstants.mapboxAccessToken.isEmpty) {
      return {
        'full': 'الموقع: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
        'short': 'موقع محدد',
        'street': '',
        'district': '',
        'city': 'بغداد',
      };
    }
    
    try {
      // Use v6 API
      final url = Uri.parse(
        'https://api.mapbox.com/search/geocode/v6/reverse?'
        'longitude=$longitude&'
        'latitude=$latitude&'
        'access_token=${AppConstants.mapboxAccessToken}&'
        'language=ar&'
        'types=address,street,neighborhood,locality,place&'
        'limit=1'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final feature = data['features'][0];
          final properties = feature['properties'] as Map<String, dynamic>?;
          final context = properties?['context'] as Map<String, dynamic>?;
          
          String? district;
          String? city;
          String? street;
          
          // Extract components from context (v6 structure)
          if (context != null) {
            final addressContext = context['address'] as Map<String, dynamic>?;
            if (addressContext != null) {
              street = addressContext['name'] as String?;
            }
            
            final streetContext = context['street'] as Map<String, dynamic>?;
            if (streetContext != null && street == null) {
              street = streetContext['name'] as String?;
            }
            
            final neighborhoodContext = context['neighborhood'] as Map<String, dynamic>?;
            if (neighborhoodContext != null) {
              district = neighborhoodContext['name'] as String?;
            }
            
            final localityContext = context['locality'] as Map<String, dynamic>?;
            if (localityContext != null && district == null) {
              district = localityContext['name'] as String?;
            }
            
            final placeContext = context['place'] as Map<String, dynamic>?;
            if (placeContext != null) {
              city = placeContext['name'] as String?;
            }
          }
          
          // Get name from properties if street not found
          if (street == null || street.isEmpty) {
            street = properties?['name'] as String?;
          }
          
          // Build formatted address
          final fullAddress = properties?['full_address'] as String? ?? 
              properties?['name'] as String? ?? '';
          
          final shortAddress = [
            if (street != null && street.isNotEmpty) street,
            if (district != null && district.isNotEmpty) district,
            if (city != null && city.isNotEmpty) city,
          ].join('، ');
          
          return {
            'full': fullAddress.isNotEmpty ? fullAddress : shortAddress,
            'short': shortAddress.isNotEmpty ? shortAddress : fullAddress,
            'street': street ?? '',
            'district': district ?? '',
            'city': city ?? 'بغداد',
          };
        }
      }
      
      // Fallback
      return {
        'full': 'الموقع: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
        'short': 'موقع محدد',
        'street': '',
        'district': '',
        'city': 'بغداد',
      };
      
    } catch (e) {
      print('Get formatted address error: $e');
      return {
        'full': 'الموقع: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
        'short': 'موقع محدد',
        'street': '',
        'district': '',
        'city': 'بغداد',
      };
    }
  }
}

