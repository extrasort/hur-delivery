import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to check app version against minimum required version
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  final _supabase = Supabase.instance.client;

  /// Get the minimum required app version from database
  Future<String?> getMinimumRequiredVersion() async {
    try {
      final response = await _supabase
          .from('system_settings')
          .select('value')
          .eq('key', 'min_app_version')
          .maybeSingle();

      if (response == null) {
        print('⚠️ min_app_version not found in database');
        return null;
      }

      final version = response['value'] as String?;
      print('📱 Minimum required version from DB: $version');
      return version;
    } catch (e) {
      print('❌ Error fetching minimum app version: $e');
      
      // Check for 401 errors (session expired)
      if (e is PostgrestException && e.code == '401') {
        print('🔐 Session expired while fetching app version - using fallback');
        return '1.0.0'; // Fallback version
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        print('🔐 Unauthorized access while fetching app version - using fallback');
        return '1.0.0'; // Fallback version
      }
      
      return null;
    }
  }

  /// Get current app version
  Future<String> getCurrentAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      print('📱 Current app version: $version');
      return version;
    } catch (e) {
      print('❌ Error getting current app version: $e');
      return '0.0.0'; // Default fallback
    }
  }

  /// Check if app needs to be updated
  /// Returns true if update is required, false otherwise
  Future<bool> isUpdateRequired() async {
    try {
      final currentVersion = await getCurrentAppVersion();
      final minVersion = await getMinimumRequiredVersion();

      // If no minimum version is set, no update required
      if (minVersion == null || minVersion.isEmpty) {
        print('✅ No minimum version set - update not required');
        return false;
      }

      final needsUpdate = _compareVersions(currentVersion, minVersion) < 0;
      
      if (needsUpdate) {
        print('🔴 UPDATE REQUIRED: Current ($currentVersion) < Required ($minVersion)');
      } else {
        print('✅ Version OK: Current ($currentVersion) >= Required ($minVersion)');
      }

      return needsUpdate;
    } catch (e) {
      print('❌ Error checking version requirement: $e');
      
      // Check for 401 errors (session expired) - skip version check if no auth
      if (e is PostgrestException && e.code == '401') {
        print('🔐 No session for version check - skipping update requirement');
        return false;
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        print('🔐 Unauthorized access for version check - skipping update requirement');
        return false;
      }
      
      // If version check fails for other reasons, assume no update required to not block users
      return false;
    }
  }

  /// Compare two semantic version strings
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Ensure both have 3 parts (major.minor.patch)
    while (parts1.length < 3) parts1.add(0);
    while (parts2.length < 3) parts2.add(0);

    // Compare major version
    if (parts1[0] != parts2[0]) {
      return parts1[0].compareTo(parts2[0]);
    }

    // Compare minor version
    if (parts1[1] != parts2[1]) {
      return parts1[1].compareTo(parts2[1]);
    }

    // Compare patch version
    return parts1[2].compareTo(parts2[2]);
  }

  /// Get version comparison result as a readable string
  Future<String> getVersionStatus() async {
    final currentVersion = await getCurrentAppVersion();
    final minVersion = await getMinimumRequiredVersion();

    if (minVersion == null || minVersion.isEmpty) {
      return 'الإصدار الحالي: $currentVersion';
    }

    final comparison = _compareVersions(currentVersion, minVersion);
    
    if (comparison < 0) {
      return 'الإصدار الحالي: $currentVersion (يجب التحديث إلى $minVersion)';
    } else if (comparison == 0) {
      return 'الإصدار الحالي: $currentVersion (محدث)';
    } else {
      return 'الإصدار الحالي: $currentVersion (أحدث من المطلوب: $minVersion)';
    }
  }
}

