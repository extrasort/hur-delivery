import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/driver_location_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';

class LocationUpdateNotificationWidget extends StatefulWidget {
  final VoidCallback? onLocationUpdateReceived;
  final Duration checkInterval;

  const LocationUpdateNotificationWidget({
    Key? key,
    this.onLocationUpdateReceived,
    this.checkInterval = const Duration(seconds: 30),
  }) : super(key: key);

  @override
  State<LocationUpdateNotificationWidget> createState() => _LocationUpdateNotificationWidgetState();
}

class _LocationUpdateNotificationWidgetState extends State<LocationUpdateNotificationWidget> {
  Timer? _timer;
  List<CustomerLocationUpdate> _pendingUpdates = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPeriodicCheck() {
    print('📍 Starting location update notification system...');
    print('📍 Check interval: ${widget.checkInterval.inSeconds} seconds');
    
    _timer = Timer.periodic(widget.checkInterval, (timer) {
      print('📍 Periodic check triggered at ${DateTime.now()}');
      _checkForLocationUpdates();
    });
    
    // Check immediately on start
    print('📍 Initial check on startup...');
    _checkForLocationUpdates();
    
    // Add multiple test checks to verify the system is working
    Future.delayed(const Duration(seconds: 5), () {
      print('📍 Test 1: Checking location updates after 5 seconds...');
      _checkForLocationUpdates();
    });
    
    Future.delayed(const Duration(seconds: 10), () {
      print('📍 Test 2: Checking location updates after 10 seconds...');
      _checkForLocationUpdates();
    });
    
    Future.delayed(const Duration(seconds: 15), () {
      print('📍 Test 3: Checking location updates after 15 seconds...');
      _checkForLocationUpdates();
    });
  }

  Future<void> _checkForLocationUpdates() async {
    if (_isLoading) {
      print('📍 Location check already in progress, skipping...');
      return;
    }
    
    print('📍 ===========================================');
    print('📍 STARTING LOCATION UPDATE CHECK');
    print('📍 Time: ${DateTime.now()}');
    print('📍 ===========================================');
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('📍 Step 1: Calling DriverLocationService.checkForLocationUpdates()...');
      final updates = await DriverLocationService.checkForLocationUpdates();
      
      print('📍 Step 2: Received ${updates.length} updates from service');
      
      if (mounted) {
        print('📍 Step 3: Widget is mounted, processing updates...');
        setState(() {
          _pendingUpdates = updates;
        });

        // Show notification for new updates
        if (updates.isNotEmpty) {
          print('📍 ✅ SUCCESS: FOUND ${updates.length} location updates - showing popup!');
          for (int i = 0; i < updates.length; i++) {
            final update = updates[i];
            print('   📍 Update ${i + 1}:');
            print('      Order ID: ${update.orderId}');
            print('      Customer: ${update.customerName}');
            print('      Phone: ${update.customerPhone}');
            print('      Address: ${update.deliveryAddress}');
            print('      Coordinates: ${update.deliveryLatitude}, ${update.deliveryLongitude}');
            print('      Merchant: ${update.merchantName}');
            print('      Status: ${update.status}');
          }
          _showLocationUpdateNotification(updates);
        } else {
          print('📍 No location updates found - system is working but no updates available');
        }
      } else {
        print('📍 Widget not mounted, skipping notification');
      }
    } catch (e) {
      print('❌ ERROR in location update check: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorCheckingLocationUpdates(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('📍 ===========================================');
      print('📍 LOCATION UPDATE CHECK COMPLETE');
      print('📍 ===========================================');
    }
  }

  void _showLocationUpdateNotification(List<CustomerLocationUpdate> updates) {
    if (updates.isEmpty) {
      print('📍 No updates to show');
      return;
    }

    print('📍 🚨 SHOWING LOCATION UPDATE POPUP for ${updates.length} orders');
    print('📍 Context: ${context.runtimeType}');
    print('📍 Widget mounted: $mounted');
    
    // Ensure we're on the main thread and context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted) {
        print('📍 PostFrameCallback: Showing dialog...');
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54, // Semi-transparent overlay
          builder: (context) {
            print('📍 Building LocationUpdateDialog...');
            return LocationUpdateDialog(
              updates: updates,
              onAcknowledge: _acknowledgeUpdates,
            );
          },
        );
      } else {
        print('❌ Cannot show dialog: mounted=$mounted, context.mounted=${context.mounted}');
      }
    });
  }

  Future<void> _acknowledgeUpdates(List<CustomerLocationUpdate> updates) async {
    print('📍 Acknowledging ${updates.length} location updates');
    
    for (final update in updates) {
      print('📍 Marking driver as notified for order: ${update.orderId}');
      final success = await DriverLocationService.markDriverNotified(update.orderId);
      if (success) {
        print('✅ Successfully marked driver as notified for order: ${update.orderId}');
      } else {
        print('❌ Failed to mark driver as notified for order: ${update.orderId}');
      }
    }
    
    setState(() {
      _pendingUpdates.removeWhere((update) => 
        updates.any((acknowledged) => acknowledged.orderId == update.orderId));
    });

    if (widget.onLocationUpdateReceived != null) {
      print('📍 Calling onLocationUpdateReceived callback');
      widget.onLocationUpdateReceived!();
    }
    
    // Trigger recreation of pins and routes
    print('🔄 Triggering recreation of pins and routes after location update');
  }

  @override
  Widget build(BuildContext context) {
    return Container(); // This widget doesn't render anything visible
  }
}

class LocationUpdateDialog extends StatelessWidget {
  final List<CustomerLocationUpdate> updates;
  final Function(List<CustomerLocationUpdate>) onAcknowledge;

  const LocationUpdateDialog({
    Key? key,
    required this.updates,
    required this.onAcknowledge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('📍 Building LocationUpdateDialog with ${updates.length} updates');
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue, size: 28),
          SizedBox(width: 12),
          Text(
            'العميل أرسل موقعه',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم تحديث موقع العميل - لا حاجة للاتصال',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ...updates.map((update) => _buildUpdateCard(update)).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('📍 User clicked إغلاق');
            Navigator.of(context).pop();
          },
          child: Text('إغلاق'),
        ),
        ElevatedButton(
          onPressed: () {
            print('📍 User clicked تم الفهم');
            onAcknowledge(updates);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('تم الفهم'),
        ),
      ],
    );
  }

  Widget _buildUpdateCard(CustomerLocationUpdate update) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  update.customerName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.store, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text('${update.merchantName}'),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'العميل أرسل موقعه - لا حاجة للاتصال',
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
