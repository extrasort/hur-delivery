import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ultimate_notification_service.dart';

/// Debug widget to test and monitor notification system
/// Add this to any dashboard to debug notifications
class NotificationDebugWidget extends StatefulWidget {
  const NotificationDebugWidget({super.key});

  @override
  State<NotificationDebugWidget> createState() => _NotificationDebugWidgetState();
}

class _NotificationDebugWidgetState extends State<NotificationDebugWidget> {
  String _status = 'Checking...';
  bool _isExpanded = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() {
    setState(() {
      _status = UltimateNotificationService.getStatus();
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_logs.length > 20) _logs.removeLast();
    });
  }

  Future<void> _sendTestNotification() async {
    _addLog('Sending test notification...');
    
    try {
      await UltimateNotificationService.sendTestNotification();
      _addLog('✅ Test notification sent to device');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _sendDatabaseTest() async {
    _addLog('Sending database test...');
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _addLog('❌ Not logged in');
        return;
      }

      final result = await Supabase.instance.client.rpc('send_test_notification', params: {
        'p_user_id': userId,
      });

      _addLog('✅ Database response: $result');
    } catch (e) {
      _addLog('❌ Database error: $e');
    }
  }

  Future<void> _checkRealtimeConnection() async {
    _addLog('Checking realtime connection...');
    
    try {
      final channels = Supabase.instance.client.getChannels();
      _addLog('Active channels: ${channels.length}');
      
      for (var channel in channels) {
        _addLog('Channel: ${channel.topic}');
      }

      if (channels.isEmpty) {
        _addLog('⚠️ No active channels! Service not started?');
      }
    } catch (e) {
      _addLog('❌ Error checking channels: $e');
    }
  }

  Future<void> _restartService() async {
    _addLog('Restarting notification service...');
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _addLog('❌ Not logged in');
        return;
      }

      await UltimateNotificationService.stop();
      _addLog('✅ Service stopped');
      
      await Future.delayed(const Duration(seconds: 1));
      
      await UltimateNotificationService.startListening(userId);
      _addLog('✅ Service restarted');
      
      _checkStatus();
    } catch (e) {
      _addLog('❌ Error restarting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text(
              '🔧 Notification Debug',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_status),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),

          if (_isExpanded) ...[
            const Divider(),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.notification_add, size: 18),
                    label: const Text('Test Local'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _sendDatabaseTest,
                    icon: const Icon(Icons.cloud, size: 18),
                    label: const Text('Test Database'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _checkRealtimeConnection,
                    icon: const Icon(Icons.wifi, size: 18),
                    label: const Text('Check Realtime'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _restartService,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Restart Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Logs
            Container(
              height: 200,
              color: Colors.black87,
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs yet. Press buttons above to test.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final color = log.contains('✅')
                            ? Colors.green
                            : log.contains('❌')
                                ? Colors.red
                                : log.contains('⚠️')
                                    ? Colors.orange
                                    : Colors.white;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

