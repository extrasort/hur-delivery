import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/voice_recording_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/voice_recording_card.dart';

class VoiceLibraryScreen extends StatefulWidget {
  const VoiceLibraryScreen({super.key});

  @override
  State<VoiceLibraryScreen> createState() => _VoiceLibraryScreenState();
}

class _VoiceLibraryScreenState extends State<VoiceLibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceRecordingProvider>().loadRecordings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).voiceLibrary,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              context.read<VoiceRecordingProvider>().loadRecordings();
            },
          ),
        ],
      ),
      body: Consumer<VoiceRecordingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Column(
                        children: [
                          Text(
                            loc.errorLoadingRecordings,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.error!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              provider.clearError();
                              provider.loadRecordings();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                            child: Text(loc.retry),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }

          final recordings = provider.activeRecordings;

          if (recordings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic_none,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Column(
                        children: [
                          Text(
                            loc.noVoiceRecordings,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.recordFirstOrder,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(loc.recordNewOrder),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadRecordings(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                return VoiceRecordingCard(
                  recording: recordings[index],
                  onReuse: () => _handleReuse(recordings[index].id),
                  onDelete: () => _handleDelete(recordings[index].id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleReuse(String recordingId) {
    // Navigate back and pass the recording ID
    Navigator.pop(context, recordingId);
  }

  Future<void> _handleDelete(String recordingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(loc.deleteRecording),
          content: Text(loc.confirmDeleteRecording),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(loc.delete),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final success = await context
          .read<VoiceRecordingProvider>()
          .archiveRecording(recordingId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف التسجيل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

