import 'package:flutter/services.dart';
import 'dart:convert';

class NajafDistrict {
  final String name;
  final double latitude;
  final double longitude;

  NajafDistrict({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class NajafDistrictsService {
  static List<NajafDistrict>? _districts;
  static bool _isLoaded = false;

  /// Load districts from CSV file
  static Future<void> loadDistricts() async {
    if (_isLoaded) return;

    try {
      // Load CSV file from root directory
      final csvData = await rootBundle.loadString('Najaf Districts.csv');
      
      _districts = [];
      final lines = csvData.split('\n');
      
      // Skip header (line 0) and process data lines
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Skip empty lines
        if (line.isEmpty || line == ',,') continue;
        
        // Parse CSV line
        final parts = line.split(',');
        if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          try {
            final name = parts[0].trim();
            // Parse coordinates (format: "latitude, longitude")
            final coordParts = parts[1].trim().replaceAll('"', '').split(',');
            
            if (coordParts.length >= 2) {
              final latitude = double.parse(coordParts[0].trim());
              final longitude = double.parse(coordParts[1].trim());
              
              _districts!.add(NajafDistrict(
                name: name,
                latitude: latitude,
                longitude: longitude,
              ));
            }
          } catch (e) {
            print('Error parsing district line $i: $e');
          }
        }
      }
      
      _isLoaded = true;
      print('✅ Loaded ${_districts!.length} Najaf districts');
    } catch (e) {
      print('❌ Error loading Najaf districts: $e');
      _districts = [];
      _isLoaded = true;
    }
  }

  /// Get all districts
  static Future<List<NajafDistrict>> getAllDistricts() async {
    if (!_isLoaded) {
      await loadDistricts();
    }
    return _districts ?? [];
  }

  /// Search districts by name (supports partial matching)
  static Future<List<NajafDistrict>> searchDistricts(String query) async {
    if (!_isLoaded) {
      await loadDistricts();
    }
    
    if (query.isEmpty) {
      return _districts ?? [];
    }
    
    final normalizedQuery = query.trim().toLowerCase();
    
    return (_districts ?? []).where((district) {
      return district.name.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  /// Find exact match for a district name
  static Future<NajafDistrict?> findDistrictByName(String name) async {
    if (!_isLoaded) {
      await loadDistricts();
    }
    
    final normalizedName = name.trim();
    
    try {
      return (_districts ?? []).firstWhere(
        (district) => district.name == normalizedName,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get coordinates for a district name
  static Future<Map<String, double>?> getCoordinates(String name) async {
    final district = await findDistrictByName(name);
    if (district != null) {
      return {
        'latitude': district.latitude,
        'longitude': district.longitude,
      };
    }
    return null;
  }

  /// Check if an address matches any known district
  static Future<bool> isKnownDistrict(String address) async {
    if (!_isLoaded) {
      await loadDistricts();
    }
    
    final normalizedAddress = address.trim();
    
    return (_districts ?? []).any((district) => 
      normalizedAddress.contains(district.name) || 
      district.name.contains(normalizedAddress)
    );
  }
}

