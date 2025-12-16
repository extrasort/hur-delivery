import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../shared/widgets/responsive_screen_wrapper.dart';
import '../../../shared/widgets/responsive_container.dart';

/// Example screen demonstrating responsive design implementation
/// This shows how to make layouts adaptive to different screen sizes
class ResponsiveExampleScreen extends StatelessWidget {
  const ResponsiveExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: ResponsiveText(
          'Responsive Design Example',
          style: AppTextStyles.responsiveHeading3(context).copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ResponsiveScreenWrapper(
        padding: const EdgeInsets.all(16),
        scrollable: true,
        centerContent: false,
        child: ResponsiveColumn(
          spacing: 20,
          children: [
            // Logo Section - Responsive
            ResponsiveContainer(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ResponsivePadding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Responsive Logo
                    Container(
                      width: ResponsiveHelper.getResponsiveLogoSize(context, 120),
                      height: ResponsiveHelper.getResponsiveLogoSize(context, 120),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ResponsiveIcon(
                        Icons.local_shipping_rounded,
                        size: ResponsiveHelper.getResponsiveIconSize(context, 60),
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                    ResponsiveText(
                      'خدمة التوصيل السريع',
                      style: AppTextStyles.responsiveHeading2(context).copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                    ResponsiveText(
                      'منصة التوصيل للسائقين والتجار',
                      style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Features Section - Responsive Grid
            ResponsiveText(
              'المميزات الرئيسية',
              style: AppTextStyles.responsiveHeading3(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Responsive Grid Layout
            ResponsiveContainer(
              child: ResponsiveHelper.isVerySmallScreen(context)
                  ? _buildVerticalFeatureList(context)
                  : _buildHorizontalFeatureList(context),
            ),

            // Buttons Section - Responsive
            ResponsiveContainer(
              child: ResponsiveColumn(
                spacing: 12,
                children: [
                  ResponsiveButton(
                    text: 'تسجيل الدخول',
                    onPressed: () {},
                    width: ResponsiveHelper.getResponsiveWidth(context, 300),
                    height: ResponsiveHelper.getResponsiveButtonHeight(context, 50),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ResponsiveButton(
                    text: 'إنشاء حساب جديد',
                    onPressed: () {},
                    width: ResponsiveHelper.getResponsiveWidth(context, 300),
                    height: ResponsiveHelper.getResponsiveButtonHeight(context, 50),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Section - Responsive Cards
            ResponsiveText(
              'إحصائيات التطبيق',
              style: AppTextStyles.responsiveHeading3(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            ResponsiveContainer(
              child: ResponsiveHelper.isVerySmallScreen(context)
                  ? _buildVerticalStats(context)
                  : _buildHorizontalStats(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalFeatureList(BuildContext context) {
    return ResponsiveColumn(
      spacing: 12,
      children: _buildFeatureItems(context),
    );
  }

  Widget _buildHorizontalFeatureList(BuildContext context) {
    return ResponsiveRow(
      spacing: 12,
      children: _buildFeatureItems(context),
    );
  }

  List<Widget> _buildFeatureItems(BuildContext context) {
    final features = [
      {'icon': Icons.speed, 'title': 'توصيل سريع', 'desc': 'في أقل من 30 دقيقة'},
      {'icon': Icons.security, 'title': 'آمن ومضمون', 'desc': 'حماية كاملة للطلبات'},
      {'icon': Icons.support_agent, 'title': 'دعم 24/7', 'desc': 'خدمة عملاء على مدار الساعة'},
    ];

    return features.map((feature) {
      return ResponsiveCard(
        padding: const EdgeInsets.all(16),
        child: ResponsiveColumn(
          spacing: 8,
          children: [
            ResponsiveIcon(
              feature['icon'] as IconData,
              size: ResponsiveHelper.getResponsiveIconSize(context, 40),
              color: AppColors.primary,
            ),
            ResponsiveText(
              feature['title'] as String,
              style: AppTextStyles.responsiveBodyMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            ResponsiveText(
              feature['desc'] as String,
              style: AppTextStyles.responsiveBodySmall(context).copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildVerticalStats(BuildContext context) {
    return ResponsiveColumn(
      spacing: 12,
      children: _buildStatCards(context),
    );
  }

  Widget _buildHorizontalStats(BuildContext context) {
    return ResponsiveRow(
      spacing: 12,
      children: _buildStatCards(context),
    );
  }

  List<Widget> _buildStatCards(BuildContext context) {
    final stats = [
      {'value': '1000+', 'label': 'طلبات مكتملة'},
      {'value': '50+', 'label': 'سائق نشط'},
      {'value': '25+', 'label': 'تاجر مسجل'},
    ];

    return stats.map((stat) {
      return Expanded(
        child: ResponsiveCard(
          padding: const EdgeInsets.all(16),
          child: ResponsiveColumn(
            spacing: 8,
            children: [
              ResponsiveText(
                stat['value'] as String,
                style: AppTextStyles.responsiveHeading2(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              ResponsiveText(
                stat['label'] as String,
                style: AppTextStyles.responsiveBodySmall(context).copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}





