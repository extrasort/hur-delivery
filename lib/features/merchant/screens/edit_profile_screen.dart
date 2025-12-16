import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';

class MerchantEditProfileScreen extends StatefulWidget {
  const MerchantEditProfileScreen({super.key});

  @override
  State<MerchantEditProfileScreen> createState() => _MerchantEditProfileScreenState();
}

class _MerchantEditProfileScreenState extends State<MerchantEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _storeNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _storeNameController = TextEditingController(text: user?.storeName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) throw Exception('User not found');

      await Supabase.instance.client.from('users').update({
        'name': _nameController.text.trim(),
        'store_name': _storeNameController.text.trim(),
        'address': _addressController.text.trim(),
      }).eq('id', user.id);

      // Refresh user data
      await context.read<AuthProvider>().refreshUser();

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.profileUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurred(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editProfile),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          onPressed: () {
                            // TODO: Implement image picker
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context).featureComingSoon),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Name Field
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: loc.name,
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.nameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Store Name Field
                      TextFormField(
                        controller: _storeNameController,
                        decoration: InputDecoration(
                          labelText: loc.storeName,
                          prefixIcon: const Icon(Icons.store_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.storeNameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Phone Field (Read-only)
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: loc.phoneNumberLabel,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          enabled: false,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Address Field
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: loc.address,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          text: loc.saveChanges,
                          onPressed: _isLoading ? null : _saveProfile,
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

