import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/messaging_service.dart';
import '../../../core/localization/app_localizations.dart';

class MessagingThreadScreen extends StatefulWidget {
  final String conversationId;
  const MessagingThreadScreen({super.key, required this.conversationId});

  @override
  State<MessagingThreadScreen> createState() => _MessagingThreadScreenState();
}

class _MessagingThreadScreenState extends State<MessagingThreadScreen> {
  late final Stream<List<Message>> _stream;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Message? _replyingTo;
  final List<Message> _pending = [];
  final Set<String> _knownIds = {};
  final ImagePicker _picker = ImagePicker();
  File? _pendingImage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Client should only show messages from past day; admin web shows all
    final since = DateTime.now().toUtc().subtract(const Duration(days: 1));
    _stream = MessagingService.instance.watchMessages(widget.conversationId,
        lookback: const Duration(days: 1));
  }

  Future<Message?> _resolveSentMessage({
    required DateTime startedAt,
    required String conversationId,
    required String? senderId,
  }) async {
    if (senderId == null) return null;
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('sender_id', senderId)
          .gte('created_at',
              startedAt.subtract(const Duration(seconds: 2)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return Message.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('⚠️ Failed to resolve sent message: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    if (_isSending) return;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() {
        _pendingImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.failedSelectImage)),
      );
    }
  }

  void _removePendingImage() {
    setState(() {
      _pendingImage = null;
    });
  }

  Future<void> _send() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    final hasText = text.isNotEmpty;
    final hasImage = _pendingImage != null;
    if (!hasText && !hasImage) {
      return;
    }

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final replyToId = _replyingTo?.id;
    Message? optimistic;
    String? attachmentUrl;
    String? attachmentType;
    final startedAt = DateTime.now().toUtc();

    setState(() {
      _isSending = true;
    });

    try {
      if (hasImage && _pendingImage != null) {
        final file = _pendingImage!;
        final bytes = await file.readAsBytes();
        final ext = file.path.split('.').last.toLowerCase();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final objectPath =
            'conversations/${widget.conversationId}/$timestamp.$ext';
        final mime = ext == 'png'
            ? 'image/png'
            : ext == 'gif'
                ? 'image/gif'
                : 'image/jpeg';
        await Supabase.instance.client.storage.from('files').uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mime,
              ),
            );
        attachmentUrl = Supabase.instance.client.storage
            .from('files')
            .getPublicUrl(objectPath);
        attachmentType = mime;
      }

      optimistic = Message.optimistic(
        conversationId: widget.conversationId,
        body: text,
        senderId: myId,
        replyToMessageId: replyToId,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      setState(() {
        _pending.add(optimistic!);
        _controller.clear();
        _pendingImage = null;
      });

      final sentMessage = await MessagingService.instance.sendMessage(
        conversationId: widget.conversationId,
        body: text.isNotEmpty ? text : null,
        replyToMessageId: replyToId,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        kind: attachmentUrl != null ? 'media' : 'text',
      );

      setState(() {
        _replyingTo = null;
        final index = _pending.indexWhere((m) => m.id == optimistic!.id);
        if (index >= 0) {
          _pending[index] = sentMessage.copyWith(isOptimistic: true);
        }
      });
    } on MessagingException catch (e) {
      final resolved = await _resolveSentMessage(
        startedAt: startedAt,
        conversationId: widget.conversationId,
        senderId: myId,
      );

      if (resolved != null && optimistic != null) {
        setState(() {
          _replyingTo = null;
          final index = _pending.indexWhere((m) => m.id == optimistic!.id);
          if (index >= 0) {
            _pending[index] = resolved.copyWith(isOptimistic: true);
          }
        });
      } else {
        setState(() {
          if (optimistic != null) {
            _pending.removeWhere((m) => m.id == optimistic!.id);
          }
        });
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty
                  ? e.message
                  : loc.failedSendMessage,
            ),
          ),
        );
      }
    } catch (e) {
      final resolved = await _resolveSentMessage(
        startedAt: startedAt,
        conversationId: widget.conversationId,
        senderId: myId,
      );

      if (resolved != null && optimistic != null) {
        setState(() {
          _replyingTo = null;
          final index = _pending.indexWhere((m) => m.id == optimistic!.id);
          if (index >= 0) {
            _pending[index] = resolved.copyWith(isOptimistic: true);
          }
        });
      } else {
        setState(() {
          if (optimistic != null) {
            _pending.removeWhere((m) => m.id == optimistic!.id);
          }
        });
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.failedSendMessage)),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }

    if (_scroll.hasClients) {
      await Future.delayed(const Duration(milliseconds: 50));
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottomOnNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final previewText = _replyingTo!.body;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.08),
        border: Border(
          left: BorderSide(color: Colors.teal.shade400, width: 3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.teal.shade800),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).conversation)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snapshot) {
                final msgs = [...(snapshot.data ?? const <Message>[])];
                // Capture known ids
                for (final m in msgs) {
                  if (m.id.isNotEmpty) _knownIds.add(m.id);
                }
                // Append pending that aren't yet in stream
                final combined = [
                  ...msgs,
                  ..._pending.where((m) => !_knownIds.contains(m.id)),
                ];
                // sort ascending by created_at then id to ensure stable order
                combined.sort((a, b) {
                  final at =
                      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bt =
                      b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final cmp = at.compareTo(bt);
                  if (cmp != 0) return cmp;
                  return a.id.compareTo(b.id);
                });
                _scrollToBottomOnNextFrame();
                if (snapshot.hasError) {
                  debugPrint('❌ Messaging stream error: ${snapshot.error}');
                }
                return ListView.builder(
                  controller: _scroll,
                  itemCount: combined.length,
                  itemBuilder: (_, i) {
                    final m = combined[i];
                    final isMe = m.senderId == myId;
                    final createdAt = _formatTime(m.createdAt);
                    final replyToId = m.replyToMessageId;
                    Message? repliedTo;
                    if (replyToId != null) {
                      for (final msg in combined) {
                        if (msg.id == replyToId) {
                          repliedTo = msg;
                          break;
                        }
                      }
                    }
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.teal.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (repliedTo != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  border: Border(
                                    left: BorderSide(
                                      color: isMe
                                          ? Colors.teal.shade600
                                          : Colors.grey.shade600,
                                      width: 3,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  repliedTo!.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ),
                              ),
                            if (m.body.isNotEmpty) Text(m.body),
                            if (m.attachmentUrl != null &&
                                m.attachmentUrl!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                    top: m.body.isNotEmpty ? 8 : 0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    m.attachmentUrl!,
                                    width: 220,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            if (m.orderId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Builder(
                                  builder: (context) {
                                    final loc = AppLocalizations.of(context);
                                    return Text(
                                      loc.orderLabel(m.orderId ?? ''),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.teal.shade700,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.reply, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      setState(() => _replyingTo = m),
                                  tooltip: AppLocalizations.of(context).reply,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  createdAt,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined),
                  onPressed: _isSending ? null : _pickImage,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_pendingImage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withOpacity(0.05),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _pendingImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        Colors.black.withOpacity(0.6),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: _removePendingImage,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildReplyPreview(),
                        TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).typeMessage,
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ],
                    ),
                  ),
                ),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
