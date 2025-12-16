import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/announcement_model.dart';
import 'error_manager.dart';

/// Service to manage system-wide announcements
class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  final _supabase = Supabase.instance.client;

  /// Get active announcements for the current user's role
  Future<List<AnnouncementModel>> getActiveAnnouncements(String userRole) async {
    return await ErrorManager.safeExecute<List<AnnouncementModel>>(
      operation: () async {
        print('🔍 Fetching announcements for role: $userRole');
        
        final response = await _supabase
            .from('system_announcements')
            .select()
            .eq('is_active', true)
            .contains('target_roles', [userRole])
            .order('created_at', ascending: false);

        print('📦 Raw response: ${response.length} announcements found');
        
        final announcements = (response as List)
            .map((json) {
              try {
                return AnnouncementModel.fromJson(json);
              } catch (e) {
                print('❌ Error parsing announcement: $e');
                return null;
              }
            })
            .whereType<AnnouncementModel>()
            .where((announcement) => announcement.isCurrentlyActive)
            .toList();

        print('✅ Active announcements: ${announcements.length}');
        return announcements;
      },
      operationName: 'fetch-announcements',
      isCritical: false,
      defaultValue: [],
    ) ?? [];
  }

  /// Get all announcements (for admin panel)
  Future<List<AnnouncementModel>> getAllAnnouncements() async {
    try {
      final response = await _supabase
          .from('system_announcements')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AnnouncementModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching all announcements: $e');
      return [];
    }
  }

  /// Check if user has dismissed a specific announcement
  Future<bool> hasUserDismissed(String announcementId, String userId) async {
    try {
      final response = await _supabase
          .from('announcement_dismissals')
          .select('id')
          .eq('announcement_id', announcementId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking dismissal: $e');
      return false;
    }
  }

  /// Dismiss an announcement for the current user
  Future<bool> dismissAnnouncement(String announcementId, String userId) async {
    try {
      await _supabase.from('announcement_dismissals').insert({
        'announcement_id': announcementId,
        'user_id': userId,
      });

      return true;
    } catch (e) {
      print('Error dismissing announcement: $e');
      return false;
    }
  }

  /// Get announcements that the user hasn't dismissed yet
  Future<List<AnnouncementModel>> getUndismissedAnnouncements(
    String userRole,
    String userId,
  ) async {
    try {
      // Get active announcements
      final announcements = await getActiveAnnouncements(userRole);

      // Filter out dismissed ones
      final undismissed = <AnnouncementModel>[];
      for (final announcement in announcements) {
        final dismissed = await hasUserDismissed(announcement.id, userId);
        if (!dismissed) {
          undismissed.add(announcement);
        }
      }

      return undismissed;
    } catch (e) {
      print('Error fetching undismissed announcements: $e');
      return [];
    }
  }

  /// Create a new announcement (admin only)
  Future<AnnouncementModel?> createAnnouncement({
    required String title,
    required String message,
    required AnnouncementType type,
    required bool isDismissable,
    required List<String> targetRoles,
    DateTime? startTime,
    DateTime? endTime,
    required String createdBy,
  }) async {
    try {
      final response = await _supabase
          .from('system_announcements')
          .insert({
            'title': title,
            'message': message,
            'type': type.value,
            'is_dismissable': isDismissable,
            'target_roles': targetRoles,
            'start_time': startTime?.toIso8601String(),
            'end_time': endTime?.toIso8601String(),
            'created_by': createdBy,
          })
          .select()
          .single();

      return AnnouncementModel.fromJson(response);
    } catch (e) {
      print('Error creating announcement: $e');
      return null;
    }
  }

  /// Update an announcement (admin only)
  Future<bool> updateAnnouncement(
    String announcementId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase
          .from('system_announcements')
          .update(updates)
          .eq('id', announcementId);

      return true;
    } catch (e) {
      print('Error updating announcement: $e');
      return false;
    }
  }

  /// Delete an announcement (admin only)
  Future<bool> deleteAnnouncement(String announcementId) async {
    try {
      await _supabase
          .from('system_announcements')
          .delete()
          .eq('id', announcementId);

      return true;
    } catch (e) {
      print('Error deleting announcement: $e');
      return false;
    }
  }

  /// Toggle announcement active status (admin only)
  Future<bool> toggleAnnouncementStatus(
    String announcementId,
    bool isActive,
  ) async {
    try {
      await _supabase
          .from('system_announcements')
          .update({'is_active': isActive})
          .eq('id', announcementId);

      return true;
    } catch (e) {
      print('Error toggling announcement status: $e');
      return false;
    }
  }

  /// Check if an announcement still exists and is active
  /// Used to auto-close dialogs when admin removes/deactivates an announcement
  Future<bool> checkAnnouncementActive(String announcementId) async {
    try {
      final response = await _supabase
          .from('system_announcements')
          .select('id, is_active, start_time, end_time')
          .eq('id', announcementId)
          .maybeSingle();

      // Announcement doesn't exist
      if (response == null) {
        print('❌ Announcement $announcementId no longer exists');
        return false;
      }

      // Announcement is not active
      if (response['is_active'] != true) {
        print('❌ Announcement $announcementId is not active');
        return false;
      }

      // Check time-based constraints
      final now = DateTime.now();
      
      // Check start time
      if (response['start_time'] != null) {
        final startTime = DateTime.parse(response['start_time']);
        if (now.isBefore(startTime)) {
          print('❌ Announcement $announcementId has not started yet');
          return false;
        }
      }

      // Check end time
      if (response['end_time'] != null) {
        final endTime = DateTime.parse(response['end_time']);
        if (now.isAfter(endTime)) {
          print('❌ Announcement $announcementId has ended');
          return false;
        }
      }

      // Announcement still exists and is active
      return true;
    } catch (e) {
      print('⚠️ Error checking announcement active status: $e');
      // Return true on error to avoid closing dialog unexpectedly
      return true;
    }
  }
}

