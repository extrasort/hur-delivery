import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../core/localization/app_localizations.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      _nameController.text = authProvider.user!.name;
      _phoneController.text = authProvider.user!.phone;
      _addressController.text = authProvider.user!.address ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile(
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _isEditing = false;
      });
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.profileSavedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? loc.errorSavingProfile),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true, // Allow keyboard to resize the screen
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).profile),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (authProvider.user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).noUserData,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }

          final user = authProvider.user!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: user.isOnline ? AppColors.success : AppColors.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                user.isOnline ? Icons.wifi : Icons.wifi_off,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Builder(
                                builder: (context) {
                                  final loc = AppLocalizations.of(context);
                                  return Text(
                                    user.isOnline ? loc.online : loc.offline,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Profile Information
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Text(
                            loc.accountInfo,
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name Field
                  _buildInfoField(
                            label: loc.name,
                    controller: _nameController,
                    icon: Icons.person,
                    isEditable: _isEditing,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                                return loc.nameRequiredField;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Phone Field (Read-only)
                  _buildInfoField(
                            label: loc.phoneNumberLabel,
                    controller: _phoneController,
                    icon: Icons.phone,
                    isEditable: false,
                            helperText: loc.phoneCannotChange,
                  ),
                  const SizedBox(height: 16),
                  // Address Field
                  _buildInfoField(
                            label: loc.address,
                    controller: _addressController,
                    icon: Icons.location_on,
                    isEditable: _isEditing,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  // Account Status
                  Text(
                            loc.accountStatus,
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildStatusRow(
                                  loc.verificationStatus,
                                  user.manualVerified ? loc.verified : loc.notVerified,
                          user.manualVerified ? AppColors.success : AppColors.warning,
                          user.manualVerified ? Icons.verified : Icons.pending,
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow(
                                  loc.status,
                                  user.isOnline ? loc.online : loc.offline,
                          user.isOnline ? AppColors.success : AppColors.error,
                          user.isOnline ? Icons.wifi : Icons.wifi_off,
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow(
                                  loc.registrationDate,
                          _formatDate(user.createdAt),
                          AppColors.textSecondary,
                          Icons.calendar_today,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action Buttons
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                                    text: loc.cancel,
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _loadUserData(); // Reset to original values
                              });
                            },
                          ),
                        ),
                        SizedBox(width: context.rs(16)),
                        Expanded(
                          child: PrimaryButton(
                                    text: loc.saveChanges,
                            onPressed: _isLoading ? null : _saveProfile,
                            isLoading: _isLoading,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Padding(
                      padding: context.rp(horizontal: 8, vertical: 0),
                      child: SizedBox(
                        height: context.rh(56),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(context.rs(12)),
                            ),
                            minimumSize: Size(double.infinity, context.rh(56)),
                            padding: context.rp(horizontal: 16, vertical: 12),
                          ),
                          child: ResponsiveText(
                            loc.editProfile,
                            style: AppTextStyles.buttonLarge.copyWith(
                              fontSize: context.rf(16),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditable,
    String? helperText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ).responsive(context),
        ),
        SizedBox(height: context.rs(8)),
        TextFormField(
          controller: controller,
          enabled: isEditable,
          maxLines: maxLines,
          validator: validator,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary),
            hintText: isEditable ? AppLocalizations.of(context).enterLabel(label) : '',
            helperText: helperText,
            helperStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: isEditable ? AppColors.surface : AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: valueColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
