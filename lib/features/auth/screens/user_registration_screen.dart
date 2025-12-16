import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../orders/screens/location_picker_screen.dart';
import 'id_verification_review_screen.dart';

class UserRegistrationScreen extends StatefulWidget {
  final String role;

  const UserRegistrationScreen({
    super.key,
    required this.role,
  });

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Merchant-specific fields
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  double? _storeLatitude;
  double? _storeLongitude;

  // Driver-specific fields
  String _selectedVehicleType = 'motorbike'; // Default to motorbike
  bool _hasDrivingLicense = false;
  bool _ownsVehicle = false;
  String _selectedDocumentType = 'national_id'; // Default to national ID

  // Merchant-specific fields
  String? _selectedBusinessType; // Type of business for merchants

  // Referral source (how did they hear about us)
  String? _referralSource;

  // Documents
  File? _idCardFront;
  File? _idCardBack;
  File? _selfieWithId; // Required for drivers, optional for merchants
  File? _driverProfilePhoto; // Optional driver profile photo

  bool _isLoading = false;
  String? _extractedLegalName; // Name extracted from ID

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    super.dispose();
  }

  String _getRoleDisplayName() {
    final loc = AppLocalizations.of(context);
    return widget.role == 'merchant' ? loc.merchant : loc.driver;
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
            case 'avatar':
              _driverProfilePhoto = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorSelectingImage(e.toString())),
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
          padding: context.rp(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveText(
                AppLocalizations.of(context).selectImageSource,
                style: AppTextStyles.heading3.responsive(context),
              ),
              SizedBox(height: context.rs(16)),
              ListTile(
                leading: Container(
                  padding: context.rp(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: Text(AppLocalizations.of(context).takePhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, type);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: AppColors.secondary),
                ),
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

  Future<void> _pickStoreLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _storeLatitude,
          initialLongitude: _storeLongitude,
          title: AppLocalizations.of(context).selectStoreLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _storeLatitude = result['latitude'];
        _storeLongitude = result['longitude'];
        _storeAddressController.text = result['address'] ?? AppLocalizations.of(context).locationSelected;
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate documents (back image not required for passport)
    final loc = AppLocalizations.of(context);
    if (_idCardFront == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadDocument),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Back image required for national ID and driver license, but NOT for passport
    if (_selectedDocumentType != 'passport' && _idCardBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadDocumentBack),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Selfie required only for drivers
    if (widget.role == 'driver' && _selfieWithId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseUploadSelfie),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Merchant-specific validation
    if (widget.role == 'merchant') {
      if (_storeLatitude == null || _storeLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.pleaseSelectStoreLocation),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      // Step 1: Verify ID card with AI
      print('🆔 Verifying ID card with AI...');
      final verificationResult = await _verifyIdWithAI();

      if (verificationResult == null || !verificationResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verificationResult?['reason'] ??
                  AppLocalizations.of(context).idVerificationFailedReason),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      print('✅ ID verification passed');

      // Extract legal name from verification result
      final legalName = verificationResult['legal_name'];
      final fullName =
          '${legalName['first']} ${legalName['father']} ${legalName['grandfather']} ${legalName['family']}';
      final idNumber = verificationResult['id_number'];

      print('📝 Extracted name: $fullName');
      print('🆔 Extracted ID: $idNumber');

      // Step 2: Prepare registration data with AI-extracted name
      Map<String, dynamic> userData = {
        'name': fullName,
        'role': widget.role,
        'id_number': idNumber,
        'legal_first_name': legalName['first'],
        'legal_father_name': legalName['father'],
        'legal_grandfather_name': legalName['grandfather'],
        'legal_family_name': legalName['family'],
        'id_expiry_date': verificationResult['id_expiry_date'],
        'id_birth_date': verificationResult['id_birth_date'],
        'verification_status': 'approved', // Auto-approve if AI check passed
        'document_type': _selectedDocumentType,
      };

      // Add referral source if provided
      if (_referralSource != null) {
        userData['referral_source'] = _referralSource;
      }

      if (widget.role == 'merchant') {
        userData.addAll({
          'store_name': _storeNameController.text.trim(),
          'address': _storeAddressController.text.trim(),
          'latitude': _storeLatitude,
          'longitude': _storeLongitude,
        });

        // Add business type if provided
        if (_selectedBusinessType != null) {
          userData['business_type'] = _selectedBusinessType;
        }
      } else if (widget.role == 'driver') {
        userData.addAll({
          'vehicle_type': _selectedVehicleType,
          'has_driving_license': _hasDrivingLicense,
          'owns_vehicle': _ownsVehicle,
        });
      }

      // Step 3: Register user with AI-verified data
      final success = await authProvider.registerUser(
        userData: userData,
        idCardFront: _idCardFront!,
        idCardBack: _idCardBack!,
        selfieWithId: widget.role == 'driver' ? _selfieWithId! : null,
        driverProfilePhoto:
            widget.role == 'driver' ? _driverProfilePhoto : null,
      );

      if (success && mounted) {
        // Navigate to review screen (GoRouter) to confirm extracted data
        context.goNamed('id-verification-review', extra: {
          'extractedData': verificationResult!,
          'role': widget.role,
          'isResubmission': false,
          'idFrontFile': _idCardFront,
          'idBackFile': _idCardBack,
          'selfieFile': _selfieWithId,
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? AppLocalizations.of(context).registrationError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      print('❌ Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorLabel(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _verifyIdWithAI() async {
    try {
      final userId = context.read<AuthProvider>().user?.id;

      print('📤 Sending images to ID verification edge function...');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Env.supabaseUrl}/functions/v1/verify-id-card'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${Env.supabaseAnonKey}';

      // Add front image (always required)
      request.files.add(await http.MultipartFile.fromPath(
        'id_front',
        _idCardFront!.path,
      ));

      // Add back image only if document type requires it (not for passport)
      if (_selectedDocumentType != 'passport' && _idCardBack != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'id_back',
          _idCardBack!.path,
        ));
      }

      // Add selfie only for drivers
      if (widget.role == 'driver' && _selfieWithId != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          _selfieWithId!.path,
        ));
      }

      // Add role, user_id, and document_type
      request.fields['role'] = widget.role;
      request.fields['document_type'] = _selectedDocumentType;
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      print('⏳ Waiting for verification response...');
      print('📄 Document type: $_selectedDocumentType');

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
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final loc = AppLocalizations.of(context);
            return Text(loc.registeringAs(_getRoleDisplayName()));
          },
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            // Go back to previous screen
            context.pop();
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: context.rp(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    // Removed circle icon for cleaner design
                    Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return Column(
                          children: [
                            ResponsiveText(
                              loc.completeData(_getRoleDisplayName()),
                              style: AppTextStyles.heading2
                                  .copyWith(
                                    color: AppColors.textPrimary,
                                  )
                                  .responsive(context),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.rs(8)),
                            ResponsiveText(
                              loc.pleaseFillAllRequired,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  )
                                  .responsive(context),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: context.rs(32)),

              // Role-specific fields
              if (widget.role == 'merchant')
                ..._buildMerchantFields()
              else if (widget.role == 'driver')
                ..._buildDriverFields(),

              SizedBox(height: context.rs(24)),

              // Referral Source Section
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(loc.howDidYouHear, Icons.campaign),
                      SizedBox(height: context.rs(16)),
                      _buildReferralSourceDropdown(),
                      SizedBox(height: context.rs(24)),
                      // Documents Section
                      _buildSectionHeader(loc.requiredDocuments, Icons.upload_file),
                    ],
                  );
                },
              ),
              SizedBox(height: context.rs(16)),

              // Document Type Selection (for all users)
              _buildDocumentTypeDropdown(),

              SizedBox(height: context.rs(16)),

              // Document Front (always required)
              _buildImageUpload(
                title: _getDocumentFrontLabel(),
                file: _idCardFront,
                onTap: () => _showImagePicker('id_front'),
                icon: Icons.credit_card,
              ),

              // Document Back (only for National ID and Driver License, NOT for Passport)
              if (_selectedDocumentType != 'passport') ...[
                SizedBox(height: context.rs(16)),
                _buildImageUpload(
                  title: _getDocumentBackLabel(),
                  file: _idCardBack,
                  onTap: () => _showImagePicker('id_back'),
                  icon: Icons.credit_card,
                ),
              ],

              // Selfie with document (Drivers only)
              if (widget.role == 'driver') ...[
                SizedBox(height: context.rs(16)),
                _buildImageUpload(
                  title: _getSelfieLabel(),
                  file: _selfieWithId,
                  onTap: () => _showImagePicker('selfie'),
                  icon: Icons.face,
                  isImportant: true,
                ),
              ],

              SizedBox(height: context.rs(32)),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: context.rh(60),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitRegistration,
                  icon: _isLoading
                      ? SizedBox(
                          width: context.ri(20),
                          height: context.ri(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.check_circle,
                          color: Colors.white, size: context.ri(22)),
                  label: Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return ResponsiveText(
                        _isLoading ? loc.registering : loc.completeRegistration,
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: context.rf(16),
                        ),
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rs(12)),
                    ),
                    padding: context.rp(horizontal: 20, vertical: 16),
                    disabledBackgroundColor: AppColors.textTertiary,
                  ),
                ),
              ),

              SizedBox(height: context.rs(16)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMerchantFields() {
    return [
      // Note about AI extraction
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).fullNameExtractedAutomatically,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // Removed profile photo upload for cleaner merchant registration

      // Store Information
      Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(loc.storeInformation, Icons.store),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _storeNameController,
                label: loc.storeName,
                hint: loc.enterStoreName,
                icon: Icons.storefront,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.storeNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Store Address with Map
              _buildLocationField(
                controller: _storeAddressController,
                label: loc.storeAddress,
                hint: loc.selectStoreLocationMap,
                onTap: _pickStoreLocation,
                hasLocation: _storeLatitude != null && _storeLongitude != null,
              ),

              const SizedBox(height: 16),

              // Business Type Selection
              _buildBusinessTypeDropdown(),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _buildDriverFields() {
    return [
      // Note about AI extraction
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).nameExtractedAutomatically,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // Vehicle Information
      Builder(
        builder: (context) {
          return _buildSectionHeader(AppLocalizations.of(context).vehicleInformation, Icons.directions_car);
        },
      ),
      const SizedBox(height: 16),

      // Vehicle Type Selection
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  return Text(
                    AppLocalizations.of(context).vehicleType,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Motorbike option (default)
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVehicleType == 'motorbike'
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVehicleType == 'motorbike'
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          Icons.two_wheeler,
                          color: _selectedVehicleType == 'motorbike'
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Text(
                              loc.motorbike,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'motorbike'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_selectedVehicleType == 'motorbike')
                          Builder(
                            builder: (context) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).defaultLabel,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    value: 'motorbike',
                    groupValue: _selectedVehicleType,
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(height: 8),
                // Car option
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVehicleType == 'car'
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVehicleType == 'car'
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          color: _selectedVehicleType == 'car'
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            return Text(
                              AppLocalizations.of(context).car,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'car'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    value: 'car',
                    groupValue: _selectedVehicleType,
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(height: 8),
                // Truck option
                Container(
                  decoration: BoxDecoration(
                    color: _selectedVehicleType == 'truck'
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedVehicleType == 'truck'
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color: _selectedVehicleType == 'truck'
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            return Text(
                              AppLocalizations.of(context).truck,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'truck'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    value: 'truck',
                    groupValue: _selectedVehicleType,
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      const SizedBox(height: 16),

      // Driving License
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.card_membership, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).doYouHaveLicense,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: _hasDrivingLicense,
              onChanged: (value) {
                setState(() {
                  _hasDrivingLicense = value;
                });
              },
              activeColor: AppColors.success,
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // Vehicle Ownership
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.key, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).doYouOwnVehicle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: _ownsVehicle,
              onChanged: (value) {
                setState(() {
                  _ownsVehicle = value;
                });
              },
              activeColor: AppColors.success,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildDriverAvatarPicker() {
    final avatarSize = math.min(96.0, context.screenWidth * 0.25);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return _buildSectionHeader(AppLocalizations.of(context).profilePhotoOptional, Icons.person);
          },
        ),
        SizedBox(height: context.rs(12)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showImagePicker('avatar'),
                borderRadius: BorderRadius.circular(avatarSize / 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 2,
                        ),
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                      child: ClipOval(
                        child: _driverProfilePhoto != null
                            ? Image.file(
                                _driverProfilePhoto!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: avatarSize * 0.55,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: context.rs(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أضف صورة شخصية واضحة لسهولة تمييزك من قبل العملاء.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_driverProfilePhoto != null) ...[
                    SizedBox(height: context.rs(8)),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _driverProfilePhoto = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(AppLocalizations.of(context).removeImage),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onTap,
    required bool hasLocation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasLocation ? AppColors.success : AppColors.border,
              width: hasLocation ? 2 : 1,
            ),
            boxShadow: hasLocation
                ? [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasLocation
                                ? AppColors.success
                                : AppColors.primary)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color:
                            hasLocation ? AppColors.success : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.text.isEmpty ? hint : controller.text,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: controller.text.isEmpty
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              fontWeight: controller.text.isEmpty
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasLocation) const SizedBox(height: 4),
                          if (hasLocation)
                            Text(
                              AppLocalizations.of(context).locationSelectedCheckmark,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.push_pin,
                      color:
                          hasLocation ? AppColors.success : AppColors.primary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralSourceDropdown() {
    final referralOptions = [
      {
        'value': 'social_media',
        'label': '📱 وسائل التواصل الاجتماعي'
      },
      {'value': 'friend', 'label': '👥 صديق أو معارف'},
      {'value': 'representative', 'label': '🤝 ممثل حر'},
      {'value': 'advertisement', 'label': '📺 إعلان'},
      {'value': 'search_engine', 'label': '🔍 محرك بحث'},
      {'value': 'word_of_mouth', 'label': '💬 من شخص آخر'},
      {'value': 'store_banner', 'label': '🏪 لافتة في متجر'},
      {'value': 'other', 'label': '📋 أخرى'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: _referralSource,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).howDidYouHearHur,
          hintText: AppLocalizations.of(context).optional,
          prefixIcon: const Icon(Icons.campaign, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              AppLocalizations.of(context).optional,
              style: const TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ...referralOptions.map((option) => DropdownMenuItem<String>(
                value: option['value'],
                child: Text(
                  option['label']!,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _referralSource = value;
          });
        },
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildDocumentTypeDropdown() {
    final documentTypes = [
      {'value': 'national_id', 'label': '🪪 البطاقة الوطنية / National ID'},
      {'value': 'driver_license', 'label': '🚗 رخصة القيادة / Driver License'},
      {'value': 'passport', 'label': '✈️ جواز السفر / Passport'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedDocumentType,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).documentType,
          hintText: AppLocalizations.of(context).selectDocumentType,
          prefixIcon: const Icon(Icons.badge, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: documentTypes
            .map((type) => DropdownMenuItem<String>(
                  value: type['value'],
                  child: Text(type['label']!),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedDocumentType = value!;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'نوع الوثيقة مطلوب';
          }
          return null;
        },
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    final businessTypes = [
      {'value': 'restaurant', 'label': '🍽️ مطعم / Restaurant'},
      {'value': 'grocery', 'label': '🛒 بقالة / Grocery'},
      {'value': 'pharmacy', 'label': '💊 صيدلية / Pharmacy'},
      {'value': 'bakery', 'label': '🥖 مخبز / Bakery'},
      {'value': 'cafe', 'label': '☕ مقهى / Cafe'},
      {'value': 'supermarket', 'label': '🏪 سوبرماركت / Supermarket'},
      {'value': 'electronics', 'label': '📱 إلكترونيات / Electronics'},
      {'value': 'clothing', 'label': '👕 ملابس / Clothing'},
      {'value': 'other', 'label': '📦 أخرى / Other'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        decoration: InputDecoration(
          labelText: 'نوع النشاط التجاري',
          hintText: 'ما نوع عملك؟',
          prefixIcon: const Icon(Icons.business, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text(
              'اختر نوع النشاط التجاري',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ...businessTypes.map((type) => DropdownMenuItem<String>(
                value: type['value'],
                child: Text(type['label']!),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedBusinessType = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'نوع النشاط التجاري مطلوب';
          }
          return null;
        },
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _getDocumentFrontLabel() {
    switch (_selectedDocumentType) {
      case 'driver_license':
        return 'رخصة القيادة - الجانب الأمامي';
      case 'passport':
        return 'جواز السفر - الصفحة الرئيسية';
      default:
        return 'الهوية الوطنية - الجانب الأمامي';
    }
  }

  String _getDocumentBackLabel() {
    switch (_selectedDocumentType) {
      case 'driver_license':
        return 'رخصة القيادة - الجانب الخلفي';
      case 'passport':
        return 'جواز السفر - صفحة إضافية'; // Not shown for passport
      default:
        return 'الهوية الوطنية - الجانب الخلفي';
    }
  }

  String _getSelfieLabel() {
    switch (_selectedDocumentType) {
      case 'driver_license':
        return 'صورة سيلفي مع رخصة القيادة';
      case 'passport':
        return 'صورة سيلفي مع جواز السفر';
      default:
        return 'صورة سيلفي مع الهوية الوطنية';
    }
  }

  Widget _buildImageUpload({
    required String title,
    required File? file,
    required VoidCallback onTap,
    required IconData icon,
    bool isImportant = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file != null ? AppColors.success : AppColors.border,
          width: file != null ? 2 : 1,
        ),
        boxShadow: file != null
            ? [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image preview or icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: file != null
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: file != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          icon,
                          color: AppColors.primary,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isImportant)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'مهم',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file != null ? 'تم الرفع ✓' : 'اضغط للرفع',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: file != null
                              ? AppColors.success
                              : AppColors.textTertiary,
                          fontWeight:
                              file != null ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  file != null ? Icons.check_circle : Icons.cloud_upload,
                  color: file != null ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
