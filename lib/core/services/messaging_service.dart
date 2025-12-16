import 'dart:async';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain exception for all messaging operations.
class MessagingException implements Exception {
  const MessagingException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() =>
      'MessagingException(code: $code, message: $message, details: $details)';
}

/// Representation of a single conversation participant.
class ConversationParticipant {
  const ConversationParticipant({
    required this.id,
    this.role,
    this.name,
    this.raw,
  });

  final String id;
  final String? role;
  final String? name;
  final Map<String, dynamic>? raw;

  factory ConversationParticipant.fromMap(Map<String, dynamic> map) {
    final user = (map['user'] as Map?)?.cast<String, dynamic>();
    final id = (map['user_id'] as String?) ?? (user?['id'] as String?) ?? '';
    return ConversationParticipant(
      id: id,
      role: (user?['role'] as String?) ?? (map['role'] as String?),
      name: (user?['name'] as String?) ?? (map['name'] as String?),
      raw: {
        ...map,
        if (user != null) 'user': user,
      },
    );
  }
}

/// Representation of a conversation record.
class Conversation {
  const Conversation({
    required this.id,
    required this.isSupport,
    this.orderId,
    this.title,
    this.createdAt,
    this.participants = const [],
    this.raw,
  });

  final String id;
  final bool isSupport;
  final String? orderId;
  final String? title;
  final DateTime? createdAt;
  final List<ConversationParticipant> participants;
  final Map<String, dynamic>? raw;

  factory Conversation.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at']?.toString();
    DateTime? createdAt;
    if (createdAtRaw != null) {
      try {
        createdAt = DateTime.parse(createdAtRaw).toUtc();
      } catch (_) {
        createdAt = null;
      }
    }
    final participants = (map['conversation_participants'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(ConversationParticipant.fromMap)
            .toList() ??
        const <ConversationParticipant>[];

    return Conversation(
      id: map['id'] as String,
      isSupport: map['is_support'] == true,
      orderId: map['order_id'] as String?,
      title: map['title'] as String?,
      createdAt: createdAt,
      participants: participants,
      raw: Map<String, dynamic>.from(map),
    );
  }
}

/// Representation of a message record.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.kind,
    this.senderId,
    this.orderId,
    this.createdAt,
    this.replyToMessageId,
    this.attachmentUrl,
    this.attachmentType,
    this.raw,
    this.isOptimistic = false,
  });

  final String id;
  final String conversationId;
  final String body;
  final String kind;
  final String? senderId;
  final String? orderId;
  final DateTime? createdAt;
  final String? replyToMessageId;
  final String? attachmentUrl;
  final String? attachmentType;
  final Map<String, dynamic>? raw;
  final bool isOptimistic;

  bool get isSystem => kind.toLowerCase() == 'system';

  Message copyWith({
    String? id,
    String? body,
    String? kind,
    String? senderId,
    String? orderId,
    DateTime? createdAt,
    String? replyToMessageId,
    String? attachmentUrl,
    String? attachmentType,
    Map<String, dynamic>? raw,
    bool? isOptimistic,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      senderId: senderId ?? this.senderId,
      orderId: orderId ?? this.orderId,
      createdAt: createdAt ?? this.createdAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      raw: raw ?? this.raw,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }

  factory Message.fromMap(Map<String, dynamic> map, {bool optimistic = false}) {
    final createdAtRaw = map['created_at']?.toString();
    DateTime? createdAt;
    if (createdAtRaw != null) {
      try {
        createdAt = DateTime.parse(createdAtRaw).toUtc();
      } catch (_) {
        createdAt = null;
      }
    }
    return Message(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'text',
      senderId: map['sender_id']?.toString(),
      orderId: map['order_id']?.toString(),
      createdAt: createdAt,
      replyToMessageId: map['reply_to_message_id']?.toString(),
      attachmentUrl: map['attachment_url']?.toString(),
      attachmentType: map['attachment_type']?.toString(),
      raw: Map<String, dynamic>.from(map),
      isOptimistic: optimistic,
    );
  }

  factory Message.optimistic({
    required String conversationId,
    required String body,
    String kind = 'text',
    String? senderId,
    String? orderId,
    String? replyToMessageId,
    String? attachmentUrl,
    String? attachmentType,
  }) {
    final now = DateTime.now().toUtc();
    return Message(
      id: 'local_${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      body: body,
      kind: kind,
      senderId: senderId,
      orderId: orderId,
      createdAt: now,
      replyToMessageId: replyToMessageId,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      raw: const {},
      isOptimistic: true,
    );
  }
}

