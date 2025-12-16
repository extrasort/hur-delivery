
class OrderModel {
  final String id;
  final String merchantId;
  final String? merchantName;
  final String? merchantPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String status;
  final double totalAmount;
  final double deliveryFee;
  final String? notes;
  final String vehicleType; // motorbike, car, or truck
  final String? bulkOrderId; // Reference to bulk order if part of bulk
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? driverAssignedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final int? timeoutRemainingSeconds; // Calculated from database
  final DateTime? readyAt; // When order will be ready for pickup
  final int? readyCountdown; // Minutes until ready (0 = ready now)
  final bool? customerLocationProvided; // Whether customer provided GPS location
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.merchantId,
    this.merchantName,
    this.merchantPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.status = 'pending',
    this.totalAmount = 0.0,
    this.deliveryFee = 0.0,
    this.notes,
    this.vehicleType = 'motorbike',
    this.bulkOrderId,
    required this.createdAt,
    this.updatedAt,
    this.driverAssignedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.timeoutRemainingSeconds,
    this.readyAt,
    this.readyCountdown,
    this.customerLocationProvided,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      merchantName: json['merchant_name'] as String?,
      merchantPhone: json['merchant_phone'] as String?,
      driverId: json['driver_id'] as String?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: double.parse(json['pickup_latitude'].toString()),
      pickupLongitude: double.parse(json['pickup_longitude'].toString()),
      deliveryAddress: json['delivery_address'] as String,
      deliveryLatitude: double.parse(json['delivery_latitude'].toString()),
      deliveryLongitude: double.parse(json['delivery_longitude'].toString()),
      status: json['status'] as String? ?? 'pending',
      totalAmount: double.parse(json['total_amount']?.toString() ?? '0'),
      deliveryFee: double.parse(json['delivery_fee']?.toString() ?? '0'),
      notes: json['notes'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorbike',
      bulkOrderId: json['bulk_order_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      driverAssignedAt: json['driver_assigned_at'] != null ? DateTime.parse(json['driver_assigned_at'] as String) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      rejectedAt: json['rejected_at'] != null ? DateTime.parse(json['rejected_at'] as String) : null,
      timeoutRemainingSeconds: json['timeout_remaining_seconds'] as int?,
      readyAt: json['ready_at'] != null ? DateTime.parse(json['ready_at'] as String) : null,
      readyCountdown: json['ready_countdown'] as int?,
      customerLocationProvided: json['customer_location_provided'] as bool?,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'merchant_name': merchantName,
      'merchant_phone': merchantPhone,
      'driver_id': driverId,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'status': status,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'notes': notes,
      'vehicle_type': vehicleType,
      'bulk_order_id': bulkOrderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'driver_assigned_at': driverAssignedAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? merchantId,
    String? merchantName,
    String? merchantPhone,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? customerName,
    String? customerPhone,
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? status,
    double? totalAmount,
    double? deliveryFee,
    String? notes,
    String? vehicleType,
    String? bulkOrderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? driverAssignedAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    int? timeoutRemainingSeconds,
    DateTime? readyAt,
    int? readyCountdown,
    bool? customerLocationProvided,
    List<OrderItemModel>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      merchantPhone: merchantPhone ?? this.merchantPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      notes: notes ?? this.notes,
      vehicleType: vehicleType ?? this.vehicleType,
      bulkOrderId: bulkOrderId ?? this.bulkOrderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      driverAssignedAt: driverAssignedAt ?? this.driverAssignedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      timeoutRemainingSeconds: timeoutRemainingSeconds ?? this.timeoutRemainingSeconds,
      readyAt: readyAt ?? this.readyAt,
      readyCountdown: readyCountdown ?? this.readyCountdown,
      customerLocationProvided: customerLocationProvided ?? this.customerLocationProvided,
      items: items ?? this.items,
    );
  }

  // Status checks (matching database)
  bool get isPending => status == 'pending'; // Not reached drivers
  bool get isAssigned => status == 'assigned'; // Reached drivers but not accepted
  bool get isAccepted => status == 'accepted'; // Driver accepted
  bool get isOnTheWay => status == 'on_the_way'; // Being delivered
  bool get isDelivered => status == 'delivered'; // Completed
  bool get isCancelled => status == 'cancelled'; // Cancelled
  bool get isUnassigned => status == 'unassigned'; // No driver assigned
  bool get isRejected => status == 'rejected'; // All drivers rejected

  bool get isActive => !isDelivered && !isCancelled && !isRejected;
  bool get isCompleted => isDelivered;
  bool get isFailed => isCancelled || isRejected;
  bool get isBulkOrder => bulkOrderId != null;

  // Status display
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'assigned':
        return 'تم التخصيص';
      case 'accepted':
        return 'تم القبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      case 'unassigned':
        return 'غير مخصص';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير معروف';
    }
  }

  // Total calculation
  double get grandTotal => totalAmount + deliveryFee;

  // Ready time calculations
  bool get isReady {
    if (readyAt == null) return true; // No ready time = ready now
    return DateTime.now().isAfter(readyAt!);
  }

  Duration get timeUntilReady {
    if (readyAt == null) return Duration.zero;
    final now = DateTime.now();
    final difference = readyAt!.difference(now);
    return difference.isNegative ? Duration.zero : difference;
  }

  int get secondsUntilReady => timeUntilReady.inSeconds;

  @override
  String toString() {
    return 'OrderModel(id: $id, status: $status, customerName: $customerName, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String name;
  final int quantity;
  final double price;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.name,
    this.quantity = 1,
    this.price = 0.0,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int? ?? 1,
      price: double.parse(json['price']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  double get totalPrice => quantity * price;

  @override
  String toString() {
    return 'OrderItemModel(id: $id, name: $name, quantity: $quantity, price: $price)';
  }
}
