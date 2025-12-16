import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../screens/location_picker_screen.dart';

class CreateScheduledOrderScreen extends StatefulWidget {
  final bool embedded;
  
  const CreateScheduledOrderScreen({super.key, this.embedded = false});

  @override
  State<CreateScheduledOrderScreen> createState() => _CreateScheduledOrderScreenState();
}

class _CreateScheduledOrderScreenState extends State<CreateScheduledOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Order details
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  String _selectedVehicleType = 'any'; // Default to any vehicle type
  final _totalAmountController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Scheduling details
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isRecurring = false;
  String? _recurrencePattern;
  DateTime? _recurrenceEndDate;
  
  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _totalAmountController.dispose();
    _deliveryFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: Text(AppLocalizations.of(context).scheduledOrder),
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
                  colors: [Colors.purple.shade600, Colors.purple.shade400],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.schedule, size: 48, color: Colors.white),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    AppLocalizations.of(context).scheduleOrderLater,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            
            // Scheduling Section
            Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(loc.dateTime),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Date Picker
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: loc.date,
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd', 'ar').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Time Picker
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (time != null) {
                          setState(() => _selectedTime = time);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: loc.time,
                          prefixIcon: const Icon(Icons.access_time),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedTime.format(context),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Recurring option
                    SwitchListTile(
                      title: Text(loc.recurringOrder),
                      subtitle: Text(_isRecurring ? loc.willRepeatAutomatically : loc.oneTimeOrder),
                      value: _isRecurring,
                      onChanged: (value) => setState(() => _isRecurring = value),
                      activeColor: AppColors.primary,
                    ),
                    if (_isRecurring) ...[
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: loc.recurrencePattern,
                          prefixIcon: const Icon(Icons.repeat),
                          border: const OutlineInputBorder(),
                        ),
                        value: _recurrencePattern,
                        items: [
                          DropdownMenuItem(value: 'daily', child: Text(loc.daily)),
                          DropdownMenuItem(value: 'weekly', child: Text(loc.weekly)),
                          DropdownMenuItem(value: 'monthly', child: Text(loc.monthly)),
                        ],
                        onChanged: (value) => setState(() => _recurrencePattern = value),
                        validator: (v) => _isRecurring && v == null ? loc.required : null,
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _recurrenceEndDate ?? _selectedDate.add(const Duration(days: 30)),
                            firstDate: _selectedDate,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _recurrenceEndDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: loc.recurrenceEndDate,
                            prefixIcon: const Icon(Icons.event_busy),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _recurrenceEndDate != null 
                                ? DateFormat('yyyy-MM-dd', 'ar').format(_recurrenceEndDate!)
                                : loc.noEnd,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    // Order Details Section
                    _buildSectionHeader(loc.orderDetails),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: InputDecoration(
                        labelText: loc.customerName,
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? loc.required : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    TextFormField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: loc.customerPhone,
                        prefixIcon: const Icon(Icons.phone),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? loc.required : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
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
            
                    _buildLocationField(
                      label: loc.deliveryLocation,
                      controller: _deliveryAddressController,
                      latitude: _deliveryLatitude,
                      longitude: _deliveryLongitude,
                      onLocationSelected: (address, lat, lng) {
                        setState(() {
                          _deliveryAddressController.text = address;
                          _deliveryLatitude = lat;
                          _deliveryLongitude = lng;
                        });
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildVehicleTypeSelector(),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    TextFormField(
                      controller: _totalAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.totalAmountIqd,
                        prefixIcon: const Icon(Icons.attach_money),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? loc.required : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    TextFormField(
                      controller: _deliveryFeeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.deliveryFeeIqd,
                        prefixIcon: const Icon(Icons.payments),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? loc.required : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: loc.notesOptional,
                        prefixIcon: const Icon(Icons.note),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    // Summary Card
                    Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.schedulingSummary,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.willBePublishedAt('${DateFormat('yyyy-MM-dd', 'ar').format(_selectedDate)} ${_selectedTime.format(context)}'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (_isRecurring && _recurrencePattern != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              loc.recurrenceLabel(_getRecurrenceLabel(_recurrencePattern!)),
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (_recurrenceEndDate != null)
                              Text(
                                '${loc.until}${DateFormat('yyyy-MM-dd', 'ar').format(_recurrenceEndDate!)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            
            Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return PrimaryButton(
                  text: _isRecurring ? loc.scheduleRecurringOrder : loc.scheduleOrder,
                  onPressed: _submitScheduledOrder,
                  isLoading: _isLoading,
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
                  loc.vehicleTypeLabel,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildVehicleOption('any', Icons.widgets_outlined, loc.anyVehicle),
                    const SizedBox(width: 8),
                    _buildVehicleOption('motorcycle', Icons.two_wheeler, loc.motorbike),
                    const SizedBox(width: 8),
                    _buildVehicleOption('car', Icons.directions_car, loc.car),
                    const SizedBox(width: 8),
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
  
  String _getRecurrenceLabel(String pattern) {
    final loc = AppLocalizations.of(context);
    switch (pattern) {
      case 'daily':
        return loc.dailyLabel;
      case 'weekly':
        return loc.weeklyLabel;
      case 'monthly':
        return loc.monthlyLabel;
      default:
        return pattern;
    }
  }
  
  Future<void> _submitScheduledOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context);
    if (_pickupLatitude == null || _pickupLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseSelectPickupLocation)),
      );
      return;
    }
    if (_deliveryLatitude == null || _deliveryLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.pleaseSelectDeliveryLocation)),
      );
      return;
    }
    
    final merchantId = Supabase.instance.client.auth.currentUser?.id;
    if (merchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.merchantDataErrorLoginAgain),
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
              Icon(Icons.info_outline, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).alert),
            ],
          ),
          content: Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Text(
                '${availabilityResult.userMessage(context)}\n\n${loc.canContinueScheduledOrder}',
                style: const TextStyle(fontSize: 16),
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
                backgroundColor: Colors.blue.shade600,
              ),
              child: Text(AppLocalizations.of(context).continueText),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final merchantId = context.read<AuthProvider>().user!.id;
      
      // Combine date and time
      final scheduledDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final scheduledTime = Duration(
        hours: _selectedTime.hour,
        minutes: _selectedTime.minute,
      );
      
      await Supabase.instance.client
          .from('scheduled_orders')
          .insert({
            'merchant_id': merchantId,
            'customer_name': _customerNameController.text,
            'customer_phone': _customerPhoneController.text,
            'pickup_address': _pickupAddressController.text,
            'delivery_address': _deliveryAddressController.text,
            'pickup_latitude': _pickupLatitude,
            'pickup_longitude': _pickupLongitude,
            'delivery_latitude': _deliveryLatitude,
            'delivery_longitude': _deliveryLongitude,
            'vehicle_type': _selectedVehicleType,
            'total_amount': double.parse(_totalAmountController.text),
            'delivery_fee': double.parse(_deliveryFeeController.text),
            'notes': _notesController.text,
            'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
            'scheduled_time': '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
            'is_recurring': _isRecurring,
            'recurrence_pattern': _isRecurring ? _recurrencePattern : null,
            'recurrence_end_date': _recurrenceEndDate?.toIso8601String().split('T')[0],
            'status': 'scheduled',
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).orderScheduledSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
