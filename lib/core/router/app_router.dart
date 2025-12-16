import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/global_order_notification_service.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/landing_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/phone_input_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/user_registration_screen.dart';
import '../../features/auth/screens/id_verification_review_screen.dart';
import '../../features/auth/screens/verification_pending_screen.dart';
import '../../features/auth/screens/driver_welcome_screen.dart';
import '../../features/auth/screens/merchant_welcome_screen.dart';
import '../../features/dashboard/screens/merchant_dashboard.dart';
import '../../features/dashboard/screens/driver_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';
import '../../features/orders/screens/create_order_screen.dart';
import '../../features/orders/screens/create_bulk_order_screen.dart';
import '../../features/orders/screens/create_scheduled_order_screen.dart';
import '../../features/orders/screens/create_voice_order_screen.dart';
import '../../features/orders/screens/order_creation_carousel.dart';
import '../../features/orders/screens/order_details_screen.dart';
import '../../features/orders/screens/order_tracking_screen.dart';
import '../../features/maps/screens/map_screen.dart';
import '../../features/driver/screens/profile_screen.dart';
import '../../features/driver/screens/orders_screen.dart';
import '../../features/driver/screens/earnings_screen.dart';
import '../../features/driver/screens/settings_screen.dart';
import '../../features/merchant/screens/edit_profile_screen.dart';
import '../../features/merchant/screens/notifications_screen.dart';
import '../../features/merchant/screens/settings_screen.dart'
    as merchant_settings;
