import 'package:flutter/material.dart';
import 'dart:async';

/// Anti-spam header notification service
/// Prevents the same notification from showing multiple times within a time period
class HeaderNotificationService {
  static final HeaderNotificationService _instance = HeaderNotificationService._internal();
  factory HeaderNotificationService() => _instance;
  HeaderNotificationService._internal();

  // Track shown notifications: key = notification hash, value = timestamp
  final Map<String, DateTime> _shownNotifications = {};
  
  // Anti-spam duration (same notification won't show again within this period)
  final Duration _antiSpamDuration = const Duration(seconds: 10);

  /// Check if a notification should be shown (not spam)
  bool shouldShow(String title, String message) {
    final hash = '${title}_$message'.hashCode.toString();
    final now = DateTime.now();

    if (_shownNotifications.containsKey(hash)) {
      final lastShown = _shownNotifications[hash]!;
      final difference = now.difference(lastShown);

      if (difference < _antiSpamDuration) {
        print('🚫 Anti-spam: Blocking duplicate notification (shown ${difference.inSeconds}s ago)');
        return false;
      }
    }

    // Mark as shown
    _shownNotifications[hash] = now;
    
    // Cleanup old entries (older than 5 minutes)
    _shownNotifications.removeWhere((key, timestamp) {
      return now.difference(timestamp) > const Duration(minutes: 5);
    });

    return true;
  }

  /// Reset anti-spam for a specific notification
  void reset(String title, String message) {
    final hash = '${title}_$message'.hashCode.toString();
    _shownNotifications.remove(hash);
  }

  /// Clear all notification history
  void clearAll() {
    _shownNotifications.clear();
  }
}

/// Show elegant pill-shaped header notification
void showHeaderNotification(
  BuildContext context, {
  required String title,
  required String message,
  NotificationType type = NotificationType.info,
  Duration duration = const Duration(seconds: 4),
  bool respectAntiSpam = true,
}) {
  // Anti-spam check
  if (respectAntiSpam) {
    if (!HeaderNotificationService().shouldShow(title, message)) {
      return; // Don't show - spam detected
    }
  }

  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _HeaderNotificationWidget(
      title: title,
      message: message,
      type: type,
      onDismiss: () {
        overlayEntry.remove();
      },
    ),
  );

  overlay.insert(overlayEntry);

  // Auto-dismiss after duration
  Future.delayed(duration, () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class _HeaderNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _HeaderNotificationWidget({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_HeaderNotificationWidget> createState() => _HeaderNotificationWidgetState();
}

class _HeaderNotificationWidgetState extends State<_HeaderNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF10B981); // Green
      case NotificationType.error:
        return const Color(0xFFEF4444); // Red
      case NotificationType.warning:
        return const Color(0xFFF59E0B); // Orange
      case NotificationType.info:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getBackgroundColor(),
                      _getBackgroundColor().withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _getBackgroundColor().withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.9),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
