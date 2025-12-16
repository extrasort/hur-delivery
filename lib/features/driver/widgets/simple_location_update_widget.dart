import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/driver_location_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_container.dart';

class SimpleLocationUpdateWidget extends StatefulWidget {
  final String driverId;
  final Function(String orderId, double lat, double lng) onLocationUpdate;

  const SimpleLocationUpdateWidget({
    super.key,
    required this.driverId,
    required this.onLocationUpdate,
  });

  @override
  State<SimpleLocationUpdateWidget> createState() => _SimpleLocationUpdateWidgetState();
}

class _SimpleLocationUpdateWidgetState extends State<SimpleLocationUpdateWidget> {
  Timer? _timer;
  final Set<String> _notifiedOrders = {};

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _acknowledgeUpdates(List<CustomerLocationUpdate> updates) async {
    for (final update in updates) {
      try {
        await DriverLocationService.markDriverNotified(update.orderId);
        widget.onLocationUpdate(update.orderId, update.deliveryLatitude, update.deliveryLongitude);
      } catch (_) {}
    }
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
            if (update.merchantName.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(update.merchantName),
                ],
              ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration, size: 16, color: Colors.blue.shade700),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).locationReadyNoCallNeeded,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w700,
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
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible - it only handles background polling
    return const SizedBox.shrink();
  }

  void _startPolling() {
    print('🔄 Starting simple location update polling every 3 seconds...');
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkForLocationUpdates();
    });
  }

  Future<void> _checkForLocationUpdates() async {
    try {
      print('🔍 Checking for customer location updates...');
      
      // Query orders table directly for this driver's active orders
      // Only check orders where customer actually provided location (not auto-updated)
      final response = await Supabase.instance.client
          .from('orders')
          .select('id, customer_location_provided, delivery_latitude, delivery_longitude, customer_name, delivery_address, coordinates_auto_updated')
          .eq('driver_id', widget.driverId)
          .inFilter('status', ['assigned', 'accepted', 'on_the_way', 'picked_up'])
          .eq('customer_location_provided', true)
          .eq('coordinates_auto_updated', false); // Only real customer locations

      if (response.isNotEmpty) {
        print('📍 Found ${response.length} orders with customer location updates');
        
        for (final order in response) {
          final orderId = order['id'] as String;
          final lat = order['delivery_latitude'] as double?;
          final lng = order['delivery_longitude'] as double?;
          final customerName = order['customer_name'] as String?;
          final address = order['delivery_address'] as String?;
          
          // Only notify if we haven't already notified for this order
          if (!_notifiedOrders.contains(orderId) && lat != null && lng != null) {
            print('📍 New location update for order $orderId: $lat, $lng');
            _notifiedOrders.add(orderId);
            
            // Show popup immediately
            _showLocationUpdatePopup(orderId, lat, lng, customerName, address);
            
            // Notify parent widget
            widget.onLocationUpdate(orderId, lat, lng);
          }
        }
      } else {
        print('📍 No location updates found');
      }
    } catch (e) {
      print('❌ Error checking for location updates: $e');
    }
  }

  void _showLocationUpdatePopup(String orderId, double lat, double lng, String? customerName, String? address) {
    if (!mounted) return;
    
    print('📍 Showing location update popup for order $orderId');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.white, size: 26),
                        SizedBox(width: 8),
                        Text(
                          'موقع العميل جاهز 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'يمكنك الآن الذهاب مباشرة باستخدام المسار المحدث',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildUpdateCard(
                      CustomerLocationUpdate(
                        orderId: orderId,
                        customerName: customerName ?? 'العميل',
                        customerPhone: '',
                        deliveryAddress: address ?? 'العنوان محدث',
                        deliveryLatitude: lat,
                        deliveryLongitude: lng,
                        merchantName: '',
                        status: '',
                        createdAt: '',
                        updatedAt: '',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close),
                        label: Text('إغلاق'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _acknowledgeUpdates([
                            CustomerLocationUpdate(
                              orderId: orderId,
                              customerName: customerName ?? 'العميل',
                              customerPhone: '',
                              deliveryAddress: address ?? 'العنوان محدث',
                              deliveryLatitude: lat,
                              deliveryLongitude: lng,
                              merchantName: '',
                              status: '',
                              createdAt: '',
                              updatedAt: '',
                            )
                          ]);
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.route),
                        label: Text('عرض المسار'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
