import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceManager {
  static String? _deviceId;
  
  /// Get unique device identifier
  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        _deviceId = 'web_${webInfo.vendor}_${webInfo.userAgent?.hashCode}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = 'android_${androidInfo.id}'; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = 'ios_${iosInfo.identifierForVendor}';
      } else {
        _deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      return _deviceId!;
    } catch (e) {
      print('Error getting device ID: $e');
      // Fallback to timestamp-based ID
      _deviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      return _deviceId!;
    }
  }
  
  /// Get device info for display
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return {
          'platform': 'Web',
          'browser': webInfo.browserName.name,
          'device': 'Browser',
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'device': '${androidInfo.brand} ${androidInfo.model}',
          'version': 'Android ${androidInfo.version.release}',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'device': '${iosInfo.model}',
          'version': 'iOS ${iosInfo.systemVersion}',
        };
      }
      
      return {
        'platform': 'Unknown',
        'device': 'Unknown Device',
      };
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'platform': 'Unknown',
        'device': 'Unknown Device',
      };
    }
  }
}

