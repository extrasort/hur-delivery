import 'package:flutter/material.dart';

/// System-wide announcement model
class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final AnnouncementType type;
  final bool isActive;
  final bool isDismissable;
  final List<String> targetRoles;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isActive,
    required this.isDismissable,
    required this.targetRoles,
    this.startTime,
    this.endTime,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: AnnouncementType.fromString(json['type'] as String),
      isActive: json['is_active'] as bool? ?? true,
      isDismissable: json['is_dismissable'] as bool? ?? true,
      targetRoles: (json['target_roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.value,
      'is_active': isActive,
      'is_dismissable': isDismissable,
      'target_roles': targetRoles,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if announcement is currently active
  bool get isCurrentlyActive {
    if (!isActive) return false;
    
    final now = DateTime.now();
    
    // Check start time
    if (startTime != null && now.isBefore(startTime!)) {
      return false;
    }
    
    // Check end time
    if (endTime != null && now.isAfter(endTime!)) {
      return false;
    }
    
    return true;
  }
}

/// Announcement type enum
enum AnnouncementType {
  maintenance('maintenance'),
  event('event'),
  update('update'),
  info('info'),
  warning('warning'),
  success('success');

  const AnnouncementType(this.value);
  final String value;

  static AnnouncementType fromString(String value) {
    return AnnouncementType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnnouncementType.info,
    );
  }

  /// Get color for this announcement type
  Color getColor() {
    switch (this) {
      case AnnouncementType.maintenance:
        return Colors.orange;
      case AnnouncementType.event:
        return Colors.purple;
      case AnnouncementType.update:
        return Colors.blue;
      case AnnouncementType.info:
        return Colors.cyan;
      case AnnouncementType.warning:
        return Colors.red;
      case AnnouncementType.success:
        return Colors.green;
    }
  }

  /// Get icon for this announcement type
  IconData getIcon() {
    switch (this) {
      case AnnouncementType.maintenance:
        return Icons.build;
      case AnnouncementType.event:
        return Icons.celebration;
      case AnnouncementType.update:
        return Icons.system_update;
      case AnnouncementType.info:
        return Icons.info;
      case AnnouncementType.warning:
        return Icons.warning;
      case AnnouncementType.success:
        return Icons.check_circle;
    }
  }

  /// Get Arabic label
  String getArabicLabel() {
    switch (this) {
      case AnnouncementType.maintenance:
        return 'صيانة';
      case AnnouncementType.event:
        return 'حدث';
      case AnnouncementType.update:
        return 'تحديث';
      case AnnouncementType.info:
        return 'معلومات';
      case AnnouncementType.warning:
        return 'تحذير';
      case AnnouncementType.success:
        return 'نجاح';
    }
  }
}

