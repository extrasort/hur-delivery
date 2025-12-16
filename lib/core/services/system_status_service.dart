import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_manager.dart';

/// Service to check system status and handle maintenance mode
class SystemStatusService {
  static final SystemStatusService _instance = SystemStatusService._internal();
  factory SystemStatusService() => _instance;
  SystemStatusService._internal();

  final _supabase = Supabase.instance.client;
  
  bool _isSystemEnabled = true;
  DateTime? _lastCheck;
  Timer? _checkTimer;
  
  // Callbacks for status changes
  final List<Function(bool)> _statusChangeCallbacks = [];
  
  bool get isSystemEnabled => _isSystemEnabled;

  /// Start periodic checking (every 5 seconds)
  void startPeriodicChecking() {
    if (_checkTimer != null) return;
    
    print('🔄 Starting system status periodic checks...');
    
    // Check immediately
    checkSystemStatus();
    
    // Then check every 5 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkSystemStatus();
    });
  }

  /// Stop periodic checking
  void stopPeriodicChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    print('⏹️ Stopped system status periodic checks');
  }

  /// Check current system status
  Future<bool> checkSystemStatus() async {
    return await ErrorManager.safeExecute<bool>(
      operation: () async {
        final response = await _supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'system_enabled')
            .maybeSingle();

        final newStatus = response?['value'] == 'true';
        
        // If status changed, notify callbacks
        if (newStatus != _isSystemEnabled) {
          print('🔔 System status changed: ${newStatus ? "ENABLED" : "DISABLED"}');
          _isSystemEnabled = newStatus;
          _notifyStatusChange(newStatus);
        }
        
        _isSystemEnabled = newStatus;
        _lastCheck = DateTime.now();
        
        return _isSystemEnabled;
      },
      operationName: 'check-system-status',
      isCritical: false, // Non-critical - assume enabled on error
      defaultValue: true, // On error, assume system is enabled to avoid blocking users
    ) ?? true;
  }

  /// Register a callback for status changes
  void onStatusChange(Function(bool) callback) {
    _statusChangeCallbacks.add(callback);
  }

  /// Remove a callback
  void removeStatusCallback(Function(bool) callback) {
    _statusChangeCallbacks.remove(callback);
  }

  /// Notify all callbacks of status change
  void _notifyStatusChange(bool isEnabled) {
    for (final callback in _statusChangeCallbacks) {
      try {
        callback(isEnabled);
      } catch (e) {
        print('Error in status change callback: $e');
      }
    }
  }

  /// Force refresh status
  Future<void> refresh() async {
    await checkSystemStatus();
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicChecking();
    _statusChangeCallbacks.clear();
  }
}

