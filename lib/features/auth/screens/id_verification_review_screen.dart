import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';

class IdVerificationReviewScreen extends StatefulWidget {
  final Map<String, dynamic> extractedData;
  final String role;
  final bool isResubmission;
  final File? idFrontFile;
  final File? idBackFile;
  final File? selfieFile;

  const IdVerificationReviewScreen({
    super.key,
    required this.extractedData,
    required this.role,
    this.isResubmission = false,
    this.idFrontFile,
    this.idBackFile,
    this.selfieFile,
  });

  @override
  State<IdVerificationReviewScreen> createState() =>
      _IdVerificationReviewScreenState();
}

class _IdVerificationReviewScreenState
    extends State<IdVerificationReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _firstNameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _grandfatherNameController;
  late TextEditingController _familyNameController;
  late TextEditingController _idNumberController;
  late TextEditingController _expiryDateController;
  late TextEditingController _birthDateController;
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with extracted data
    final legalName = widget.extractedData['legal_name'] ?? {};
    _firstNameController =
        TextEditingController(text: legalName['first'] ?? '');
    _fatherNameController =
        TextEditingController(text: legalName['father'] ?? '');
    _grandfatherNameController =
        TextEditingController(text: legalName['grandfather'] ?? '');
    _familyNameController =
        TextEditingController(text: legalName['family'] ?? '');
    _idNumberController =
        TextEditingController(text: widget.extractedData['id_number'] ?? '');
    _expiryDateController = TextEditingController(
        text: widget.extractedData['id_expiry_date'] ?? '');
    _birthDateController = TextEditingController(
        text: widget.extractedData['id_birth_date'] ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _familyNameController.dispose();
    _idNumberController.dispose();
    _expiryDateController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // Check if user already has an ID number in the database
  Future<bool> _checkIfUserHasIdNumber() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;
      
      final response = await Supabase.instance.client
          .from('users')
          .select('id_number')
          .eq('id', currentUser.id)
          .maybeSingle();
      
      if (response != null && response['id_number'] != null) {
        final idNumber = response['id_number'] as String;
        return idNumber.isNotEmpty;
      }
      
      return false;
    } catch (e) {
      print('⚠️ Error checking ID number: $e');
      return false;
    }
  }

  Future<String?> _uploadToStorage(File file, String path) async {
    try {
      final supabase = Supabase.instance.client;
      
      print('📤 Uploading file to: $path');
      
      await supabase.storage.from('files').upload(
          path,
          file,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );
      
      print('✅ File uploaded successfully');
      return path;
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        throw Exception('User ID not found');
      }

      print('📝 Submitting verified ID information...');

      // Upload images to storage if provided
      String? idFrontPath;
      String? idBackPath;
      String? selfiePath;
      String? idFrontPublicUrl;
      String? idBackPublicUrl;
      String? selfiePublicUrl;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageBasePath = 'documents/$userId';

      if (widget.idFrontFile != null) {
        print('📤 Uploading ID front image...');
        idFrontPath = await _uploadToStorage(
          widget.idFrontFile!,
          '$storageBasePath/id_front_review_$timestamp.jpg',
        );
        if (idFrontPath != null) {
          idFrontPublicUrl = Supabase.instance.client.storage
              .from('files')
              .getPublicUrl(idFrontPath);
        }
      }

      if (widget.idBackFile != null) {
        print('📤 Uploading ID back image...');
        idBackPath = await _uploadToStorage(
          widget.idBackFile!,
          '$storageBasePath/id_back_review_$timestamp.jpg',
        );
        if (idBackPath != null) {
          idBackPublicUrl = Supabase.instance.client.storage
              .from('files')
              .getPublicUrl(idBackPath);
        }
      }

      if (widget.selfieFile != null) {
        print('📤 Uploading selfie image...');
        selfiePath = await _uploadToStorage(
          widget.selfieFile!,
          '$storageBasePath/selfie_review_$timestamp.jpg',
        );
        if (selfiePath != null) {
          selfiePublicUrl = Supabase.instance.client.storage
              .from('files')
              .getPublicUrl(selfiePath);
        }
      }

      // Call the database update function
      final existingFrontUrl =
          widget.extractedData['id_card_front_url'] as String?;
      final existingBackUrl =
          widget.extractedData['id_card_back_url'] as String?;
      final existingSelfieUrl =
          widget.extractedData['selfie_with_id_url'] as String?;
      final existingRole = widget.extractedData['role'] as String?;
      final currentRole = authProvider.user?.role ??
          (existingRole != null && existingRole.isNotEmpty
              ? existingRole
              : widget.role);

      final response = await http.post(
        Uri.parse('${Env.supabaseUrl}/rest/v1/rpc/update_user_id_verification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.supabaseAnonKey}',
          'apikey': Env.supabaseAnonKey,
        },
        body: json.encode({
          'p_user_id': userId,
          'p_id_number': _idNumberController.text.trim(),
          'p_legal_first_name': _firstNameController.text.trim(),
          'p_legal_father_name': _fatherNameController.text.trim(),
          'p_legal_grandfather_name': _grandfatherNameController.text.trim(),
          'p_legal_family_name': _familyNameController.text.trim(),
          'p_id_front_url': idFrontPublicUrl ?? existingFrontUrl,
          'p_id_back_url': idBackPublicUrl ?? existingBackUrl,
          'p_selfie_url': widget.role == 'driver'
              ? (selfiePublicUrl ?? existingSelfieUrl)
              : null,
          'p_id_expiry_date': _expiryDateController.text.isNotEmpty
              ? _expiryDateController.text
              : null,
          'p_id_birth_date': _birthDateController.text.isNotEmpty
              ? _birthDateController.text
              : null,
          'p_verification_notes': 'User confirmed and approved',
        }),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ ID verification saved successfully');
        // Also update users table with edited info as source of truth
        try {
          final fullName =
              '${_firstNameController.text.trim()} ${_fatherNameController.text.trim()} ${_grandfatherNameController.text.trim()} ${_familyNameController.text.trim()}';
          final updateData = <String, dynamic>{
            'name': fullName.trim(),
            'id_number': _idNumberController.text.trim(),
            'legal_first_name': _firstNameController.text.trim(),
            'legal_father_name': _fatherNameController.text.trim(),
            'legal_grandfather_name': _grandfatherNameController.text.trim(),
            'legal_family_name': _familyNameController.text.trim(),
            if (idFrontPublicUrl != null) 'id_card_front_url': idFrontPublicUrl,
            if (idBackPublicUrl != null) 'id_card_back_url': idBackPublicUrl,
            if (selfiePublicUrl != null) 'selfie_with_id_url': selfiePublicUrl,
            'role': currentRole,
            if (_expiryDateController.text.isNotEmpty)
              'id_expiry_date': _expiryDateController.text,
            if (_birthDateController.text.isNotEmpty)
              'id_birth_date': _birthDateController.text,
            'updated_at': DateTime.now().toIso8601String(),
          };
          await Supabase.instance.client
              .from('users')
              .update(updateData)
              .eq('id', userId);
          print('✅ Users table updated with reviewed info');
        } catch (e) {
          print('⚠️ Failed to update users table with reviewed info: $e');
        }

        // Refresh user data
        await authProvider.initialize();

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم التحقق وتفعيل حسابك بنجاح'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );

          // Wait a moment, then navigate
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            final user = authProvider.user;
            if (user?.role == 'merchant') {
              context.go('/merchant-dashboard');
            } else {
              context.go('/driver-dashboard');
            }
          }
        }
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Verification submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorSavingData(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).reviewIdData),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).extractedInfoMessage,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Full name section
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader(loc.fullNameSection, Icons.person),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstNameController,
                          label: loc.firstName,
                          hint: loc.enterName,
                          validator: (value) =>
                              value?.isEmpty ?? true ? loc.nameRequired : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _fatherNameController,
                          label: loc.fatherName,
                          hint: loc.enterFatherName,
                          validator: (value) =>
                              value?.isEmpty ?? true ? loc.fatherNameRequired : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _grandfatherNameController,
                          label: loc.grandfatherName,
                          hint: loc.enterGrandfatherName,
                          validator: (value) =>
                              value?.isEmpty ?? true ? loc.grandfatherNameRequired : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _familyNameController,
                          label: loc.familyName,
                          hint: loc.enterFamilyName,
                          validator: (value) =>
                              value?.isEmpty ?? true ? loc.familyNameRequired : null,
                        ),
                        const SizedBox(height: 32),
                        // ID number section
                        _buildSectionHeader(loc.cardInformation, Icons.credit_card),
                        const SizedBox(height: 16),
                        // ID number field - read-only if user already has one (resubmission)
                        // Check if user already has id_number to determine if this is a resubmission
                        FutureBuilder<bool>(
                          future: _checkIfUserHasIdNumber(),
                          builder: (context, snapshot) {
                            final hasIdNumber = snapshot.data ?? false;
                            return _buildTextField(
                              controller: _idNumberController,
                              label: loc.nationalIdNumber,
                              hint: loc.idNumberHint,
                              keyboardType: TextInputType.number,
                              enabled: !hasIdNumber, // Disable if user already has ID number
                              validator: (value) {
                                if (value?.isEmpty ?? true) return loc.idNumberRequired;
                                // No format restrictions - accept any value
                                return null;
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),

                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        _buildTextField(
                          controller: _expiryDateController,
                          label: loc.expiryDate,
                          hint: 'YYYY-MM-DD',
                          keyboardType: TextInputType.datetime,
                          validator: null, // Optional
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _birthDateController,
                          label: loc.birthDate,
                          hint: 'YYYY-MM-DD',
                          keyboardType: TextInputType.datetime,
                          validator: null, // Optional
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Extracted name preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.preview,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'الاسم الكامل',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_firstNameController.text} ${_fatherNameController.text} ${_grandfatherNameController.text} ${_familyNameController.text}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Submit button
                PrimaryButton(
                  text: _isSubmitting ? 'جاري الحفظ...' : 'تأكيد البيانات',
                  onPressed: _isSubmitting ? null : _submitVerification,
                ),

                const SizedBox(height: 16),

                // Cancel/back button
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('إلغاء التحقق'),
                              content: const Text(
                                  'هل أنت متأكد من إلغاء عملية التحقق؟ ستحتاج لرفع الصور مرة أخرى.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('رجوع'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (widget.isResubmission) {
                                context.go('/verification-pending');
                              } else {
                                context.go('/');
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('إلغاء'),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool? enabled,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled == false ? Colors.grey.shade100 : Colors.white,
      ),
      keyboardType: keyboardType,
      validator: validator,
      textDirection: TextDirection.rtl,
    );
  }
}
