import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/whatsapp_location_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';

class CustomerLocationSharingWidget extends StatefulWidget {
  final String orderId;
  final String customerPhone;
  final VoidCallback? onLocationShared;

  const CustomerLocationSharingWidget({
    Key? key,
    required this.orderId,
    required this.customerPhone,
    this.onLocationShared,
  }) : super(key: key);

  @override
  State<CustomerLocationSharingWidget> createState() => _CustomerLocationSharingWidgetState();
}

class _CustomerLocationSharingWidgetState extends State<CustomerLocationSharingWidget> {
  bool _isLoading = false;
  bool _locationShared = false;
  String? _currentAddress;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _checkLocationAvailability();
  }

  Future<void> _checkLocationAvailability() async {
    final isAvailable = await WhatsAppLocationService.isLocationSharingAvailable();
    if (!isAvailable && mounted) {
      setState(() {});
    }
  }

  Future<void> _shareCurrentLocation() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Request permissions if needed
      final hasPermission = await WhatsAppLocationService.requestLocationPermissions();
      if (!hasPermission) {
        _showErrorDialog(AppLocalizations.of(context).pleaseAllowLocationAccess);
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
      });

      // Get address from coordinates
      final address = await WhatsAppLocationService.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _currentAddress = address;
      });

      // Send location to server
      final success = await WhatsAppLocationService.sendCustomerLocation(
        orderId: widget.orderId,
        customerPhone: widget.customerPhone,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      if (success) {
        setState(() {
          _locationShared = true;
        });

        if (widget.onLocationShared != null) {
          widget.onLocationShared!();
        }

        _showSuccessDialog();
      } else {
        _showErrorDialog(AppLocalizations.of(context).failedToSendLocation);
      }
    } catch (e) {
      _showErrorDialog(AppLocalizations.of(context).errorGettingLocation(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.locationSentSuccessfully),
        content: Text(loc.locationReceivedAutoUpdate),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.ok),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'مشاركة الموقع',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'يرجى مشاركة موقعك الحالي لتحديث عنوان التسليم:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            if (_currentPosition != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الموقع الحالي:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'خط العرض: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'خط الطول: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_currentAddress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'العنوان: $_currentAddress',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_locationShared) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'تم إرسال الموقع بنجاح',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _shareCurrentLocation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_isLoading ? 'جاري الحصول على الموقع...' : 'مشاركة موقعي الحالي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Text(
              'ملاحظة: سيتم استخدام موقعك الحالي لتحديث عنوان التسليم تلقائياً.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
