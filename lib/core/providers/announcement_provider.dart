import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../../shared/widgets/announcement_dialog.dart';

/// Provider to manage and periodically check for announcements
class AnnouncementProvider extends ChangeNotifier {
  final AnnouncementService _announcementService = AnnouncementService();
  
  Timer? _checkTimer;
  List<AnnouncementModel> _announcements = [];
  Set<String> _shownAnnouncementIds = {};
  
  String? _userRole;
  String? _userId;
  BuildContext? _context;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the provider with user info and start checking
  Future<void> initialize({
    required String userRole,
    required String userId,
    required BuildContext context,
  }) async {
    _userRole = userRole;
    _userId = userId;
    _context = context;
    _isInitialized = true;

    print('🔔 AnnouncementProvider initialized for role: $userRole');
    
    // Check immediately on initialization
    await checkAndShowAnnouncements();
    
    // Then check every 5 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkAndShowAnnouncements();
    });
  }

  /// Check for new announcements and show them
  Future<void> checkAndShowAnnouncements() async {
    if (_userRole == null || _userId == null || _context == null) return;
    if (!_context!.mounted) return;

    try {
      print('🔍 Checking for announcements...');
      
      final announcements = await _announcementService
          .getUndismissedAnnouncements(_userRole!, _userId!);

      // Filter out announcements we've already shown in this session
      final newAnnouncements = announcements
          .where((a) => !_shownAnnouncementIds.contains(a.id))
          .toList();

      if (newAnnouncements.isEmpty) {
        return;
      }

      print('📢 Found ${newAnnouncements.length} new announcements to show');

      // Show each announcement
      for (final announcement in newAnnouncements) {
        if (!_context!.mounted) break;

        _shownAnnouncementIds.add(announcement.id);
        
        await showDialog(
          context: _context!,
          barrierDismissible: false,
          builder: (context) => AnnouncementDialog(
            announcement: announcement,
            userId: _userId!,
            onDismiss: () {
              // Mark as shown so we don't show it again in this session
              _shownAnnouncementIds.add(announcement.id);
            },
          ),
        );
      }

      _announcements = announcements;
      notifyListeners();
    } catch (e) {
      print('❌ Error checking announcements: $e');
    }
  }

  /// Stop checking for announcements
  void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    print('⏹️ Stopped checking for announcements');
  }

  /// Resume checking for announcements
  void resumeChecking() {
    if (_isInitialized && _checkTimer == null) {
      _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        checkAndShowAnnouncements();
      });
      print('▶️ Resumed checking for announcements');
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

