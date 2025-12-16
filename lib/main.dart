import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/providers/location_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/wallet_provider.dart';
import 'core/providers/voice_recording_provider.dart';
import 'core/providers/announcement_provider.dart';
import 'core/providers/system_status_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/flutterfire_notification_service.dart';
import 'core/services/location_service.dart';
import 'core/services/global_order_notification_service.dart';
// NotificationWatcher removed - database trigger handles FCM notifications now
// import 'core/services/notification_watcher.dart';
import 'shared/widgets/no_internet_screen.dart';
import 'core/services/precache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reduce logs and improve cache in release
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    PaintingBinding.instance.imageCache.maximumSize = 200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // ~200MB
  }
  if (!kReleaseMode) {
    debugPrint('\n');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🚀 HUR DELIVERY APP STARTING');
    debugPrint('═══════════════════════════════════════\n');
  }
  
  // Initialize Mapbox only if a token is provided (avoid bundling token in app)
  try {
    if (AppConstants.mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
      if (!kReleaseMode) debugPrint('✅ Mapbox initialized');
    } else {
      if (!kReleaseMode) debugPrint('ℹ️ Mapbox token not set. Skipping Mapbox initialization.');
    }
  } catch (e) {
    if (!kReleaseMode) debugPrint('❌ Mapbox initialization error: $e');
  }
  
  // Initialize Supabase with persistence
  if (!kReleaseMode) debugPrint('🔧 Initializing Supabase...');
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: null, // Uses default secure storage (SharedPreferences with encryption)
      autoRefreshToken: true, // Automatically refresh tokens when they expire
    ),
  );
  // Note: Session persistence is enabled by default in Supabase Flutter
  if (!kReleaseMode) debugPrint('✅ Supabase initialized with session persistence (auto-refresh enabled)\n');
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Initialize Crashlytics and register global error handlers
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    if (!kReleaseMode) debugPrint('✅ Firebase initialized with proper configuration');
  } catch (e) {
    if (!kReleaseMode) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('⚠️ Check Firebase configuration');
    }
  }

  // Initialize FlutterFire notification service
  try {
    await FlutterFireNotificationService.initialize();
    if (!kReleaseMode) debugPrint('✅ FlutterFire notification service initialized');
  } catch (e) {
    if (!kReleaseMode) debugPrint('❌ FlutterFire notification service error: $e');
  }

  // NotificationWatcher removed - database trigger now handles FCM notifications
  // Database trigger (trigger_fcm_push) automatically calls Edge Function
  // when notifications are inserted, so no need for app-side watcher
  if (!kReleaseMode) debugPrint('ℹ️  Using database trigger for FCM notifications (NotificationWatcher disabled)');
  
  // Initialize location service
  try {
    await LocationService.initialize();
    if (!kReleaseMode) debugPrint('✅ Location service initialized\n');
  } catch (e) {
    if (!kReleaseMode) debugPrint('❌ Location service error: $e');
  }
  
  if (!kReleaseMode) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('✅ APP INITIALIZATION COMPLETE');
    debugPrint('═══════════════════════════════════════\n');
  }
  
  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // Only enable in debug/profile mode
      builder: (context) => const HurDeliveryApp(),
    ),
  );
}

class HurDeliveryApp extends StatefulWidget {
  const HurDeliveryApp({super.key});

  @override
  State<HurDeliveryApp> createState() => _HurDeliveryAppState();
}

class _HurDeliveryAppState extends State<HurDeliveryApp> {
  @override
  void initState() {
    super.initState();
    // Set up auth listener to start global notifications
    _setupGlobalNotificationListener();
    // Precache core assets after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PrecacheService.preloadCoreAssets(context);
    });
  }

  void _setupGlobalNotificationListener() {
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        final userId = session.user.id;
        final userRole = session.user.userMetadata?['role'] as String?;
        
        if (userId != null && userRole != null && (userRole == 'driver' || userRole == 'merchant')) {
          print('🔔 Starting global notifications for $userRole: $userId');
          GlobalOrderNotificationService.initialize(
            userId: userId,
            userRole: userRole,
          );
        }
      } else {
        // User logged out, stop service
        GlobalOrderNotificationService.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with foreground task handler
    return WithForegroundTask(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => VoiceRecordingProvider()),
          ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
          ChangeNotifierProvider(create: (_) => SystemStatusProvider()),
        ],
        child: Consumer3<LocaleProvider, ConnectivityProvider, AuthProvider>(
          builder: (context, localeProvider, connectivityProvider, authProvider, _) {
            // Use locale from provider, fallback to DevicePreview or default
            final deviceLocale = DevicePreview.locale(context);
            // Use saved locale from provider, or DevicePreview, or default to Arabic
            final appLocale = localeProvider.isLoading 
                ? (deviceLocale ?? const Locale('ar', 'IQ'))
                : localeProvider.locale;
            final isArabic = appLocale.languageCode == 'ar';

            return MaterialApp.router(
              title: AppLocalizations(appLocale).appTitle,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.light,

              // Arabic + English localization
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: appLocale,

              // Direction + responsive text scaling + DevicePreview
              builder: (context, child) {
                child = DevicePreview.appBuilder(context, child);

                // Show no internet screen if offline
                if (!connectivityProvider.isOnline) {
                  final textDirection =
                      isArabic ? TextDirection.rtl : TextDirection.ltr;
                  return Directionality(
                    textDirection: textDirection,
                    child: const NoInternetScreen(),
                  );
                }

                final textDirection =
                    isArabic ? TextDirection.rtl : TextDirection.ltr;

                // Apply responsive text scaling globally
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaleFactor:
                        _getTextScaleFactor(MediaQuery.of(context).size.width),
                  ),
                  child: Directionality(
                    textDirection: textDirection,
                    child: child!,
                  ),
                );
              },

              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}

// Helper function for global responsive text scaling
double _getTextScaleFactor(double screenWidth) {
  if (screenWidth < 360) {
    return 0.8; // 20% reduction for very small screens
  } else if (screenWidth < 400) {
    return 0.85; // 15% reduction for small screens
  } else if (screenWidth < 600) {
    return 0.9; // 10% reduction for mobile screens
  } else {
    return 1.0; // No scaling for larger screens
  }
}