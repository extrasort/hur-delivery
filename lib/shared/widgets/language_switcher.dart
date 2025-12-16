import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Language switcher widget that can be used in app bars or anywhere
class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;
  final Color? iconColor;
  final Color? textColor;
  final double? iconSize;
  final double? fontSize;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.iconColor,
    this.textColor,
    this.iconSize,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final loc = AppLocalizations.of(context);
    final isArabic = localeProvider.isArabic;

    return TextButton.icon(
      onPressed: () => localeProvider.toggleLocale(),
      icon: Icon(
        Icons.language,
        color: iconColor ?? (textColor ?? Colors.white),
        size: iconSize ?? 18,
      ),
      label: Text(
        isArabic ? 'EN' : loc.arabicChar,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? 14,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

/// Compact language switcher button for app bars
class LanguageSwitcherButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? foregroundColor;

  const LanguageSwitcherButton({
    super.key,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final loc = AppLocalizations.of(context);
    final isArabic = localeProvider.isArabic;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LanguageSwitcher(
        iconColor: foregroundColor ?? Colors.white,
        textColor: foregroundColor ?? Colors.white,
      ),
    );
  }
}

/// Language switcher as a list tile for settings screens
class LanguageSwitcherTile extends StatelessWidget {
  const LanguageSwitcherTile({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final loc = AppLocalizations.of(context);
    final isArabic = localeProvider.isArabic;

    return ListTile(
      leading: Icon(Icons.language, color: AppColors.primary),
      title: Text(loc.language),
      subtitle: Text(isArabic ? loc.languageArabic : loc.languageEnglish),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isArabic ? 'ع' : 'EN',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ],
      ),
      onTap: () => localeProvider.toggleLocale(),
    );
  }
}

