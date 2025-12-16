import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/localization/app_localizations.dart';

class MerchantWelcomeScreen extends StatefulWidget {
  const MerchantWelcomeScreen({super.key});

  @override
  State<MerchantWelcomeScreen> createState() => _MerchantWelcomeScreenState();
}

class _MerchantWelcomeScreenState extends State<MerchantWelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToMerchantDashboard();
    }
  }

  void _navigateToMerchantDashboard() {
    // Navigate to merchant dashboard
    context.go('/merchant-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return TextButton(
                onPressed: _navigateToMerchantDashboard,
                child: Text(
                  loc.skip,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page View with banners
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return _WelcomePage(
                        imagePath: 'assets/images/banner1.png',
                        title: loc.merchantWelcomeTitle1,
                        description: loc.merchantWelcomeDesc1,
                        screenHeight: screenHeight,
                        screenWidth: screenWidth,
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return _WelcomePage(
                        imagePath: 'assets/images/banner4.png',
                        title: loc.merchantWelcomeTitle2,
                        description: loc.merchantWelcomeDesc2,
                        screenHeight: screenHeight,
                        screenWidth: screenWidth,
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return _WelcomePage(
                        imagePath: 'assets/images/banner5.png',
                        title: loc.merchantWelcomeTitle3,
                        description: loc.merchantWelcomeDesc3,
                        screenHeight: screenHeight,
                        screenWidth: screenWidth,
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Page indicator
            Padding(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? AppColors.primary 
                          : AppColors.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            
            // Next/Get Started button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.02,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Text(
                        _currentPage < 2 ? loc.next : loc.startNow,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final double screenHeight;
  final double screenWidth;

  const _WelcomePage({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.04),
          
          // Text bubbles above
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title bubble
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: screenHeight * 0.025,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.065,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.03),
                
                // Description bubble
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: screenHeight * 0.025,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: screenWidth * 0.042,
                      color: Colors.grey.shade800,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: screenHeight * 0.03),
          
          // Banner image at the bottom
          Expanded(
            flex: 2,
            child: Container(
              width: screenWidth * 0.85,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }
}

