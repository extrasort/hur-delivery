import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class AppColors {
  // Primary Hur Colors
  static const Color primary = Color(0xFF008C95); // New teal color
  static const Color secondary = Color(0xFF1E40AF); // Blue
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color error = Color(0xFFEF4444); // Red
  
  // Background Colors
  static const Color background = Color(0xFFF9FAFB); // Light gray
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceVariant = Color(0xFFF3F4F6); // Light gray
  
  // Text Colors
  static const Color textPrimary = Color(0xFF111827); // Dark gray
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray
  
  // Border Colors
  static const Color border = Color(0xFFE5E7EB); // Light border
  static const Color borderFocus = Color(0xFF008C95); // Primary border
  
  // Status Colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusAccepted = Color(0xFF10B981);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFFEF4444);
}

class AppTextStyles {
  // Arabic Font Family
  static const String fontFamily = 'Tajawal';
  
  // Heading Styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  // Button Styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: Colors.white,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: Colors.white,
  );
  
  // Caption Styles
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: AppColors.textTertiary,
    height: 1.3,
  );
  
  // Responsive text styles
  static TextStyle responsiveHeading1(BuildContext context) {
    return heading1.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 32),
    );
  }
  
  static TextStyle responsiveHeading2(BuildContext context) {
    return heading2.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
    );
  }
  
  static TextStyle responsiveHeading3(BuildContext context) {
    return heading3.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
    );
  }
  
  static TextStyle responsiveBodyLarge(BuildContext context) {
    return bodyLarge.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
    );
  }
  
  static TextStyle responsiveBodyMedium(BuildContext context) {
    return bodyMedium.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
    );
  }
  
  static TextStyle responsiveBodySmall(BuildContext context) {
    return bodySmall.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
    );
  }
  
  static TextStyle responsiveButtonLarge(BuildContext context) {
    return buttonLarge.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
    );
  }
  
  static TextStyle responsiveButtonMedium(BuildContext context) {
    return buttonMedium.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
    );
  }
  
  static TextStyle responsiveCaption(BuildContext context) {
    return caption.copyWith(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onError: Colors.white,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading3,
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.heading1,
        displayMedium: AppTextStyles.heading2,
        displaySmall: AppTextStyles.heading3,
        headlineLarge: AppTextStyles.heading2,
        headlineMedium: AppTextStyles.heading3,
        headlineSmall: AppTextStyles.heading3,
        titleLarge: AppTextStyles.heading3,
        titleMedium: AppTextStyles.bodyLarge,
        titleSmall: AppTextStyles.bodyMedium,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.buttonMedium,
        labelMedium: AppTextStyles.bodyMedium,
        labelSmall: AppTextStyles.caption,
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      brightness: Brightness.dark,
      
      // Dark theme colors would go here
      // For now, we'll use the light theme as the app is designed for light mode
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Color(0xFF1F2937),
        background: Color(0xFF111827),
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),
    );
  }
}
