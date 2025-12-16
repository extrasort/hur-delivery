import '../config/env.dart';

class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = Env.supabaseUrl;
  static const String supabaseAnonKey = Env.supabaseAnonKey;
  
  // Mapbox Configuration
  static const String mapboxAccessToken = Env.mapboxAccessToken;
  
  // App Configuration
  static const String appName = 'حر';
  static const String appVersion = '1.0.1';
  static const String packageId = 'com.hur.delivery';
  
  // Currency
  static const String currency = 'IQD';
  static const String currencySymbol = 'د.ع';
  
  // Phone Configuration
  static const String countryCode = '964';
  static const String phonePattern = r'^964[0-9]{10}$'; // Matches 964 followed by exactly 10 digits (allows 7XXXXXXXXX and 999XXXXXXXX)
  
  // Order Configuration
  static const int orderTimeoutMinutes = 2;
  static const double defaultDeliveryFee = 5000.0; // IQD
  static const double commissionRate = 0.1; // 10%
  
  // Location Configuration
  static const double defaultLatitude = 33.3152; // Baghdad
  static const double defaultLongitude = 44.3661;
  static const double locationAccuracy = 10.0; // meters
  
  // Notification Configuration
  static const String notificationChannelId = 'hur_delivery_channel';
  static const String notificationChannelName = 'Hur Delivery Notifications';
  
  // API Endpoints
  static const String baseUrl = 'https://api.hur.delivery';
  static const String uploadUrl = '$baseUrl/upload';
  static const String whatsappServerUrl = 'https://striking-enthusiasm-production.up.railway.app';
  static const String otpRelayUrl = 'https://striking-enthusiasm-production.up.railway.app/send-otp-otpiq';
  
  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String orderImagesPath = 'order_images';
  static const String documentsPath = 'documents';
  
  // User Roles
  static const String roleMerchant = 'merchant';
  static const String roleDriver = 'driver';
  static const String roleCustomer = 'customer';
  static const String roleAdmin = 'admin';
  
  // Order Status (matching database)
  static const String statusPending = 'pending'; // Not reached drivers
  static const String statusAssigned = 'assigned'; // Reached drivers but not accepted
  static const String statusAccepted = 'accepted'; // Driver accepted
  static const String statusOnTheWay = 'on_the_way'; // Being delivered
  static const String statusDelivered = 'delivered'; // Completed
  static const String statusCancelled = 'cancelled'; // Cancelled
  static const String statusUnassigned = 'unassigned'; // No driver assigned
  static const String statusRejected = 'rejected'; // All drivers rejected
  
  // Notification Types
  static const String notificationOrderAssigned = 'order_assigned';
  static const String notificationOrderStatusUpdate = 'order_status_update';
  static const String notificationDriverLocation = 'driver_location';
  static const String notificationSystem = 'system';
}
