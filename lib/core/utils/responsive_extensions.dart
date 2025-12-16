import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Extension methods on BuildContext for easier responsive access
extension ResponsiveContext on BuildContext {
  // Screen size detection
  bool get isVerySmallScreen => ResponsiveHelper.isVerySmallScreen(this);
  bool get isSmallScreen => ResponsiveHelper.isSmallScreen(this);
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  
  // Screen dimensions
  Size get screenSize => ResponsiveHelper.getScreenSize(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  
  // Responsive sizing
  double rw(double baseWidth) => ResponsiveHelper.getResponsiveWidth(this, baseWidth);
  double rh(double baseHeight) => ResponsiveHelper.getResponsiveSpacing(this, baseHeight);
  double rf(double baseFontSize) => ResponsiveHelper.getResponsiveFontSize(this, baseFontSize);
  double ri(double baseIconSize) => ResponsiveHelper.getResponsiveIconSize(this, baseIconSize);
  double rs(double baseSpacing) => ResponsiveHelper.getResponsiveSpacing(this, baseSpacing);
  
  // Form elements
  double get formElementWidth => ResponsiveHelper.getFormElementWidth(this);
  double get formElementHeight => ResponsiveHelper.getFormElementHeight(this);
  
  // Padding and spacing
  EdgeInsets rp({double horizontal = 16.0, double vertical = 16.0}) =>
      ResponsiveHelper.getResponsivePadding(this, horizontal: horizontal, vertical: vertical);
  
  EdgeInsets get cardPadding => ResponsiveHelper.getResponsiveCardPadding(this);
  EdgeInsets get safeAreaPadding => ResponsiveHelper.getSafeAreaPadding(this);
  
  // App bar and navigation
  double get appBarHeight => ResponsiveHelper.getResponsiveAppBarHeight(this);
  double get bottomNavHeight => ResponsiveHelper.getResponsiveBottomNavHeight(this);
  
  // Other
  double rLogo(double baseSize) => ResponsiveHelper.getResponsiveLogoSize(this, baseSize);
  double rFab() => ResponsiveHelper.getResponsiveFabSize(this);
  bool get hasNotch => ResponsiveHelper.hasNotch(this);
}

/// Extension for responsive EdgeInsets
extension ResponsiveEdgeInsets on EdgeInsets {
  EdgeInsets responsive(BuildContext context) {
    return ResponsiveHelper.getResponsivePadding(
      context,
      horizontal: horizontal,
      vertical: vertical,
    );
  }
}

/// Extension for responsive double values
extension ResponsiveDouble on double {
  double responsiveWidth(BuildContext context) =>
      ResponsiveHelper.getResponsiveWidth(context, this);
  
  double responsiveHeight(BuildContext context) =>
      ResponsiveHelper.getResponsiveSpacing(context, this);
  
  double responsiveFont(BuildContext context) =>
      ResponsiveHelper.getResponsiveFontSize(context, this);
  
  double responsiveIcon(BuildContext context) =>
      ResponsiveHelper.getResponsiveIconSize(context, this);
  
  double responsiveSpacing(BuildContext context) =>
      ResponsiveHelper.getResponsiveSpacing(context, this);
}

/// Extension for responsive TextStyle
extension ResponsiveTextStyle on TextStyle {
  TextStyle responsive(BuildContext context) {
    return copyWith(
      fontSize: fontSize != null
          ? ResponsiveHelper.getResponsiveFontSize(context, fontSize!)
          : null,
    );
  }
}

