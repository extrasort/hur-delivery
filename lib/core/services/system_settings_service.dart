import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to fetch and manage system settings from the database
class SystemSettingsService {
  static final SystemSettingsService _instance = SystemSettingsService._internal();
  factory SystemSettingsService() => _instance;
  SystemSettingsService._internal();

  final _supabase = Supabase.instance.client;
  
  // Cache for settings
  final Map<String, String> _settingsCache = {};
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Get a system setting by key
  Future<String?> getSetting(String key) async {
    try {
      // Check cache first
      if (_settingsCache.containsKey(key) && _lastFetchTime != null) {
        if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
          return _settingsCache[key];
        }
      }

      // Fetch from database
      final response = await _supabase
          .from('system_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final value = response['value'] as String;
        _settingsCache[key] = value;
        _lastFetchTime = DateTime.now();
        return value;
      }

      return null;
    } catch (e) {
      print('Error fetching system setting $key: $e');
      
      // Check for 401 errors (session expired)
      if (e is PostgrestException && e.code == '401') {
        print('🔐 Session expired while fetching system setting - clearing cache');
        _settingsCache.clear();
        _lastFetchTime = null;
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        print('🔐 Unauthorized access while fetching system setting - clearing cache');
        _settingsCache.clear();
        _lastFetchTime = null;
      }
      
      return null;
    }
  }

  /// Get support phone number
  Future<String> getSupportPhone() async {
    final phone = await getSetting('support_phone');
    return phone ?? '+964771234567'; // Fallback to default
  }

  /// Get multiple settings at once
  Future<Map<String, String>> getSettings(List<String> keys) async {
    try {
      final response = await _supabase
          .from('system_settings')
          .select('key, value')
          .inFilter('key', keys);

      final Map<String, String> settings = {};
      for (final row in response as List) {
        settings[row['key'] as String] = row['value'] as String;
      }

      // Update cache
      _settingsCache.addAll(settings);
      _lastFetchTime = DateTime.now();

      return settings;
    } catch (e) {
      print('Error fetching system settings: $e');
      return {};
    }
  }

  /// Clear cache to force refresh
  void clearCache() {
    _settingsCache.clear();
    _lastFetchTime = null;
  }
}

