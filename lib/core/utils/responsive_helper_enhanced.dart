import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Enhanced responsive helper with percentage-based utilities
class ResponsiveHelperEnhanced {
  /// Get responsive width as percentage of screen width
  static double widthPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * (percent / 100);
  }
  
  /// Get responsive height as percentage of screen height
  static double heightPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * (percent / 100);
  }
  
  /// Get responsive size maintaining aspect ratio
  static Size responsiveSize(BuildContext context, double baseWidth, double baseHeight) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    double width = baseWidth;
    double height = baseHeight;
    
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      width = screenWidth * 0.85;
      height = height * (width / baseWidth);
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      width = screenWidth * 0.8;
      height = height * (width / baseWidth);
    } else if (ResponsiveHelper.isMobile(context)) {
      width = screenWidth * 0.75;
      height = height * (width / baseWidth);
    }
    
    return Size(width, height);
  }
  
  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context, double baseRadius) {
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return baseRadius * 0.8;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return baseRadius * 0.9;
    }
    return baseRadius;
  }
  
  /// Get responsive elevation
  static double getResponsiveElevation(BuildContext context, double baseElevation) {
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return baseElevation * 0.8;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return baseElevation * 0.9;
    }
    return baseElevation;
  }
  
  /// Get responsive grid columns count
  static int getResponsiveGridColumns(BuildContext context) {
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return 1;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return 1;
    } else if (ResponsiveHelper.isMobile(context)) {
      return 2;
    } else if (ResponsiveHelper.isTablet(context)) {
      return 3;
    } else {
      return 4;
    }
  }
  
  /// Get responsive aspect ratio for cards
  static double getResponsiveCardAspectRatio(BuildContext context) {
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return 1.2;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return 1.3;
    } else if (ResponsiveHelper.isMobile(context)) {
      return 1.4;
    } else {
      return 1.5;
    }
  }
  
  /// Get responsive list item height
  static double getResponsiveListItemHeight(BuildContext context, double baseHeight) {
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return baseHeight * 0.9;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return baseHeight * 0.95;
    }
    return baseHeight;
  }
  
  /// Get responsive dialog width
  static double getResponsiveDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return screenWidth * 0.9;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return screenWidth * 0.85;
    } else if (ResponsiveHelper.isMobile(context)) {
      return screenWidth * 0.8;
    } else {
      return 400; // Fixed width for larger screens
    }
  }
  
  /// Get responsive bottom sheet height
  static double getResponsiveBottomSheetHeight(BuildContext context, double percent) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * (percent / 100);
  }
  
  /// Get responsive image size
  static double getResponsiveImageSize(BuildContext context, double baseSize) {
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      return baseSize * 0.75;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      return baseSize * 0.85;
    } else if (ResponsiveHelper.isMobile(context)) {
      return baseSize * 0.95;
    }
    return baseSize;
  }
  
  /// Get responsive gap between elements
  static double getResponsiveGap(BuildContext context, double baseGap) {
    return ResponsiveHelper.getResponsiveSpacing(context, baseGap);
  }
  
  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  /// Get responsive value based on orientation
  static double getResponsiveValue(
    BuildContext context, {
    required double portrait,
    required double landscape,
  }) {
    return isLandscape(context) ? landscape : portrait;
  }
  
  /// Get responsive max width for content containers
  static double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (ResponsiveHelper.isDesktop(context)) {
      return 1200;
    } else if (ResponsiveHelper.isTablet(context)) {
      return 800;
    } else {
      return screenWidth;
    }
  }
  
  /// Get responsive horizontal padding for screens
  static EdgeInsets getScreenHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double padding;
    
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      padding = screenWidth * 0.04;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      padding = screenWidth * 0.05;
    } else if (ResponsiveHelper.isMobile(context)) {
      padding = screenWidth * 0.06;
    } else {
      padding = 24;
    }
    
    return EdgeInsets.symmetric(horizontal: padding);
  }
  
  /// Get responsive vertical padding for screens
  static EdgeInsets getScreenVerticalPadding(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    double padding;
    
    if (ResponsiveHelper.isVerySmallScreen(context)) {
      padding = screenHeight * 0.02;
    } else if (ResponsiveHelper.isSmallScreen(context)) {
      padding = screenHeight * 0.025;
    } else {
      padding = screenHeight * 0.03;
    }
    
    return EdgeInsets.symmetric(vertical: padding);
  }
  
  /// Get responsive screen padding (both horizontal and vertical)
  static EdgeInsets getScreenPadding(BuildContext context) {
    return getScreenHorizontalPadding(context) + getScreenVerticalPadding(context);
  }
}

