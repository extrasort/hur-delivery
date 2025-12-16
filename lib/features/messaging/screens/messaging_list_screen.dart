import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'messaging_thread_screen.dart';

class MessagingListScreen extends StatefulWidget {
  const MessagingListScreen({
    super.key,
    this.startSupportOnLoad = false,
    this.initialOrderId,
  });

  final bool startSupportOnLoad;
  final String? initialOrderId;

  @override
  State<MessagingListScreen> createState() => _MessagingListScreenState();
}

class _MessagingListScreenState extends State<MessagingListScreen> {
  bool _loading = true;
  List<Conversation> _conversations = [];
  String? _role;

  @override
  void initState() {
    super.initState();
    final currentUser = Supabase.instance.client.auth.currentUser;
    _role = currentUser?.userMetadata?['role'] as String? ??
        currentUser?.appMetadata?['role'] as String? ??
        currentUser?.userMetadata?['app_role'] as String? ??
        currentUser?.appMetadata?['app_role'] as String?;
    _load();
    if (widget.startSupportOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startSupportChat(orderId: widget.initialOrderId);
        }
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await MessagingService.instance.fetchRecentConversations();
      if (!mounted) return;
      setState(() {
        _conversations = rows;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _resolveDisplayTitle(Conversation conversation) {
    final loc = AppLocalizations.of(context);
    final defaultTitle =
        conversation.title ?? (conversation.isSupport ? loc.technicalSupport : loc.conversationLabel);
    final createdAt = conversation.createdAt;
    final orderId = conversation.orderId;
    final isSupport = conversation.isSupport;
    final role = (_role ?? '').toLowerCase();

    if ((role == 'driver' || role == 'merchant') && isSupport) {
      final label = createdAt != null
          ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt.toLocal())
          : defaultTitle;
      if (orderId != null) {
        return '$label • ${loc.orderLabel(orderId)}';
      }
      return label;
    }

    if (role == 'admin' && isSupport) {
      // Find first non-admin participant
      for (final p in conversation.participants) {
        final userRole = p.role?.toLowerCase();
        if (userRole == null || userRole == 'admin') continue;
        final name = p.name;
        if (name != null && name.isNotEmpty) {
          if (orderId != null && orderId.isNotEmpty) {
            return '$name • ${loc.orderLabel(orderId)}';
          }
          return name;
        }
      }
      // Fallback to explicitly including conversation id if no participant
      if (orderId != null && orderId.isNotEmpty) {
        return loc.supportOrder(orderId.substring(0, 6));
      }
      return defaultTitle;
    }

    return defaultTitle;
  }

  Future<void> _startSupportChat({String? orderId}) async {
    try {
      final convId = await MessagingService.instance.ensureSupportConversation(
        orderId: orderId ?? widget.initialOrderId,
      );
      if (!mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MessagingThreadScreen(conversationId: convId),
      ));

      if (mounted) {
        await _load();
      }
    } on MessagingException catch (error) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final message = error.message.isNotEmpty
          ? error.message
          : loc.failedOpenSupport;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final message = error.message?.isNotEmpty == true
          ? error.message!
          : loc.failedOpenSupport;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.failedOpenSupport)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).messages),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            onPressed: () => _startSupportChat(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return _loading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
                  ? Center(child: Text(loc.noConversations))
                  : ListView.separated(
                      itemBuilder: (context, index) {
                        final c = _conversations[index];
                        final title = _resolveDisplayTitle(c);
                        final orderId = c.orderId;
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(title),
                          subtitle: orderId != null ? Text(loc.orderLabel(orderId)) : null,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              MessagingThreadScreen(conversationId: c.id),
                        ));
                      },
                    );
                  },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: _conversations.length,
                      );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startSupportChat(),
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}
