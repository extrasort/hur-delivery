import 'package:flutter/material.dart';

// Export extensions and enhanced helper
export 'responsive_extensions.dart';
export 'responsive_helper_enhanced.dart';

class ResponsiveHelper {
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 1024;
  
  // Screen size detection
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < _mobileBreakpoint;
  }
  
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= _mobileBreakpoint && width < _tabletBreakpoint;
  }
  
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= _tabletBreakpoint;
  }
  
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 400;
  }
  
  static bool isVerySmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }
  
  // Responsive sizing based on screen width - maintains consistent layout
  static double getResponsiveWidth(BuildContext context, double baseWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // For consistent layout, use percentage-based scaling rather than fixed reductions
    if (isVerySmallScreen(context)) {
      return screenWidth * 0.75; // 75% of screen width for very small screens
    } else if (isSmallScreen(context)) {
      return screenWidth * 0.8; // 80% of screen width for small screens
    } else if (isMobile(context)) {
      return screenWidth * 0.85; // 85% of screen width for mobile
    } else {
      // For larger screens, maintain the base width but ensure it doesn't exceed 90% of screen
      return baseWidth > screenWidth * 0.9 ? screenWidth * 0.9 : baseWidth;
    }
  }
  
  // Responsive font sizes - aggressive scaling for smaller screens
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (isVerySmallScreen(context)) {
      return baseFontSize * 0.8; // Reduce font size by 20% for very small screens
    } else if (isSmallScreen(context)) {
      return baseFontSize * 0.85; // Reduce font size by 15% for small screens
    } else if (isMobile(context)) {
      return baseFontSize * 0.9; // Reduce font size by 10% for mobile
    } else {
      return baseFontSize; // Keep original font size for larger screens
    }
  }
  
  // Responsive padding - aggressive scaling for smaller screens
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double horizontal = 16.0,
    double vertical = 16.0,
  }) {
    if (isVerySmallScreen(context)) {
      return EdgeInsets.symmetric(
        horizontal: horizontal * 0.6, // Reduce padding by 40%
        vertical: vertical * 0.65, // Reduce vertical padding by 35%
      );
    } else if (isSmallScreen(context)) {
      return EdgeInsets.symmetric(
        horizontal: horizontal * 0.7, // Reduce padding by 30%
        vertical: vertical * 0.75, // Reduce vertical padding by 25%
      );
    } else if (isMobile(context)) {
      return EdgeInsets.symmetric(
        horizontal: horizontal * 0.85, // Reduce padding by 15%
        vertical: vertical * 0.85,
      );
    } else {
      return EdgeInsets.symmetric(
        horizontal: horizontal, // Keep original padding for larger screens
        vertical: vertical,
      );
    }
  }
  
  // Responsive spacing - aggressive scaling for smaller screens
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    if (isVerySmallScreen(context)) {
      return baseSpacing * 0.6; // Reduce spacing by 40%
    } else if (isSmallScreen(context)) {
      return baseSpacing * 0.7; // Reduce spacing by 30%
    } else if (isMobile(context)) {
      return baseSpacing * 0.85; // Reduce spacing by 15%
    } else {
      return baseSpacing; // Keep original spacing for larger screens
    }
  }
  
  // Responsive icon sizes - aggressive scaling for smaller screens
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    if (isVerySmallScreen(context)) {
      return baseIconSize * 0.75; // Reduce icon size by 25%
    } else if (isSmallScreen(context)) {
      return baseIconSize * 0.8; // Reduce icon size by 20%
    } else if (isMobile(context)) {
      return baseIconSize * 0.9; // Reduce icon size by 10%
    } else {
      return baseIconSize; // Keep original icon size for larger screens
    }
  }
  
  // Responsive button height - more conservative scaling
  static double getResponsiveButtonHeight(BuildContext context, double baseHeight) {
    if (isVerySmallScreen(context)) {
      return baseHeight * 0.95; // Reduce button height by 5%
    } else if (isSmallScreen(context)) {
      return baseHeight * 0.98; // Reduce button height by 2%
    } else if (isMobile(context)) {
      return baseHeight; // Keep original button height
    } else {
      return baseHeight * 1.05; // Slightly increase button height for larger screens
    }
  }
  
  // Responsive card padding
  static EdgeInsets getResponsiveCardPadding(BuildContext context) {
    if (isVerySmallScreen(context)) {
      return const EdgeInsets.all(12); // Smaller padding for very small screens
    } else if (isSmallScreen(context)) {
      return const EdgeInsets.all(14); // Medium padding for small screens
    } else {
      return const EdgeInsets.all(16); // Standard padding for larger screens
    }
  }
  
  // Responsive logo size - maintains consistent proportions
  static double getResponsiveLogoSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (isVerySmallScreen(context)) {
      return screenWidth * 0.5; // 50% of screen width for very small screens
    } else if (isSmallScreen(context)) {
      return screenWidth * 0.55; // 55% of screen width for small screens
    } else if (isMobile(context)) {
      return screenWidth * 0.6; // 60% of screen width for mobile
    } else {
      // For larger screens, use the base size but ensure it doesn't exceed 70% of screen
      return baseSize > screenWidth * 0.7 ? screenWidth * 0.7 : baseSize;
    }
  }
  
  // Get responsive screen dimensions
  static Size getScreenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }
  
  // Consistent form element width - ensures input fields and buttons have same width
  static double getFormElementWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Use consistent percentage-based width for all form elements
    if (isVerySmallScreen(context)) {
      return screenWidth * 0.85; // 85% of screen width
    } else if (isSmallScreen(context)) {
      return screenWidth * 0.8; // 80% of screen width
    } else if (isMobile(context)) {
      return screenWidth * 0.75; // 75% of screen width
    } else {
      return screenWidth * 0.7; // 70% of screen width for larger screens
    }
  }
  
  // Consistent form element height - ensures buttons and input fields have same height
  static double getFormElementHeight(BuildContext context) {
    if (isVerySmallScreen(context)) {
      return 44; // Smaller for very small screens
    } else if (isSmallScreen(context)) {
      return 46; // Smaller for small screens
    } else if (isMobile(context)) {
      return 50; // Standard height for mobile
    } else {
      return 56; // Larger for bigger screens
    }
  }
  
  // Check if device has notch or status bar
  static bool hasNotch(BuildContext context) {
    return MediaQuery.of(context).padding.top > 24;
  }
  
  // Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
  
  // Responsive bottom navigation bar height
  static double getResponsiveBottomNavHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (isVerySmallScreen(context)) {
      return screenHeight * 0.08; // 8% of screen height
    } else if (isSmallScreen(context)) {
      return screenHeight * 0.09; // 9% of screen height
    } else {
      return screenHeight * 0.1; // 10% of screen height
    }
  }
  
  // Responsive app bar height
  static double getResponsiveAppBarHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (isVerySmallScreen(context)) {
      return screenHeight * 0.06; // 6% of screen height
    } else if (isSmallScreen(context)) {
      return screenHeight * 0.07; // 7% of screen height
    } else {
      return screenHeight * 0.08; // 8% of screen height
    }
  }
  
  // Responsive floating action button size
  static double getResponsiveFabSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (isVerySmallScreen(context)) {
      return screenWidth * 0.12; // 12% of screen width
    } else if (isSmallScreen(context)) {
      return screenWidth * 0.13; // 13% of screen width
    } else {
      return screenWidth * 0.14; // 14% of screen width
    }
  }
  
  /// Get responsive value using percentage of screen width
  static double widthPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * (percent / 100);
  }
  
  /// Get responsive value using percentage of screen height
  static double heightPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * (percent / 100);
  }
}
