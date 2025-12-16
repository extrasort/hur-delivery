import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../screens/location_picker_screen.dart';

class CreateBulkOrderScreen extends StatefulWidget {
  final bool embedded;
  
  const CreateBulkOrderScreen({super.key, this.embedded = false});

  @override
  State<CreateBulkOrderScreen> createState() => _CreateBulkOrderScreenState();
}

class _CreateBulkOrderScreenState extends State<CreateBulkOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Common bulk order details (only pickup is constant)
  final _pickupAddressController = TextEditingController();
  double? _pickupLatitude;
  double? _pickupLongitude;
  final _notesController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  String _selectedVehicleType = 'any'; // Default to any vehicle type
  
  // Scheduling slider
  double _scheduledMinutes = 0; // 0 = now, 10, 20, 30, 40, 50, 60
  
  // List of delivery items
  final List<BulkOrderItem> _deliveryItems = [];
  
  @override
  void dispose() {
    _pickupAddressController.dispose();
    _notesController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: Text(AppLocalizations.of(context).bulkOrders),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.layers, size: 48, color: Colors.white),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    AppLocalizations.of(context).multipleOrdersSamePickup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            
            // Section: Common Details
            Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(loc.sharedDetails),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Pickup Location
                    _buildLocationField(
                      label: loc.pickupLocation,
                      controller: _pickupAddressController,
                      latitude: _pickupLatitude,
                      longitude: _pickupLongitude,
                      onLocationSelected: (address, lat, lng) {
                        setState(() {
                          _pickupAddressController.text = address;
                          _pickupLatitude = lat;
                          _pickupLongitude = lng;
                        });
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: loc.generalNotesOptional,
                        prefixIcon: const Icon(Icons.note),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    // Scheduling Section
                    _buildSectionHeader(loc.whenNeedDrivers),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return Row(
                            children: [
                              Text(
                                _scheduledMinutes == 0 
                                    ? loc.nowImmediately 
                                    : loc.afterMinutes(_scheduledMinutes.toInt()),
                                style: AppTextStyles.heading3.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                              if (_scheduledMinutes > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    loc.scheduledOrders,
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withOpacity(0.2),
                      valueIndicatorColor: AppColors.primary,
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _scheduledMinutes,
                      min: 0,
                      max: 60,
                      divisions: 6,
                      label: _scheduledMinutes == 0 
                          ? AppLocalizations.of(context).now 
                          : '${_scheduledMinutes.toInt()} ${AppLocalizations.of(context).minutes}',
                      onChanged: (value) {
                        setState(() {
                          _scheduledMinutes = value;
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.now,
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                loc.sixtyMinutes,
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    
                    // Section: Delivery Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader(loc.deliveryAddresses(_deliveryItems.length)),
                                ElevatedButton.icon(
                                  onPressed: _addDeliveryItem,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(loc.addAddress),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    
                    // Delivery Items List
                    if (_deliveryItems.isEmpty)
                      Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context).noDeliveryAddresses,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._deliveryItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _buildDeliveryItemCard(index, item);
                      }),
                    
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    
                    // Submit Button
                    Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        return PrimaryButton(
                          text: loc.createBulkOrders(_deliveryItems.length),
                          onPressed: _deliveryItems.isEmpty ? null : _submitBulkOrder,
                          isLoading: _isLoading,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
  
  Widget _buildLocationField({
    required String label,
    required TextEditingController controller,
    required double? latitude,
    required double? longitude,
    required Function(String, double, double) onLocationSelected,
  }) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => LocationPickerScreen(
              title: label,
              initialLatitude: latitude,
              initialLongitude: longitude,
            ),
          ),
        );
        
        if (result != null) {
          onLocationSelected(
            result['address'],
            result['latitude'],
            result['longitude'],
          );
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: const Icon(Icons.map),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context).pleaseSelect(label);
            }
            return null;
          },
        ),
      ),
    );
  }
  
  Widget _buildVehicleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final loc = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.vehicleType,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildVehicleOption('motorcycle', Icons.two_wheeler, loc.motorcycle),
                    const SizedBox(width: 12),
                    _buildVehicleOption('car', Icons.directions_car, loc.car),
                    const SizedBox(width: 12),
                    _buildVehicleOption('truck', Icons.local_shipping, loc.truck),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildVehicleOption(String type, IconData icon, String label) {
    final isSelected = _selectedVehicleType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedVehicleType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeliveryItemCard(int index, BulkOrderItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.015),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeDeliveryItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(),
          _buildInfoRow(Icons.phone, item.customerPhone),
          _buildInfoRow(Icons.location_on, item.deliveryAddress),
          _buildInfoRow(Icons.attach_money, AppLocalizations.of(context).orderPriceLabel(item.totalAmount)),
          if (item.itemNotes != null && item.itemNotes!.isNotEmpty)
            _buildInfoRow(Icons.note, item.itemNotes!),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _addDeliveryItem() {
    showDialog(
      context: context,
      builder: (context) => _AddDeliveryItemDialog(
        onAdd: (item) {
          setState(() {
            _deliveryItems.add(item);
          });
        },
      ),
    );
  }
  
  void _removeDeliveryItem(int index) {
    setState(() {
      _deliveryItems.removeAt(index);
    });
  }
  
  Future<void> _submitBulkOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context);
    if (_pickupLatitude == null || _pickupLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseSelectPickup)),
      );
      return;
    }
    if (_deliveryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseAddDelivery)),
      );
      return;
    }
    
    final merchantId = Supabase.instance.client.auth.currentUser?.id;
    if (merchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.merchantDataError),
        ),
      );
      return;
    }

    final availabilityResult = await DriverAvailabilityService.checkAvailability(
      merchantId: merchantId,
      vehicleType: _selectedVehicleType,
    );

    if (!availabilityResult.available) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Text(loc.noDriversAvailable),
            ],
          ),
          content: Text(
            availabilityResult.userMessage(context),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.continueAtOwnRisk),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).confirmBulkOrders),
        content: Builder(
          builder: (context) {
            final loc = AppLocalizations.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.confirmBulkOrdersQuestion(_deliveryItems.length),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _scheduledMinutes > 0
                      ? loc.scheduledBulkOrdersMessage(_scheduledMinutes.toInt())
                      : loc.publishOrdersImmediately,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final merchantId = context.read<AuthProvider>().user!.id;
      
      print('🚀 Starting bulk order creation for merchant: $merchantId');
      print('   Pickup: ${_pickupAddressController.text}');
      print('   Vehicle type: $_selectedVehicleType');
      print('   Delivery fee: ${_deliveryFeeController.text}');
      print('   Items count: ${_deliveryItems.length}');
      
      // Validate vehicle type before insertion
      if (!['motorcycle', 'car', 'truck'].contains(_selectedVehicleType)) {
        throw Exception('Invalid vehicle type: $_selectedVehicleType');
      }
      
      // Check if this is a scheduled bulk order
      final scheduledTime = _scheduledMinutes > 0 
          ? DateTime.now().add(Duration(minutes: _scheduledMinutes.toInt()))
          : null;
      
      // Create bulk order
      final bulkOrderResponse = await Supabase.instance.client
          .from('bulk_orders')
          .insert({
            'merchant_id': merchantId,
            'pickup_address': _pickupAddressController.text,
            'pickup_latitude': _pickupLatitude,
            'pickup_longitude': _pickupLongitude,
            'vehicle_type': _selectedVehicleType,
            'delivery_fee': double.parse(_deliveryFeeController.text),
            'notes': _notesController.text.isEmpty ? null : _notesController.text,
            'total_orders': _deliveryItems.length,
            'posted_orders': 0,
            'status': 'draft',
            if (scheduledTime != null) 'scheduled_at': scheduledTime.toIso8601String(),
          })
          .select()
          .single();
      
      final bulkOrderId = bulkOrderResponse['id'];
      print('✅ Bulk order created with ID: $bulkOrderId');
      print('   Vehicle type saved: ${bulkOrderResponse['vehicle_type']}');
      
      // Insert bulk order items
      print('📝 Inserting ${_deliveryItems.length} bulk order items...');
      for (int i = 0; i < _deliveryItems.length; i++) {
        final item = _deliveryItems[i];
        print('   Item ${i + 1}: ${item.customerName} -> ${item.deliveryAddress}');
        
        await Supabase.instance.client
            .from('bulk_order_items')
            .insert({
              'bulk_order_id': bulkOrderId,
              'customer_name': item.customerName,
              'customer_phone': item.customerPhone,
              'delivery_address': item.deliveryAddress,
              'delivery_latitude': item.deliveryLatitude,
              'delivery_longitude': item.deliveryLongitude,
              'total_amount': item.totalAmount,
              'item_notes': item.itemNotes,
              'status': 'pending',
              'sequence_number': i + 1,
            });
      }
      print('✅ All bulk order items inserted');
      
      // Verify bulk order was created correctly
      final verifyBulk = await Supabase.instance.client
          .from('bulk_orders')
          .select()
          .eq('id', bulkOrderId)
          .single();
      
      print('🔍 Verifying bulk order before posting:');
      print('   ID: ${verifyBulk['id']}');
      print('   Vehicle Type: ${verifyBulk['vehicle_type']}');
      print('   Total Orders: ${verifyBulk['total_orders']}');
      print('   Status: ${verifyBulk['status']}');
      
      // Post bulk order (create all orders immediately or schedule them)
      if (scheduledTime != null) {
        // Scheduled bulk order - don't post immediately
        print('📅 Bulk order scheduled for: ${scheduledTime.toIso8601String()}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).bulkOrdersScheduledSuccess(_deliveryItems.length, _scheduledMinutes.toInt())),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ),
          );
          context.pop();
        }
      } else {
        // Immediate posting
        print('📤 Calling post_bulk_order RPC function...');
        print('   Bulk Order ID: $bulkOrderId');
        
        try {
          final result = await Supabase.instance.client
              .rpc('post_bulk_order', params: {'p_bulk_order_id': bulkOrderId});
          
          print('✅ RPC call completed. Raw result: $result');
          print('   Result type: ${result.runtimeType}');
          
          if (mounted) {
            int posted = 0;
            int failed = 0;
            
            if (result is List && result.isNotEmpty) {
              posted = result[0]['posted_count'] ?? 0;
              failed = result[0]['failed_count'] ?? 0;
            }
            
            print('📊 Results: Posted=$posted, Failed=$failed');
            
            final loc = AppLocalizations.of(context);
            String message = loc.bulkOrdersCreatedSuccess(posted);
            if (failed > 0) {
              message += ' (${loc.failed}: $failed)';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: failed > 0 ? Colors.orange : AppColors.success,
                duration: const Duration(seconds: 4),
              ),
            );
            context.pop();
          }
        } catch (rpcError) {
          print('❌ RPC Error: $rpcError');
          throw Exception(AppLocalizations.of(context).bulkOrdersFailed(rpcError.toString()));
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error creating bulk order: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorGeneric}: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class BulkOrderItem {
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final double totalAmount;
  final double deliveryFee;
  final String vehicleType;
  final String? itemNotes;
  
  BulkOrderItem({
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.totalAmount,
    required this.deliveryFee,
    required this.vehicleType,
    this.itemNotes,
  });
}

class _AddDeliveryItemDialog extends StatefulWidget {
  final Function(BulkOrderItem) onAdd;
  
  const _AddDeliveryItemDialog({required this.onAdd});
  
  @override
  State<_AddDeliveryItemDialog> createState() => _AddDeliveryItemDialogState();
}

class _AddDeliveryItemDialogState extends State<_AddDeliveryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedVehicleType = 'any'; // Default to any vehicle type
  double? _latitude;
  double? _longitude;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            shrinkWrap: true,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).addDeliveryAddress,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).customerName,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context).required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).phoneNumber,
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context).required : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerScreen(
                        title: AppLocalizations.of(context).deliveryLocation,
                        initialLatitude: _latitude,
                        initialLongitude: _longitude,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _addressController.text = result['address'];
                      _latitude = result['latitude'];
                      _longitude = result['longitude'];
                    });
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).deliveryLocation,
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: const Icon(Icons.map),
                    ),
                    validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context).required : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    children: [
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: loc.orderAmount,
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        validator: (v) => v == null || v.isEmpty ? loc.required : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _deliveryFeeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: loc.deliveryFeeIqd,
                          prefixIcon: const Icon(Icons.local_shipping),
                        ),
                        validator: (v) => v == null || v.isEmpty ? loc.required : null,
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.vehicleType,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildVehicleOption('motorcycle'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildVehicleOption('car'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildVehicleOption('truck'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: loc.notesOptional,
                          prefixIcon: const Icon(Icons.note),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate() && _latitude != null && _longitude != null) {
                            widget.onAdd(BulkOrderItem(
                              customerName: _nameController.text,
                              customerPhone: _phoneController.text,
                              deliveryAddress: _addressController.text,
                              deliveryLatitude: _latitude!,
                              deliveryLongitude: _longitude!,
                              totalAmount: double.parse(_amountController.text),
                              deliveryFee: double.tryParse(_deliveryFeeController.text) ?? 0.0,
                              vehicleType: _selectedVehicleType,
                              itemNotes: _notesController.text.isEmpty ? null : _notesController.text,
                            ));
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(loc.add, style: const TextStyle(fontSize: 16)),
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

  Widget _buildVehicleOption(String type) {
    final loc = AppLocalizations.of(context);
    final labels = {
      'motorcycle': loc.motorbike,
      'car': loc.car,
      'truck': loc.truck,
    };
    final icons = {
      'motorcycle': Icons.two_wheeler,
      'car': Icons.directions_car,
      'truck': Icons.local_shipping,
    };
    
    final isSelected = _selectedVehicleType == type;
    return InkWell(
      onTap: () => setState(() => _selectedVehicleType = type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icons[type],
              color: isSelected ? Colors.white : Colors.black54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              labels[type] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
