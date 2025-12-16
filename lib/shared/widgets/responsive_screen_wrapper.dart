import 'package:flutter/material.dart';
import '../../core/utils/responsive_helper.dart';
import 'responsive_container.dart';

class ResponsiveScreenWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool scrollable;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool centerContent;
  final bool useResponsivePadding;

  const ResponsiveScreenWrapper({
    super.key,
    required this.child,
    this.padding,
    this.scrollable = false,
    this.useSafeArea = true,
    this.backgroundColor,
    this.centerContent = false,
    this.useResponsivePadding = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Apply responsive padding
    if (useResponsivePadding && padding != null) {
      content = ResponsivePadding(
        padding: padding,
        child: content,
      );
    } else if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    // Center content if requested
    if (centerContent) {
      content = Center(child: content);
    }

    // Make scrollable if requested
    if (scrollable) {
      content = SingleChildScrollView(
        child: content,
      );
    }

    // Apply safe area if requested
    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    // Apply background color
    if (backgroundColor != null) {
      content = Container(
        color: backgroundColor,
        child: content,
      );
    }

    return content;
  }
}

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool useResponsivePadding;
  final bool useResponsiveMargin;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.useResponsivePadding = true,
    this.useResponsiveMargin = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: elevation,
      shape: borderRadius != null
          ? RoundedRectangleBorder(borderRadius: borderRadius!)
          : null,
      margin: useResponsiveMargin && margin != null
          ? EdgeInsets.only(
              left: ResponsiveHelper.getResponsiveSpacing(context, margin!.left),
              top: ResponsiveHelper.getResponsiveSpacing(context, margin!.top),
              right: ResponsiveHelper.getResponsiveSpacing(context, margin!.right),
              bottom: ResponsiveHelper.getResponsiveSpacing(context, margin!.bottom),
            )
          : margin,
      child: useResponsivePadding
          ? ResponsivePadding(
              padding: padding ?? ResponsiveHelper.getResponsiveCardPadding(context),
              child: child,
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
    );
  }
}

class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;
  final bool useResponsiveWidth;
  final bool useResponsiveHeight;
  final bool useResponsiveText;

  const ResponsiveButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
    this.useResponsiveWidth = true,
    this.useResponsiveHeight = true,
    this.useResponsiveText = true,
  });

  @override
  Widget build(BuildContext context) {
    double? finalWidth = width;
    double? finalHeight = height;

    if (useResponsiveWidth && width != null) {
      finalWidth = ResponsiveHelper.getResponsiveWidth(context, width!);
    }

    if (useResponsiveHeight && height != null) {
      finalHeight = ResponsiveHelper.getResponsiveButtonHeight(context, height!);
    }

    Widget button = ElevatedButton(
      onPressed: isEnabled && !isLoading ? onPressed : null,
      style: style,
      child: isLoading
          ? SizedBox(
              width: ResponsiveHelper.getResponsiveIconSize(context, 20),
              height: ResponsiveHelper.getResponsiveIconSize(context, 20),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : ResponsiveText(
              text,
              useResponsiveStyle: useResponsiveText,
            ),
    );

    if (finalWidth != null || finalHeight != null) {
      button = SizedBox(
        width: finalWidth,
        height: finalHeight,
        child: button,
      );
    }

    return button;
  }
}

class ResponsiveListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? contentPadding;
  final bool useResponsivePadding;

  const ResponsiveListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.useResponsivePadding = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      contentPadding: useResponsivePadding && contentPadding != null
          ? ResponsiveHelper.getResponsivePadding(
              context,
              horizontal: contentPadding!.horizontal,
              vertical: contentPadding!.vertical,
            )
          : contentPadding,
    );
  }
}

class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final bool useResponsiveHeight;

  const ResponsiveAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.useResponsiveHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null
          ? ResponsiveText(
              title!,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            )
          : null,
      actions: actions,
      leading: leading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        useResponsiveHeight ? 56 : kToolbarHeight,
      );
}





