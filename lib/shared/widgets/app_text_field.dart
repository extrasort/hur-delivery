import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final TextDirection? textDirection;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ).responsive(context),
        ),
        SizedBox(height: context.rs(8)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: maxLines,
          minLines: minLines,
          onTap: onTap,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          textDirection: textDirection,
          style: AppTextStyles.bodyMedium.responsive(context),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixText: prefixText,
            suffixText: suffixText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            counterText: '', // Hide character counter
            contentPadding: context.rp(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
              borderSide: const BorderSide(color: AppColors.borderFocus, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            filled: true,
            fillColor: enabled ? AppColors.surfaceVariant : AppColors.border,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            errorStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}
