class ScheduledOrderModel {
  final String id;
  final String merchantId;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final double totalAmount;
  final double deliveryFee;
  final String? notes;
  final String vehicleType;
  final DateTime scheduledDate;
  final Duration scheduledTime;
  final String status; // scheduled, posted, failed, cancelled
  final String? createdOrderId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ScheduledOrderModel({
    required this.id,
    required this.merchantId,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.totalAmount,
    required this.deliveryFee,
    this.notes,
    required this.vehicleType,
    required this.scheduledDate,
    required this.scheduledTime,
    this.status = 'scheduled',
    this.createdOrderId,
    required this.createdAt,
    this.updatedAt,
  });

  factory ScheduledOrderModel.fromJson(Map<String, dynamic> json) {
    // Parse scheduled_time string (HH:MM:SS) to Duration
    Duration parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
        seconds: parts.length > 2 ? int.parse(parts[2]) : 0,
      );
    }

    return ScheduledOrderModel(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: double.parse(json['pickup_latitude'].toString()),
      pickupLongitude: double.parse(json['pickup_longitude'].toString()),
      deliveryAddress: json['delivery_address'] as String,
      deliveryLatitude: double.parse(json['delivery_latitude'].toString()),
      deliveryLongitude: double.parse(json['delivery_longitude'].toString()),
      totalAmount: double.parse(json['total_amount']?.toString() ?? '0'),
      deliveryFee: double.parse(json['delivery_fee']?.toString() ?? '0'),
      notes: json['notes'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorcycle',
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: parseTime(json['scheduled_time'] as String),
      status: json['status'] as String? ?? 'scheduled',
      createdOrderId: json['created_order_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'notes': notes,
      'vehicle_type': vehicleType,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'scheduled_time': '${scheduledTime.inHours.toString().padLeft(2, '0')}:${(scheduledTime.inMinutes % 60).toString().padLeft(2, '0')}:${(scheduledTime.inSeconds % 60).toString().padLeft(2, '0')}',
      'status': status,
      'created_order_id': createdOrderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Get the DateTime when this order will be posted
  DateTime get scheduledDateTime {
    return scheduledDate.add(scheduledTime);
  }

  // Get duration until order is posted
  Duration get timeUntilPosted {
    final now = DateTime.now();
    final scheduled = scheduledDateTime;
    return scheduled.difference(now);
  }

  // Check if order is due to be posted
  bool get isDue {
    return DateTime.now().isAfter(scheduledDateTime);
  }

  // Get seconds remaining
  int get secondsRemaining {
    return timeUntilPosted.inSeconds.clamp(0, double.infinity).toInt();
  }

  // Total amount including delivery fee
  double get grandTotal => totalAmount + deliveryFee;

  // Status display
  String get statusDisplay {
    switch (status) {
      case 'scheduled':
        return 'مجدول';
      case 'posted':
        return 'تم النشر';
      case 'failed':
        return 'فشل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledOrderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ScheduledOrderModel(id: $id, customerName: $customerName, scheduledAt: $scheduledDateTime)';
  }
}


