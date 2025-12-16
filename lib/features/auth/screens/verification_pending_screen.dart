import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import 'id_verification_review_screen.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  File? _idCardFront;
  File? _idCardBack;
  File? _selfieWithId;
  bool _isResubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    // Check verification status every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        context.read<AuthProvider>().initialize();
        _checkVerificationStatus();
      }
    });
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          switch (type) {
            case 'id_front':
              _idCardFront = File(image.path);
              break;
            case 'id_back':
              _idCardBack = File(image.path);
              break;
            case 'selfie':
              _selfieWithId = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorSelectingImage(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImagePicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(AppLocalizations.of(context).takePhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(context).chooseFromGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, type);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resubmitVerification() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    
    if (user == null) return;

    // Validate required images
    if (_idCardFront == null || _idCardBack == null) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadIdFrontBack),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Driver-specific validation
    if (user.role == 'driver' && _selfieWithId == null) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadSelfieWithId),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isResubmitting = true;
    });

    try {
      print('🆔 Resubmitting ID verification...');
      final verificationResult = await _verifyIdWithAI(user.role, user.id);
      
      if (verificationResult == null || !verificationResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verificationResult?['reason'] ?? AppLocalizations.of(context).idVerificationFailed),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      print('✅ ID verification passed by AI');
      print('📊 Verification result: ${verificationResult.toString()}');
      
      if (mounted) {
        // Navigate to review screen to confirm extracted data
        print('📝 Navigating to review screen...');
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => IdVerificationReviewScreen(
              extractedData: verificationResult,
              role: user.role,
              isResubmission: true,
              idFrontFile: _idCardFront,
              idBackFile: _idCardBack,
              selfieFile: _selfieWithId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Resubmission error: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorLabel(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResubmitting = false;
        });
      }
    }
  }


  Future<Map<String, dynamic>?> _verifyIdWithAI(String role, String userId) async {
    try {
      print('📤 Sending images to ID verification edge function...');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Env.supabaseUrl}/functions/v1/verify-id-card'),
      );
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${Env.supabaseAnonKey}';
      
      // Add images
      request.files.add(await http.MultipartFile.fromPath(
        'id_front',
        _idCardFront!.path,
      ));
      
      request.files.add(await http.MultipartFile.fromPath(
        'id_back',
        _idCardBack!.path,
      ));
      
      // Add selfie only for drivers
      if (role == 'driver' && _selfieWithId != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          _selfieWithId!.path,
        ));
      }
      
      // Add role and user_id
      request.fields['role'] = role;
      request.fields['user_id'] = userId;
      
      print('⏳ Waiting for verification response...');
      
      var response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );
      
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);
      
      print('📥 Verification response: ${jsonData.toString()}');
      
      return jsonData;
    } catch (e) {
      print('❌ ID verification error: $e');
      return {
        'success': false,
        'reason': AppLocalizations.of(context).connectionFailed(e.toString()),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final isRejected = user?.verificationStatus == 'rejected';
        
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    
                    // Status Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: (isRejected ? AppColors.error : AppColors.warning).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Icon(
                        isRejected ? Icons.error_outline_rounded : Icons.pending_actions_rounded,
                        size: 64,
                        color: isRejected ? AppColors.error : AppColors.warning,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Status Text
                    Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return Column(
                          children: [
                            Text(
                              isRejected ? loc.verificationRejected : loc.verificationPending,
                              style: AppTextStyles.heading2,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isRejected 
                                ? loc.verificationRejectedMessage
                                : loc.verificationReviewMessage,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isRejected
                                ? loc.pleaseUploadClearIdImages
                                : loc.verificationUnderReview,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 48),
                    
                    if (isRejected) ...[
                      // Re-upload section for rejected users
                      _buildDocumentUploadSection(user!),
                      
                      const SizedBox(height: 24),
                      
                      // Resubmit button
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return PrimaryButton(
                            text: _isResubmitting ? loc.verifying : loc.resubmitVerification,
                            onPressed: _isResubmitting ? null : _resubmitVerification,
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                    ] else ...[
                      // Info card for pending users
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final loc = AppLocalizations.of(context);
                                return Column(
                                  children: [
                                    Text(
                                      loc.whatHappensNow,
                                      style: AppTextStyles.heading3.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      loc.verificationProcessSteps,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.primary,
                                        height: 1.6,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      TextButton(
                        onPressed: () {
                          // Refresh status
                          context.read<AuthProvider>().initialize();
                        },
                        child: Text(AppLocalizations.of(context).refreshStatus),
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                    
                    // Logout button
                    OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      ),
                      child: Text(AppLocalizations.of(context).logout),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentUploadSection(user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).uploadNewDocuments,
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            AppLocalizations.of(context).pleaseUploadClearId,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• الصورة واضحة وغير مهتزة\n• البطاقة حقيقية (وليست صورة من شاشة)\n• جميع البيانات ظاهرة ومقروءة',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // ID Front
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildUploadButton(
                    loc.idCardFront,
                    _idCardFront,
                    () => _showImagePicker('id_front'),
                  ),
                  const SizedBox(height: 12),
                  // ID Back
                  _buildUploadButton(
                    loc.idCardBack,
                    _idCardBack,
                    () => _showImagePicker('id_back'),
                  ),
                  // Selfie (only for drivers)
                  if (user.role == 'driver') ...[
                    const SizedBox(height: 12),
                    _buildUploadButton(
                      loc.selfieWithId,
                      _selfieWithId,
                      () => _showImagePicker('selfie'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String label, File? file, VoidCallback onTap) {
    final hasFile = file != null;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile ? AppColors.success.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle : Icons.add_photo_alternate,
              color: hasFile ? AppColors.success : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasFile ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

