import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/localization/app_localizations.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String _content = '';
  bool _isLoading = true;

  bool get _isArabic {
    final loc = AppLocalizations.of(context);
    return loc.isArabic;
  }

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    
    try {
      final assetPath = _isArabic 
          ? 'legal/privacy_policy_ar.md'
          : 'legal/privacy_policy_en.md';
      
      final content = await rootBundle.loadString(assetPath);
      
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading privacy policy: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        setState(() {
          _content = loc.errorLoadingPrivacy;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleLanguage() {
    // Note: Language toggle functionality would need to be implemented
    // at the app level to change the locale. For now, this just reloads content.
    _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).privacyPolicy),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Language Toggle Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton.icon(
              onPressed: _toggleLanguage,
              icon: const Icon(Icons.language, color: Colors.white, size: 18),
              label: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    loc.isArabic ? 'EN' : loc.arabicChar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  );
                },
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Markdown(
                data: _content,
                selectable: true,
                padding: const EdgeInsets.all(20),
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFamily: 'Tajawal',
                  height: 1.5,
                ),
                h2: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                  height: 1.4,
                ),
                h3: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                  height: 1.3,
                ),
                p: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
                em: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  fontFamily: 'Tajawal',
                ),
                listBullet: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontFamily: 'Tajawal',
                ),
                blockquote: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Tajawal',
                ),
                code: TextStyle(
                  fontSize: 13,
                  backgroundColor: AppColors.surfaceVariant,
                  fontFamily: 'monospace',
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border,
                      width: 1.0,
                    ),
                  ),
                ),
                blockSpacing: 12.0,
                listIndent: 24.0,
                textAlign: _isArabic ? WrapAlignment.start : WrapAlignment.start,
              ),
              onTapLink: (text, href, title) async {
                if (href != null) {
                  final uri = Uri.parse(href);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
          ),
    );
  }
}