import '../../features/messaging/screens/messaging_list_screen.dart';
import '../../features/messaging/screens/support_conversation_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/legal/screens/privacy_policy_screen.dart';
import '../../features/legal/screens/terms_conditions_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: GlobalOrderNotificationService.navigatorKey,
    initialLocation: '/splash',
    routes: [
      // Splash screen (initial route with session restoration)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Public routes (no auth required)
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        name: 'role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/phone-input',
        name: 'phone-input',
        builder: (context, state) {
          final role = state.extra as String?;
          return PhoneInputScreen(role: role ?? 'merchant');
        },
      ),
      // Login route (OTP-only): use phone input with login role
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => PhoneInputScreen(role: 'login'),
      ),
      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        builder: (context, state) {
          final data = state.extra as Map<String, String>?;
          return OtpVerificationScreen(
            phone: data?['phone'] ?? '',
            role: data?['role'] ?? 'merchant',
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final data = state.extra as Map<String, String>?;
          return ResetPasswordScreen(
            phoneE164: data?['phone'] ?? '',
            prefilledCode: data?['code'],
          );
        },
      ),
      GoRoute(
        path: '/user-registration',
        name: 'user-registration',
        builder: (context, state) {
          final role = state.extra as String?;
          return UserRegistrationScreen(role: role ?? 'merchant');
        },
      ),
      GoRoute(
        path: '/id-verification-review',
        name: 'id-verification-review',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          return IdVerificationReviewScreen(
            extractedData: data?['extractedData'],
            role: (data?['role'] as String?) ?? 'merchant',
            isResubmission: (data?['isResubmission'] as bool?) ?? false,
            idFrontFile: data?['idFrontFile'],
            idBackFile: data?['idBackFile'],
            selfieFile: data?['selfieFile'],
          );
        },
      ),
      GoRoute(
        path: '/verification-pending',
        name: 'verification-pending',
        builder: (context, state) => const VerificationPendingScreen(),
      ),
      GoRoute(
        path: '/driver-welcome',
        name: 'driver-welcome',
        builder: (context, state) => const DriverWelcomeScreen(),
      ),
      GoRoute(
        path: '/merchant-welcome',
        name: 'merchant-welcome',
        builder: (context, state) => const MerchantWelcomeScreen(),
      ),
      
      // Protected routes (auth required)
      GoRoute(
        path: '/merchant-dashboard',
        name: 'merchant-dashboard',
        builder: (context, state) => const MerchantDashboard(),
        routes: [
          GoRoute(
            path: 'create-order',
            name: 'create-order',
            builder: (context, state) {
              final pageParam = state.uri.queryParameters['page'];
              final initialPage =
                  pageParam != null ? int.tryParse(pageParam) ?? 0 : 0;
              return OrderCreationCarousel(initialPage: initialPage);
            },
          ),
          GoRoute(
            path: 'order-details/:orderId',
            name: 'order-details',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return OrderDetailsScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'order-tracking/:orderId',
            name: 'order-tracking',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return OrderTrackingScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'edit-profile',
            name: 'merchant-edit-profile',
            builder: (context, state) => const MerchantEditProfileScreen(),
          ),
          GoRoute(
            path: 'notifications',
            name: 'merchant-notifications',
            builder: (context, state) => const MerchantNotificationsScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: 'merchant-settings',
            builder: (context, state) =>
                const merchant_settings.MerchantSettingsScreen(),
          ),
          GoRoute(
            path: 'privacy-policy',
            name: 'merchant-privacy-policy',
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: 'terms-conditions',
            name: 'merchant-terms-conditions',
            builder: (context, state) => const TermsConditionsScreen(),
          ),
        ],
      ),
      
      // Wallet screen (standalone route for better navigation)
      GoRoute(
        path: '/merchant-wallet',
        name: 'merchant-wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      
      GoRoute(
        path: '/driver-dashboard',
        name: 'driver-dashboard',
        builder: (context, state) => const DriverDashboard(),
        routes: [
          GoRoute(
            path: 'order-details/:orderId',
            name: 'driver-order-details',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return OrderDetailsScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'order-tracking/:orderId',
            name: 'driver-order-tracking',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return OrderTrackingScreen(orderId: orderId);
            },
          ),
        ],
      ),
      
      // Driver sub-screens
      GoRoute(
        path: '/driver/profile',
        name: 'driver-profile',
        builder: (context, state) => const DriverProfileScreen(),
      ),
      GoRoute(
        path: '/driver/orders',
        name: 'driver-orders',
        builder: (context, state) => const DriverOrdersScreen(),
      ),
      GoRoute(
        path: '/driver/messages',
        name: 'driver-messages',
        builder: (context, state) {
          final orderIdParam = state.uri.queryParameters['orderId'];
          return SupportConversationScreen(
            initialOrderId: (orderIdParam != null && orderIdParam.isNotEmpty)
                ? orderIdParam
                : null,
          );
        },
      ),
      GoRoute(
        path: '/driver/earnings',
        name: 'driver-earnings',
        builder: (context, state) => const DriverEarningsScreen(),
      ),
      GoRoute(
        path: '/driver/settings',
        name: 'driver-settings',
        builder: (context, state) => const DriverSettingsScreen(),
      ),
      GoRoute(
        path: '/driver/privacy-policy',
        name: 'driver-privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/driver/terms-conditions',
        name: 'driver-terms-conditions',
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: '/merchant/messages',
        name: 'merchant-messages',
        builder: (context, state) {
          final startSupport = state.uri.queryParameters['support'] == 'true';
          final orderIdParam = state.uri.queryParameters['orderId'];
          return MessagingListScreen(
            startSupportOnLoad: startSupport,
            initialOrderId: (orderIdParam != null && orderIdParam.isNotEmpty)
                ? orderIdParam
                : null,
          );
        },
      ),
      GoRoute(
        path: '/merchant/support',
        name: 'merchant-support',
        builder: (context, state) {
          final orderIdParam = state.uri.queryParameters['orderId'];
          return SupportConversationScreen(
            initialOrderId: (orderIdParam != null && orderIdParam.isNotEmpty)
                ? orderIdParam
                : null,
          );
        },
      ),
      GoRoute(
        path: '/admin-dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      
      // Map routes
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) {
          final latitude =
              double.tryParse(state.uri.queryParameters['lat'] ?? '0');
          final longitude =
              double.tryParse(state.uri.queryParameters['lng'] ?? '0');
          return MapScreen(
            initialLatitude: latitude ?? 33.3152,
            initialLongitude: longitude ?? 44.3661,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'صفحة غير موجودة',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'الرابط المطلوب غير موجود',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
}
