import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? context.rh(56),
      child: OutlinedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: context.rp(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rs(12)),
          ),
          disabledForegroundColor: AppColors.textTertiary,
        ),
        child: isLoading
            ? SizedBox(
                width: context.ri(20),
                height: context.ri(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : ResponsiveText(
                text,
                style: AppTextStyles.buttonLarge.copyWith(
                  color: isEnabled ? AppColors.primary : AppColors.textTertiary,
                ).responsive(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
