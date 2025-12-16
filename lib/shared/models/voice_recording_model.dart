class VoiceRecording {
  final String id;
  final String merchantId;
  final String storagePath;
  final String filename;
  final int? durationSeconds;
  final int? fileSizeBytes;
  final String? transcription;
  final Map<String, dynamic>? extractedData;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  VoiceRecording({
    required this.id,
    required this.merchantId,
    required this.storagePath,
    required this.filename,
    this.durationSeconds,
    this.fileSizeBytes,
    this.transcription,
    this.extractedData,
    this.notes,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  factory VoiceRecording.fromJson(Map<String, dynamic> json) {
    return VoiceRecording(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      storagePath: json['storage_path'] as String,
      filename: json['filename'] as String,
      durationSeconds: json['duration_seconds'] as int?,
      fileSizeBytes: json['file_size_bytes'] as int?,
      transcription: json['transcription'] as String?,
      extractedData: json['extracted_data'] as Map<String, dynamic>?,
      notes: json['notes'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastUsedAt: json['last_used_at'] != null 
          ? DateTime.parse(json['last_used_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant_id': merchantId,
        'storage_path': storagePath,
        'filename': filename,
        'duration_seconds': durationSeconds,
        'file_size_bytes': fileSizeBytes,
        'transcription': transcription,
        'extracted_data': extractedData,
        'notes': notes,
        'is_archived': isArchived,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_used_at': lastUsedAt?.toIso8601String(),
      };

  VoiceRecording copyWith({
    String? id,
    String? merchantId,
    String? storagePath,
    String? filename,
    int? durationSeconds,
    int? fileSizeBytes,
    String? transcription,
    Map<String, dynamic>? extractedData,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return VoiceRecording(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      storagePath: storagePath ?? this.storagePath,
      filename: filename ?? this.filename,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      transcription: transcription ?? this.transcription,
      extractedData: extractedData ?? this.extractedData,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  // Helper getters
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSizeBytes == null) return '--';
    if (fileSizeBytes! < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes! < 1024 * 1024) {
      return '${(fileSizeBytes! / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} دقيقة';
      }
      return '${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  bool get hasTranscription => transcription != null && transcription!.isNotEmpty;
  bool get hasExtractedData => extractedData != null && extractedData!.isNotEmpty;
}

