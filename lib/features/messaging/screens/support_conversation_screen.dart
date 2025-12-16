import 'package:flutter/material.dart';

import '../../../core/services/messaging_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'messaging_thread_screen.dart';
import 'messaging_list_screen.dart';

/// Thin wrapper that ensures the driver support chat opens directly without
/// showing the conversation list. It always resolves (or creates) the single
/// support conversation for the current user and then delegates to
/// [MessagingThreadScreen], which already limits history to the past 24 hours.
class SupportConversationScreen extends StatefulWidget {
  const SupportConversationScreen({super.key, this.initialOrderId});

  final String? initialOrderId;

  @override
  State<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  String? _conversationId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Automatic retry with exponential backoff
    const maxRetries = 3;
    const baseDelay = Duration(milliseconds: 500);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final convId = await MessagingService.instance.ensureSupportConversation(
          orderId: widget.initialOrderId,
        );

        if (!mounted) return;

        if (convId == null || convId.isEmpty) {
          // If this is not the last attempt, retry
          if (attempt < maxRetries - 1) {
            await Future.delayed(baseDelay * (attempt + 1));
            continue;
          }
          
          // Last attempt failed
          if (!mounted) return;
          final loc = AppLocalizations.of(context);
          setState(() {
            _error = loc.failedOpenSupport;
            _loading = false;
          });
          return;
        }

        // Success!
        if (!mounted) return;
        setState(() {
          _conversationId = convId;
          _loading = false;
        });
        return; // Exit successfully
      } on MessagingException catch (e) {
        print('❌ Support conversation error (attempt ${attempt + 1}/$maxRetries): ${e.code} -> ${e.message}');
        
        // Retry on transient errors, but not on authentication errors
        if (attempt < maxRetries - 1 && e.code != 'NOT_AUTHENTICATED') {
          await Future.delayed(baseDelay * (attempt + 1));
          continue;
        }
        
        // Last attempt or non-retryable error
        if (!mounted) return;
        setState(() {
          _error = e.message;
          _loading = false;
        });
        return;
      } catch (e) {
        print('❌ Support conversation error (attempt ${attempt + 1}/$maxRetries): $e');
        
        // Retry on generic errors
        if (attempt < maxRetries - 1) {
          await Future.delayed(baseDelay * (attempt + 1));
          continue;
        }
        
        // Last attempt failed
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        setState(() {
          _error = loc.failedOpenSupport;
          _loading = false;
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.support)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.support)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadConversation,
                child: Text(loc.retry),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MessagingListScreen(
                        startSupportOnLoad: true,
                      ),
                    ),
                  );
                },
                child: Text(loc.openMessagesList),
              ),
            ],
          ),
        ),
      );
    }

    return MessagingThreadScreen(conversationId: _conversationId!);
  }
}
