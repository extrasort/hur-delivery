import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/header_notification.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/driver_availability_service.dart';
import '../../../core/services/najaf_districts_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import 'location_picker_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  final bool embedded;
  final Map<String, dynamic>? initialData;
  
  const CreateOrderScreen({
    super.key, 
    this.embedded = false,
    this.initialData,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final FocusNode _customerPhoneFocusNode = FocusNode();
  final _pickupAddressController = TextEditingController();
  final FocusNode _pickupAddressFocusNode = FocusNode();
  final _deliveryAddressController = TextEditingController();
  final FocusNode _deliveryAddressFocusNode = FocusNode();
  final _totalAmountController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _notesController = TextEditingController();
  
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  
  bool _isLoading = false;
  int _onlineDriversCount = 0;
  bool _checkingDrivers = true;
  RealtimeChannel? _driversChannel;
  Timer? _refreshTimer;
  Timer? _phoneDebounce;
  List<String> _phoneSuggestions = [];
  bool _showPhoneSuggestions = false;
  Timer? _addressDebounce;
  List<NajafDistrict> _pickupAddressSuggestions = [];
  List<NajafDistrict> _deliveryAddressSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDeliverySuggestions = false;
  bool _phoneLocked = false;
  
  // Scheduling slider
  double _scheduledMinutes = 0; // 0 = now, 10, 20, 30, 40, 50, 60
  
  // Vehicle type selection
  String _selectedVehicleType = 'any'; // Default to any vehicle type

  @override
  void initState() {
    super.initState();
    
    // Pre-fill form if initialData is provided (e.g., from voice order)
    if (widget.initialData != null) {
      _prefillFormFromVoiceData(widget.initialData!);
    }
    
    // Check credit limit immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
        final loc = AppLocalizations.of(context);
      final walletProvider = context.read<WalletProvider>();
      if (walletProvider.balance <= walletProvider.creditLimit) {
        // Redirect back and show message
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.insufficientBalanceCreate),
            backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Show info about voice-filled data
      if (widget.initialData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.formFilledFromVoice),
            backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
          ),
        );
      }
    });
    
    _loadMerchantLocation();
    _checkOnlineDrivers();
    _subscribeToDriverUpdates();
    _startPeriodicRefresh();
    
    // Add listeners for real-time updates
    _totalAmountController.addListener(() {
      setState(() {}); // Trigger rebuild to update summary
    });
    _deliveryFeeController.addListener(() {
      setState(() {}); // Trigger rebuild to update summary
    });

    // Phone field behaviors: strip leading zero and fetch suggestions
    _customerPhoneController.addListener(() {
      final text = _customerPhoneController.text;
      if (text.startsWith('0')) {
        final withoutZero = text.replaceFirst(RegExp('^0+'), '');
        if (withoutZero != text) {
          final selectionIndex = _customerPhoneController.selection.baseOffset - (text.length - withoutZero.length);
          _customerPhoneController.value = TextEditingValue(
            text: withoutZero,
            selection: TextSelection.collapsed(offset: selectionIndex.clamp(0, withoutZero.length)),
          );
        }
      }

      // Debounced fetch after 3+ digits
      if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\D'), '').length >= 3 && _customerPhoneFocusNode.hasFocus) {
        _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
      } else {
        setState(() {
          _phoneSuggestions = [];
          _showPhoneSuggestions = false;
        });
      }

      // Lock when valid Iraqi local number (10 digits starting with 7)
      final digits = _customerPhoneController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 10 && digits.startsWith('7')) {
        _phoneLocked = true;
      }
    });

    _customerPhoneFocusNode.addListener(() {
      if (!_customerPhoneFocusNode.hasFocus) {
        setState(() {
          _showPhoneSuggestions = false;
        });
      } else {
        if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\D'), '').length >= 3) {
          _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
        }
      }
    });
    
    // Initialize address suggestions
    _initializeAddressListeners();
    NajafDistrictsService.loadDistricts();
  }
  
  void _prefillFormFromVoiceData(Map<String, dynamic> data) {
    print('📝 Pre-filling form from voice data: $data');
    
    if (data['customer_name'] != null) {
      _customerNameController.text = data['customer_name'];
    }
    if (data['customer_phone'] != null) {
      _customerPhoneController.text = data['customer_phone'];
    }
    if (data['delivery_address'] != null) {
      _deliveryAddressController.text = data['delivery_address'];
    }
    if (data['delivery_fee'] != null) {
      _deliveryFeeController.text = data['delivery_fee'].toString();
    }
    if (data['grand_total'] != null) {
      _totalAmountController.text = data['grand_total'].toString();
    }
    if (data['notes'] != null) {
      _notesController.text = data['notes'];
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driversChannel?.unsubscribe();
    _phoneDebounce?.cancel();
    _addressDebounce?.cancel();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerPhoneFocusNode.dispose();
    _pickupAddressController.dispose();
    _pickupAddressFocusNode.dispose();
    _deliveryAddressController.dispose();
    _deliveryAddressFocusNode.dispose();
    _totalAmountController.dispose();
    _deliveryFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _debouncedFetchPhoneSuggestions(String input) {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _fetchCustomerPhoneSuggestions(input);
    });
  }

  Future<void> _fetchCustomerPhoneSuggestions(String input) async {
    try {
      final auth = context.read<AuthProvider>();
      final merchantId = auth.user?.id;
      if (merchantId == null) return;

      final digits = input.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 3) return;

      // Query distinct customer_phone for this merchant starting with typed digits (ignoring +964 if present)
      // Normalize search by allowing both with and without +964
      final patterns = <String>[
        '$digits%',
        '+964$digits%',
        '964$digits%',
      ];

      final results = <String>{};
      for (final p in patterns) {
        final rows = await Supabase.instance.client
            .from('orders')
            .select('customer_phone')
            .eq('merchant_id', merchantId)
            .ilike('customer_phone', p)
            .limit(10);
        for (final r in rows) {
          final ph = (r['customer_phone'] ?? '').toString();
          if (ph.isNotEmpty) results.add(ph);
        }
      }

      setState(() {
        _phoneSuggestions = results.take(10).toList();
        _showPhoneSuggestions = _phoneSuggestions.isNotEmpty && _customerPhoneFocusNode.hasFocus;
      });
    } catch (e) {
      // Silently ignore
    }
  }

  void _initializeAddressListeners() {
    // Pickup address listener
    _pickupAddressController.addListener(() {
      if (_pickupAddressFocusNode.hasFocus) {
        _debouncedFetchAddressSuggestions('pickup');
      }
    });

    _pickupAddressFocusNode.addListener(() {
      if (!_pickupAddressFocusNode.hasFocus) {
        setState(() {
          _showPickupSuggestions = false;
        });
      } else if (_pickupAddressController.text.isNotEmpty) {
        _debouncedFetchAddressSuggestions('pickup');
      }
    });

    // Delivery address listener
    _deliveryAddressController.addListener(() {
      if (_deliveryAddressFocusNode.hasFocus) {
        _debouncedFetchAddressSuggestions('delivery');
      }
    });

    _deliveryAddressFocusNode.addListener(() {
      if (!_deliveryAddressFocusNode.hasFocus) {
        setState(() {
          _showDeliverySuggestions = false;
        });
      } else if (_deliveryAddressController.text.isNotEmpty) {
        _debouncedFetchAddressSuggestions('delivery');
      }
    });
  }

  void _debouncedFetchAddressSuggestions(String type) {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _fetchAddressSuggestions(type);
    });
  }

  Future<void> _fetchAddressSuggestions(String type) async {
    final controller = type == 'pickup' ? _pickupAddressController : _deliveryAddressController;
    final query = controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        if (type == 'pickup') {
          _pickupAddressSuggestions = [];
          _showPickupSuggestions = false;
        } else {
          _deliveryAddressSuggestions = [];
          _showDeliverySuggestions = false;
        }
      });
      return;
    }

    try {
      final suggestions = await NajafDistrictsService.searchDistricts(query);

      if (mounted) {
        setState(() {
          if (type == 'pickup') {
            _pickupAddressSuggestions = suggestions.take(8).toList();
            _showPickupSuggestions = _pickupAddressSuggestions.isNotEmpty && _pickupAddressFocusNode.hasFocus;
          } else {
            _deliveryAddressSuggestions = suggestions.take(8).toList();
            _showDeliverySuggestions = _deliveryAddressSuggestions.isNotEmpty && _deliveryAddressFocusNode.hasFocus;
          }
        });
      }
    } catch (e) {
      print('Error fetching address suggestions: $e');
    }
  }

  void _selectDistrict(NajafDistrict district, String type) {
    setState(() {
      if (type == 'pickup') {
        _pickupAddressController.text = district.name;
        _pickupLatitude = district.latitude;
        _pickupLongitude = district.longitude;
        _showPickupSuggestions = false;
        _pickupAddressFocusNode.unfocus();
      } else {
        _deliveryAddressController.text = district.name;
        _deliveryLatitude = district.latitude;
        _deliveryLongitude = district.longitude;
        _showDeliverySuggestions = false;
        _deliveryAddressFocusNode.unfocus();
      }
    });
  }

  Future<void> _loadMerchantLocation() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    
    if (user != null && user.latitude != null && user.longitude != null) {
      setState(() {
        _pickupLatitude = user.latitude;
        _pickupLongitude = user.longitude;
        final loc = AppLocalizations.of(context);
        _pickupAddressController.text = user.address ?? loc.storeLocation;
      });
    } else {
      // Default to Baghdad
      setState(() {
        _pickupLatitude = AppConstants.defaultLatitude;
        _pickupLongitude = AppConstants.defaultLongitude;
        final loc = AppLocalizations.of(context);
        _pickupAddressController.text = loc.storeLocation;
      });
    }
  }

  void _startPeriodicRefresh() {
    // Refresh driver count every 10 seconds as fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkOnlineDrivers();
    });
  }

  void _subscribeToDriverUpdates() {
    try {
      // Subscribe to real-time driver status changes
      _driversChannel = Supabase.instance.client
          .channel('driver_status_changes_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'role',
              value: 'driver',
            ),
            callback: (payload) {
              print('🔄 Driver status changed: ${payload.eventType}');
              print('📊 Old data: ${payload.oldRecord?['is_online']}');
              print('📊 New data: ${payload.newRecord?['is_online']}');
              _checkOnlineDrivers();
            },
          )
          .subscribe((status, error) {
            if (error != null) {
              print('❌ Subscription error: $error');
            } else {
              print('✅ Subscription status: $status');
            }
          });
      
      print('✅ Subscribed to driver status updates');
    } catch (e) {
      print('❌ Failed to subscribe to driver updates: $e');
    }
  }

  Future<void> _checkOnlineDrivers() async {
    try {
      print('');
      print('═══════════════════════════════════════');
      print('🔍 CHECKING FOR AVAILABLE DRIVERS (ONLINE & FREE)');
      print('═══════════════════════════════════════');
      
      // First check all drivers to see their status
      final allDrivers = await Supabase.instance.client
          .from('users')
          .select('id, name, is_online, manual_verified, role')
          .eq('role', 'driver');
      
      print('📊 Total drivers: ${allDrivers.length}');
      for (var driver in allDrivers) {
        final online = driver['is_online'] ?? false;
        final verified = driver['manual_verified'] ?? false;
        print('   ${driver['name']}: online=$online, verified=$verified');
      }
      
      // Get only online drivers
      final onlineDrivers = await Supabase.instance.client
          .from('users')
          .select('id, name, is_online, manual_verified')
          .eq('role', 'driver')
          .eq('is_online', true);
      
      print('');
      print('📋 Online drivers: ${onlineDrivers.length}');
      
      if (onlineDrivers.isEmpty) {
        print('❌ NO ONLINE DRIVERS FOUND!');
        if (mounted) {
          setState(() {
            _onlineDriversCount = 0;
            _checkingDrivers = false;
          });
        }
        return;
      }
      
      // Get driver IDs
      final driverIds = (onlineDrivers as List<dynamic>)
          .map((driver) => driver['id'] as String?)
          .whereType<String>()
          .toList();
      
      // Check for active orders
      final activeOrders = await Supabase.instance.client
          .from('orders')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .inFilter('status', ['pending', 'assigned', 'accepted', 'on_the_way']);
      
      // Get drivers with active orders
      final busyDriverIds = (activeOrders as List<dynamic>)
          .map((order) => order['driver_id'] as String?)
          .whereType<String>()
          .toSet();
      
      // Calculate free drivers
      final freeDriverCount = driverIds.where((id) => !busyDriverIds.contains(id)).length;
      
      print('');
      print('📊 Driver Status:');
      print('   Online: ${driverIds.length}');
      print('   Busy: ${busyDriverIds.length}');
      print('   Free: $freeDriverCount');
      
      for (var driver in onlineDrivers) {
        final id = driver['id'] as String;
        final name = driver['name'];
        final isBusy = busyDriverIds.contains(id);
        print('   ${isBusy ? "🔴" : "🟢"} $name - ${isBusy ? "BUSY" : "FREE"}');
      }
      
      print('');
      print('🔄 Updating UI state...');
      print('   Current count: $_onlineDriversCount');
      print('   New count: $freeDriverCount');
      print('   Mounted: $mounted');
      
      if (mounted) {
        setState(() {
          _onlineDriversCount = freeDriverCount;
          _checkingDrivers = false;
        });
        print('✅ UI STATE UPDATED to $_onlineDriversCount drivers');
      } else {
        print('❌ Widget not mounted - UI NOT updated');
      }
      
      print('═══════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ERROR CHECKING DRIVERS ❌❌❌');
      print('Error: $e');
      print('Type: ${e.runtimeType}');
      print('Stack: $stackTrace');
      print('');
      
      if (mounted) {
        setState(() {
          _checkingDrivers = false;
        });
      }
    }
  }

  Future<void> _pickLocation(String type) async {
    final loc = AppLocalizations.of(context);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: type == 'pickup' ? _pickupLatitude : _deliveryLatitude,
          initialLongitude: type == 'pickup' ? _pickupLongitude : _deliveryLongitude,
          title: type == 'pickup' ? loc.pickLocationPickup : loc.pickLocationDelivery,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (type == 'pickup') {
          _pickupLatitude = result['latitude'];
          _pickupLongitude = result['longitude'];
          _pickupAddressController.text = result['address'] ?? loc.locationSelected;
        } else {
          _deliveryLatitude = result['latitude'];
          _deliveryLongitude = result['longitude'];
          _deliveryAddressController.text = result['address'] ?? loc.locationSelected;
        }
      });
    }
  }

  Future<void> _geocodeAddress(String type) async {
    final address = type == 'pickup' 
        ? _pickupAddressController.text.trim()
        : _deliveryAddressController.text.trim();

    if (address.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final result = await GeocodingService.geocodeNajafAddress(address);

      if (result != null && mounted) {
        setState(() {
          if (type == 'pickup') {
            _pickupLatitude = result['latitude'];
            _pickupLongitude = result['longitude'];
            // Use 'address' field from v6 API response (which now returns 'address' instead of 'formatted_address')
            if (result['address'] != null) {
              _pickupAddressController.text = result['address'];
            } else if (result['formatted_address'] != null) {
              _pickupAddressController.text = result['formatted_address'];
            }
          } else {
            _deliveryLatitude = result['latitude'];
            _deliveryLongitude = result['longitude'];
            // Use 'address' field from v6 API response
            if (result['address'] != null) {
              _deliveryAddressController.text = result['address'];
            } else if (result['formatted_address'] != null) {
              _deliveryAddressController.text = result['formatted_address'];
            }
          }
          _isLoading = false;
        });

        if (mounted) {
          final loc = AppLocalizations.of(context);
          showHeaderNotification(
            context,
            title: loc.locationSuccess,
            message: loc.locationSuccessMessage,
            type: NotificationType.success,
          );
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.locationNotFound,
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final loc = AppLocalizations.of(context);
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.locationError,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    final loc = AppLocalizations.of(context);
    // Check credit limit first
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.balance <= walletProvider.creditLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.insufficientBalanceCreate),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Check for online drivers
    if (_onlineDriversCount == 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.warning, size: context.ri(24)),
              SizedBox(width: context.rs(8)),
              ResponsiveText(loc.noDriversOnline, style: TextStyle(fontSize: context.rf(16))),
            ],
          ),
          content: ResponsiveText(
            loc.cannotCreateOrder,
            style: TextStyle(fontSize: context.rf(16)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.ok),
            ),
          ],
        ),
      );
      return;
    }
    
    final merchantId = Supabase.instance.client.auth.currentUser?.id;
    if (merchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.userDataError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final availabilityResult = await DriverAvailabilityService.checkAvailability(
      merchantId: merchantId,
      vehicleType: _selectedVehicleType,
    );

    if (!availabilityResult.available) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.warning, size: context.ri(24)),
              SizedBox(width: context.rs(8)),
              ResponsiveText(loc.noDriversAvailable, style: TextStyle(fontSize: context.rf(16))),
            ],
          ),
          content: ResponsiveText(
            availabilityResult.userMessage(context),
            style: TextStyle(fontSize: context.rf(16)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.ok),
            ),
          ],
        ),
      );
      return;
    }
    
    if (_pickupLatitude == null || _pickupLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.pickLocationPickup} - ${loc.required}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_deliveryLatitude == null || _deliveryLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.pickLocationDelivery} - ${loc.required}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Normalize phone to always save with +964 prefix
      final customerPhone = _formatCustomerPhoneForSave(_customerPhoneController.text);
      final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      final deliveryFee = double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;

      // Calculate ready_at time if countdown is set
      DateTime? readyAt;
      int readyCountdown = _scheduledMinutes.toInt();
      
      if (_scheduledMinutes > 0) {
        readyAt = DateTime.now().add(Duration(minutes: readyCountdown));
      }

      // Create order (always immediate, but with ready countdown if set)
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.createOrder(
        customerName: _customerNameController.text.trim().isEmpty 
            ? loc.customerNameFallback
            : _customerNameController.text.trim(),
        customerPhone: customerPhone,
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLatitude: _pickupLatitude!,
        pickupLongitude: _pickupLongitude!,
        deliveryAddress: _deliveryAddressController.text.trim(),
        deliveryLatitude: _deliveryLatitude!,
        deliveryLongitude: _deliveryLongitude!,
        totalAmount: totalAmount,
        deliveryFee: deliveryFee,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        vehicleType: _selectedVehicleType,
        readyAt: readyAt,
        readyCountdown: readyCountdown > 0 ? readyCountdown : null,
      );

      if (success && mounted) {
        showHeaderNotification(
          context,
          title: loc.orderCreated,
          message: readyCountdown > 0 
              ? loc.orderCreatedReadyAfter(readyCountdown)
              : loc.orderCreatedSuccess,
          type: NotificationType.success,
        );
        Navigator.pop(context);
      } else if (mounted) {
        showHeaderNotification(
          context,
          title: loc.error,
          message: orderProvider.error ?? loc.orderCreateError,
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showHeaderNotification(
          context,
          title: loc.error,
          message: loc.orderCreateError,
          type: NotificationType.error,
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

  String _formatCustomerPhoneForSave(String input) {
    // Keep only digits
    String digits = input.replaceAll(RegExp(r'\D'), '');
    // Remove leading country code if user typed it
    if (digits.startsWith('964')) {
      digits = digits.substring(3);
    }
    // Strip leading zeros
    digits = digits.replaceFirst(RegExp('^0+'), '');
    // Compose
    return '+964$digits';
  }

  // Check if form has enough information to enable floating button
  bool get _hasEnoughInfoToCreateOrder {
    return _customerPhoneController.text.trim().isNotEmpty &&
           _pickupLatitude != null &&
           _pickupLongitude != null &&
           _deliveryLatitude != null &&
           _deliveryLongitude != null &&
           _totalAmountController.text.trim().isNotEmpty &&
           _deliveryFeeController.text.trim().isNotEmpty &&
           !_isLoading;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: widget.embedded ? null : AppBar(
        title: Text(AppLocalizations.of(context).createNewOrder),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Form(
        key: _formKey,
        child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: ResponsiveHelper.getResponsiveSpacing(context, 20),
                right: ResponsiveHelper.getResponsiveSpacing(context, 20),
                top: ResponsiveHelper.getResponsiveSpacing(context, 20),
                bottom: _hasEnoughInfoToCreateOrder 
                    ? 100  // Add padding when button is visible
                    : ResponsiveHelper.getResponsiveSpacing(context, 20),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver Status Banner
              if (_checkingDrivers)
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  margin: EdgeInsets.only(bottom: context.rs(16)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.rs(12)),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: context.ri(20),
                        height: context.ri(20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: context.rs(12)),
                      ResponsiveText(
                        AppLocalizations.of(context).checkingDrivers,
                        style: TextStyle(fontSize: context.rf(14)),
                      ),
                    ],
                  ),
                )
              else if (_onlineDriversCount == 0)
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  margin: EdgeInsets.only(bottom: context.rs(16)),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.rs(12)),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: AppColors.warning,
                        size: context.ri(24),
                      ),
                      SizedBox(width: context.rs(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResponsiveText(
                              AppLocalizations.of(context).noDriversOnline,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                                fontSize: context.rf(15),
                              ),
                            ),
                            SizedBox(height: context.rs(4)),
                            ResponsiveText(
                              AppLocalizations.of(context).cannotCreateOrder,
                              style: TextStyle(
                                fontSize: context.rf(13),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  margin: EdgeInsets.only(bottom: context.rs(16)),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.rs(12)),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).driversAvailableNow,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkOnlineDrivers,
                        child: Text(AppLocalizations.of(context).refresh),
                      ),
                    ],
                  ),
                ),
              
              // Customer Information Section
              _buildSectionHeader(AppLocalizations.of(context).customerInfo, Icons.person),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _customerNameController,
                label: AppLocalizations.of(context).customerNameOptional,
                hint: AppLocalizations.of(context).enterCustomerName,
                icon: Icons.person_outline,
                isRequired: false,
              ),
              
              const SizedBox(height: 16),
              
              _buildPhoneField(),
              if (_showPhoneSuggestions && _phoneSuggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _phoneSuggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _phoneSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, color: AppColors.textSecondary, size: 18),
                          title: Text(
                            suggestion,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                            textDirection: TextDirection.ltr,
                          ),
                          onTap: () {
                            // Put selected suggestion into input (without country code prefix if duplicated visually)
                            final normalized = suggestion.replaceFirst(RegExp(r'^\+?964'), '');
                            _customerPhoneController.text = normalized;
                            _customerPhoneController.selection = TextSelection.collapsed(offset: _customerPhoneController.text.length);
                            // Validate and lock/unfocus
                            final digits = normalized.replaceAll(RegExp(r'\D'), '');
                            if (digits.length == 10 && digits.startsWith('7')) {
                              _phoneLocked = true;
                              _customerPhoneFocusNode.unfocus();
                            }
                            setState(() => _showPhoneSuggestions = false);
                          },
                        );
                      },
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Location Section
              _buildSectionHeader(AppLocalizations.of(context).locations, Icons.location_on),
              const SizedBox(height: 16),
              
              // Pickup Location
              _buildLocationField(
                controller: _pickupAddressController,
                label: AppLocalizations.of(context).pickupLocation,
                hint: AppLocalizations.of(context).pickupLocationHint,
                icon: Icons.store,
                onTap: () => _pickLocation('pickup'),
                hasLocation: _pickupLatitude != null && _pickupLongitude != null,
                type: 'pickup',
              ),
              
              const SizedBox(height: 16),
              
              // Delivery Location
              _buildLocationField(
                controller: _deliveryAddressController,
                label: AppLocalizations.of(context).deliveryLocation,
                hint: AppLocalizations.of(context).deliveryLocationHint,
                icon: Icons.location_on,
                onTap: () => _pickLocation('delivery'),
                hasLocation: _deliveryLatitude != null && _deliveryLongitude != null,
                type: 'delivery',
                isRequired: true,
              ),
              
              const SizedBox(height: 24),
              
              // Pricing Section
              _buildSectionHeader(AppLocalizations.of(context).prices, Icons.attach_money),
              const SizedBox(height: 16),
              
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _totalAmountController,
                          label: loc.totalAmount,
                      hint: '0',
                      icon: Icons.money,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                          suffix: loc.currencySymbol,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                              return loc.amountRequired;
                        }
                        if (double.tryParse(value) == null) {
                              return loc.enterValidNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _deliveryFeeController,
                          label: loc.deliveryFee,
                      hint: '0',
                      icon: Icons.local_shipping,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                          suffix: loc.currencySymbol,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                              return loc.deliveryFeeRequired;
                        }
                        if (double.tryParse(value) == null) {
                              return loc.enterValidNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Vehicle Type Section
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(loc.vehicleType, Icons.directions_car),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                              loc.selectVehicleType,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Any Vehicle Option (Default)
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedVehicleType == 'any' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedVehicleType == 'any' ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(
                              Icons.widgets_outlined,
                              color: _selectedVehicleType == 'any' ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                                      loc.anyVehicle,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'any' ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_selectedVehicleType == 'any')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  loc.defaultText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(right: 28, top: 4),
                          child: Text(
                            loc.anyVehicleHint,
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                        ),
                        value: 'any',
                        groupValue: _selectedVehicleType,
                        onChanged: (value) {
                          setState(() {
                            _selectedVehicleType = value!;
                          });
                        },
                        activeColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Motorbike Radio Button
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedVehicleType == 'motorbike' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedVehicleType == 'motorbike' ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(
                              Icons.two_wheeler,
                              color: _selectedVehicleType == 'motorbike' ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.motorbike,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'motorbike' ? FontWeight.w600 : FontWeight.w400,
                              ),
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
                    // Car Radio Button
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedVehicleType == 'car' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedVehicleType == 'car' ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: _selectedVehicleType == 'car' ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.car,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'car' ? FontWeight.w600 : FontWeight.w400,
                              ),
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
                    // Truck Radio Button
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedVehicleType == 'truck' ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedVehicleType == 'truck' ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: _selectedVehicleType == 'truck' ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.truck,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: _selectedVehicleType == 'truck' ? FontWeight.w600 : FontWeight.w400,
                              ),
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
                    const SizedBox(height: 8),
                    // Info text
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedVehicleType == 'motorbike'
                                  ? loc.motorbikeHint
                                  : _selectedVehicleType == 'car'
                                      ? loc.carHint
                                      : loc.truckHint,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Notes Section
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(loc.notesOptional, Icons.note),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                        label: loc.additionalNotes,
                        hint: loc.addNotesHint,
                icon: Icons.edit_note,
                maxLines: 4,
                isRequired: false,
              ),
              const SizedBox(height: 24),
              // Scheduling Section
                      _buildSectionHeader(loc.whenReady, Icons.access_time),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 20)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scheduledMinutes == 0 
                                  ? loc.readyNow
                                  : loc.readyAfterMinutes(_scheduledMinutes.toInt()),
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
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
                                    ? loc.nowText
                                    : '${_scheduledMinutes.toInt()} ${loc.minutesText}',
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
                        Text(
                                  loc.nowText,
                                  style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                                  loc.sixtyMinutes,
                                  style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              // Total Summary Card
                      Builder(
                        builder: (context) {
                          final loc2 = AppLocalizations.of(context);
                          return Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 20)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                                      loc2.totalAmount,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                                      '${_totalAmountController.text.isEmpty ? "0" : _totalAmountController.text} ${loc2.currencySymbol}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                                      loc2.deliveryFee,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                                      '${_deliveryFeeController.text.isEmpty ? "0" : _deliveryFeeController.text} ${loc2.currencySymbol}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.white.withOpacity(0.3), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                                      loc2.grandTotalLabel,
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                                      '${_calculateGrandTotal()} ${loc2.currencySymbol}',
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                          );
                        },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
          ),
          // Floating Create Order Button - appears when enough info is filled
          if (_hasEnoughInfoToCreateOrder)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                width: double.infinity,
                    height: 56,
                        child: Builder(
                          builder: (context) {
                        final loc = AppLocalizations.of(context);
                            return ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitOrder,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart, color: Colors.white, size: 22),
                  label: Text(
                            _isLoading ? loc.creatingOrder : loc.createOrder,
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    disabledBackgroundColor: AppColors.textTertiary,
                  ),
                            );
                          },
                ),
              ),
          ),
        ),
            ),
        ],
      ),
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
    int maxLines = 1,
    bool isRequired = false,
    String? suffix,
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
            if (isRequired)
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
          maxLines: maxLines,
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
            suffixText: suffix,
            suffixStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Builder(
      builder: (context) {
        final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
                  loc.customerPhoneLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: _customerPhoneController,
            focusNode: _customerPhoneFocusNode,
            keyboardType: TextInputType.phone,
            maxLines: 1,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                    return loc.phoneRequired;
              }
              // Enforce Iraqi local format: 7XXXXXXXXX (10 digits)
              final digits = value.replaceAll(RegExp(r'\D'), '');
              if (!(digits.length == 10 && digits.startsWith('7'))) {
                    return loc.phoneInvalidFormat;
              }
              return null;
            },
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: '7XX XXX XXXX',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              prefix: Container(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '+964',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onTap: () {
              if (!_phoneLocked && _customerPhoneController.text.replaceAll(RegExp(r'\\D'), '').length >= 3) {
                _debouncedFetchPhoneSuggestions(_customerPhoneController.text);
                setState(() {
                  _showPhoneSuggestions = true;
                });
              }
            },
            onChanged: (val) {
              // Ensure suggestions panel visibility while typing
              if (!_phoneLocked && val.replaceAll(RegExp(r'\\D'), '').length >= 3) {
                setState(() {
                  _showPhoneSuggestions = true;
                });
              } else {
                setState(() {
                  _showPhoneSuggestions = false;
                });
              }
            },
            onFieldSubmitted: (_) {
              // Lock and unfocus on accept
              final digits = _customerPhoneController.text.replaceAll(RegExp(r'\\D'), '');
              if (digits.length == 10 && digits.startsWith('7')) {
                _phoneLocked = true;
                _customerPhoneFocusNode.unfocus();
                setState(() => _showPhoneSuggestions = false);
              }
            },
          ),
        ),
      ],
    );
      },
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    required bool hasLocation,
    required String type,
    bool isRequired = false,
  }) {
    final focusNode = type == 'pickup' ? _pickupAddressFocusNode : _deliveryAddressFocusNode;
    final showSuggestions = type == 'pickup' ? _showPickupSuggestions : _showDeliverySuggestions;
    final suggestions = type == 'pickup' ? _pickupAddressSuggestions : _deliveryAddressSuggestions;
    
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
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          child: Row(
            children: [
              // Icon
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (hasLocation ? AppColors.success : AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: hasLocation ? AppColors.success : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              // Text Field
              Expanded(
                child: TextField(
                  controller: controller,
                      focusNode: focusNode,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    suffixIcon: hasLocation
                        ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                        : null,
                  ),
                  onSubmitted: (_) => _geocodeAddress(type),
                ),
              ),
              // Map Button
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.map, color: AppColors.primary),
                    tooltip: loc.openMap,
                  );
                },
              ),
              // Geocode Button
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return IconButton(
                onPressed: () => _geocodeAddress(type),
                icon: const Icon(Icons.search, color: AppColors.success),
                    tooltip: loc.searchAddress,
                  );
                },
              ),
            ],
          ),
            ),
            // Suggestions dropdown
            if (showSuggestions && suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: suggestions.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  itemBuilder: (context, index) {
                    final district = suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      title: Text(
                        district.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _selectDistrict(district, type),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _calculateGrandTotal() {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final delivery = double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;
    return (total + delivery).toStringAsFixed(0);
  }
}