import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';
import '../../shared/models/announcement_model.dart';
import '../../core/services/announcement_service.dart';
import '../../core/localization/app_localizations.dart';

/// Dialog to display system-wide announcements
class AnnouncementDialog extends StatefulWidget {
  final AnnouncementModel announcement;
  final String userId;
  final VoidCallback? onDismiss;

  const AnnouncementDialog({
    super.key,
    required this.announcement,
    required this.userId,
    this.onDismiss,
  });

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  Timer? _countdownTimer;
  Timer? _existenceCheckTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    if (!widget.announcement.isDismissable && widget.announcement.endTime != null) {
      _startCountdown();
    }
    
    // Always start checking if announcement still exists (for undismissable announcements)
    if (!widget.announcement.isDismissable) {
      _startExistenceCheck();
    }
  }

  void _startCountdown() {
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (widget.announcement.endTime != null) {
      final remaining = widget.announcement.endTime!.difference(DateTime.now());
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _remainingTime = remaining;
        });
      }
    }
  }

  /// Periodically check if the announcement still exists and is active
  void _startExistenceCheck() {
    print('🔍 Starting existence check for announcement: ${widget.announcement.id}');
    
    // Check every 3 seconds
    _existenceCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkAnnouncementExists();
    });
  }

  Future<void> _checkAnnouncementExists() async {
    try {
      // Check if announcement still exists and is active
      final stillExists = await AnnouncementService().checkAnnouncementActive(
        widget.announcement.id,
      );
      
      if (!stillExists && mounted) {
        print('✅ Announcement ${widget.announcement.id} was removed or deactivated - auto-closing dialog');
        _existenceCheckTimer?.cancel();
        _countdownTimer?.cancel();
        Navigator.of(context).pop();
        widget.onDismiss?.call();
      }
    } catch (e) {
      print('⚠️ Error checking announcement existence: $e');
      // Don't close on error - better to keep showing than to close unexpectedly
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _existenceCheckTimer?.cancel();
    super.dispose();
  }

  /// Show announcement dialog if there are any undismissed announcements
  static Future<void> showAnnouncementsIfAny({
    required BuildContext context,
    required String userRole,
    required String userId,
  }) async {
    try {
      print('🔔 Checking announcements for user: $userId, role: $userRole');
      
      final announcements = await AnnouncementService()
          .getUndismissedAnnouncements(userRole, userId);

      print('📢 Found ${announcements.length} undismissed announcements');

      if (announcements.isEmpty || !context.mounted) {
        print('⏭️ No announcements to show or context not mounted');
        return;
      }

      // Show announcements one by one
      for (final announcement in announcements) {
        if (!context.mounted) break;

        print('🎯 Showing announcement: ${announcement.title}');
        
        await showDialog(
          context: context,
          barrierDismissible: false, // Always block interaction - must use button to dismiss
          builder: (context) => AnnouncementDialog(
            announcement: announcement,
            userId: userId,
          ),
        );
      }
    } catch (e) {
      print('❌ Error showing announcements: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.85),
        body: Center(
          child: Container(
            margin: context.rp(horizontal: 24, vertical: 24),
            constraints: BoxConstraints(maxWidth: context.rw(450)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.rs(24)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Small icon at top
                SizedBox(height: context.rs(24)),
                Container(
                  width: context.rw(48),
                  height: context.rw(48),
                  decoration: BoxDecoration(
                    color: widget.announcement.type.getColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.announcement.type.getColor().withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.announcement.type.getIcon(),
                    color: Colors.white,
                    size: context.ri(24),
                  ),
                ),
                SizedBox(height: context.rs(20)),

                // Content box with title and message
                Container(
                  margin: context.rp(horizontal: 20, vertical: 0),
                  padding: context.rp(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: widget.announcement.type.getColor().withOpacity(0.05),
                    borderRadius: BorderRadius.circular(context.rs(16)),
                    border: Border.all(
                      color: widget.announcement.type.getColor().withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                // Title
                      ResponsiveText(
                    widget.announcement.title,
                    style: TextStyle(
                          fontSize: context.rf(20),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                          height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                      SizedBox(height: context.rs(12)),
                      
                      // Divider
                      Container(
                        height: 1,
                        width: context.rw(60),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.announcement.type.getColor().withOpacity(0),
                              widget.announcement.type.getColor().withOpacity(0.3),
                              widget.announcement.type.getColor().withOpacity(0),
                            ],
                          ),
                        ),
                ),
                      SizedBox(height: context.rs(12)),

                // Message
                      ResponsiveText(
                    widget.announcement.message,
                    style: TextStyle(
                          fontSize: context.rf(15),
                      color: AppColors.textSecondary,
                      height: 1.6,
                          letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Countdown for non-dismissable with end time
                if (!widget.announcement.isDismissable && _remainingTime != null) ...[
                  SizedBox(height: context.rs(16)),
                  Container(
                    padding: context.rp(horizontal: 16, vertical: 10),
                    margin: context.rp(horizontal: 20, vertical: 0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(context.rs(10)),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: AppColors.primary,
                          size: context.ri(18),
                        ),
                        SizedBox(width: context.rs(6)),
                        ResponsiveText(
                          _formatCountdown(_remainingTime!),
                          style: TextStyle(
                            fontSize: context.rf(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: context.rs(24)),

                // Action button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rs(20),
                    0,
                    context.rs(20),
                    context.rs(20),
                  ),
                  child: widget.announcement.isDismissable
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await AnnouncementService().dismissAnnouncement(
                                widget.announcement.id,
                                widget.userId,
                              );
                              
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                widget.onDismiss?.call();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.announcement.type.getColor(),
                              foregroundColor: Colors.white,
                              padding: context.rp(horizontal: 0, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.rs(12)),
                              ),
                              elevation: 2,
                              shadowColor: widget.announcement.type.getColor().withOpacity(0.4),
                            ),
                            child: ResponsiveText(
                              AppLocalizations.of(context).gotIt,
                              style: TextStyle(
                                fontSize: context.rf(16),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(), // Don't show message for non-dismissable
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final loc = AppLocalizations.of(context);
    if (duration.inDays > 0) {
      return loc.endsInDays(duration.inDays);
    } else if (duration.inHours > 0) {
      return loc.endsInHours(duration.inHours);
    } else if (duration.inMinutes > 0) {
      return loc.endsInMinutes(duration.inMinutes);
    } else {
      return loc.endsInSeconds(duration.inSeconds);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final loc = AppLocalizations.of(context);
    final months = [
      loc.january,
      loc.february,
      loc.march,
      loc.april,
      loc.may,
      loc.june,
      loc.july,
      loc.august,
      loc.september,
      loc.october,
      loc.november,
      loc.december,
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}


