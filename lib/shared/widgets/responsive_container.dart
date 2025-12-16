import 'package:flutter/material.dart';
import '../../core/utils/responsive_helper.dart';

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final bool useResponsivePadding;
  final bool useResponsiveMargin;
  final bool useResponsiveWidth;
  final bool useResponsiveHeight;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
    this.useResponsivePadding = true,
    this.useResponsiveMargin = true,
    this.useResponsiveWidth = true,
    this.useResponsiveHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsets finalPadding = padding ?? EdgeInsets.zero;
    EdgeInsets finalMargin = margin ?? EdgeInsets.zero;
    double? finalWidth = width;
    double? finalHeight = height;

    // Apply responsive adjustments
    if (useResponsivePadding && padding != null) {
      finalPadding = ResponsiveHelper.getResponsivePadding(
        context,
        horizontal: padding!.horizontal,
        vertical: padding!.vertical,
      );
    }

    if (useResponsiveMargin && margin != null) {
      finalMargin = EdgeInsets.only(
        left: ResponsiveHelper.getResponsiveSpacing(context, margin!.left),
        top: ResponsiveHelper.getResponsiveSpacing(context, margin!.top),
        right: ResponsiveHelper.getResponsiveSpacing(context, margin!.right),
        bottom: ResponsiveHelper.getResponsiveSpacing(context, margin!.bottom),
      );
    }

    if (useResponsiveWidth && width != null) {
      finalWidth = ResponsiveHelper.getResponsiveWidth(context, width!);
    }

    if (useResponsiveHeight && height != null) {
      finalHeight = ResponsiveHelper.getResponsiveButtonHeight(context, height!);
    }

    return Container(
      padding: finalPadding,
      margin: finalMargin,
      width: finalWidth,
      height: finalHeight,
      decoration: decoration,
      child: child,
    );
  }
}

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool useResponsive;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.padding,
    this.useResponsive = true,
  });

  @override
  Widget build(BuildContext context) {
    final finalPadding = useResponsive && padding != null
        ? ResponsiveHelper.getResponsivePadding(
            context,
            horizontal: padding!.horizontal,
            vertical: padding!.vertical,
          )
        : padding ?? EdgeInsets.zero;

    return Padding(
      padding: finalPadding,
      child: child,
    );
  }
}

class ResponsiveSizedBox extends StatelessWidget {
  final double? width;
  final double? height;
  final bool useResponsiveWidth;
  final bool useResponsiveHeight;

  const ResponsiveSizedBox({
    super.key,
    this.width,
    this.height,
    this.useResponsiveWidth = false,
    this.useResponsiveHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    double? finalWidth = width;
    double? finalHeight = height;

    if (useResponsiveWidth && width != null) {
      finalWidth = ResponsiveHelper.getResponsiveWidth(context, width!);
    }

    if (useResponsiveHeight && height != null) {
      finalHeight = ResponsiveHelper.getResponsiveSpacing(context, height!);
    }

    return SizedBox(
      width: finalWidth,
      height: finalHeight,
    );
  }
}

class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;
  final bool useResponsiveSpacing;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
    this.useResponsiveSpacing = true,
  });

  @override
  Widget build(BuildContext context) {
    final finalSpacing = useResponsiveSpacing && spacing != null
        ? ResponsiveHelper.getResponsiveSpacing(context, spacing!)
        : spacing ?? 0;

    final List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1 && finalSpacing > 0) {
        spacedChildren.add(SizedBox(height: finalSpacing));
      }
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;
  final bool useResponsiveSpacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
    this.useResponsiveSpacing = true,
  });

  @override
  Widget build(BuildContext context) {
    final finalSpacing = useResponsiveSpacing && spacing != null
        ? ResponsiveHelper.getResponsiveSpacing(context, spacing!)
        : spacing ?? 0;

    final List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1 && finalSpacing > 0) {
        spacedChildren.add(SizedBox(width: finalSpacing));
      }
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool useResponsiveStyle;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.useResponsiveStyle = true,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle? finalStyle = style;

    if (useResponsiveStyle && style != null) {
      finalStyle = style!.copyWith(
        fontSize: ResponsiveHelper.getResponsiveFontSize(context, style!.fontSize ?? 14),
      );
    }

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class ResponsiveIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final bool useResponsiveSize;

  const ResponsiveIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.useResponsiveSize = true,
  });

  @override
  Widget build(BuildContext context) {
    final finalSize = useResponsiveSize && size != null
        ? ResponsiveHelper.getResponsiveIconSize(context, size!)
        : size;

    return Icon(
      icon,
      size: finalSize,
      color: color,
    );
  }
}





