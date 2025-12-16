import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_manager.dart';

/// Notification Watcher Service
/// 
/// Watches the notifications table via realtime and automatically
/// sends push notifications when new notifications are created
class NotificationWatcher {
  static StreamSubscription? _subscription;
  static final Set<String> _processedIds = {};
  static bool _isWatching = false;

  /// Start watching for new notifications
  static Future<void> startWatching() async {
    if (_isWatching) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      print('⚠️  Cannot watch notifications - user not authenticated');
      return;
    }

    print('\n═══════════════════════════════════════════════════════');
    print('👁️  NOTIFICATION WATCHER: Starting');
    print('═══════════════════════════════════════════════════════');
    print('User ID: ${currentUser.id}');
    print('═══════════════════════════════════════════════════════\n');

    try {
      _subscription = Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUser.id)
          .listen((data) async {
        
        for (var notification in data) {
          final id = notification['id'] as String;
          
          // Skip if already processed
          if (_processedIds.contains(id)) {
            continue;
          }
          
          // Mark as processed
          _processedIds.add(id);
          
          print('\n🔔 New notification detected in database');
          print('   ID: $id');
          print('   Type: ${notification['type']}');
          print('   Title: ${notification['title']}');
          
          // Send push notification via Edge Function
          try {
            final userId = notification['user_id'] as String;
            final title = notification['title'] as String;
            final body = notification['body'] as String;
            final type = notification['type'] as String;
            final data = notification['data'] as Map<String, dynamic>? ?? {};
            
            // Call NotificationManager to send via Edge Function
            final success = await NotificationManager.sendNotification(
              targetUserId: userId,
              title: title,
              body: body,
              type: type,
              data: data,
              skipDatabase: true, // Already in database
            );
            
            print('   Result: ${success ? "✅ SENT" : "❌ FAILED"}');
            
          } catch (e) {
            print('   ❌ Failed to send: $e');
          }
        }
      });

      _isWatching = true;
      print('✅ Notification watcher started successfully\n');

    } catch (e) {
      print('❌ Failed to start notification watcher: $e');
    }
  }

  /// Stop watching notifications
  static Future<void> stopWatching() async {
    await _subscription?.cancel();
    _subscription = null;
    _isWatching = false;
    _processedIds.clear();
    print('🛑 Notification watcher stopped');
  }

  /// Check if watching
  static bool get isWatching => _isWatching;
}






