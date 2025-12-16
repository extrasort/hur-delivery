import 'package:flutter/material.dart';
import '../services/system_status_service.dart';

/// Provider to manage system-wide status (maintenance mode)
class SystemStatusProvider extends ChangeNotifier {
  final SystemStatusService _systemStatusService = SystemStatusService();
  
  bool _isSystemEnabled = true;
  bool _isChecking = false;
  
  bool get isSystemEnabled => _isSystemEnabled;
  bool get isChecking => _isChecking;
  bool get isMaintenanceMode => !_isSystemEnabled;

  /// Initialize and start checking
  Future<void> initialize() async {
    print('🔧 Initializing SystemStatusProvider...');
    
    // Check immediately
    await checkStatus();
    
    // Start periodic checking
    _systemStatusService.startPeriodicChecking();
    
    // Listen for status changes
    _systemStatusService.onStatusChange((isEnabled) {
      _isSystemEnabled = isEnabled;
      notifyListeners();
    });
    
    print('✅ SystemStatusProvider initialized');
  }

  /// Manually check system status
  Future<void> checkStatus() async {
    _isChecking = true;
    notifyListeners();
    
    try {
      _isSystemEnabled = await _systemStatusService.checkSystemStatus();
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Refresh status
  Future<void> refresh() async {
    await _systemStatusService.refresh();
  }

  @override
  void dispose() {
    _systemStatusService.dispose();
    super.dispose();
  }
}