/// Central messaging facade that orchestrates Supabase RPCs and Realtime streams.
class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> purgeEmptyConversations(
      {Duration maxAge = const Duration(minutes: 5)}) async {
    try {
      await _client.rpc('purge_empty_conversations', params: {
        'p_age_minutes': maxAge.inMinutes,
      });
    } catch (_) {
      // ignore purge failures – non-critical
    }
  }

  Future<List<Conversation>> fetchRecentConversations({
    Duration lookback = const Duration(days: 7),
  }) async {
    // CRITICAL SECURITY FIX: Only fetch conversations for the current user
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const MessagingException(
        'AUTH_REQUIRED',
        'User must be authenticated to fetch conversations',
      );
    }

    final cutoff = DateTime.now().toUtc().subtract(lookback);
    
    // First, get conversation IDs where the current user is a participant
    final participantResponse = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', currentUserId);
    
    final participantRows = (participantResponse as List).cast<Map<String, dynamic>>();
    final conversationIds = participantRows
        .map((row) => row['conversation_id'] as String)
        .toList();
    
    // If user has no conversations, return empty list
    if (conversationIds.isEmpty) {
      return [];
    }
    
    // Now fetch only those conversations with full details
    final response = await _client
        .from('conversations')
        .select(
          'id, title, order_id, is_support, created_at, conversation_participants(user:users(id,name,role), user_id, role)',
        )
        .inFilter('id', conversationIds)
        .gte('created_at', cutoff.toIso8601String())
        .order('created_at', ascending: false);

    final rows = (response as List).cast<Map<String, dynamic>>();
    return rows.map(Conversation.fromMap).toList();
  }

  Stream<List<Message>> watchMessages(
    String conversationId, {
    Duration lookback = const Duration(hours: 24),
  }) {
    final since = DateTime.now().toUtc().subtract(lookback);

    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) {
      final list = rows.cast<Map<String, dynamic>>();
          return list.map(Message.fromMap).where((message) {
            final createdAt = message.createdAt;
            if (createdAt == null) return true;
            return !createdAt.isBefore(since);
      }).toList();
    });
  }

  Future<Message> sendMessage({
    required String conversationId,
    String? body,
    String kind = 'text',
    String? orderId,
    String? replyToMessageId,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final trimmedBody = body?.trim() ?? '';
    final hasBody = trimmedBody.isNotEmpty;
    final hasAttachment = attachmentUrl != null && attachmentUrl.isNotEmpty;

    if (!hasBody && !hasAttachment) {
      throw const MessagingException(
        'EMPTY_MESSAGE',
        'لا يمكن إرسال رسالة فارغة.',
      );
    }

    final params = <String, dynamic>{
      'p_conversation_id': conversationId,
      'p_kind': kind,
    };
    if (hasBody) params['p_body'] = trimmedBody;
    if (orderId != null) params['p_order_id'] = orderId;
    if (replyToMessageId != null) params['p_reply_to'] = replyToMessageId;
    if (attachmentUrl != null) params['p_attachment_url'] = attachmentUrl;
    if (attachmentType != null) params['p_attachment_type'] = attachmentType;

    PostgrestResponse response;
    try {
      response = await _client.rpc('send_message', params: params);
    } on PostgrestException catch (error) {
      throw MessagingException(
        'SEND_FAILED',
        error.message ?? 'تعذر إرسال الرسالة',
        error,
      );
    }

    final payload = response.data;

    final normalized = _extractFirstMap(payload) ?? _extractFirstMap(response);

    if (normalized != null && normalized.isNotEmpty) {
      return Message.fromMap(normalized);
    }

    final messageId =
        _extractIdentifier(payload) ?? _extractIdentifier(response);

    if (messageId != null && messageId.isNotEmpty) {
      final fetched = await _client
          .from('messages')
          .select()
          .eq('id', messageId)
          .limit(1)
          .maybeSingle();
      if (fetched != null) {
        return Message.fromMap(Map<String, dynamic>.from(fetched));
      }
      return Message(
        id: messageId,
        conversationId: conversationId,
        body: hasBody ? trimmedBody : '',
        kind: kind,
        senderId: _client.auth.currentUser?.id,
        orderId: orderId,
        createdAt: DateTime.now().toUtc(),
        replyToMessageId: replyToMessageId,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        raw: const {},
      );
    }

    final fallback = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (fallback != null) {
      return Message.fromMap(Map<String, dynamic>.from(fallback));
    }

    return Message(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      body: hasBody ? trimmedBody : '',
      kind: kind,
      senderId: _client.auth.currentUser?.id,
      orderId: orderId,
      createdAt: DateTime.now().toUtc(),
      replyToMessageId: replyToMessageId,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      raw: const {},
      isOptimistic: true,
    );
  }

  Future<Conversation?> getConversationById(String id) async {
    final data = await _client
        .from('conversations')
        .select(
          'id, title, order_id, is_support, created_at, conversation_participants(user:users(id,name,role), user_id, role)',
        )
        .eq('id', id)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return Conversation.fromMap(Map<String, dynamic>.from(data));
  }

  Future<String> ensureSupportConversation({
    String? orderId,
    List<String> participantIds = const [],
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const MessagingException(
        'NOT_AUTHENTICATED',
        'المستخدم غير مسجل الدخول.',
      );
    }

    // Check for existing non-archived support conversation
    // Wrap in try-catch to handle transient network errors gracefully
    String? existingId;
    try {
      final existing = await _client
          .from('conversations')
          .select('id')
          .eq('is_support', true)
          .eq('created_by', currentUser.id)
          .or('is_archived.is.null,is_archived.eq.false') // Handle NULL as false (not archived)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      existingId = existing != null ? existing['id'] as String? : null;
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }
    } catch (e) {
      // If the check fails (network error, etc.), continue to create/get conversation
      // The RPC function will handle deduplication on the server side
      print('⚠️ Failed to check existing conversation, proceeding to create/get: $e');
    }

    final params = {
      'p_order_id': orderId,
      'p_participant_ids': participantIds.isEmpty ? null : participantIds,
      'p_is_support': true,
    };

    PostgrestResponse response;
    try {
      response =
          await _client.rpc('create_or_get_conversation', params: params);
    } on PostgrestException catch (error) {
      // Even if RPC fails, check if conversation was created
      // (might have succeeded but returned error for other reason)
      final fallbackCheck = await _client
          .from('conversations')
          .select('id')
          .eq('is_support', true)
          .eq('created_by', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final fallbackId = fallbackCheck != null ? fallbackCheck['id'] as String? : null;
      if (fallbackId != null && fallbackId.isNotEmpty) {
        return fallbackId;
      }
      
      throw MessagingException(
        'CONVERSATION_RPC_FAILED',
        error.message ?? 'تعذر فتح محادثة الدعم',
        error,
      );
    }

    // The RPC function returns UUID directly as a string
    String? convId;
    if (response.data is String) {
      convId = response.data as String;
    } else {
      convId = _extractIdentifier(response.data) ?? _extractIdentifier(response);
    }

    // If we still don't have an ID, check the database directly
    // (the conversation might have been created but ID not returned properly)
    if (convId == null || convId.isEmpty) {
      // Wait a brief moment for the database to be consistent
      await Future.delayed(const Duration(milliseconds: 100));
      
      final fallback = await _client
          .from('conversations')
          .select('id')
          .eq('is_support', true)
          .eq('created_by', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final fallbackId = fallback != null ? fallback['id'] as String? : null;
      if (fallbackId != null && fallbackId.isNotEmpty) {
        return fallbackId;
      }
      throw const MessagingException(
        'MISSING_CONVERSATION_ID',
        'لم يتم استلام معرّف المحادثة من الخادم.',
      );
    }

    return convId;
  }

  static String? _extractIdentifier(dynamic value) {
    if (value == null) return null;

    if (value is String && value.isNotEmpty) {
      return value;
    }

    if (value is Map) {
      if (value['id'] is String && (value['id'] as String).isNotEmpty) {
        return value['id'] as String;
      }
      for (final key in const [
        'conversation_id',
        'message_id',
        'create_or_get_conversation',
        'send_message',
        'data',
      ]) {
        final identifier = _extractIdentifier(value[key]);
        if (identifier != null) return identifier;
      }
    }

    if (value is Iterable) {
      for (final item in value) {
        final identifier = _extractIdentifier(item);
        if (identifier != null) return identifier;
      }
    }

    if (value is PostgrestResponse) {
      return _extractIdentifier(value.data);
    }

    try {
      final dynamic data = (value as dynamic).data;
      return _extractIdentifier(data);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _extractFirstMap(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      final map = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.value is Map || entry.value is Iterable) {
          final nested = _extractFirstMap(entry.value);
          if (nested != null) return nested;
        }
        if (entry.key is String) {
          map[entry.key as String] = entry.value;
        }
      }
      if (map.isNotEmpty && map.containsKey('id')) {
        return map.cast<String, dynamic>();
      }
    }

    if (value is Iterable) {
      for (final item in value) {
        final nested = _extractFirstMap(item);
        if (nested != null) return nested;
      }
    }

    if (value is PostgrestResponse) {
      return _extractFirstMap(value.data);
    }

    try {
      final dynamic data = (value as dynamic).data;
      return _extractFirstMap(data);
    } catch (_) {
    return null;
    }
  }
}
